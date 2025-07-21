defmodule VSMCore.Channels.AlgedonicChannel do
  @moduledoc """
  Algedonic Channel for VSM emergency signals (S1 -> S5 direct).
  """
  
  use GenServer
  require Logger
  
  @registry_name :algedonic_channel_registry

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def subscribe(subscriber_id) do
    Registry.register(@registry_name, :algedonic_channel, subscriber_id)
  end

  def unsubscribe(subscriber_id) do
    Registry.unregister(@registry_name, :algedonic_channel)
  end

  def send_message(message) do
    GenServer.cast(__MODULE__, {:send_message, message})
  end

  def broadcast(message) do
    GenServer.cast(__MODULE__, {:broadcast, message})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Start the registry for this channel if it doesn't exist
    result = case Registry.start_link(keys: :duplicate, name: @registry_name) do
      {:ok, _} -> 
        Logger.info("Algedonic Channel registry started")
        :ok
      {:error, {:already_started, _}} -> 
        Logger.debug("Algedonic Channel registry already exists")
        :ok
      error -> 
        Logger.error("Failed to start Algedonic Channel registry: #{inspect(error)}")
        error
    end
    
    case result do
      :ok ->
        Logger.info("Algedonic Channel started")
        {:ok, %{messages: [], subscribers: []}}
      error ->
        error
    end
  end

  @impl true
  def handle_cast({:send_message, message}, state) do
    case VSMCore.Shared.Message.validate(message) do
      :ok ->
        Logger.warning("ALGEDONIC SIGNAL: #{message.type} from #{message.from} - EMERGENCY ROUTING TO S5")
        
        # Route emergency signal directly to S5
        Registry.dispatch(@registry_name, :algedonic_channel, fn entries ->
          Enum.each(entries, fn {pid, subscriber_id} ->
            if subscriber_id == :system5 do
              send(pid, {:algedonic_signal, message})
            end
          end)
        end)
        
        {:noreply, %{state | messages: [message | state.messages]}}
        
      {:error, reason} ->
        Logger.warning("Algedonic Channel: Invalid emergency signal rejected - #{inspect(reason)}")
        {:noreply, state}
    end
  rescue
    error ->
      Logger.error("Algedonic Channel: Error processing emergency signal - #{inspect(error)}")
      {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast, message}, state) do
    case VSMCore.Shared.Message.validate(message) do
      :ok ->
        Logger.warning("Algedonic Channel: Broadcasting emergency signal #{message.type}")
        
        # Broadcast to all subscribers
        Registry.dispatch(@registry_name, :algedonic_channel, fn entries ->
          Enum.each(entries, fn {pid, _subscriber_id} ->
            send(pid, {:algedonic_signal, message})
          end)
        end)
        
        {:noreply, %{state | messages: [message | state.messages]}}
        
      {:error, reason} ->
        Logger.warning("Algedonic Channel: Invalid emergency broadcast rejected - #{inspect(reason)}")
        {:noreply, state}
    end
  rescue
    error ->
      Logger.error("Algedonic Channel: Error processing emergency broadcast - #{inspect(error)}")
      {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end