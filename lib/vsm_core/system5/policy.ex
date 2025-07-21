defmodule VSMCore.System5.Policy do
  @moduledoc """
  System 5 - Policy and Identity Management
  
  Responsible for:
  - Ultimate decision making  
  - Policy formulation and enforcement
  - Balancing internal and external demands
  """
  
  use GenServer
  require Logger
  
  alias VSMCore.Shared.Message
  
  @subsystem_id :system5
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple())
  end

  def set_identity(identity_config) do
    GenServer.call(via_tuple(), {:set_identity, identity_config})
  end

  def define_values(values) do
    GenServer.call(via_tuple(), {:define_values, values})
  end

  def make_decision(decision_request) do
    GenServer.call(via_tuple(), {:make_decision, decision_request})
  end

  def set_policy(policy_area, policy_details) do
    GenServer.call(via_tuple(), {:set_policy, policy_area, policy_details})
  end

  def evaluate_alignment(proposal) do
    GenServer.call(via_tuple(), {:evaluate_alignment, proposal})
  end

  def handle_crisis(crisis_info) do
    GenServer.call(via_tuple(), {:handle_crisis, crisis_info})
  end

  def get_organizational_state do
    GenServer.call(via_tuple(), :get_organizational_state)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("S5 Policy subsystem starting")
    
    state = %{
      id: @subsystem_id,
      identity: nil,
      values: nil,
      policies: %{},
      crisis_mode: false,
      decision_history: [],
      organizational_health: %{overall: 1.0},
      config: Keyword.get(opts, :config, %{})
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:set_identity, identity_config}, _from, state) do
    Logger.info("S5: Setting organizational identity")
    
    # Broadcast identity change to all systems
    message = Message.new(
      @subsystem_id,
      :all,
      :command_channel,
      :identity_update,
      %{identity: identity_config, action: :align_operations}
    )
    
    # Would send via CommandChannel
    Logger.info("Broadcasting identity update: #{inspect(message)}")
    
    {:reply, {:ok, identity_config}, %{state | identity: identity_config}}
  end

  @impl true  
  def handle_call({:make_decision, decision_request}, _from, state) do
    Logger.info("S5: Making decision on: #{inspect(decision_request)}")
    
    decision = %{
      id: "dec_#{System.unique_integer([:positive])}",
      request: decision_request,
      decision: :approved,
      timestamp: DateTime.utc_now(),
      rationale: "Policy-based decision"
    }
    
    {:reply, {:ok, decision}, state}
  end

  @impl true
  def handle_call(_request, _from, state) do
    {:reply, {:error, :not_implemented}, state}
  end

  @impl true
  def handle_info(_info, state) do
    {:noreply, state}
  end

  # Private Functions
  
  defp via_tuple do
    {:via, Registry, {VSMCore.Registry, @subsystem_id}}
  end
end