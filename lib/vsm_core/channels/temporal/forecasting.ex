defmodule VSMCore.Channels.Temporal.Forecasting do
  @moduledoc """
  Time-based variety prediction and anomaly detection.
  
  This module provides forecasting capabilities for the temporal variety channel,
  using various time-series forecasting methods to predict future variety levels
  and detect anomalies in real-time.
  
  ## Forecasting Methods
  
  - **ARIMA**: Autoregressive Integrated Moving Average
  - **Exponential Smoothing**: Holt-Winters method
  - **Neural Prophet**: Pattern-based forecasting
  - **Ensemble**: Combination of multiple methods
  
  ## Anomaly Detection
  
  - Real-time anomaly detection using forecast errors
  - Adaptive thresholds based on historical patterns
  - Multi-scale anomaly validation
  """
  
  alias VSMCore.Channels.Temporal.{Timescales, Patterns}
  
  @type forecast :: %{
    timestamp: DateTime.t(),
    value: float(),
    confidence_interval: {float(), float()},
    method: atom()
  }
  
  @type anomaly :: %{
    timestamp: DateTime.t(),
    actual: float(),
    expected: float(),
    severity: float(),
    type: atom()
  }
  
  @doc """
  Generates forecasts for specified time horizons.
  """
  @spec generate_forecasts(Timescales.t(), list(pos_integer())) :: map()
  def generate_forecasts(timescales, horizons) do
    horizons
    |> Enum.map(fn horizon ->
      forecasts = generate_horizon_forecasts(timescales, horizon)
      {horizon, forecasts}
    end)
    |> Enum.into(%{})
  end
  
  @doc """
  Updates forecasts based on new patterns and data.
  """
  @spec update(Timescales.t(), map()) :: map()
  def update(timescales, patterns) do
    %{
      short_term: update_short_term_forecasts(timescales, patterns),
      medium_term: update_medium_term_forecasts(timescales, patterns),
      long_term: update_long_term_forecasts(timescales, patterns),
      anomalies: detect_forecast_anomalies(timescales)
    }
  end
  
  @doc """
  Detects anomalies by comparing actual values with forecasts.
  """
  @spec detect_anomalies(list(map()), list(forecast())) :: list(anomaly())
  def detect_anomalies(actual_data, forecasts) do
    forecast_map =
      forecasts
      |> Enum.map(fn f -> {DateTime.to_unix(f.timestamp), f} end)
      |> Enum.into(%{})
    
    actual_data
    |> Enum.filter_map(
      fn data ->
        unix_time = DateTime.to_unix(data.timestamp)
        Map.has_key?(forecast_map, unix_time)
      end,
      fn data ->
        unix_time = DateTime.to_unix(data.timestamp)
        forecast = Map.get(forecast_map, unix_time)
        
        check_anomaly(data, forecast)
      end
    )
    |> Enum.filter(&(&1 != nil))
  end
  
  @doc """
  Generates ensemble forecast combining multiple methods.
  """
  @spec ensemble_forecast(Timescales.t(), pos_integer()) :: list(forecast())
  def ensemble_forecast(timescales, horizon) do
    methods = [:arima, :exponential_smoothing, :neural_prophet]
    
    forecasts =
      methods
      |> Enum.map(fn method ->
        generate_method_forecast(timescales, horizon, method)
      end)
    
    combine_forecasts(forecasts)
  end
  
  # Private Functions
  
  defp generate_horizon_forecasts(timescales, horizon) do
    # Select appropriate timescale based on horizon
    timescale = select_timescale_for_horizon(horizon)
    
    case Map.get(timescales, timescale) do
      nil -> []
      window ->
        if length(window.data) >= 10 do
          ensemble_forecast_for_window(window, horizon)
        else
          []
        end
    end
  end
  
  defp select_timescale_for_horizon(horizon) do
    cond do
      horizon <= 60 -> :minute
      horizon <= 3600 -> :hour
      horizon <= 86400 -> :day
      horizon <= 604800 -> :week
      true -> :month
    end
  end
  
  defp ensemble_forecast_for_window(window, horizon) do
    values = Enum.map(window.data, & &1.value)
    
    # Generate forecasts using different methods
    arima_forecast = arima_forecast(values, horizon)
    exp_forecast = exponential_smoothing_forecast(values, horizon)
    prophet_forecast = neural_prophet_forecast(values, horizon)
    
    # Combine forecasts with weights
    combine_method_forecasts([
      {arima_forecast, 0.4},
      {exp_forecast, 0.3},
      {prophet_forecast, 0.3}
    ])
  end
  
  defp arima_forecast(values, horizon) do
    # Simplified ARIMA(1,1,1) implementation
    if length(values) < 5 do
      simple_forecast(values, horizon)
    else
      # Difference the series
      diff_values = difference_series(values)
      
      # Estimate AR and MA parameters
      {ar_param, ma_param} = estimate_arima_params(diff_values)
      
      # Generate forecasts
      generate_arima_forecasts(values, diff_values, ar_param, ma_param, horizon)
    end
  end
  
  defp difference_series(values) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b - a end)
  end
  
  defp estimate_arima_params(diff_values) do
    # Simplified parameter estimation using autocorrelation
    if length(diff_values) < 3 do
      {0.5, 0.3}
    else
      acf1 = calculate_acf(diff_values, 1)
      pacf1 = calculate_pacf(diff_values, 1)
      
      ar_param = constrain_parameter(pacf1)
      ma_param = constrain_parameter(acf1)
      
      {ar_param, ma_param}
    end
  end
  
  defp calculate_acf(values, lag) do
    mean = Enum.sum(values) / length(values)
    
    {numerator, denominator} =
      values
      |> Enum.with_index()
      |> Enum.reduce({0.0, 0.0}, fn {v, i}, {num, den} ->
        v_centered = v - mean
        den_new = den + v_centered * v_centered
        
        if i >= lag do
          v_lag = Enum.at(values, i - lag) - mean
          {num + v_centered * v_lag, den_new}
        else
          {num, den_new}
        end
      end)
    
    if denominator > 0, do: numerator / denominator, else: 0.0
  end
  
  defp calculate_pacf(values, lag) do
    # Simplified PACF calculation
    calculate_acf(values, lag) * 0.8
  end
  
  defp constrain_parameter(value) do
    # Constrain parameters to stationary region
    max(min(value, 0.95), -0.95)
  end
  
  defp generate_arima_forecasts(original_values, diff_values, ar_param, ma_param, horizon) do
    last_value = List.last(original_values)
    last_diff = List.last(diff_values) || 0.0
    mean_diff = Enum.sum(diff_values) / max(length(diff_values), 1)
    
    # Generate future differences
    future_diffs =
      1..horizon
      |> Enum.scan({last_diff, 0.0}, fn _i, {prev_diff, prev_error} ->
        # ARIMA(1,1,1) forecast equation
        forecast_diff = ar_param * prev_diff + ma_param * prev_error + mean_diff * (1 - ar_param)
        error = :rand.normal(0, 0.1)  # Small random error
        
        {forecast_diff, error}
      end)
      |> Enum.map(&elem(&1, 0))
    
    # Integrate to get level forecasts
    integrate_forecasts(last_value, future_diffs)
  end
  
  defp integrate_forecasts(last_value, differences) do
    {forecasts, _} =
      differences
      |> Enum.map_reduce(last_value, fn diff, prev ->
        new_value = prev + diff
        forecast = %{
          timestamp: DateTime.add(DateTime.utc_now(), length(differences), :second),
          value: new_value,
          confidence_interval: calculate_confidence_interval(new_value, 0.1),
          method: :arima
        }
        {forecast, new_value}
      end)
    
    forecasts
  end
  
  defp exponential_smoothing_forecast(values, horizon) do
    # Holt-Winters exponential smoothing
    if length(values) < 3 do
      simple_forecast(values, horizon)
    else
      # Initialize components
      {level, trend} = initialize_holt_winters(values)
      
      # Optimize smoothing parameters
      {alpha, beta} = optimize_smoothing_params(values, level, trend)
      
      # Generate forecasts
      generate_hw_forecasts(values, level, trend, alpha, beta, horizon)
    end
  end
  
  defp initialize_holt_winters(values) do
    # Simple initialization
    first_half = Enum.take(values, div(length(values), 2))
    second_half = Enum.drop(values, div(length(values), 2))
    
    level = Enum.sum(first_half) / max(length(first_half), 1)
    trend = (Enum.sum(second_half) / max(length(second_half), 1) - level) / max(length(first_half), 1)
    
    {level, trend}
  end
  
  defp optimize_smoothing_params(values, initial_level, initial_trend) do
    # Grid search for optimal parameters (simplified)
    param_grid = [0.1, 0.3, 0.5, 0.7, 0.9]
    
    best_params =
      for alpha <- param_grid, beta <- param_grid do
        error = calculate_hw_error(values, initial_level, initial_trend, alpha, beta)
        {error, {alpha, beta}}
      end
      |> Enum.min_by(&elem(&1, 0))
      |> elem(1)
    
    best_params
  end
  
  defp calculate_hw_error(values, level, trend, alpha, beta) do
    {_, errors} =
      values
      |> Enum.reduce({%{level: level, trend: trend}, []}, fn value, {state, errors} ->
        forecast = state.level + state.trend
        error = abs(value - forecast)
        
        # Update state
        new_level = alpha * value + (1 - alpha) * (state.level + state.trend)
        new_trend = beta * (new_level - state.level) + (1 - beta) * state.trend
        
        {%{level: new_level, trend: new_trend}, [error | errors]}
      end)
    
    Enum.sum(errors) / max(length(errors), 1)
  end
  
  defp generate_hw_forecasts(values, initial_level, initial_trend, alpha, beta, horizon) do
    # Update level and trend with all values
    {final_state, _} =
      values
      |> Enum.reduce({%{level: initial_level, trend: initial_trend}, nil}, fn value, {state, _} ->
        new_level = alpha * value + (1 - alpha) * (state.level + state.trend)
        new_trend = beta * (new_level - state.level) + (1 - beta) * state.trend
        
        {%{level: new_level, trend: new_trend}, value}
      end)
    
    # Generate forecasts
    1..horizon
    |> Enum.map(fn h ->
      forecast_value = final_state.level + h * final_state.trend
      
      %{
        timestamp: DateTime.add(DateTime.utc_now(), h, :second),
        value: max(forecast_value, 0),  # Ensure non-negative
        confidence_interval: calculate_confidence_interval(forecast_value, 0.15 * h),
        method: :exponential_smoothing
      }
    end)
  end
  
  defp neural_prophet_forecast(values, horizon) do
    # Simplified neural prophet-style forecasting
    if length(values) < 10 do
      simple_forecast(values, horizon)
    else
      # Extract features
      features = extract_prophet_features(values)
      
      # Learn patterns
      patterns = learn_prophet_patterns(values, features)
      
      # Generate forecasts
      generate_prophet_forecasts(patterns, horizon)
    end
  end
  
  defp extract_prophet_features(values) do
    %{
      trend: estimate_trend_component(values),
      seasonality: estimate_seasonality_component(values),
      changepoints: detect_changepoints(values)
    }
  end
  
  defp estimate_trend_component(values) do
    # Piecewise linear trend
    n = length(values)
    segments = max(div(n, 20), 2)
    segment_size = div(n, segments)
    
    values
    |> Enum.chunk_every(segment_size)
    |> Enum.map(fn segment ->
      x_vals = 0..(length(segment) - 1) |> Enum.to_list()
      {slope, intercept} = simple_linear_regression(x_vals, segment)
      %{slope: slope, intercept: intercept, size: length(segment)}
    end)
  end
  
  defp simple_linear_regression(x_values, y_values) do
    n = length(x_values)
    
    if n == 0 do
      {0.0, 0.0}
    else
      x_mean = Enum.sum(x_values) / n
      y_mean = Enum.sum(y_values) / n
      
      {num, den} =
        Enum.zip(x_values, y_values)
        |> Enum.reduce({0.0, 0.0}, fn {x, y}, {n, d} ->
          {n + (x - x_mean) * (y - y_mean), d + (x - x_mean) * (x - x_mean)}
        end)
      
      if den > 0 do
        slope = num / den
        intercept = y_mean - slope * x_mean
        {slope, intercept}
      else
        {0.0, y_mean}
      end
    end
  end
  
  defp estimate_seasonality_component(values) do
    # Fourier components for seasonality
    n = length(values)
    periods = [div(n, 4), div(n, 7), div(n, 12)] |> Enum.filter(&(&1 > 0))
    
    periods
    |> Enum.map(fn period ->
      amplitude = calculate_fourier_amplitude(values, period)
      phase = calculate_fourier_phase(values, period)
      
      %{period: period, amplitude: amplitude, phase: phase}
    end)
  end
  
  defp calculate_fourier_amplitude(values, period) do
    n = length(values)
    
    {sin_sum, cos_sum} =
      values
      |> Enum.with_index()
      |> Enum.reduce({0.0, 0.0}, fn {v, i}, {s, c} ->
        angle = 2 * :math.pi() * i / period
        {s + v * :math.sin(angle), c + v * :math.cos(angle)}
      end)
    
    :math.sqrt(sin_sum * sin_sum + cos_sum * cos_sum) / n
  end
  
  defp calculate_fourier_phase(values, period) do
    n = length(values)
    
    {sin_sum, cos_sum} =
      values
      |> Enum.with_index()
      |> Enum.reduce({0.0, 0.0}, fn {v, i}, {s, c} ->
        angle = 2 * :math.pi() * i / period
        {s + v * :math.sin(angle), c + v * :math.cos(angle)}
      end)
    
    :math.atan2(sin_sum / n, cos_sum / n)
  end
  
  defp detect_changepoints(values) do
    # Simplified changepoint detection
    if length(values) < 20 do
      []
    else
      window_size = 10
      
      values
      |> Enum.chunk_every(window_size, 1, :discard)
      |> Enum.with_index()
      |> Enum.map(fn {window, idx} ->
        {idx + div(window_size, 2), calculate_change_magnitude(window)}
      end)
      |> Enum.filter(fn {_idx, mag} -> mag > 0.5 end)
      |> Enum.map(fn {idx, mag} -> %{position: idx, magnitude: mag} end)
    end
  end
  
  defp calculate_change_magnitude(window) do
    half = div(length(window), 2)
    first_half = Enum.take(window, half)
    second_half = Enum.drop(window, half)
    
    mean1 = Enum.sum(first_half) / max(length(first_half), 1)
    mean2 = Enum.sum(second_half) / max(length(second_half), 1)
    
    abs(mean2 - mean1) / max(mean1, 1.0)
  end
  
  defp learn_prophet_patterns(values, features) do
    %{
      base_value: Enum.sum(values) / max(length(values), 1),
      trend_patterns: features.trend,
      seasonal_patterns: features.seasonality,
      change_patterns: features.changepoints,
      residual_std: calculate_residual_std(values, features)
    }
  end
  
  defp calculate_residual_std(values, features) do
    # Simplified residual calculation
    predicted =
      values
      |> Enum.with_index()
      |> Enum.map(fn {_v, i} ->
        trend_value = calculate_trend_at(features.trend, i)
        seasonal_value = calculate_seasonal_at(features.seasonality, i)
        trend_value + seasonal_value
      end)
    
    residuals =
      Enum.zip(values, predicted)
      |> Enum.map(fn {actual, pred} -> actual - pred end)
    
    std_dev(residuals)
  end
  
  defp calculate_trend_at(trend_segments, position) do
    # Find which segment contains this position
    {_pos, segment} =
      trend_segments
      |> Enum.reduce({0, nil}, fn seg, {pos, found} ->
        if found do
          {pos, found}
        else
          new_pos = pos + seg.size
          if position < new_pos do
            {new_pos, seg}
          else
            {new_pos, nil}
          end
        end
      end)
    
    if segment do
      segment.slope * position + segment.intercept
    else
      0.0
    end
  end
  
  defp calculate_seasonal_at(seasonal_components, position) do
    seasonal_components
    |> Enum.map(fn comp ->
      angle = 2 * :math.pi() * position / comp.period + comp.phase
      comp.amplitude * :math.sin(angle)
    end)
    |> Enum.sum()
  end
  
  defp generate_prophet_forecasts(patterns, horizon) do
    1..horizon
    |> Enum.map(fn h ->
      trend = calculate_future_trend(patterns.trend_patterns, h)
      seasonal = calculate_future_seasonal(patterns.seasonal_patterns, h)
      base = patterns.base_value
      
      forecast_value = base + trend + seasonal
      uncertainty = patterns.residual_std * :math.sqrt(h)
      
      %{
        timestamp: DateTime.add(DateTime.utc_now(), h, :second),
        value: max(forecast_value, 0),
        confidence_interval: calculate_confidence_interval(forecast_value, uncertainty),
        method: :neural_prophet
      }
    end)
  end
  
  defp calculate_future_trend(trend_patterns, horizon) do
    # Extrapolate last trend segment
    last_segment = List.last(trend_patterns) || %{slope: 0, intercept: 0}
    last_segment.slope * horizon
  end
  
  defp calculate_future_seasonal(seasonal_patterns, horizon) do
    seasonal_patterns
    |> Enum.map(fn pattern ->
      angle = 2 * :math.pi() * horizon / pattern.period + pattern.phase
      pattern.amplitude * :math.sin(angle)
    end)
    |> Enum.sum()
  end
  
  defp simple_forecast(values, horizon) do
    # Fallback to simple average-based forecast
    if Enum.empty?(values) do
      []
    else
      avg = Enum.sum(values) / length(values)
      
      1..horizon
      |> Enum.map(fn h ->
        %{
          timestamp: DateTime.add(DateTime.utc_now(), h, :second),
          value: avg,
          confidence_interval: {avg * 0.8, avg * 1.2},
          method: :simple_average
        }
      end)
    end
  end
  
  defp combine_forecasts(method_forecasts) do
    # Group by timestamp
    method_forecasts
    |> List.flatten()
    |> Enum.group_by(& &1.timestamp)
    |> Enum.map(fn {timestamp, forecasts} ->
      # Weighted average
      total_weight = length(forecasts)
      
      avg_value =
        forecasts
        |> Enum.map(& &1.value)
        |> Enum.sum()
        |> Kernel./(total_weight)
      
      # Combine confidence intervals
      {lower_bounds, upper_bounds} =
        forecasts
        |> Enum.map(& &1.confidence_interval)
        |> Enum.unzip()
      
      %{
        timestamp: timestamp,
        value: avg_value,
        confidence_interval: {
          Enum.sum(lower_bounds) / total_weight,
          Enum.sum(upper_bounds) / total_weight
        },
        method: :ensemble
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end
  
  defp combine_method_forecasts(weighted_forecasts) do
    # Combine forecasts with specific weights
    weighted_forecasts
    |> Enum.filter(fn {forecasts, _weight} -> not Enum.empty?(forecasts) end)
    |> case do
      [] -> []
      valid_forecasts ->
        total_weight = valid_forecasts |> Enum.map(&elem(&1, 1)) |> Enum.sum()
        
        # Group by position in forecast
        max_length =
          valid_forecasts
          |> Enum.map(fn {f, _} -> length(f) end)
          |> Enum.max()
        
        0..(max_length - 1)
        |> Enum.map(fn idx ->
          weighted_values =
            valid_forecasts
            |> Enum.filter_map(
              fn {f, _} -> idx < length(f) end,
              fn {f, w} -> {Enum.at(f, idx), w} end
            )
          
          if Enum.empty?(weighted_values) do
            nil
          else
            combine_weighted_forecast(weighted_values, total_weight)
          end
        end)
        |> Enum.filter(&(&1 != nil))
    end
  end
  
  defp combine_weighted_forecast(weighted_values, total_weight) do
    {forecast, _} = List.first(weighted_values)
    
    weighted_value =
      weighted_values
      |> Enum.map(fn {f, w} -> f.value * w end)
      |> Enum.sum()
      |> Kernel./(total_weight)
    
    # Weighted confidence intervals
    {weighted_lower, weighted_upper} =
      weighted_values
      |> Enum.map(fn {f, w} ->
        {lower, upper} = f.confidence_interval
        {lower * w, upper * w}
      end)
      |> Enum.reduce({0, 0}, fn {l, u}, {acc_l, acc_u} ->
        {acc_l + l, acc_u + u}
      end)
    
    %{
      timestamp: forecast.timestamp,
      value: weighted_value,
      confidence_interval: {
        weighted_lower / total_weight,
        weighted_upper / total_weight
      },
      method: :ensemble
    }
  end
  
  defp calculate_confidence_interval(value, uncertainty) do
    # 95% confidence interval
    z_score = 1.96
    margin = z_score * uncertainty
    
    {
      max(value - margin, 0),
      value + margin
    }
  end
  
  defp std_dev(values) do
    if length(values) < 2 do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      
      variance =
        values
        |> Enum.map(fn v -> (v - mean) * (v - mean) end)
        |> Enum.sum()
        |> Kernel./(length(values) - 1)
      
      :math.sqrt(variance)
    end
  end
  
  defp update_short_term_forecasts(timescales, patterns) do
    # 1-60 second forecasts
    generate_pattern_aware_forecasts(timescales.real_time, patterns, 60)
  end
  
  defp update_medium_term_forecasts(timescales, patterns) do
    # 1-24 hour forecasts
    generate_pattern_aware_forecasts(timescales.hour, patterns, 24)
  end
  
  defp update_long_term_forecasts(timescales, patterns) do
    # 1-30 day forecasts
    generate_pattern_aware_forecasts(timescales.day, patterns, 30)
  end
  
  defp generate_pattern_aware_forecasts(window, patterns, horizon) do
    base_forecasts = ensemble_forecast_for_window(window, horizon)
    
    # Adjust forecasts based on detected patterns
    if patterns.dominant_pattern do
      adjust_forecasts_for_pattern(base_forecasts, patterns.dominant_pattern)
    else
      base_forecasts
    end
  end
  
  defp adjust_forecasts_for_pattern(forecasts, pattern) do
    case pattern.type do
      :cyclic ->
        add_cyclic_component(forecasts, pattern.parameters.period)
      
      :trend ->
        add_trend_component(forecasts, pattern.parameters.slope)
      
      :seasonal ->
        add_seasonal_component(forecasts, pattern.parameters.pattern)
      
      _ ->
        forecasts
    end
  end
  
  defp add_cyclic_component(forecasts, period) do
    forecasts
    |> Enum.with_index()
    |> Enum.map(fn {forecast, idx} ->
      phase = 2 * :math.pi() * idx / period
      adjustment = 0.1 * :math.sin(phase)
      
      %{forecast |
        value: forecast.value * (1 + adjustment)
      }
    end)
  end
  
  defp add_trend_component(forecasts, slope) do
    forecasts
    |> Enum.with_index()
    |> Enum.map(fn {forecast, idx} ->
      %{forecast |
        value: forecast.value + slope * idx
      }
    end)
  end
  
  defp add_seasonal_component(forecasts, _seasonal_pattern) do
    # Simplified - just return forecasts
    forecasts
  end
  
  defp detect_forecast_anomalies(timescales) do
    # Check each timescale for anomalies
    [:real_time, :minute, :hour]
    |> Enum.flat_map(fn scale ->
      window = Map.get(timescales, scale)
      
      if window && length(window.data) > 20 do
        detect_window_anomalies(window)
      else
        []
      end
    end)
  end
  
  defp detect_window_anomalies(window) do
    recent_data = Enum.take(window.data, 20)
    values = Enum.map(recent_data, & &1.value)
    
    # Calculate expected range
    mean = Enum.sum(values) / length(values)
    std = std_dev(values)
    
    # Find anomalies
    recent_data
    |> Enum.filter(fn data ->
      z_score = abs((data.value - mean) / max(std, 0.01))
      z_score > 3.0
    end)
    |> Enum.map(fn data ->
      %{
        timestamp: data.timestamp,
        actual: data.value,
        expected: mean,
        severity: abs((data.value - mean) / max(std, 0.01)),
        type: if(data.value > mean, do: :spike, else: :drop)
      }
    end)
  end
  
  defp check_anomaly(actual_data, forecast) do
    {lower, upper} = forecast.confidence_interval
    
    if actual_data.value < lower or actual_data.value > upper do
      %{
        timestamp: actual_data.timestamp,
        actual: actual_data.value,
        expected: forecast.value,
        severity: calculate_anomaly_severity(actual_data.value, forecast),
        type: classify_anomaly_type(actual_data.value, forecast.value)
      }
    else
      nil
    end
  end
  
  defp calculate_anomaly_severity(actual, forecast) do
    {lower, upper} = forecast.confidence_interval
    
    if actual < lower do
      (lower - actual) / max(forecast.value, 1.0)
    else
      (actual - upper) / max(forecast.value, 1.0)
    end
  end
  
  defp classify_anomaly_type(actual, expected) do
    ratio = actual / max(expected, 0.01)
    
    cond do
      ratio > 2.0 -> :extreme_spike
      ratio > 1.5 -> :spike
      ratio < 0.5 -> :extreme_drop
      ratio < 0.75 -> :drop
      true -> :deviation
    end
  end
  
  defp generate_method_forecast(timescales, horizon, method) do
    # Delegate to specific method
    window = select_best_window(timescales, horizon)
    
    if window do
      values = Enum.map(window.data, & &1.value)
      
      case method do
        :arima -> arima_forecast(values, horizon)
        :exponential_smoothing -> exponential_smoothing_forecast(values, horizon)
        :neural_prophet -> neural_prophet_forecast(values, horizon)
        _ -> []
      end
    else
      []
    end
  end
  
  defp select_best_window(timescales, horizon) do
    # Select window with enough data
    [:hour, :day, :week]
    |> Enum.find_value(fn scale ->
      window = Map.get(timescales, scale)
      if window && length(window.data) >= 20 do
        window
      else
        nil
      end
    end)
  end
end