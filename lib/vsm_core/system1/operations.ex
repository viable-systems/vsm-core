defmodule VSMCore.System1.Operations do
  @moduledoc """
  System 1 (Operations) - The implementation subsystem.
  
  Manages operational units that perform the primary activities of the system.
  Each unit handles transactions and measures variety in real-time.
  """
  
  use GenServer
  require Logger
  
  alias VSMCore.System1.{Unit, Transaction, Metrics}
  alias VSMCore.Shared.{Message, Channel}
  
  @subsystem_id :system1
  
  # Client API
  
  @doc """
  Starts the System 1 Operations server.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Registers a new operational unit.
  """
  def register_unit(server \\ __MODULE__, unit_config) do
    GenServer.call(server, {:register_unit, unit_config})
  end
  
  @doc """
  Processes a transaction through an appropriate operational unit.
  """
  def process_transaction(server \\ __MODULE__, transaction) do
    GenServer.call(server, {:process_transaction, transaction})
  end
  
  @doc """
  Gets the current variety measurement across all units.
  """
  def get_variety(server \\ __MODULE__) do
    GenServer.call(server, :get_variety)
  end
  
  @doc """
  Gets performance metrics for all operational units.
  """
  def get_metrics(server \\ __MODULE__) do
    GenServer.call(server, :get_metrics)
  end
  
  @doc """
  Lists all registered operational units.
  """
  def list_units(server \\ __MODULE__) do
    GenServer.call(server, :list_units)
  end
  
  @doc """
  Sends an algedonic signal directly to System 5.
  """
  def send_algedonic_signal(server \\ __MODULE__, signal) do
    GenServer.cast(server, {:send_algedonic, signal})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    # Set up ETS table for metrics
    :ets.new(:s1_metrics, [:named_table, :public, :set])
    
    # Initialize state
    state = %{
      units: %{},
      unit_supervisor: nil,
      metrics: %Metrics{},
      variety_log: [],
      config: Keyword.get(opts, :config, %{})
    }
    
    # Start the unit supervisor
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)
    
    # Subscribe to relevant channels
    VSMCore.Channels.CoordinationChannel.subscribe(@subsystem_id)
    VSMCore.Channels.AuditChannel.subscribe(@subsystem_id)
    VSMCore.Channels.CommandChannel.subscribe(@subsystem_id)
    
    Logger.info("System 1 Operations started")
    
    {:ok, %{state | unit_supervisor: supervisor}}
  end
  
  @impl true
  def handle_call({:register_unit, unit_config}, _from, state) do
    case start_unit(unit_config, state.unit_supervisor) do
      {:ok, unit_pid} ->
        unit_id = unit_config.id
        units = Map.put(state.units, unit_id, %{
          pid: unit_pid,
          config: unit_config,
          started_at: DateTime.utc_now()
        })
        
        Logger.info("Registered operational unit: #{unit_id}")
        
        # Notify System 2 about new unit
        Message.send(:system1, :system2, :coordination_channel, :unit_registered, %{
          unit_id: unit_id,
          capabilities: unit_config.capabilities
        })
        
        {:reply, {:ok, unit_id}, %{state | units: units}}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:process_transaction, transaction}, _from, state) do
    # Validate transaction first
    unless is_map(transaction) and Map.has_key?(transaction, :type) do
      Logger.warning("System1: Invalid transaction format - #{inspect(transaction)}")
      result = {:error, :invalid_transaction}
      # Record failed transaction metrics even for validation failures
      try do
        Metrics.record_transaction(transaction, result)
      rescue
        _ -> :ok  # Ignore metrics errors for invalid transactions
      end
      {:reply, result, state}
    else
      # Select appropriate unit based on transaction type
      case select_unit(transaction, state.units) do
        {:ok, unit_id, unit_info} ->
          # Forward to unit for processing
          result = Unit.process(unit_info.pid, transaction)
          
          # Update metrics
          Metrics.record_transaction(transaction, result)
          
          # Calculate variety
          variety = calculate_variety(transaction, result)
          state = update_variety_log(state, variety)
          
          {:reply, result, state}
          
        {:error, :no_suitable_unit} ->
          # Record failed transaction metrics and emit telemetry
          result = {:error, :no_suitable_unit}
          Metrics.record_transaction(transaction, result)
          
          # Request resource from System 3 (if resource bargain channel exists)
          try do
            Message.send(:system1, :system3, :resource_bargain_channel, :unit_request, %{
              transaction_type: transaction.type,
              required_capabilities: transaction.required_capabilities
            })
          rescue
            ArgumentError ->
              Logger.warning("System1: Resource bargain channel not available for unit request")
          end
          
          {:reply, result, state}
      end
    end
  end
  
  @impl true
  def handle_call(:get_variety, _from, state) do
    variety = calculate_current_variety(state.variety_log)
    {:reply, {:ok, variety}, state}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = Metrics.get_all()
    {:reply, {:ok, metrics}, state}
  end
  
  @impl true
  def handle_call(:list_units, _from, state) do
    units = Enum.map(state.units, fn {id, info} ->
      %{
        id: id,
        status: Unit.get_status(info.pid),
        config: info.config,
        started_at: info.started_at
      }
    end)
    
    {:reply, {:ok, units}, state}
  end
  
  @impl true
  def handle_cast({:send_algedonic, signal}, state) do
    # Send urgent signal directly to System 5
    Message.send(:system1, :system5, :algedonic_channel, :alert, signal)
    
    Logger.warning("Algedonic signal sent: #{inspect(signal)}")
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:channel_message, message}, state) do
    state = handle_channel_message(message, state)
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Handle unit failure
    case find_unit_by_pid(pid, state.units) do
      {unit_id, unit_info} ->
        Logger.error("Unit #{unit_id} crashed: #{inspect(reason)}")
        
        # Restart unit if configured
        if unit_info.config[:auto_restart] do
          case start_unit(unit_info.config, state.unit_supervisor) do
            {:ok, new_pid} ->
              units = Map.put(state.units, unit_id, %{unit_info | pid: new_pid})
              {:noreply, %{state | units: units}}
            _ ->
              units = Map.delete(state.units, unit_id)
              {:noreply, %{state | units: units}}
          end
        else
          units = Map.delete(state.units, unit_id)
          {:noreply, %{state | units: units}}
        end
        
      nil ->
        {:noreply, state}
    end
  end
  
  # Private Functions
  
  defp start_unit(config, supervisor) do
    spec = {Unit, config}
    DynamicSupervisor.start_child(supervisor, spec)
  end
  
  defp select_unit(transaction, units) do
    # Find unit with matching capabilities
    matching_units = Enum.filter(units, fn {_id, info} ->
      Unit.can_handle?(info.pid, transaction)
    end)
    
    case matching_units do
      [] -> {:error, :no_suitable_unit}
      units ->
        # Select unit with lowest load
        {unit_id, unit_info} = Enum.min_by(units, fn {_id, info} ->
          Unit.get_load(info.pid)
        end)
        {:ok, unit_id, unit_info}
    end
  end
  
  defp calculate_variety(transaction, result) do
    # Ashby's Law: variety of controller must match variety of system
    input_variety = Transaction.calculate_input_variety(transaction)
    output_variety = Transaction.calculate_output_variety(result)
    
    %{
      timestamp: DateTime.utc_now(),
      input: input_variety,
      output: output_variety,
      ratio: output_variety / max(input_variety, 1)
    }
  end
  
  defp update_variety_log(state, variety) do
    # Keep last 1000 variety measurements
    variety_log = [variety | state.variety_log] |> Enum.take(1000)
    %{state | variety_log: variety_log}
  end
  
  defp calculate_current_variety(variety_log) do
    case variety_log do
      [] -> %{input: 0, output: 0, ratio: 1.0}
      log ->
        recent = Enum.take(log, 100)
        
        avg_input = (Enum.map(recent, & &1.input) |> Enum.sum()) / length(recent)
        avg_output = (Enum.map(recent, & &1.output) |> Enum.sum()) / length(recent)
        avg_ratio = avg_output / max(avg_input, 1)
        
        %{
          input: avg_input,
          output: avg_output,
          ratio: avg_ratio,
          trend: calculate_trend(log)
        }
    end
  end
  
  defp calculate_trend(variety_log) when length(variety_log) < 2, do: :stable
  
  defp calculate_trend(variety_log) do
    recent = Enum.take(variety_log, 10) |> Enum.map(& &1.ratio)
    older = Enum.slice(variety_log, 10, 10) |> Enum.map(& &1.ratio)
    
    recent_avg = Enum.sum(recent) / length(recent)
    older_avg = if older == [], do: recent_avg, else: Enum.sum(older) / length(older)
    
    cond do
      recent_avg > older_avg * 1.1 -> :increasing
      recent_avg < older_avg * 0.9 -> :decreasing
      true -> :stable
    end
  end
  
  defp handle_channel_message(message, state) do
    case {message.channel, message.type} do
      {:command_channel, :execute} ->
        # Handle command from System 3
        handle_command(message.payload, state)
        
      {:coordination_channel, :coordinate} ->
        # Handle coordination request from System 2
        handle_coordination(message.payload, state)
        
      {:audit_channel, :audit_request} ->
        # Handle audit from System 3*
        handle_audit(message.payload, state)
        
      _ ->
        state
    end
  end
  
  defp handle_command(command, state) do
    Logger.info("Received command: #{inspect(command)}")
    
    # Execute command across relevant units
    Enum.each(state.units, fn {_id, info} ->
      Unit.execute_command(info.pid, command)
    end)
    
    state
  end
  
  defp handle_coordination(request, state) do
    Logger.debug("Handling coordination request: #{inspect(request)}")
    
    # Coordinate between units as requested by System 2
    case request.type do
      :sync_state ->
        # Synchronize state between units
        sync_unit_states(request.unit_ids, state)
        
      :load_balance ->
        # Rebalance load between units
        balance_unit_loads(request.unit_ids, state)
        
      _ ->
        :ok
    end
    
    state
  end
  
  defp handle_audit(audit_request, state) do
    Logger.info("Processing audit request: #{inspect(audit_request)}")
    
    # Collect audit information
    audit_data = %{
      units: Map.keys(state.units),
      metrics: Metrics.get_all(),
      variety: calculate_current_variety(state.variety_log),
      timestamp: DateTime.utc_now()
    }
    
    # Send audit response
    Message.send(:system1, :system3_star, :audit_channel, :audit_response, audit_data)
    
    state
  end
  
  defp find_unit_by_pid(pid, units) do
    Enum.find(units, fn {_id, info} -> info.pid == pid end)
  end
  
  defp sync_unit_states(unit_ids, state) do
    units = Enum.filter(state.units, fn {id, _} -> id in unit_ids end)
    
    # Gather states from all units
    states = Enum.map(units, fn {id, info} ->
      {id, Unit.get_state(info.pid)}
    end)
    
    # Merge and redistribute states
    merged_state = merge_unit_states(states)
    
    Enum.each(units, fn {_id, info} ->
      Unit.update_state(info.pid, merged_state)
    end)
  end
  
  defp merge_unit_states(states) do
    # Simple merge strategy - can be customized
    Enum.reduce(states, %{}, fn {_id, state}, acc ->
      Map.merge(acc, state, fn _k, v1, v2 ->
        # Prefer newer values
        if compare_timestamps(v1, v2) > 0, do: v1, else: v2
      end)
    end)
  end
  
  defp compare_timestamps(%{timestamp: t1}, %{timestamp: t2}) do
    DateTime.compare(t1, t2)
  end
  defp compare_timestamps(_, _), do: 0
  
  defp balance_unit_loads(unit_ids, state) do
    units = Enum.filter(state.units, fn {id, _} -> id in unit_ids end)
    
    # Get current loads
    loads = Enum.map(units, fn {id, info} ->
      {id, Unit.get_load(info.pid)}
    end)
    
    # Calculate average load
    total_load = Enum.reduce(loads, 0, fn {_id, load}, acc -> acc + load end)
    avg_load = total_load / length(loads)
    
    # Rebalance by migrating work
    Enum.each(loads, fn {id, load} ->
      cond do
        load > avg_load * 1.2 ->
          # Unit is overloaded, migrate some work
          Unit.migrate_work(state.units[id].pid, :out, load - avg_load)
          
        load < avg_load * 0.8 ->
          # Unit is underloaded, accept more work
          Unit.migrate_work(state.units[id].pid, :in, avg_load - load)
          
        true ->
          :ok
      end
    end)
  end
end