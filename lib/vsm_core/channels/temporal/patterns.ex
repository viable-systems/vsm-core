defmodule VSMCore.Channels.Temporal.Patterns do
  @moduledoc """
  Temporal pattern recognition for the variety channel.
  
  This module identifies and analyzes temporal patterns in variety data,
  including cyclic patterns, trends, seasonality, and anomalies. It uses
  various time-series analysis techniques to extract meaningful patterns
  across different timescales.
  
  ## Pattern Types
  
  - **Cyclic Patterns**: Repeating patterns with regular or irregular periods
  - **Trends**: Long-term directional movements (increasing/decreasing)
  - **Seasonality**: Patterns that repeat at fixed intervals
  - **Anomalies**: Unusual spikes or drops in variety
  - **Regime Changes**: Structural breaks in the time series
  """
  
  alias VSMCore.Channels.Temporal.Timescales
  
  @type pattern_type :: :cyclic | :trend | :seasonal | :anomaly | :regime_change
  
  @type pattern :: %{
    type: pattern_type(),
    timescale: atom(),
    confidence: float(),
    parameters: map(),
    detected_at: DateTime.t(),
    description: String.t()
  }
  
  @type analysis_result :: %{
    patterns: list(pattern()),
    dominant_pattern: pattern() | nil,
    pattern_strength: float(),
    next_expected: map()
  }
  
  @doc """
  Analyzes timescale data to identify temporal patterns.
  """
  @spec analyze(Timescales.t()) :: analysis_result()
  def analyze(timescales) do
    patterns =
      timescales
      |> Enum.flat_map(fn {scale, window} ->
        analyze_scale_patterns(scale, window)
      end)
      |> filter_significant_patterns()
      |> rank_patterns()
    
    %{
      patterns: patterns,
      dominant_pattern: find_dominant_pattern(patterns),
      pattern_strength: calculate_pattern_strength(patterns),
      next_expected: predict_next_occurrence(patterns, timescales)
    }
  end
  
  @doc """
  Detects cyclic patterns in the data using autocorrelation and FFT.
  """
  @spec detect_cycles(list(map())) :: list(pattern())
  def detect_cycles(data) when length(data) < 10, do: []
  
  def detect_cycles(data) do
    values = Enum.map(data, & &1.value)
    
    # Autocorrelation analysis
    autocorr_patterns = analyze_autocorrelation(values)
    
    # Frequency domain analysis (simplified FFT)
    freq_patterns = analyze_frequency_domain(values)
    
    # Combine and validate patterns
    (autocorr_patterns ++ freq_patterns)
    |> consolidate_cyclic_patterns()
    |> Enum.filter(&valid_cycle?/1)
  end
  
  @doc """
  Identifies trend patterns using various trend detection methods.
  """
  @spec detect_trends(list(map())) :: list(pattern())
  def detect_trends(data) when length(data) < 5, do: []
  
  def detect_trends(data) do
    values = Enum.map(data, & &1.value)
    
    # Linear trend
    linear_trend = detect_linear_trend(values)
    
    # Non-linear trends
    nonlinear_trends = detect_nonlinear_trends(values)
    
    # Change point detection
    change_points = detect_change_points(values)
    
    [linear_trend | nonlinear_trends ++ change_points]
    |> Enum.filter(&(&1 != nil))
  end
  
  @doc """
  Detects seasonal patterns based on time-of-day, day-of-week, etc.
  """
  @spec detect_seasonality(list(map())) :: list(pattern())
  def detect_seasonality(data) when length(data) < 24, do: []
  
  def detect_seasonality(data) do
    # Group by time components
    hourly_pattern = detect_hourly_seasonality(data)
    daily_pattern = detect_daily_seasonality(data)
    weekly_pattern = detect_weekly_seasonality(data)
    
    [hourly_pattern, daily_pattern, weekly_pattern]
    |> Enum.filter(&(&1 != nil))
  end
  
  @doc """
  Identifies anomalous patterns using statistical methods.
  """
  @spec detect_anomalies(list(map())) :: list(pattern())
  def detect_anomalies(data) when length(data) < 10, do: []
  
  def detect_anomalies(data) do
    values = Enum.map(data, & &1.value)
    
    # Statistical anomalies (z-score)
    statistical_anomalies = detect_statistical_anomalies(values, data)
    
    # Isolation forest approach (simplified)
    isolation_anomalies = detect_isolation_anomalies(values, data)
    
    # Combine and deduplicate
    (statistical_anomalies ++ isolation_anomalies)
    |> Enum.uniq_by(& &1.parameters.index)
  end
  
  # Private Functions
  
  defp analyze_scale_patterns(scale, window) do
    if length(window.data) < 10 do
      []
    else
      cycles = detect_cycles(window.data)
      trends = detect_trends(window.data)
      seasonal = detect_seasonality(window.data)
      anomalies = detect_anomalies(window.data)
      
      (cycles ++ trends ++ seasonal ++ anomalies)
      |> Enum.map(fn pattern ->
        Map.put(pattern, :timescale, scale)
      end)
    end
  end
  
  defp analyze_autocorrelation(values) do
    max_lag = min(div(length(values), 4), 50)
    
    1..max_lag
    |> Enum.map(fn lag ->
      correlation = calculate_autocorrelation(values, lag)
      {lag, correlation}
    end)
    |> Enum.filter(fn {_lag, corr} -> abs(corr) > 0.5 end)
    |> Enum.map(fn {lag, corr} ->
      %{
        type: :cyclic,
        confidence: abs(corr),
        parameters: %{
          period: lag,
          strength: corr,
          method: :autocorrelation
        },
        detected_at: DateTime.utc_now(),
        description: "Cyclic pattern with period #{lag}"
      }
    end)
  end
  
  defp calculate_autocorrelation(values, lag) do
    n = length(values)
    
    if lag >= n do
      0.0
    else
      mean = Enum.sum(values) / n
      
      {numerator, var} =
        values
        |> Enum.with_index()
        |> Enum.reduce({0.0, 0.0}, fn {v, i}, {num, variance} ->
          v_centered = v - mean
          variance_new = variance + v_centered * v_centered
          
          if i >= lag do
            v_lag = Enum.at(values, i - lag) - mean
            {num + v_centered * v_lag, variance_new}
          else
            {num, variance_new}
          end
        end)
      
      if var > 0 do
        numerator / var
      else
        0.0
      end
    end
  end
  
  defp analyze_frequency_domain(values) do
    # Simplified DFT for pattern detection
    n = length(values)
    frequencies = [2, 3, 4, 6, 8, 12, 24]  # Common periods
    
    frequencies
    |> Enum.map(fn freq ->
      magnitude = calculate_frequency_magnitude(values, freq, n)
      {freq, magnitude}
    end)
    |> Enum.filter(fn {_freq, mag} -> mag > 0.3 end)
    |> Enum.map(fn {freq, mag} ->
      %{
        type: :cyclic,
        confidence: mag,
        parameters: %{
          period: div(n, freq),
          frequency: freq,
          method: :frequency_analysis
        },
        detected_at: DateTime.utc_now(),
        description: "Frequency component at #{freq} cycles"
      }
    end)
  end
  
  defp calculate_frequency_magnitude(values, freq, n) do
    {real, imag} =
      values
      |> Enum.with_index()
      |> Enum.reduce({0.0, 0.0}, fn {v, k}, {re, im} ->
        angle = -2.0 * :math.pi() * freq * k / n
        {
          re + v * :math.cos(angle),
          im + v * :math.sin(angle)
        }
      end)
    
    :math.sqrt(real * real + imag * imag) / n
  end
  
  defp consolidate_cyclic_patterns(patterns) do
    patterns
    |> Enum.group_by(fn p -> round(p.parameters.period) end)
    |> Enum.map(fn {period, group} ->
      # Take the pattern with highest confidence
      Enum.max_by(group, & &1.confidence)
    end)
  end
  
  defp valid_cycle?(pattern) do
    pattern.confidence > 0.6 and
    pattern.parameters.period > 1 and
    pattern.parameters.period < 100
  end
  
  defp detect_linear_trend(values) do
    n = length(values)
    
    if n < 3 do
      nil
    else
      # Simple linear regression
      x_values = 0..(n-1) |> Enum.to_list()
      x_mean = (n - 1) / 2
      y_mean = Enum.sum(values) / n
      
      {slope, r_squared} = calculate_linear_regression(x_values, values, x_mean, y_mean)
      
      if abs(slope) > 0.01 and r_squared > 0.5 do
        %{
          type: :trend,
          confidence: r_squared,
          parameters: %{
            slope: slope,
            direction: if(slope > 0, do: :increasing, else: :decreasing),
            r_squared: r_squared
          },
          detected_at: DateTime.utc_now(),
          description: "Linear #{if slope > 0, do: "upward", else: "downward"} trend"
        }
      else
        nil
      end
    end
  end
  
  defp calculate_linear_regression(x_values, y_values, x_mean, y_mean) do
    {num, den_x, den_y} =
      Enum.zip(x_values, y_values)
      |> Enum.reduce({0.0, 0.0, 0.0}, fn {x, y}, {n, dx, dy} ->
        x_diff = x - x_mean
        y_diff = y - y_mean
        {
          n + x_diff * y_diff,
          dx + x_diff * x_diff,
          dy + y_diff * y_diff
        }
      end)
    
    if den_x > 0 do
      slope = num / den_x
      r_squared = if den_y > 0, do: (num * num) / (den_x * den_y), else: 0.0
      {slope, r_squared}
    else
      {0.0, 0.0}
    end
  end
  
  defp detect_nonlinear_trends(values) do
    # Detect exponential and polynomial trends
    exponential = detect_exponential_trend(values)
    quadratic = detect_quadratic_trend(values)
    
    [exponential, quadratic]
    |> Enum.filter(&(&1 != nil))
  end
  
  defp detect_exponential_trend(values) do
    # Log-transform and check for linear trend
    log_values =
      values
      |> Enum.map(fn v -> if v > 0, do: :math.log(v), else: 0.0 end)
    
    case detect_linear_trend(log_values) do
      nil -> nil
      trend ->
        %{trend |
          type: :trend,
          parameters: Map.put(trend.parameters, :trend_type, :exponential),
          description: "Exponential #{trend.parameters.direction} trend"
        }
    end
  end
  
  defp detect_quadratic_trend(values) do
    # Simplified quadratic trend detection using differences
    if length(values) < 5 do
      nil
    else
      first_diff = compute_differences(values)
      second_diff = compute_differences(first_diff)
      
      if consistent_sign?(second_diff) do
        %{
          type: :trend,
          confidence: 0.7,
          parameters: %{
            trend_type: :quadratic,
            acceleration: Enum.sum(second_diff) / length(second_diff),
            direction: if(Enum.at(second_diff, 0) > 0, do: :accelerating, else: :decelerating)
          },
          detected_at: DateTime.utc_now(),
          description: "Quadratic trend with #{if Enum.at(second_diff, 0) > 0, do: "positive", else: "negative"} acceleration"
        }
      else
        nil
      end
    end
  end
  
  defp compute_differences(values) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b - a end)
  end
  
  defp consistent_sign?(values) do
    if Enum.empty?(values) do
      false
    else
      positive = Enum.count(values, &(&1 > 0))
      negative = Enum.count(values, &(&1 < 0))
      
      positive > length(values) * 0.8 or negative > length(values) * 0.8
    end
  end
  
  defp detect_change_points(values) do
    # CUSUM-based change point detection
    if length(values) < 20 do
      []
    else
      mean = Enum.sum(values) / length(values)
      
      {cusums, _} =
        values
        |> Enum.map_reduce(0, fn v, sum ->
          new_sum = sum + (v - mean)
          {new_sum, new_sum}
        end)
      
      # Find significant changes
      threshold = 2 * :math.sqrt(calculate_variance(values) * length(values))
      
      cusums
      |> Enum.with_index()
      |> Enum.filter(fn {cusum, _idx} -> abs(cusum) > threshold end)
      |> Enum.map(fn {_cusum, idx} ->
        %{
          type: :regime_change,
          confidence: 0.8,
          parameters: %{
            change_point: idx,
            before_mean: calculate_mean(Enum.take(values, idx)),
            after_mean: calculate_mean(Enum.drop(values, idx))
          },
          detected_at: DateTime.utc_now(),
          description: "Regime change at position #{idx}"
        }
      end)
    end
  end
  
  defp detect_hourly_seasonality(data) do
    hourly_groups =
      data
      |> Enum.group_by(fn m -> m.timestamp.hour end)
      |> Enum.map(fn {hour, group} ->
        {hour, Enum.map(group, & &1.value) |> calculate_mean()}
      end)
      |> Enum.sort()
    
    if length(hourly_groups) >= 12 do
      variance = hourly_groups |> Enum.map(&elem(&1, 1)) |> calculate_variance()
      
      if variance > 0.1 do
        %{
          type: :seasonal,
          confidence: min(variance, 1.0),
          parameters: %{
            period: :hourly,
            pattern: Map.new(hourly_groups)
          },
          detected_at: DateTime.utc_now(),
          description: "Hourly seasonality pattern detected"
        }
      else
        nil
      end
    else
      nil
    end
  end
  
  defp detect_daily_seasonality(data) do
    # Check for day-of-week patterns
    daily_groups =
      data
      |> Enum.group_by(fn m -> Date.day_of_week(m.timestamp) end)
      |> Enum.map(fn {day, group} ->
        {day, Enum.map(group, & &1.value) |> calculate_mean()}
      end)
      |> Enum.sort()
    
    if length(daily_groups) >= 5 do
      variance = daily_groups |> Enum.map(&elem(&1, 1)) |> calculate_variance()
      
      if variance > 0.15 do
        %{
          type: :seasonal,
          confidence: min(variance * 1.5, 1.0),
          parameters: %{
            period: :daily,
            pattern: Map.new(daily_groups)
          },
          detected_at: DateTime.utc_now(),
          description: "Daily seasonality pattern detected"
        }
      else
        nil
      end
    else
      nil
    end
  end
  
  defp detect_weekly_seasonality(data) do
    # Simplified weekly pattern detection
    if length(data) < 168 do  # Less than a week of hourly data
      nil
    else
      # Check if there's a 7-day cycle
      values = Enum.map(data, & &1.value)
      correlation = calculate_autocorrelation(values, 168)
      
      if correlation > 0.6 do
        %{
          type: :seasonal,
          confidence: correlation,
          parameters: %{
            period: :weekly,
            correlation: correlation
          },
          detected_at: DateTime.utc_now(),
          description: "Weekly seasonality pattern detected"
        }
      else
        nil
      end
    end
  end
  
  defp detect_statistical_anomalies(values, data) do
    mean = calculate_mean(values)
    std_dev = :math.sqrt(calculate_variance(values))
    
    if std_dev > 0 do
      data
      |> Enum.with_index()
      |> Enum.filter(fn {metric, _idx} ->
        z_score = abs((metric.value - mean) / std_dev)
        z_score > 3.0
      end)
      |> Enum.map(fn {metric, idx} ->
        z_score = (metric.value - mean) / std_dev
        
        %{
          type: :anomaly,
          confidence: min(abs(z_score) / 5.0, 1.0),
          parameters: %{
            index: idx,
            value: metric.value,
            z_score: z_score,
            method: :statistical
          },
          detected_at: metric.timestamp,
          description: "Statistical anomaly (z-score: #{Float.round(z_score, 2)})"
        }
      end)
    else
      []
    end
  end
  
  defp detect_isolation_anomalies(values, data) do
    # Simplified isolation forest approach
    if length(values) < 20 do
      []
    else
      # Calculate isolation scores based on local density
      scores =
        data
        |> Enum.with_index()
        |> Enum.map(fn {metric, idx} ->
          score = calculate_isolation_score(metric.value, values, idx)
          {metric, idx, score}
        end)
      
      # Threshold for anomalies
      threshold = 0.7
      
      scores
      |> Enum.filter(fn {_metric, _idx, score} -> score > threshold end)
      |> Enum.map(fn {metric, idx, score} ->
        %{
          type: :anomaly,
          confidence: score,
          parameters: %{
            index: idx,
            value: metric.value,
            isolation_score: score,
            method: :isolation
          },
          detected_at: metric.timestamp,
          description: "Isolation anomaly (score: #{Float.round(score, 2)})"
        }
      end)
    end
  end
  
  defp calculate_isolation_score(value, all_values, idx) do
    # Distance to k nearest neighbors
    k = 5
    
    distances =
      all_values
      |> Enum.with_index()
      |> Enum.reject(fn {_v, i} -> i == idx end)
      |> Enum.map(fn {v, _i} -> abs(v - value) end)
      |> Enum.sort()
      |> Enum.take(k)
    
    avg_distance = Enum.sum(distances) / k
    max_distance = Enum.max(all_values) - Enum.min(all_values)
    
    if max_distance > 0 do
      avg_distance / max_distance
    else
      0.0
    end
  end
  
  defp filter_significant_patterns(patterns) do
    patterns
    |> Enum.filter(fn p -> p.confidence > 0.5 end)
    |> Enum.sort_by(& &1.confidence, :desc)
  end
  
  defp rank_patterns(patterns) do
    # Group by type and take best from each
    patterns
    |> Enum.group_by(& &1.type)
    |> Enum.flat_map(fn {_type, group} ->
      Enum.take(Enum.sort_by(group, & &1.confidence, :desc), 3)
    end)
  end
  
  defp find_dominant_pattern(patterns) do
    if Enum.empty?(patterns) do
      nil
    else
      Enum.max_by(patterns, & &1.confidence)
    end
  end
  
  defp calculate_pattern_strength(patterns) do
    if Enum.empty?(patterns) do
      0.0
    else
      # Weighted average of pattern confidences
      total_confidence = Enum.sum(Enum.map(patterns, & &1.confidence))
      total_confidence / length(patterns)
    end
  end
  
  defp predict_next_occurrence(patterns, _timescales) do
    cyclic_patterns = Enum.filter(patterns, fn p -> p.type == :cyclic end)
    
    if Enum.empty?(cyclic_patterns) do
      %{}
    else
      cyclic_patterns
      |> Enum.map(fn pattern ->
        next_time = DateTime.add(
          pattern.detected_at,
          pattern.parameters.period * 1000,
          :millisecond
        )
        
        {pattern.timescale, %{
          expected_at: next_time,
          pattern: pattern.type,
          confidence: pattern.confidence
        }}
      end)
      |> Enum.into(%{})
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
      
      sum_squared =
        values
        |> Enum.map(fn v -> (v - mean) * (v - mean) end)
        |> Enum.sum()
      
      sum_squared / (length(values) - 1)
    end
  end
end