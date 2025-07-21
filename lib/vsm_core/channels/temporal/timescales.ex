defmodule VSMCore.Channels.Temporal.Timescales do
  @moduledoc """
  Multi-timescale variety tracking for the temporal variety channel.
  
  This module manages variety calculations across different time windows,
  from real-time to monthly scales. Each timescale maintains its own
  sliding window of data and provides scale-specific variety metrics.
  
  ## Supported Timescales
  
  - **Real-time**: Sub-second measurements (1 second window)
  - **Minute**: Minute-level aggregations (5 minute window)
  - **Hour**: Hourly aggregations (1 hour window)
  - **Day**: Daily aggregations (24 hour window)
  - **Week**: Weekly aggregations (7 day window)
  - **Month**: Monthly aggregations (30 day window)
  """
  
  @type timescale :: :real_time | :minute | :hour | :day | :week | :month
  
  @type window :: %{
    scale: timescale(),
    duration: pos_integer(),
    data: list(map()),
    aggregates: map(),
    last_update: DateTime.t()
  }
  
  @type t :: %{required(timescale()) => window()}
  
  @timescale_configs %{
    real_time: %{duration: 1_000, max_points: 60},
    minute: %{duration: 60_000, max_points: 300},
    hour: %{duration: 3_600_000, max_points: 168},
    day: %{duration: 86_400_000, max_points: 90},
    week: %{duration: 604_800_000, max_points: 52},
    month: %{duration: 2_592_000_000, max_points: 24}
  }
  
  @doc """
  Initializes timescale windows with default configurations.
  """
  @spec initialize(map()) :: t()
  def initialize(config \\ %{}) do
    Enum.reduce(@timescale_configs, %{}, fn {scale, scale_config}, acc ->
      window = %{
        scale: scale,
        duration: scale_config.duration,
        data: [],
        aggregates: initialize_aggregates(),
        last_update: DateTime.utc_now()
      }
      
      Map.put(acc, scale, window)
    end)
  end
  
  @doc """
  Updates all timescale windows with a new metric.
  """
  @spec update(t(), map()) :: t()
  def update(timescales, metric) do
    Enum.reduce(timescales, %{}, fn {scale, window}, acc ->
      updated_window = update_window(window, metric)
      Map.put(acc, scale, updated_window)
    end)
  end
  
  @doc """
  Gets variety metrics for a specific timescale.
  """
  @spec get_variety(t(), timescale()) :: {:ok, list(map())} | {:error, :invalid_timescale}
  def get_variety(timescales, scale) do
    case Map.get(timescales, scale) do
      nil -> {:error, :invalid_timescale}
      window -> {:ok, calculate_variety_metrics(window)}
    end
  end
  
  @doc """
  Gets aggregated statistics across all timescales.
  """
  @spec get_statistics(t()) :: map()
  def get_statistics(timescales) do
    Enum.reduce(timescales, %{}, fn {scale, window}, acc ->
      stats = %{
        count: length(window.data),
        variety: calculate_current_variety(window),
        trend: calculate_trend(window),
        volatility: calculate_volatility(window),
        aggregates: window.aggregates
      }
      
      Map.put(acc, scale, stats)
    end)
  end
  
  @doc """
  Performs cross-scale analysis to identify multi-timescale patterns.
  """
  @spec cross_scale_analysis(t()) :: map()
  def cross_scale_analysis(timescales) do
    scales = [:real_time, :minute, :hour, :day, :week, :month]
    
    %{
      alignment: calculate_scale_alignment(timescales, scales),
      propagation: analyze_variety_propagation(timescales, scales),
      coherence: calculate_temporal_coherence(timescales, scales)
    }
  end
  
  # Private Functions
  
  defp initialize_aggregates do
    %{
      min: nil,
      max: nil,
      mean: 0.0,
      variance: 0.0,
      momentum: 0.0,
      acceleration: 0.0
    }
  end
  
  defp update_window(window, metric) do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, -window.duration, :millisecond)
    
    # Add new metric and remove old ones
    updated_data =
      [metric | window.data]
      |> Enum.filter(fn m -> DateTime.compare(m.timestamp, cutoff) == :gt end)
      |> Enum.take(@timescale_configs[window.scale].max_points)
    
    # Update aggregates
    updated_aggregates = update_aggregates(window.aggregates, updated_data)
    
    %{window |
      data: updated_data,
      aggregates: updated_aggregates,
      last_update: now
    }
  end
  
  defp update_aggregates(aggregates, data) do
    if Enum.empty?(data) do
      initialize_aggregates()
    else
      values = Enum.map(data, & &1.value)
      
      %{
        min: Enum.min(values),
        max: Enum.max(values),
        mean: calculate_mean(values),
        variance: calculate_variance(values),
        momentum: calculate_momentum(data),
        acceleration: calculate_acceleration(data)
      }
    end
  end
  
  defp calculate_variety_metrics(window) do
    window.data
    |> Enum.chunk_every(10, 1, :discard)
    |> Enum.map(fn chunk ->
      %{
        timestamp: List.last(chunk).timestamp,
        variety: calculate_chunk_variety(chunk),
        confidence: calculate_chunk_confidence(chunk),
        dimensions: aggregate_dimensions(chunk)
      }
    end)
  end
  
  defp calculate_current_variety(window) do
    if Enum.empty?(window.data) do
      0.0
    else
      recent_data = Enum.take(window.data, 10)
      calculate_chunk_variety(recent_data)
    end
  end
  
  defp calculate_chunk_variety(chunk) do
    # Aggregate variety across the chunk
    chunk
    |> Enum.map(& &1.value)
    |> calculate_mean()
  end
  
  defp calculate_chunk_confidence(chunk) do
    # Average confidence across the chunk
    chunk
    |> Enum.map(& &1.confidence)
    |> calculate_mean()
  end
  
  defp aggregate_dimensions(chunk) do
    # Merge dimensions across the chunk
    Enum.reduce(chunk, %{}, fn metric, acc ->
      Map.merge(acc, metric.dimensions, fn _k, v1, v2 -> v1 + v2 end)
    end)
  end
  
  defp calculate_trend(window) do
    if length(window.data) < 2 do
      0.0
    else
      # Simple linear regression for trend
      indexed_values =
        window.data
        |> Enum.map(& &1.value)
        |> Enum.with_index()
      
      {sum_x, sum_y, sum_xy, sum_x2, n} =
        Enum.reduce(indexed_values, {0, 0, 0, 0, 0}, fn {y, x}, {sx, sy, sxy, sx2, count} ->
          {sx + x, sy + y, sxy + x * y, sx2 + x * x, count + 1}
        end)
      
      if n > 0 and sum_x2 * n - sum_x * sum_x != 0 do
        (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
      else
        0.0
      end
    end
  end
  
  defp calculate_volatility(window) do
    if window.aggregates.variance > 0 do
      :math.sqrt(window.aggregates.variance)
    else
      0.0
    end
  end
  
  defp calculate_momentum(data) do
    if length(data) < 2 do
      0.0
    else
      recent = Enum.take(data, 5) |> Enum.map(& &1.value) |> calculate_mean()
      older = Enum.take(data, -5) |> Enum.map(& &1.value) |> calculate_mean()
      
      recent - older
    end
  end
  
  defp calculate_acceleration(data) do
    if length(data) < 3 do
      0.0
    else
      # Rate of change of momentum
      recent_momentum = data |> Enum.take(10) |> calculate_momentum()
      older_momentum = data |> Enum.drop(10) |> Enum.take(10) |> calculate_momentum()
      
      recent_momentum - older_momentum
    end
  end
  
  defp calculate_mean(values) do
    if Enum.empty?(values) do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end
  
  defp calculate_variance(values) do
    if length(values) < 2 do
      0.0
    else
      mean = calculate_mean(values)
      
      sum_squared_diff =
        values
        |> Enum.map(fn v -> (v - mean) * (v - mean) end)
        |> Enum.sum()
      
      sum_squared_diff / (length(values) - 1)
    end
  end
  
  defp calculate_scale_alignment(timescales, scales) do
    # Check if variety trends align across scales
    trends =
      scales
      |> Enum.map(fn scale ->
        window = Map.get(timescales, scale)
        {scale, calculate_trend(window)}
      end)
    
    # Calculate correlation between consecutive scales
    scales
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [s1, s2] ->
      t1 = Keyword.get(trends, s1, 0.0)
      t2 = Keyword.get(trends, s2, 0.0)
      
      alignment = if t1 * t2 > 0, do: 1.0, else: -1.0
      {{s1, s2}, alignment}
    end)
    |> Enum.into(%{})
  end
  
  defp analyze_variety_propagation(timescales, scales) do
    # Analyze how variety changes propagate across scales
    scales
    |> Enum.map(fn scale ->
      window = Map.get(timescales, scale)
      
      {scale, %{
        momentum: window.aggregates.momentum,
        acceleration: window.aggregates.acceleration,
        lag: estimate_propagation_lag(window)
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp calculate_temporal_coherence(timescales, scales) do
    # Measure how coherent variety patterns are across scales
    varieties =
      scales
      |> Enum.map(fn scale ->
        window = Map.get(timescales, scale)
        calculate_current_variety(window)
      end)
    
    mean_variety = calculate_mean(varieties)
    variance = calculate_variance(varieties)
    
    if mean_variety > 0 do
      1.0 - (:math.sqrt(variance) / mean_variety)
    else
      0.0
    end
  end
  
  defp estimate_propagation_lag(window) do
    # Estimate lag based on acceleration patterns
    if abs(window.aggregates.acceleration) > 0.01 do
      window.duration / 2
    else
      window.duration
    end
  end
end