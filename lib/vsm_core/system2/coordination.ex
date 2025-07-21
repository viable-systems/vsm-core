defmodule VSMCore.System2.Coordination do
  @moduledoc """
  System 2 - Coordination subsystem GenServer implementation.
  """
  
  use GenServer
  require Logger

  @subsystem_id :system2

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple())
  end

  @impl true
  def init(_opts) do
    Logger.info("S2 Coordination subsystem starting")
    
    state = %{
      id: @subsystem_id,
      active_units: [],
      coordination_state: :normal
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call(_request, _from, state) do
    {:reply, {:error, :not_implemented}, state}
  end

  @impl true
  def handle_info(_info, state) do
    {:noreply, state}
  end

  defp via_tuple do
    {:via, Registry, {VSMCore.Registry, @subsystem_id}}
  end
end