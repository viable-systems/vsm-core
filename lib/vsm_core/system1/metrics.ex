defmodule VSMCore.System1.Metrics do
  @moduledoc """
  Metrics collection and analysis for System 1 operations.
  
  Tracks performance metrics, variety measurements, and provides
  real-time insights into operational efficiency.
  """
  
  use GenServer
  require Logger
  
  alias VSMCore.System1.Transaction
  
  defstruct [
    :transactions_total,
    :transactions_success,
    :transactions_failed,
    :processing_times,
    :variety_measurements,
    :unit_metrics,
    :started_at,
    :config
  ]
  
  # Client API
  
  @doc """
  Starts the metrics server.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Records a transaction and its result.
  """
  def record_transaction(transaction, result, server \\ __MODULE__) do
    GenServer.cast(server, {:record_transaction, transaction, result})
  end
  
  @doc """
  Records metrics for a specific unit.
  """
  def record_unit_metrics(unit_id, metrics, server \\ __MODULE__) do
    GenServer.cast(server, {:record_unit_metrics, unit_id, metrics})
  end
  
  @doc """
  Records a variety measurement.
  """
  def record_variety(measurement, server \\ __MODULE__) do
    GenServer.cast(server, {:record_variety, measurement})
  end
  
  @doc """
  Gets all current metrics.
  """
  def get_all(server \\ __MODULE__) do
    GenServer.call(server, :get_all)
  end
  
  @doc """
  Gets metrics for a specific time window.
  """
  def get_window(window_minutes, server \\ __MODULE__) do
    GenServer.call(server, {:get_window, window_minutes})
  end
  
  @doc """
  Gets unit-specific metrics.
  """
  def get_unit_metrics(unit_id, server \\ __MODULE__) do
    GenServer.call(server, {:get_unit_metrics, unit_id})
  end
  
  @doc """
  Gets variety trend analysis.
  """
  def get_variety_trend(server \\ __MODULE__) do
    GenServer.call(server, :get_variety_trend)
  end
  
  @doc """
  Resets all metrics.
  """
  def reset(server \\ __MODULE__) do
    GenServer.cast(server, :reset)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    # Set up ETS tables for efficient metric storage
    :ets.new(:s1_metrics_transactions, [:named_table, :public, :ordered_set])
    :ets.new(:s1_metrics_units, [:named_table, :public, :set])
    :ets.new(:s1_metrics_variety, [:named_table, :public, :ordered_set])
    
    state = %__MODULE__{
      transactions_total: 0,
      transactions_success: 0,
      transactions_failed: 0,
      processing_times: [],
      variety_measurements: [],
      unit_metrics: %{},
      started_at: DateTime.utc_now(),
      config: Keyword.get(opts, :config, default_config())
    }
    
    # Schedule periodic metric aggregation
    if Map.get(state.config, :aggregation_interval) do
      schedule_aggregation(state.config.aggregation_interval)
    end
    
    # Schedule periodic cleanup
    if Map.get(state.config, :retention_period) do
      schedule_cleanup(state.config.retention_period)
    end
    
    Logger.info("System 1 Metrics collector started")
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_transaction, transaction, result}, state) do
    timestamp = DateTime.utc_now()
    
    # Update counters
    state = %{state | transactions_total: state.transactions_total + 1}
    
    state = case result do
      {:ok, _} ->
        %{state | transactions_success: state.transactions_success + 1}
        
      {:error, _} ->
        %{state | transactions_failed: state.transactions_failed + 1}
    end
    
    # Store transaction metric - handle missing fields gracefully
    metric = %{
      transaction_id: Map.get(transaction, :id, generate_transaction_id()),
      type: Map.get(transaction, :type, :unknown),
      priority: Map.get(transaction, :priority, :medium),
      result: elem(result, 0),
      timestamp: timestamp,
      source: Map.get(transaction, :source, :unknown)
    }
    
    :ets.insert(:s1_metrics_transactions, {timestamp, metric})
    
    # Emit telemetry event - use transaction_type for compatibility
    :telemetry.execute(
      [:vsm_core, :system1, :transaction],
      %{count: 1},
      %{
        transaction_type: Map.get(transaction, :type, :unknown),
        result: elem(result, 0),
        priority: Map.get(transaction, :priority, :medium)
      }
    )
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:record_unit_metrics, unit_id, metrics}, state) do
    timestamp = DateTime.utc_now()
    
    # Update unit metrics
    unit_metrics = Map.get(state.unit_metrics, unit_id, %{
      measurements: [],
      last_updated: timestamp
    })
    
    measurement = Map.put(metrics, :timestamp, timestamp)
    measurements = [measurement | unit_metrics.measurements] |> Enum.take(1000)
    
    updated_unit_metrics = %{
      measurements: measurements,
      last_updated: timestamp,
      current: metrics
    }
    
    :ets.insert(:s1_metrics_units, {unit_id, updated_unit_metrics})
    
    # Update processing times
    if metrics[:processing_time] do
      processing_times = [metrics.processing_time | state.processing_times]
      |> Enum.take(10000)
      
      state = %{state | processing_times: processing_times}
    end
    
    # Emit telemetry event
    :telemetry.execute(
      [:vsm_core, :system1, :unit],
      Map.take(metrics, [:processing_time, :load]),
      %{unit_id: unit_id}
    )
    
    unit_metrics_map = Map.put(state.unit_metrics, unit_id, updated_unit_metrics)
    
    {:noreply, %{state | unit_metrics: unit_metrics_map}}
  end
  
  @impl true
  def handle_cast({:record_variety, measurement}, state) do
    timestamp = DateTime.utc_now()
    
    # Store variety measurement
    variety_entry = Map.put(measurement, :timestamp, timestamp)
    :ets.insert(:s1_metrics_variety, {timestamp, variety_entry})
    
    # Keep recent measurements in state
    variety_measurements = [variety_entry | state.variety_measurements]
    |> Enum.take(1000)
    
    # Emit telemetry event
    :telemetry.execute(
      [:vsm_core, :system1, :variety],
      %{
        input: measurement.input,
        output: measurement.output,
        ratio: measurement.ratio
      },
      %{}
    )
    
    {:noreply, %{state | variety_measurements: variety_measurements}}
  end
  
  @impl true
  def handle_cast(:reset, state) do
    # Clear ETS tables
    :ets.delete_all_objects(:s1_metrics_transactions)
    :ets.delete_all_objects(:s1_metrics_units)
    :ets.delete_all_objects(:s1_metrics_variety)
    
    # Reset state
    new_state = %{state |
      transactions_total: 0,
      transactions_success: 0,
      transactions_failed: 0,
      processing_times: [],
      variety_measurements: [],
      unit_metrics: %{},
      started_at: DateTime.utc_now()
    }
    
    Logger.info("System 1 Metrics reset")
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_all, _from, state) do
    metrics = compile_metrics(state)
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call({:get_window, window_minutes}, _from, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -window_minutes * 60, :second)
    
    # Get transactions in window
    transactions = :ets.select(:s1_metrics_transactions, [
      {
        {:"$1", :"$2"},
        [{:>, :"$1", cutoff}],
        [:"$2"]
      }
    ])
    
    # Get variety in window
    variety = :ets.select(:s1_metrics_variety, [
      {
        {:"$1", :"$2"},
        [{:>, :"$1", cutoff}],
        [:"$2"]
      }
    ])
    
    window_metrics = %{
      window_minutes: window_minutes,
      transactions: analyze_transactions(transactions),
      variety: analyze_variety(variety),
      timestamp: DateTime.utc_now()
    }
    
    {:reply, window_metrics, state}
  end
  
  @impl true
  def handle_call({:get_unit_metrics, unit_id}, _from, state) do
    case :ets.lookup(:s1_metrics_units, unit_id) do
      [{^unit_id, metrics}] ->
        {:reply, {:ok, analyze_unit_metrics(metrics)}, state}
        
      [] ->
        {:reply, {:error, :unit_not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:get_variety_trend, _from, state) do
    trend = analyze_variety_trend(state.variety_measurements)
    {:reply, trend, state}
  end
  
  @impl true
  def handle_info(:aggregate_metrics, state) do
    # Perform periodic aggregation
    aggregate_stored_metrics()
    
    # Schedule next aggregation
    schedule_aggregation(state.config.aggregation_interval)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:cleanup_old_metrics, state) do
    # Clean up old metrics
    cleanup_old_metrics(state.config.retention_period)
    
    # Schedule next cleanup
    schedule_cleanup(state.config.retention_period)
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp default_config do
    %{
      aggregation_interval: :timer.minutes(5),
      retention_period: :timer.hours(24),
      percentiles: [50, 90, 95, 99]
    }
  end
  
  defp compile_metrics(state) do
    %{
      summary: %{
        uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
        transactions_total: state.transactions_total,
        transactions_success: state.transactions_success,
        transactions_failed: state.transactions_failed,
        success_rate: calculate_success_rate(state),
        current_units: map_size(state.unit_metrics)
      },
      performance: analyze_performance(state.processing_times),
      variety: analyze_variety(state.variety_measurements),
      units: compile_unit_summaries(state.unit_metrics),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp calculate_success_rate(%{transactions_total: 0}), do: 1.0
  
  defp calculate_success_rate(state) do
    state.transactions_success / state.transactions_total
  end
  
  defp analyze_performance(processing_times) when length(processing_times) == 0 do
    %{
      count: 0,
      mean: 0,
      median: 0,
      p90: 0,
      p95: 0,
      p99: 0,
      min: 0,
      max: 0
    }
  end
  
  defp analyze_performance(processing_times) do
    sorted = Enum.sort(processing_times)
    count = length(sorted)
    
    %{
      count: count,
      mean: Enum.sum(sorted) / count,
      median: percentile(sorted, 50),
      p90: percentile(sorted, 90),
      p95: percentile(sorted, 95),
      p99: percentile(sorted, 99),
      min: List.first(sorted),
      max: List.last(sorted)
    }
  end
  
  defp analyze_variety(variety_measurements) when length(variety_measurements) == 0 do
    %{
      current_ratio: 1.0,
      average_ratio: 1.0,
      input_variety: 0,
      output_variety: 0,
      efficiency: 1.0
    }
  end
  
  defp analyze_variety(variety_measurements) do
    recent = Enum.take(variety_measurements, 100)
    
    ratios = Enum.map(recent, & &1.ratio)
    inputs = Enum.map(recent, & &1.input)
    outputs = Enum.map(recent, & &1.output)
    
    %{
      current_ratio: List.first(ratios, 1.0),
      average_ratio: Enum.sum(ratios) / length(ratios),
      input_variety: Enum.sum(inputs) / length(inputs),
      output_variety: Enum.sum(outputs) / length(outputs),
      efficiency: calculate_variety_efficiency(recent)
    }
  end
  
  defp calculate_variety_efficiency(measurements) do
    # Efficiency is how well output variety matches input variety
    # Perfect efficiency = 1.0 (output matches input)
    
    avg_ratio = measurements
    |> Enum.map(& &1.ratio)
    |> Enum.sum()
    |> Kernel./(length(measurements))
    
    # Convert ratio to efficiency score
    cond do
      avg_ratio > 1.5 -> 0.7  # Over-controlling
      avg_ratio > 1.2 -> 0.9  # Slightly over-controlling
      avg_ratio > 0.8 -> 1.0  # Good match
      avg_ratio > 0.5 -> 0.8  # Under-controlling
      true -> 0.5             # Severely under-controlling
    end
  end
  
  defp analyze_variety_trend(measurements) when length(measurements) < 10 do
    %{trend: :insufficient_data, confidence: 0.0}
  end
  
  defp analyze_variety_trend(measurements) do
    # Use simple linear regression on recent ratios
    recent = Enum.take(measurements, 50)
    |> Enum.with_index()
    |> Enum.map(fn {m, i} -> {i, m.ratio} end)
    
    {slope, _intercept, r_squared} = linear_regression(recent)
    
    trend = cond do
      abs(slope) < 0.01 -> :stable
      slope > 0 -> :improving
      slope < 0 -> :degrading
    end
    
    %{
      trend: trend,
      slope: slope,
      confidence: r_squared,
      prediction: predict_future_ratio(slope, List.first(measurements).ratio)
    }
  end
  
  defp linear_regression(points) do
    n = length(points)
    
    {sum_x, sum_y, sum_xy, sum_x2} = Enum.reduce(points, {0, 0, 0, 0}, 
      fn {x, y}, {sx, sy, sxy, sx2} ->
        {sx + x, sy + y, sxy + x * y, sx2 + x * x}
      end)
    
    # Calculate slope and intercept
    denominator = n * sum_x2 - sum_x * sum_x
    
    if denominator == 0 do
      {0, sum_y / n, 0}
    else
      slope = (n * sum_xy - sum_x * sum_y) / denominator
      intercept = (sum_y - slope * sum_x) / n
      
      # Calculate R-squared
      y_mean = sum_y / n
      
      {ss_tot, ss_res} = Enum.reduce(points, {0, 0}, fn {x, y}, {tot, res} ->
        y_pred = slope * x + intercept
        {
          tot + :math.pow(y - y_mean, 2),
          res + :math.pow(y - y_pred, 2)
        }
      end)
      
      r_squared = if ss_tot == 0, do: 0, else: 1 - (ss_res / ss_tot)
      
      {slope, intercept, r_squared}
    end
  end
  
  defp predict_future_ratio(slope, current_ratio) do
    # Predict ratio 10 measurements in the future
    future_ratio = current_ratio + slope * 10
    
    # Bound between reasonable limits
    max(0.1, min(2.0, future_ratio))
  end
  
  defp compile_unit_summaries(unit_metrics) do
    Enum.map(unit_metrics, fn {unit_id, metrics} ->
      {unit_id, analyze_unit_metrics(metrics)}
    end)
    |> Map.new()
  end
  
  defp analyze_unit_metrics(metrics) do
    current = metrics.current || %{}
    measurements = metrics.measurements || []
    
    recent_loads = measurements
    |> Enum.take(100)
    |> Enum.map(& &1[:load] || 0)
    
    %{
      current_load: current[:load] || 0,
      average_load: calculate_average(recent_loads),
      transactions_processed: current[:transactions_processed] || 0,
      error_count: current[:error_count] || 0,
      last_updated: metrics.last_updated
    }
  end
  
  defp calculate_average([]), do: 0
  defp calculate_average(list), do: Enum.sum(list) / length(list)
  
  defp analyze_transactions(transactions) do
    total = length(transactions)
    
    if total == 0 do
      %{total: 0, by_type: %{}, by_result: %{}, by_priority: %{}}
    else
      by_type = Enum.group_by(transactions, & &1.type)
      |> Enum.map(fn {type, txns} -> {type, length(txns)} end)
      |> Map.new()
      
      by_result = Enum.group_by(transactions, & &1.result)
      |> Enum.map(fn {result, txns} -> {result, length(txns)} end)
      |> Map.new()
      
      by_priority = Enum.group_by(transactions, & &1.priority)
      |> Enum.map(fn {priority, txns} -> {priority, length(txns)} end)
      |> Map.new()
      
      %{
        total: total,
        by_type: by_type,
        by_result: by_result,
        by_priority: by_priority
      }
    end
  end
  
  defp percentile([], _p), do: 0
  
  defp percentile(sorted_list, p) do
    k = (length(sorted_list) - 1) * p / 100
    f = :erlang.trunc(k)
    c = k - f
    
    if f + 1 < length(sorted_list) do
      Enum.at(sorted_list, f) * (1 - c) + Enum.at(sorted_list, f + 1) * c
    else
      Enum.at(sorted_list, f)
    end
  end
  
  defp aggregate_stored_metrics do
    # This would aggregate metrics for long-term storage
    # For now, just log
    Logger.debug("Aggregating System 1 metrics")
  end
  
  defp cleanup_old_metrics(retention_period) do
    cutoff = DateTime.add(DateTime.utc_now(), -retention_period, :millisecond)
    
    # Clean up old transaction metrics
    :ets.select_delete(:s1_metrics_transactions, [
      {
        {:"$1", :_},
        [{:<, :"$1", cutoff}],
        [true]
      }
    ])
    
    # Clean up old variety metrics
    :ets.select_delete(:s1_metrics_variety, [
      {
        {:"$1", :_},
        [{:<, :"$1", cutoff}],
        [true]
      }
    ])
    
    Logger.debug("Cleaned up metrics older than #{cutoff}")
  end
  
  defp schedule_aggregation(interval) do
    Process.send_after(self(), :aggregate_metrics, interval)
  end
  
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup_old_metrics, interval)
  end
  
  defp generate_transaction_id do
    "txn_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
end