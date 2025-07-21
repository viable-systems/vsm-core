defmodule VSMCore.Channels.Temporal.Visualization do
  @moduledoc """
  Data preparation for temporal variety visualization.
  
  This module transforms temporal variety data into formats suitable
  for various visualization libraries and dashboards. It provides
  structured data ready for charts, graphs, and real-time displays.
  
  ## Visualization Types
  
  - **Time Series Charts**: Line, area, and candlestick charts
  - **Heatmaps**: Temporal heatmaps for pattern visualization
  - **Network Graphs**: Causal relationship networks
  - **Dashboards**: Real-time dashboard data
  """
  
  @type chart_data :: %{
    type: atom(),
    data: list(map()),
    metadata: map()
  }
  
  @doc """
  Prepares data for visualization based on specified options.
  """
  @spec prepare_data(map(), keyword()) :: map()
  def prepare_data(state, opts \\ []) do
    viz_type = Keyword.get(opts, :type, :dashboard)
    
    case viz_type do
      :time_series -> prepare_time_series_data(state, opts)
      :heatmap -> prepare_heatmap_data(state, opts)
      :network -> prepare_network_data(state, opts)
      :dashboard -> prepare_dashboard_data(state, opts)
      _ -> prepare_dashboard_data(state, opts)
    end
  end
  
  # Private Functions
  
  defp prepare_time_series_data(state, opts) do
    scales = Keyword.get(opts, :scales, [:minute, :hour, :day])
    
    %{
      type: :time_series,
      series: prepare_multi_scale_series(state.timescales, scales),
      annotations: prepare_annotations(state),
      metadata: %{
        last_update: DateTime.utc_now(),
        scales: scales
      }
    }
  end
  
  defp prepare_multi_scale_series(timescales, scales) do
    scales
    |> Enum.map(fn scale ->
      window = Map.get(timescales, scale)
      
      if window do
        %{
          name: to_string(scale),
          data: format_window_data(window),
          style: get_scale_style(scale)
        }
      else
        nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end
  
  defp format_window_data(window) do
    window.data
    |> Enum.map(fn metric ->
      %{
        x: DateTime.to_unix(metric.timestamp, :millisecond),
        y: Float.round(metric.value, 4),
        confidence: metric.confidence
      }
    end)
    |> Enum.sort_by(& &1.x)
  end
  
  defp get_scale_style(scale) do
    case scale do
      :real_time -> %{color: "#FF6B6B", width: 1}
      :minute -> %{color: "#4ECDC4", width: 2}
      :hour -> %{color: "#45B7D1", width: 2}
      :day -> %{color: "#96CEB4", width: 3}
      :week -> %{color: "#DDA0DD", width: 3}
      :month -> %{color: "#FFD93D", width: 4}
    end
  end
  
  defp prepare_annotations(state) do
    pattern_annotations = 
      if state.patterns[:patterns] do
        state.patterns.patterns
        |> Enum.map(&pattern_to_annotation/1)
      else
        []
      end
    
    anomaly_annotations =
      if state.forecasts[:anomalies] do
        state.forecasts.anomalies
        |> Enum.map(&anomaly_to_annotation/1)
      else
        []
      end
    
    pattern_annotations ++ anomaly_annotations
  end
  
  defp pattern_to_annotation(pattern) do
    %{
      x: DateTime.to_unix(pattern.detected_at, :millisecond),
      type: :pattern,
      pattern_type: pattern.type,
      label: pattern.description,
      style: %{color: pattern_color(pattern.type)}
    }
  end
  
  defp anomaly_to_annotation(anomaly) do
    %{
      x: DateTime.to_unix(anomaly.timestamp, :millisecond),
      type: :anomaly,
      severity: anomaly.severity,
      label: "Anomaly: #{anomaly.type}",
      style: %{color: severity_color(anomaly.severity)}
    }
  end
  
  defp pattern_color(type) do
    case type do
      :cyclic -> "#3498db"
      :trend -> "#2ecc71"
      :seasonal -> "#f39c12"
      :regime_change -> "#e74c3c"
      _ -> "#95a5a6"
    end
  end
  
  defp severity_color(severity) do
    cond do
      severity > 5.0 -> "#e74c3c"
      severity > 3.0 -> "#f39c12"
      severity > 2.0 -> "#f1c40f"
      true -> "#95a5a6"
    end
  end
  
  defp prepare_heatmap_data(state, _opts) do
    %{
      type: :heatmap,
      data: prepare_temporal_heatmap(state.buffer),
      metadata: %{
        value_range: calculate_value_range(state.buffer)
      }
    }
  end
  
  defp prepare_temporal_heatmap(buffer) do
    buffer
    |> Enum.group_by(
      fn metric -> {metric.timestamp.hour, Date.day_of_week(metric.timestamp)} end
    )
    |> Enum.map(fn {{hour, day}, metrics} ->
      %{
        hour: hour,
        day: day,
        value: calculate_mean_value(metrics),
        count: length(metrics)
      }
    end)
  end
  
  defp calculate_mean_value(metrics) do
    values = Enum.map(metrics, & &1.value)
    
    if Enum.empty?(values) do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end
  
  defp calculate_value_range(buffer) do
    if Enum.empty?(buffer) do
      {0.0, 0.0}
    else
      values = Enum.map(buffer, & &1.value)
      {Enum.min(values), Enum.max(values)}
    end
  end
  
  defp prepare_network_data(state, _opts) do
    %{
      type: :network,
      nodes: prepare_causal_nodes(state.causal_chains),
      edges: prepare_causal_edges(state.causal_chains),
      metadata: %{
        layout: :force_directed
      }
    }
  end
  
  defp prepare_causal_nodes(causal_chains) do
    causal_chains
    |> Enum.flat_map(fn chain ->
      [chain.root_cause | chain.effects]
    end)
    |> Enum.uniq()
    |> Enum.map(fn node ->
      %{
        id: to_string(node),
        label: to_string(node),
        size: calculate_node_importance(node, causal_chains)
      }
    end)
  end
  
  defp calculate_node_importance(node, chains) do
    appearances = 
      chains
      |> Enum.count(fn chain ->
        node == chain.root_cause or node in chain.effects
      end)
    
    5 + appearances * 2
  end
  
  defp prepare_causal_edges(causal_chains) do
    causal_chains
    |> Enum.flat_map(& &1.links)
    |> Enum.map(fn link ->
      %{
        source: to_string(link.from),
        target: to_string(link.to),
        weight: link.strength,
        label: "lag: #{link.lag}"
      }
    end)
  end
  
  defp prepare_dashboard_data(state, _opts) do
    %{
      type: :dashboard,
      current_metrics: prepare_current_metrics(state),
      trend_indicators: prepare_trend_indicators(state),
      mini_charts: prepare_mini_charts(state),
      alerts: prepare_alerts(state)
    }
  end
  
  defp prepare_current_metrics(state) do
    latest_values = get_latest_values(state.timescales)
    
    %{
      real_time_variety: latest_values[:real_time],
      hourly_variety: latest_values[:hour],
      daily_variety: latest_values[:day],
      active_patterns: count_active_patterns(state.patterns),
      anomaly_count: count_recent_anomalies(state.forecasts[:anomalies])
    }
  end
  
  defp get_latest_values(timescales) do
    timescales
    |> Enum.map(fn {scale, window} ->
      latest = 
        if window && not Enum.empty?(window.data) do
          List.first(window.data).value
        else
          0.0
        end
      
      {scale, Float.round(latest, 3)}
    end)
    |> Enum.into(%{})
  end
  
  defp count_active_patterns(patterns) do
    if patterns[:patterns] do
      length(patterns.patterns)
    else
      0
    end
  end
  
  defp count_recent_anomalies(anomalies) do
    if anomalies do
      cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)
      
      Enum.count(anomalies, fn a ->
        DateTime.compare(a.timestamp, cutoff) == :gt
      end)
    else
      0
    end
  end
  
  defp prepare_trend_indicators(state) do
    timescales = state.timescales
    
    %{
      minute_trend: get_trend_indicator(timescales[:minute]),
      hour_trend: get_trend_indicator(timescales[:hour]),
      day_trend: get_trend_indicator(timescales[:day])
    }
  end
  
  defp get_trend_indicator(window) do
    if window && window.aggregates do
      momentum = window.aggregates.momentum
      
      %{
        direction: trend_direction(momentum),
        strength: abs(momentum),
        icon: trend_icon(momentum)
      }
    else
      %{direction: :neutral, strength: 0.0, icon: "→"}
    end
  end
  
  defp trend_direction(momentum) do
    cond do
      momentum > 0.01 -> :up
      momentum < -0.01 -> :down
      true -> :neutral
    end
  end
  
  defp trend_icon(momentum) do
    cond do
      momentum > 0.01 -> "↗"
      momentum < -0.01 -> "↘"
      true -> "→"
    end
  end
  
  defp prepare_mini_charts(state) do
    %{
      sparkline_hour: prepare_sparkline(state.timescales[:hour], 20),
      sparkline_day: prepare_sparkline(state.timescales[:day], 20)
    }
  end
  
  defp prepare_sparkline(window, points) do
    if window && not Enum.empty?(window.data) do
      window.data
      |> Enum.take(points)
      |> Enum.map(& &1.value)
      |> Enum.reverse()
    else
      []
    end
  end
  
  defp prepare_alerts(state) do
    anomaly_alerts = 
      if state.forecasts[:anomalies] do
        state.forecasts.anomalies
        |> Enum.take(5)
        |> Enum.map(&format_anomaly_alert/1)
      else
        []
      end
    
    pattern_alerts =
      if state.patterns[:patterns] do
        state.patterns.patterns
        |> Enum.filter(fn p -> p.confidence > 0.8 end)
        |> Enum.take(3)
        |> Enum.map(&format_pattern_alert/1)
      else
        []
      end
    
    anomaly_alerts ++ pattern_alerts
  end
  
  defp format_anomaly_alert(anomaly) do
    %{
      type: :anomaly,
      severity: alert_severity(anomaly.severity),
      message: "#{anomaly.type} detected",
      timestamp: anomaly.timestamp,
      details: %{
        actual: anomaly.actual,
        expected: anomaly.expected
      }
    }
  end
  
  defp format_pattern_alert(pattern) do
    %{
      type: :pattern,
      severity: :info,
      message: "#{pattern.type} pattern detected",
      timestamp: pattern.detected_at,
      details: pattern.parameters
    }
  end
  
  defp alert_severity(severity) do
    cond do
      severity > 5.0 -> :critical
      severity > 3.0 -> :warning
      true -> :info
    end
  end
end