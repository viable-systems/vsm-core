defmodule VSMCore.Shared.Channel do
  @moduledoc """
  Implements the communication channels for the VSM subsystems.
  
  Channels provide pub/sub messaging infrastructure for inter-subsystem
  communication with proper isolation and flow control.
  """
  
  use GenServer
  require Logger
  
  @channels [
    :command_channel,
    :coordination_channel,
    :audit_channel,
    :algedonic_channel,
    :resource_bargain_channel
  ]
  
  # Client API
  
  @doc """
  Starts the channel registry.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Subscribes a process to a channel.
  """
  def subscribe(channel, pid \\ self()) do
    Registry.register(channel_registry(channel), channel, pid)
  end
  
  @doc """
  Unsubscribes a process from a channel.
  """
  def unsubscribe(channel, pid \\ self()) do
    Registry.unregister(channel_registry(channel), channel)
  end
  
  @doc """
  Publishes a message to a channel.
  """
  def publish(channel, message) do
    Registry.dispatch(channel_registry(channel), channel, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:channel_message, message})
      end
    end)
    
    # Log high-priority messages
    if message.type in [:alert, :emergency, :critical] do
      Logger.warning("High priority message on #{channel}: #{inspect(message.type)}")
    end
    
    :ok
  end
  
  @doc """
  Lists all subscribers to a channel.
  """
  def subscribers(channel) do
    Registry.lookup(channel_registry(channel), channel)
    |> Enum.map(fn {pid, _} -> pid end)
  end
  
  @doc """
  Gets statistics for a channel.
  """
  def stats(channel) do
    subscribers = subscribers(channel)
    
    %{
      channel: channel,
      subscriber_count: length(subscribers),
      subscribers: subscribers,
      active: true
    }
  end
  
  @doc """
  Lists all available channels.
  """
  def list_channels do
    @channels
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Start registries for each channel
    for channel <- @channels do
      Registry.start_link(
        keys: :duplicate,
        name: channel_registry(channel)
      )
    end
    
    # Start channel supervisors
    children = for channel <- @channels do
      %{
        id: {ChannelSupervisor, channel},
        start: {ChannelSupervisor, :start_link, [[name: channel_supervisor(channel)]]},
        type: :supervisor
      }
    end
    
    {:ok, %{channels: @channels, supervisors: children}}
  end
  
  # Private Functions
  
  defp channel_registry(channel) do
    :"#{channel}_registry"
  end
  
  defp channel_supervisor(channel) do
    :"#{channel}_supervisor"
  end
  
  # Channel Supervisor module
  defmodule ChannelSupervisor do
    use Supervisor
    
    def start_link(opts) do
      Supervisor.start_link(__MODULE__, opts, opts)
    end
    
    @impl true
    def init(_opts) do
      children = []
      Supervisor.init(children, strategy: :one_for_one)
    end
  end
end