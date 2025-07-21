defmodule VSMCore.Channels.CommandChannel do
  @moduledoc """
  Command Channel for VSM hierarchical command flow (S5 -> S4 -> S3 -> S1).
  """
  
  use GenServer
  require Logger
  
  @registry_name :command_channel_registry

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def subscribe(subscriber_id) do
    Registry.register(@registry_name, :command_channel, subscriber_id)
  end

  def unsubscribe(subscriber_id) do
    Registry.unregister(@registry_name, :command_channel)
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
        Logger.info("Command Channel registry started")
        :ok
      {:error, {:already_started, _}} -> 
        Logger.debug("Command Channel registry already exists")
        :ok
      error -> 
        Logger.error("Failed to start Command Channel registry: #{inspect(error)}")
        error
    end
    
    case result do
      :ok ->
        Logger.info("Command Channel started")
        {:ok, %{messages: [], subscribers: []}}
      error ->
        error
    end
  end

  @impl true
  def handle_cast({:send_message, message}, state) do
    case VSMCore.Shared.Message.validate(message) do
      :ok ->
        Logger.debug("Command Channel: Routing message #{message.type} from #{message.from} to #{message.to}")
        
        # Route to specific subscriber
        Registry.dispatch(@registry_name, :command_channel, fn entries ->
          Enum.each(entries, fn {pid, subscriber_id} ->
            if subscriber_id == message.to do
              send(pid, {:channel_message, message})
            end
          end)
        end)
        
        {:noreply, %{state | messages: [message | state.messages]}}
        
      {:error, reason} ->
        Logger.warning("Command Channel: Invalid message rejected - #{inspect(reason)}")
        {:noreply, state}
    end
  rescue
    error ->
      Logger.error("Command Channel: Error processing message - #{inspect(error)}")
      {:noreply, state}
  end

  @impl true
  def handle_cast({:broadcast, message}, state) do
    case VSMCore.Shared.Message.validate(message) do
      :ok ->
        Logger.debug("Command Channel: Broadcasting message #{message.type} from #{message.from}")
        
        # Broadcast to all subscribers
        Registry.dispatch(@registry_name, :command_channel, fn entries ->
          Enum.each(entries, fn {pid, _subscriber_id} ->
            send(pid, {:channel_message, message})
          end)
        end)
        
        {:noreply, %{state | messages: [message | state.messages]}}
        
      {:error, reason} ->
        Logger.warning("Command Channel: Invalid broadcast message rejected - #{inspect(reason)}")
        {:noreply, state}
    end
  rescue
    error ->
      Logger.error("Command Channel: Error processing broadcast - #{inspect(error)}")
      {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end