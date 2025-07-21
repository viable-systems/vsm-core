defmodule VSMCore.Channels.Temporal.Aggregation do
  @moduledoc """
  Multi-scale aggregation and temporal summarization for the variety channel.
  
  This module provides sophisticated aggregation capabilities across different
  timescales, enabling summary statistics, trend aggregation, and hierarchical
  temporal summaries.
  
  ## Aggregation Features
  
  - **Hierarchical Aggregation**: Roll-up from fine to coarse timescales
  - **Statistical Summaries**: Mean, variance, percentiles, etc.
  - **Trend Aggregation**: Aggregate trends across scales
  - **Anomaly Summarization**: Aggregate anomaly counts and severity
  - **Dimensional Aggregation**: Aggregate by variety dimensions
  """
  
  alias VSMCore.Channels.Temporal.{Timescales, Patterns, Forecasting, Causality}
  
  @type summary :: %{
    period: atom(),
    start_time: DateTime.t(),
    end_time: DateTime.t(),
    metrics: map(),
    patterns: list(map()),
    anomalies: list(map()),
    dimensions: map()
  }
  
  @type aggregation_config :: %{
    scales: list(atom()),
    metrics: list(atom()),
    percentiles: list(float())
  }
  
  @doc """
  Generates a comprehensive summary of the temporal variety state.
  """
  @spec generate_summary(map()) :: map()
  def generate_summary(state) do
    %{
      overview: generate_overview(state),
      timescale_summaries: generate_timescale_summaries(state.timescales),
      pattern_summary: summarize_patterns(state.patterns),
      forecast_summary: summarize_forecasts(state.forecasts),
      causal_summary: summarize_causality(state.causal_chains),
      dimensional_breakdown: generate_dimensional_breakdown(state.buffer)
    }
  end
  
  @doc """
  Performs hierarchical aggregation across timescales.
  """
  @spec hierarchical_aggregation(Timescales.t()) :: map()
  def hierarchical_aggregation(timescales) do
    scales = [:real_time, :minute, :hour, :day, :week, :month]
    
    # Build hierarchy
    hierarchy =
      scales
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [fine, coarse] ->
        {fine, aggregate_scale_to_scale(timescales[fine], timescales[coarse])}
      end)
      |> Enum.into(%{})
    
    %{
      hierarchy: hierarchy,
      roll_up_metrics: calculate_roll_up_metrics(hierarchy),
      consistency_score: calculate_consistency_score(hierarchy)
    }
  end
  
  @doc """
  Aggregates variety by dimensions across timescales.
  """
  @spec dimensional_aggregation(list(map())) :: map()
  def dimensional_aggregation(buffer) do
    buffer
    |> extract_dimensional_data()
    |> aggregate_by_dimension()
    |> calculate_dimensional_statistics()
  end
  
  @doc """
  Creates time-based summaries for reporting.
  """
  @spec time_based_summary(map(), DateTime.t(), DateTime.t()) :: summary()
  def time_based_summary(state, start_time, end_time) do
    filtered_data = filter_by_time_range(state.buffer, start_time, end_time)
    
    %{
      period: calculate_period(start_time, end_time),
      start_time: start_time,
      end_time: end_time,
      metrics: calculate_summary_metrics(filtered_data),
      patterns: extract_patterns_in_range(state.patterns, start_time, end_time),
      anomalies: extract_anomalies_in_range(state.forecasts[:anomalies], start_time, end_time),
      dimensions: aggregate_dimensions_in_range(filtered_data)
    }
  end
  
  # Private Functions
  
  defp generate_overview(state) do
    current_time = DateTime.utc_now()
    
    %{
      timestamp: current_time,
      total_observations: length(state.buffer),
      active_patterns: count_active_patterns(state.patterns),
      anomaly_rate: calculate_anomaly_rate(state.forecasts[:anomalies]),
      variety_trend: calculate_overall_trend(state.timescales),
      health_score: calculate_health_score(state)
    }
  end
  
  defp generate_timescale_summaries(timescales) do
    timescales
    |> Enum.map(fn {scale, window} ->
      {scale, summarize_window(window)}
    end)
    |> Enum.into(%{})
  end
  
  defp summarize_window(window) do
    if Enum.empty?(window.data) do
      empty_summary()
    else
      values = Enum.map(window.data, & &1.value)
      
      %{
        count: length(window.data),
        mean: calculate_mean(values),
        std_dev: calculate_std_dev(values),
        min: Enum.min(values),
        max: Enum.max(values),
        percentiles: calculate_percentiles(values, [0.25, 0.5, 0.75, 0.95]),
        trend: window.aggregates.momentum,
        volatility: calculate_volatility(values),
        last_update: window.last_update
      }
    end
  end
  
  defp empty_summary do
    %{
      count: 0,
      mean: 0.0,
      std_dev: 0.0,
      min: 0.0,
      max: 0.0,
      percentiles: %{},
      trend: 0.0,
      volatility: 0.0,
      last_update: nil
    }
  end
  
  defp summarize_patterns(patterns) when is_map(patterns) do
    pattern_list = Map.get(patterns, :patterns, [])
    
    %{
      total_patterns: length(pattern_list),
      by_type: group_patterns_by_type(pattern_list),
      dominant_type: find_dominant_pattern_type(pattern_list),
      average_confidence: calculate_average_confidence(pattern_list),
      time_distribution: calculate_pattern_time_distribution(pattern_list)
    }
  end
  
  defp summarize_patterns(_), do: %{total_patterns: 0, by_type: %{}}
  
  defp group_patterns_by_type(patterns) do
    patterns
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, group} ->
      {type, %{
        count: length(group),
        avg_confidence: calculate_average_confidence(group),
        patterns: Enum.take(group, 3)  # Top 3 patterns
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp find_dominant_pattern_type(patterns) do
    if Enum.empty?(patterns) do
      nil
    else
      patterns
      |> Enum.group_by(& &1.type)
      |> Enum.max_by(fn {_type, group} -> length(group) end)
      |> elem(0)
    end
  end
  
  defp calculate_average_confidence(patterns) do
    if Enum.empty?(patterns) do
      0.0
    else
      patterns
      |> Enum.map(& &1.confidence)
      |> Enum.sum()
      |> Kernel./(length(patterns))
    end
  end
  
  defp calculate_pattern_time_distribution(patterns) do
    patterns
    |> Enum.group_by(fn p -> 
      p.detected_at.hour
    end)
    |> Enum.map(fn {hour, group} ->
      {hour, length(group)}
    end)
    |> Enum.into(%{})
  end
  
  defp summarize_forecasts(forecasts) when is_map(forecasts) do
    %{
      horizons: Map.keys(forecasts) |> Enum.reject(&(&1 == :anomalies)),
      accuracy_metrics: calculate_forecast_accuracy(forecasts),
      anomaly_summary: summarize_anomalies(Map.get(forecasts, :anomalies, [])),
      confidence_levels: aggregate_forecast_confidence(forecasts)
    }
  end
  
  defp summarize_forecasts(_), do: %{horizons: [], accuracy_metrics: %{}}
  
  defp calculate_forecast_accuracy(forecasts) do
    # Placeholder for actual accuracy calculation
    %{
      mae: 0.0,  # Mean Absolute Error
      rmse: 0.0, # Root Mean Square Error
      mape: 0.0  # Mean Absolute Percentage Error
    }
  end
  
  defp summarize_anomalies(anomalies) do
    if Enum.empty?(anomalies) do
      %{count: 0, severity_distribution: %{}}
    else
      %{
        count: length(anomalies),
        severity_distribution: group_by_severity(anomalies),
        type_distribution: group_by_anomaly_type(anomalies),
        recent_anomalies: Enum.take(anomalies, -5)
      }
    end
  end
  
  defp group_by_severity(anomalies) do
    anomalies
    |> Enum.group_by(fn a ->
      cond do
        a.severity > 5.0 -> :critical
        a.severity > 3.0 -> :high
        a.severity > 2.0 -> :medium
        true -> :low
      end
    end)
    |> Enum.map(fn {level, group} -> {level, length(group)} end)
    |> Enum.into(%{})
  end
  
  defp group_by_anomaly_type(anomalies) do
    anomalies
    |> Enum.frequencies_by(& &1.type)
  end
  
  defp aggregate_forecast_confidence(forecasts) do
    forecasts
    |> Enum.reject(fn {k, _v} -> k == :anomalies end)
    |> Enum.map(fn {horizon, forecast_list} ->
      avg_confidence = 
        if is_list(forecast_list) and not Enum.empty?(forecast_list) do
          forecast_list
          |> Enum.map(fn f ->
            {lower, upper} = f.confidence_interval
            width = upper - lower
            if width > 0, do: 1.0 / width, else: 0.0
          end)
          |> Enum.sum()
          |> Kernel./(length(forecast_list))
        else
          0.0
        end
      
      {horizon, avg_confidence}
    end)
    |> Enum.into(%{})
  end
  
  defp summarize_causality(causal_chains) do
    if Enum.empty?(causal_chains) do
      %{chain_count: 0, root_causes: [], terminal_effects: []}
    else
      %{
        chain_count: length(causal_chains),
        average_chain_length: calculate_average_chain_length(causal_chains),
        root_causes: extract_root_causes(causal_chains),
        terminal_effects: extract_terminal_effects(causal_chains),
        strongest_chains: find_strongest_chains(causal_chains, 3),
        total_lag_distribution: calculate_lag_distribution(causal_chains)
      }
    end
  end
  
  defp calculate_average_chain_length(chains) do
    if Enum.empty?(chains) do
      0.0
    else
      chains
      |> Enum.map(fn chain -> length(chain.links) end)
      |> Enum.sum()
      |> Kernel./(length(chains))
    end
  end
  
  defp extract_root_causes(chains) do
    chains
    |> Enum.map(& &1.root_cause)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
  end
  
  defp extract_terminal_effects(chains) do
    chains
    |> Enum.flat_map(& &1.effects)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
  end
  
  defp find_strongest_chains(chains, n) do
    chains
    |> Enum.sort_by(fn chain ->
      # Score based on link strengths and chain length
      total_strength = Enum.sum(Enum.map(chain.links, & &1.strength))
      total_strength * length(chain.links)
    end, :desc)
    |> Enum.take(n)
    |> Enum.map(&summarize_chain/1)
  end
  
  defp summarize_chain(chain) do
    %{
      id: chain.id,
      path: build_chain_path(chain),
      total_strength: Enum.sum(Enum.map(chain.links, & &1.strength)),
      total_lag: chain.total_lag
    }
  end
  
  defp build_chain_path(chain) do
    [chain.root_cause | Enum.map(chain.links, & &1.to)]
    |> Enum.join(" → ")
  end
  
  defp calculate_lag_distribution(chains) do
    chains
    |> Enum.map(& &1.total_lag)
    |> Enum.frequencies()
    |> Enum.sort()
  end
  
  defp generate_dimensional_breakdown(buffer) do
    dimensional_data = extract_dimensional_data(buffer)
    
    dimensional_data
    |> Enum.map(fn {dimension, values} ->
      {dimension, %{
        total_value: Enum.sum(values),
        mean_value: calculate_mean(values),
        contribution: calculate_contribution(values, dimensional_data),
        trend: calculate_dimension_trend(values),
        volatility: calculate_volatility(values)
      }}
    end)
    |> Enum.into(%{})
    |> add_dimension_rankings()
  end
  
  defp extract_dimensional_data(buffer) do
    buffer
    |> Enum.flat_map(fn metric ->
      Enum.map(metric.dimensions, fn {dim, value} ->
        {dim, value}
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
  
  defp calculate_contribution(dimension_values, all_dimensional_data) do
    total_sum = 
      all_dimensional_data
      |> Enum.flat_map(fn {_dim, values} -> values end)
      |> Enum.sum()
    
    if total_sum > 0 do
      Enum.sum(dimension_values) / total_sum
    else
      0.0
    end
  end
  
  defp calculate_dimension_trend(values) do
    if length(values) < 2 do
      0.0
    else
      # Simple trend: compare first and last halves
      half = div(length(values), 2)
      first_half = Enum.take(values, half)
      second_half = Enum.drop(values, half)
      
      first_mean = calculate_mean(first_half)
      second_mean = calculate_mean(second_half)
      
      if first_mean > 0 do
        (second_mean - first_mean) / first_mean
      else
        0.0
      end
    end
  end
  
  defp add_dimension_rankings(dimensional_breakdown) do
    rankings = %{
      by_contribution: rank_dimensions_by(dimensional_breakdown, :contribution),
      by_volatility: rank_dimensions_by(dimensional_breakdown, :volatility),
      by_trend: rank_dimensions_by(dimensional_breakdown, :trend)
    }
    
    Map.put(dimensional_breakdown, :_rankings, rankings)
  end
  
  defp rank_dimensions_by(breakdown, metric) do
    breakdown
    |> Enum.reject(fn {k, _v} -> k == :_rankings end)
    |> Enum.sort_by(fn {_dim, stats} -> 
      Map.get(stats, metric, 0)
    end, :desc)
    |> Enum.take(10)
    |> Enum.map(&elem(&1, 0))
  end
  
  defp aggregate_scale_to_scale(fine_window, coarse_window) do
    if fine_window && coarse_window do
      %{
        alignment_score: calculate_scale_alignment(fine_window, coarse_window),
        information_loss: calculate_information_loss(fine_window, coarse_window),
        aggregation_method: determine_aggregation_method(fine_window.scale)
      }
    else
      %{alignment_score: 0.0, information_loss: 0.0, aggregation_method: :none}
    end
  end
  
  defp calculate_scale_alignment(fine_window, coarse_window) do
    # Compare trends between scales
    fine_trend = Map.get(fine_window.aggregates, :momentum, 0)
    coarse_trend = Map.get(coarse_window.aggregates, :momentum, 0)
    
    if fine_trend * coarse_trend > 0 do
      # Same direction
      1.0 - abs(fine_trend - coarse_trend) / max(abs(fine_trend), abs(coarse_trend))
    else
      0.0
    end
  end
  
  defp calculate_information_loss(fine_window, coarse_window) do
    # Estimate information loss in aggregation
    fine_variance = Map.get(fine_window.aggregates, :variance, 0)
    coarse_variance = Map.get(coarse_window.aggregates, :variance, 0)
    
    if fine_variance > 0 do
      1.0 - coarse_variance / fine_variance
    else
      0.0
    end
  end
  
  defp determine_aggregation_method(scale) do
    case scale do
      :real_time -> :mean
      :minute -> :weighted_mean
      :hour -> :median
      _ -> :percentile_based
    end
  end
  
  defp calculate_roll_up_metrics(hierarchy) do
    hierarchy
    |> Enum.map(fn {scale, aggregation} ->
      {scale, %{
        efficiency: 1.0 - aggregation.information_loss,
        alignment: aggregation.alignment_score
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp calculate_consistency_score(hierarchy) do
    if map_size(hierarchy) == 0 do
      1.0
    else
      scores = 
        hierarchy
        |> Map.values()
        |> Enum.map(& &1.alignment_score)
      
      calculate_mean(scores)
    end
  end
  
  defp aggregate_by_dimension(dimensional_data) do
    dimensional_data
    |> Enum.map(fn {dimension, values} ->
      {dimension, %{
        values: values,
        statistics: calculate_dimension_statistics(values)
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp calculate_dimension_statistics(values) do
    %{
      count: length(values),
      sum: Enum.sum(values),
      mean: calculate_mean(values),
      std_dev: calculate_std_dev(values),
      percentiles: calculate_percentiles(values, [0.1, 0.25, 0.5, 0.75, 0.9])
    }
  end
  
  defp calculate_dimensional_statistics(aggregated_data) do
    %{
      total_dimensions: map_size(aggregated_data),
      dimension_distribution: calculate_dimension_distribution(aggregated_data),
      correlation_matrix: calculate_dimension_correlations(aggregated_data),
      dominance_score: calculate_dimension_dominance(aggregated_data)
    }
  end
  
  defp calculate_dimension_distribution(aggregated_data) do
    total_sum = 
      aggregated_data
      |> Map.values()
      |> Enum.map(fn d -> d.statistics.sum end)
      |> Enum.sum()
    
    if total_sum > 0 do
      aggregated_data
      |> Enum.map(fn {dim, data} ->
        {dim, data.statistics.sum / total_sum}
      end)
      |> Enum.into(%{})
    else
      %{}
    end
  end
  
  defp calculate_dimension_correlations(aggregated_data) do
    # Simplified correlation matrix
    dimensions = Map.keys(aggregated_data)
    
    if length(dimensions) < 2 do
      %{}
    else
      # Placeholder for actual correlation calculation
      %{computed: false, reason: "Requires time-aligned data"}
    end
  end
  
  defp calculate_dimension_dominance(aggregated_data) do
    distribution = calculate_dimension_distribution(aggregated_data)
    
    if map_size(distribution) > 0 do
      # Herfindahl index
      distribution
      |> Map.values()
      |> Enum.map(fn share -> share * share end)
      |> Enum.sum()
    else
      0.0
    end
  end
  
  defp filter_by_time_range(buffer, start_time, end_time) do
    buffer
    |> Enum.filter(fn metric ->
      DateTime.compare(metric.timestamp, start_time) != :lt and
      DateTime.compare(metric.timestamp, end_time) != :gt
    end)
  end
  
  defp calculate_period(start_time, end_time) do
    diff_seconds = DateTime.diff(end_time, start_time)
    
    cond do
      diff_seconds <= 3600 -> :hourly
      diff_seconds <= 86400 -> :daily
      diff_seconds <= 604800 -> :weekly
      true -> :custom
    end
  end
  
  defp calculate_summary_metrics(data) do
    if Enum.empty?(data) do
      empty_summary()
    else
      values = Enum.map(data, & &1.value)
      
      %{
        observations: length(data),
        mean_variety: calculate_mean(values),
        max_variety: Enum.max(values),
        min_variety: Enum.min(values),
        variety_range: Enum.max(values) - Enum.min(values),
        coefficient_of_variation: calculate_cv(values)
      }
    end
  end
  
  defp extract_patterns_in_range(patterns, start_time, end_time) do
    pattern_list = Map.get(patterns, :patterns, [])
    
    pattern_list
    |> Enum.filter(fn p ->
      DateTime.compare(p.detected_at, start_time) != :lt and
      DateTime.compare(p.detected_at, end_time) != :gt
    end)
    |> Enum.take(10)
  end
  
  defp extract_anomalies_in_range(anomalies, start_time, end_time) do
    if anomalies do
      anomalies
      |> Enum.filter(fn a ->
        DateTime.compare(a.timestamp, start_time) != :lt and
        DateTime.compare(a.timestamp, end_time) != :gt
      end)
    else
      []
    end
  end
  
  defp aggregate_dimensions_in_range(data) do
    data
    |> extract_dimensional_data()
    |> aggregate_by_dimension()
  end
  
  defp count_active_patterns(patterns) do
    pattern_list = Map.get(patterns, :patterns, [])
    length(pattern_list)
  end
  
  defp calculate_anomaly_rate(anomalies) do
    if anomalies && length(anomalies) > 0 do
      # Anomalies per hour
      time_span = 
        case {List.first(anomalies), List.last(anomalies)} do
          {first, last} -> 
            DateTime.diff(last.timestamp, first.timestamp, :second) / 3600
          _ -> 
            1.0
        end
      
      if time_span > 0 do
        length(anomalies) / time_span
      else
        0.0
      end
    else
      0.0
    end
  end
  
  defp calculate_overall_trend(timescales) do
    trends = 
      timescales
      |> Map.values()
      |> Enum.map(fn window -> Map.get(window.aggregates, :momentum, 0) end)
    
    if Enum.empty?(trends) do
      0.0
    else
      calculate_mean(trends)
    end
  end
  
  defp calculate_health_score(state) do
    # Composite health score based on various factors
    factors = [
      {0.3, calculate_stability_score(state.timescales)},
      {0.2, calculate_pattern_consistency_score(state.patterns)},
      {0.2, calculate_forecast_reliability_score(state.forecasts)},
      {0.3, calculate_causality_clarity_score(state.causal_chains)}
    ]
    
    factors
    |> Enum.map(fn {weight, score} -> weight * score end)
    |> Enum.sum()
    |> min(1.0)
    |> max(0.0)
  end
  
  defp calculate_stability_score(timescales) do
    volatilities = 
      timescales
      |> Map.values()
      |> Enum.map(fn window ->
        if window.aggregates.variance > 0 do
          :math.sqrt(window.aggregates.variance)
        else
          0.0
        end
      end)
    
    if Enum.empty?(volatilities) do
      1.0
    else
      avg_volatility = calculate_mean(volatilities)
      1.0 / (1.0 + avg_volatility)
    end
  end
  
  defp calculate_pattern_consistency_score(patterns) do
    pattern_list = Map.get(patterns, :patterns, [])
    
    if Enum.empty?(pattern_list) do
      0.5  # Neutral score
    else
      avg_confidence = calculate_average_confidence(pattern_list)
      avg_confidence
    end
  end
  
  defp calculate_forecast_reliability_score(_forecasts) do
    # Placeholder - would calculate based on forecast accuracy
    0.7
  end
  
  defp calculate_causality_clarity_score(causal_chains) do
    if Enum.empty?(causal_chains) do
      0.5  # Neutral score
    else
      # Score based on chain strength and clarity
      avg_strength = 
        causal_chains
        |> Enum.flat_map(& &1.links)
        |> Enum.map(& &1.strength)
        |> calculate_mean()
      
      avg_strength
    end
  end
  
  # Utility Functions
  
  defp calculate_mean(values) do
    if Enum.empty?(values) do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end
  
  defp calculate_std_dev(values) do
    if length(values) < 2 do
      0.0
    else
      mean = calculate_mean(values)
      
      variance = 
        values
        |> Enum.map(fn v -> (v - mean) * (v - mean) end)
        |> Enum.sum()
        |> Kernel./(length(values) - 1)
      
      :math.sqrt(variance)
    end
  end
  
  defp calculate_volatility(values) do
    if length(values) < 2 do
      0.0
    else
      # Calculate returns
      returns = 
        values
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] ->
          if a > 0, do: (b - a) / a, else: 0.0
        end)
      
      calculate_std_dev(returns)
    end
  end
  
  defp calculate_cv(values) do
    mean = calculate_mean(values)
    
    if mean > 0 do
      calculate_std_dev(values) / mean
    else
      0.0
    end
  end
  
  defp calculate_percentiles(values, percentiles) do
    if Enum.empty?(values) do
      %{}
    else
      sorted = Enum.sort(values)
      n = length(sorted)
      
      percentiles
      |> Enum.map(fn p ->
        index = round(p * (n - 1))
        value = Enum.at(sorted, index)
        {p, value}
      end)
      |> Enum.into(%{})
    end
  end
end