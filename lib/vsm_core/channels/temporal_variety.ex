defmodule VSMCore.Channels.TemporalVariety do
  @moduledoc """
  Temporal Variety Channel for VSM Core.
  
  This module implements a sophisticated temporal variety tracking system that monitors
  and analyzes variety across multiple timescales. It provides real-time variety tracking,
  pattern recognition, forecasting, and causal analysis capabilities.
  
  ## Features
  
  - Multi-timescale variety tracking (real-time to monthly)
  - Time-series analysis and pattern recognition
  - Predictive forecasting with anomaly detection
  - Causal chain analysis and temporal correlation
  - Aggregation and summarization across timescales
  - Visualization-ready data preparation
  
  ## Architecture
  
  The temporal variety channel consists of several specialized components:
  
  - `Timescales`: Manages variety calculations across different time windows
  - `Patterns`: Recognizes temporal patterns, cycles, and trends
  - `Forecasting`: Predicts future variety and detects anomalies
  - `Causality`: Analyzes causal relationships and temporal correlations
  - `Aggregation`: Performs multi-scale aggregation and summarization
  - `Visualization`: Prepares data for visual representation
  """
  
  use GenServer
  require Logger
  
  alias VSMCore.Channels.Temporal.{
    Timescales,
    Patterns,
    Forecasting,
    Causality,
    Aggregation,
    Visualization
  }
  
  @type variety_metric :: %{
    timestamp: DateTime.t(),
    value: float(),
    dimensions: map(),
    confidence: float()
  }
  
  @type timescale :: :real_time | :minute | :hour | :day | :week | :month
  
  @type state :: %{
    timescales: map(),
    patterns: map(),
    forecasts: map(),
    causal_chains: list(),
    buffer: list(),
    config: map()
  }
  
  # Client API
  
  @doc """
  Starts the temporal variety channel.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Records a variety measurement at the current time.
  """
  @spec record_variety(map()) :: :ok
  def record_variety(measurement) do
    GenServer.cast(__MODULE__, {:record_variety, measurement})
  end
  
  @doc """
  Gets variety metrics for a specific timescale.
  """
  @spec get_variety(timescale()) :: {:ok, list(variety_metric())} | {:error, term()}
  def get_variety(timescale) do
    GenServer.call(__MODULE__, {:get_variety, timescale})
  end
  
  @doc """
  Gets recognized patterns across all timescales.
  """
  @spec get_patterns() :: {:ok, map()} | {:error, term()}
  def get_patterns do
    GenServer.call(__MODULE__, :get_patterns)
  end
  
  @doc """
  Gets variety forecasts for specified horizons.
  """
  @spec get_forecasts(list(pos_integer())) :: {:ok, map()} | {:error, term()}
  def get_forecasts(horizons) do
    GenServer.call(__MODULE__, {:get_forecasts, horizons})
  end
  
  @doc """
  Gets causal relationships and correlations.
  """
  @spec get_causality() :: {:ok, map()} | {:error, term()}
  def get_causality do
    GenServer.call(__MODULE__, :get_causality)
  end
  
  @doc """
  Gets aggregated variety summary.
  """
  @spec get_summary() :: {:ok, map()} | {:error, term()}
  def get_summary do
    GenServer.call(__MODULE__, :get_summary)
  end
  
  @doc """
  Gets visualization-ready data.
  """
  @spec get_visualization_data(keyword()) :: {:ok, map()} | {:error, term()}
  def get_visualization_data(opts \\ []) do
    GenServer.call(__MODULE__, {:get_visualization_data, opts})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    config = build_config(opts)
    
    state = %{
      timescales: Timescales.initialize(config),
      patterns: %{},
      forecasts: %{},
      causal_chains: [],
      buffer: [],
      config: config
    }
    
    schedule_periodic_tasks(config)
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_variety, measurement}, state) do
    timestamp = DateTime.utc_now()
    
    metric = %{
      timestamp: timestamp,
      value: calculate_variety_value(measurement),
      dimensions: measurement,
      confidence: calculate_confidence(measurement)
    }
    
    new_state =
      state
      |> update_buffer(metric)
      |> update_timescales(metric)
      |> trigger_analysis_if_needed()
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:get_variety, timescale}, _from, state) do
    case Timescales.get_variety(state.timescales, timescale) do
      {:ok, metrics} -> {:reply, {:ok, metrics}, state}
      error -> {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:get_patterns, _from, state) do
    {:reply, {:ok, state.patterns}, state}
  end
  
  @impl true
  def handle_call({:get_forecasts, horizons}, _from, state) do
    forecasts = Forecasting.generate_forecasts(state.timescales, horizons)
    {:reply, {:ok, forecasts}, state}
  end
  
  @impl true
  def handle_call(:get_causality, _from, state) do
    causality_data = %{
      causal_chains: state.causal_chains,
      correlations: Causality.analyze_correlations(state.timescales)
    }
    {:reply, {:ok, causality_data}, state}
  end
  
  @impl true
  def handle_call(:get_summary, _from, state) do
    summary = Aggregation.generate_summary(state)
    {:reply, {:ok, summary}, state}
  end
  
  @impl true
  def handle_call({:get_visualization_data, opts}, _from, state) do
    viz_data = Visualization.prepare_data(state, opts)
    {:reply, {:ok, viz_data}, state}
  end
  
  @impl true
  def handle_info(:analyze_patterns, state) do
    new_patterns = Patterns.analyze(state.timescales)
    new_state = %{state | patterns: new_patterns}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:update_forecasts, state) do
    new_forecasts = Forecasting.update(state.timescales, state.patterns)
    new_state = %{state | forecasts: new_forecasts}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:analyze_causality, state) do
    new_chains = Causality.analyze_chains(state.buffer, state.patterns)
    new_state = %{state | causal_chains: new_chains}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:cleanup_buffer, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -state.config.buffer_retention_hours, :hour)
    
    new_buffer = Enum.filter(state.buffer, fn metric ->
      DateTime.compare(metric.timestamp, cutoff) == :gt
    end)
    
    {:noreply, %{state | buffer: new_buffer}}
  end
  
  # Private Functions
  
  defp build_config(opts) do
    %{
      buffer_size: Keyword.get(opts, :buffer_size, 10_000),
      buffer_retention_hours: Keyword.get(opts, :buffer_retention_hours, 168),
      pattern_analysis_interval: Keyword.get(opts, :pattern_analysis_interval, :timer.minutes(5)),
      forecast_update_interval: Keyword.get(opts, :forecast_update_interval, :timer.minutes(15)),
      causality_analysis_interval: Keyword.get(opts, :causality_analysis_interval, :timer.minutes(30)),
      cleanup_interval: Keyword.get(opts, :cleanup_interval, :timer.hours(1))
    }
  end
  
  defp schedule_periodic_tasks(config) do
    Process.send_after(self(), :analyze_patterns, config.pattern_analysis_interval)
    Process.send_after(self(), :update_forecasts, config.forecast_update_interval)
    Process.send_after(self(), :analyze_causality, config.causality_analysis_interval)
    Process.send_after(self(), :cleanup_buffer, config.cleanup_interval)
  end
  
  defp update_buffer(state, metric) do
    new_buffer = [metric | state.buffer] |> Enum.take(state.config.buffer_size)
    %{state | buffer: new_buffer}
  end
  
  defp update_timescales(state, metric) do
    new_timescales = Timescales.update(state.timescales, metric)
    %{state | timescales: new_timescales}
  end
  
  defp trigger_analysis_if_needed(state) do
    if should_trigger_analysis?(state) do
      send(self(), :analyze_patterns)
    end
    
    state
  end
  
  defp should_trigger_analysis?(state) do
    buffer_size = length(state.buffer)
    
    # Trigger analysis when buffer reaches certain thresholds
    rem(buffer_size, 100) == 0 and buffer_size > 0
  end
  
  defp calculate_variety_value(measurement) do
    # Shannon entropy calculation for variety
    dimensions = Map.keys(measurement)
    
    if Enum.empty?(dimensions) do
      0.0
    else
      total = Enum.sum(Map.values(measurement))
      
      measurement
      |> Enum.map(fn {_dim, count} ->
        if count > 0 and total > 0 do
          probability = count / total
          -probability * :math.log2(probability)
        else
          0.0
        end
      end)
      |> Enum.sum()
    end
  end
  
  defp calculate_confidence(measurement) do
    # Confidence based on sample size and data quality
    total_samples = Enum.sum(Map.values(measurement))
    
    cond do
      total_samples >= 1000 -> 0.95
      total_samples >= 100 -> 0.85
      total_samples >= 10 -> 0.70
      true -> 0.50
    end
  end
end