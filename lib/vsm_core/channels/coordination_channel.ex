defmodule VSMCore.Channels.CoordinationChannel do
  @moduledoc """
  Coordination Channel for VSM lateral coordination (S2 <-> S1).
  """
  
  use GenServer
  require Logger
  
  @registry_name :coordination_channel_registry

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def subscribe(subscriber_id) do
    Registry.register(@registry_name, :coordination_channel, subscriber_id)
  end

  def unsubscribe(subscriber_id) do
    Registry.unregister(@registry_name, :coordination_channel)
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
        Logger.info("Coordination Channel registry started")
        :ok
      {:error, {:already_started, _}} -> 
        Logger.debug("Coordination Channel registry already exists")
        :ok
      error -> 
        Logger.error("Failed to start Coordination Channel registry: #{inspect(error)}")
        error
    end
    
    case result do
      :ok ->
        Logger.info("Coordination Channel started")
        {:ok, %{messages: [], subscribers: []}}
      error ->
        error
    end
  end

  @impl true
  def handle_cast({:send_message, message}, state) do
    case VSMCore.Shared.Message.validate(message) do
      :ok ->
        Logger.debug("Coordination Channel: Routing message #{message.type} from #{message.from} to #{message.to}")
        
        # Route to specific subscriber
        Registry.dispatch(@registry_name, :coordination_channel, fn entries ->
          Enum.each(entries, fn {pid, subscriber_id} ->
            if subscriber_id == message.to do
              send(pid, {:channel_message, message})
            end
          end)
        end)
        
        {:noreply, %{state | messages: [message | state.messages]}}
        
      {:error, reason} ->
        Logger.warning("Coordination Channel: Invalid message rejected - #{inspect(reason)}")
        {:noreply, state}
    end
  rescue
    error ->
      Logger.error("Coordination Channel: Error processing message - #{inspect(error)}")
      {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast, message}, state) do
    case VSMCore.Shared.Message.validate(message) do
      :ok ->
        Logger.debug("Coordination Channel: Broadcasting message #{message.type} from #{message.from}")
        
        # Broadcast to all subscribers
        Registry.dispatch(@registry_name, :coordination_channel, fn entries ->
          Enum.each(entries, fn {pid, _subscriber_id} ->
            send(pid, {:channel_message, message})
          end)
        end)
        
        {:noreply, %{state | messages: [message | state.messages]}}
        
      {:error, reason} ->
        Logger.warning("Coordination Channel: Invalid broadcast message rejected - #{inspect(reason)}")
        {:noreply, state}
    end
  rescue
    error ->
      Logger.error("Coordination Channel: Error processing broadcast - #{inspect(error)}")
      {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end