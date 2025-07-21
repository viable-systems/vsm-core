defmodule VSMCore.System1.Unit do
  @moduledoc """
  Represents an individual operational unit within System 1.
  
  Each unit is an autonomous agent that processes transactions,
  maintains its own state, and coordinates with other units.
  """
  
  use GenServer
  require Logger
  
  alias VSMCore.System1.{Transaction, Metrics}
  alias VSMCore.Shared.Message
  
  defstruct [
    :id,
    :capabilities,
    :state,
    :load,
    :transactions_processed,
    :error_count,
    :started_at,
    :config
  ]
  
  # Client API
  
  @doc """
  Starts a new operational unit.
  """
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end
  
  @doc """
  Processes a transaction through this unit.
  """
  def process(unit, transaction) do
    GenServer.call(unit, {:process, transaction})
  end
  
  @doc """
  Checks if this unit can handle a given transaction.
  """
  def can_handle?(unit, transaction) do
    GenServer.call(unit, {:can_handle?, transaction})
  end
  
  @doc """
  Gets the current load of this unit.
  """
  def get_load(unit) do
    GenServer.call(unit, :get_load)
  end
  
  @doc """
  Gets the current status of this unit.
  """
  def get_status(unit) do
    GenServer.call(unit, :get_status)
  end
  
  @doc """
  Gets the current state of this unit.
  """
  def get_state(unit) do
    GenServer.call(unit, :get_state)
  end
  
  @doc """
  Updates the state of this unit.
  """
  def update_state(unit, new_state) do
    GenServer.call(unit, {:update_state, new_state})
  end
  
  @doc """
  Executes a command on this unit.
  """
  def execute_command(unit, command) do
    GenServer.cast(unit, {:execute_command, command})
  end
  
  @doc """
  Migrates work in or out of this unit.
  """
  def migrate_work(unit, direction, amount) do
    GenServer.cast(unit, {:migrate_work, direction, amount})
  end
  
  # Server Callbacks
  
  @impl true
  def init(config) do
    # Register with process registry
    if config[:id] do
      Registry.register(:s1_unit_registry, config.id, self())
    end
    
    state = %__MODULE__{
      id: config[:id] || generate_unit_id(),
      capabilities: config[:capabilities] || [],
      state: %{},
      load: 0,
      transactions_processed: 0,
      error_count: 0,
      started_at: DateTime.utc_now(),
      config: config
    }
    
    # Schedule periodic health checks
    if config[:health_check_interval] do
      schedule_health_check(config[:health_check_interval])
    end
    
    Logger.info("Unit #{state.id} started with capabilities: #{inspect(state.capabilities)}")
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:process, transaction}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    # Process the transaction
    result = try do
      process_transaction(transaction, state)
    rescue
      error ->
        Logger.error("Error processing transaction: #{inspect(error)}")
        {:error, error}
    end
    
    # Update metrics
    processing_time = System.monotonic_time(:microsecond) - start_time
    
    state = case result do
      {:ok, _} ->
        %{state | 
          transactions_processed: state.transactions_processed + 1,
          load: update_load(state.load, :decrease)
        }
        
      {:error, _} ->
        %{state | 
          error_count: state.error_count + 1,
          load: update_load(state.load, :decrease)
        }
    end
    
    # Record metrics
    Metrics.record_unit_metrics(state.id, %{
      processing_time: processing_time,
      load: state.load,
      transactions_processed: state.transactions_processed,
      error_count: state.error_count
    })
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:can_handle?, transaction}, _from, state) do
    can_handle = transaction_matches_capabilities?(transaction, state.capabilities)
    {:reply, can_handle, state}
  end
  
  @impl true
  def handle_call(:get_load, _from, state) do
    {:reply, state.load, state}
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      id: state.id,
      operational: true,
      load: state.load,
      health: calculate_health(state),
      uptime: DateTime.diff(DateTime.utc_now(), state.started_at),
      transactions_processed: state.transactions_processed,
      error_rate: calculate_error_rate(state)
    }
    
    {:reply, status, state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end
  
  @impl true
  def handle_call({:update_state, new_state}, _from, state) do
    merged_state = Map.merge(state.state, new_state)
    {:reply, :ok, %{state | state: merged_state}}
  end
  
  @impl true
  def handle_cast({:execute_command, command}, state) do
    state = execute_unit_command(command, state)
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:migrate_work, direction, amount}, state) do
    state = case direction do
      :in ->
        # Accept more work
        %{state | load: state.load + amount}
        
      :out ->
        # Reduce work
        %{state | load: max(0, state.load - amount)}
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:health_check, state) do
    # Perform health check
    health = calculate_health(state)
    
    if health < 0.5 do
      # Unit is unhealthy, send algedonic signal
      Message.send(state.id, :system5, :algedonic_channel, :unit_health_critical, %{
        unit_id: state.id,
        health: health,
        metrics: %{
          error_rate: calculate_error_rate(state),
          load: state.load
        }
      })
    end
    
    # Schedule next health check
    schedule_health_check(state.config[:health_check_interval])
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp generate_unit_id do
    "unit_#{:erlang.unique_integer([:positive])}"
  end
  
  defp process_transaction(transaction, state) do
    # Simulate processing based on capabilities
    cond do
      # Check if unit is overloaded
      state.load > 0.9 ->
        {:error, :overloaded}
        
      # Check if transaction matches capabilities
      not transaction_matches_capabilities?(transaction, state.capabilities) ->
        {:error, :capability_mismatch}
        
      # Process based on transaction type
      true ->
        result = case transaction.type do
          :compute ->
            process_compute_transaction(transaction, state)
            
          :data ->
            process_data_transaction(transaction, state)
            
          :io ->
            process_io_transaction(transaction, state)
            
          _ ->
            process_generic_transaction(transaction, state)
        end
        
        {:ok, result}
    end
  end
  
  defp transaction_matches_capabilities?(transaction, capabilities) do
    required = transaction.required_capabilities || []
    Enum.all?(required, &(&1 in capabilities))
  end
  
  defp process_compute_transaction(transaction, _state) do
    # Simulate computation
    input = transaction.payload
    
    %{
      transaction_id: transaction.id,
      result: perform_computation(input),
      processed_at: DateTime.utc_now(),
      processing_node: node()
    }
  end
  
  defp process_data_transaction(transaction, state) do
    # Simulate data processing
    operation = transaction.payload.operation
    data = transaction.payload.data
    
    result = case operation do
      :store ->
        store_data(data, state)
        
      :retrieve ->
        retrieve_data(data, state)
        
      :transform ->
        transform_data(data, state)
        
      _ ->
        {:error, :unknown_operation}
    end
    
    %{
      transaction_id: transaction.id,
      result: result,
      processed_at: DateTime.utc_now()
    }
  end
  
  defp process_io_transaction(transaction, _state) do
    # Simulate I/O operation
    %{
      transaction_id: transaction.id,
      result: {:ok, "I/O operation completed"},
      processed_at: DateTime.utc_now()
    }
  end
  
  defp process_generic_transaction(transaction, _state) do
    # Generic processing
    %{
      transaction_id: transaction.id,
      result: {:ok, transaction.payload},
      processed_at: DateTime.utc_now()
    }
  end
  
  defp perform_computation(input) do
    # Simulate some computation
    case input do
      %{operation: :factorial, n: n} when is_integer(n) and n >= 0 ->
        factorial(n)
        
      %{operation: :fibonacci, n: n} when is_integer(n) and n >= 0 ->
        fibonacci(n)
        
      _ ->
        :crypto.hash(:sha256, :erlang.term_to_binary(input))
    end
  end
  
  defp factorial(0), do: 1
  defp factorial(n), do: n * factorial(n - 1)
  
  defp fibonacci(0), do: 0
  defp fibonacci(1), do: 1
  defp fibonacci(n), do: fibonacci(n - 1) + fibonacci(n - 2)
  
  defp store_data(data, state) do
    key = :crypto.hash(:sha256, :erlang.term_to_binary(data)) |> Base.encode16()
    :ets.insert(:s1_data_store, {key, data})
    {:ok, key}
  end
  
  defp retrieve_data(key, _state) do
    case :ets.lookup(:s1_data_store, key) do
      [{^key, data}] -> {:ok, data}
      [] -> {:error, :not_found}
    end
  end
  
  defp transform_data(data, _state) do
    # Simple transformation
    transformed = data
    |> Enum.map(fn {k, v} -> {String.upcase(to_string(k)), v} end)
    |> Map.new()
    
    {:ok, transformed}
  end
  
  defp update_load(current_load, :increase) do
    min(1.0, current_load + 0.1)
  end
  
  defp update_load(current_load, :decrease) do
    max(0.0, current_load - 0.05)
  end
  
  defp calculate_health(state) do
    # Health score based on error rate and load
    error_rate = calculate_error_rate(state)
    load_factor = 1.0 - state.load
    
    # Weighted average
    (load_factor * 0.4 + (1.0 - error_rate) * 0.6)
  end
  
  defp calculate_error_rate(state) do
    total = state.transactions_processed + state.error_count
    if total == 0, do: 0.0, else: state.error_count / total
  end
  
  defp execute_unit_command(command, state) do
    case command.action do
      :reset_metrics ->
        %{state | 
          transactions_processed: 0,
          error_count: 0,
          load: 0
        }
        
      :update_capabilities ->
        %{state | capabilities: command.capabilities}
        
      :set_config ->
        %{state | config: Map.merge(state.config, command.config)}
        
      _ ->
        Logger.warning("Unknown command: #{inspect(command)}")
        state
    end
  end
  
  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end
end