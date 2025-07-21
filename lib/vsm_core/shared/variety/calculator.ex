defmodule VSMCore.Shared.Variety.Calculator do
  @moduledoc """
  Provides real-time variety calculations and complexity metrics for VSM systems.
  
  This module calculates variety metrics, assesses system-environment balance,
  and provides recommendations for variety management.
  """
  
  alias VSMCore.Shared.VarietyEngineering
  
  @type variety_metric :: %{
    value: float(),
    timestamp: integer(),
    dimensions: map(),
    confidence: float()
  }
  
  @type complexity_metric :: %{
    structural: float(),
    dynamic: float(),
    emergent: float(),
    total: float()
  }
  
  @type balance_assessment :: %{
    ratio: float(),
    state: :balanced | :overwhelmed | :underutilized,
    adjustment_needed: float(),
    recommendations: [atom()]
  }
  
  @doc """
  Calculates real-time variety for a given system state.
  """
  def calculate_variety(system_state, options \\ []) do
    calculation_method = Keyword.get(options, :method, :comprehensive)
    time_window = Keyword.get(options, :window, :current)
    include_potential = Keyword.get(options, :include_potential, true)
    
    base_variety = 
      case calculation_method do
        :simple -> calculate_simple_variety(system_state)
        :dimensional -> calculate_dimensional_variety(system_state, options)
        :comprehensive -> calculate_comprehensive_variety(system_state, options)
      end
    
    temporal_variety = apply_temporal_window(base_variety, time_window, system_state)
    
    final_variety = 
      if include_potential do
        add_potential_variety(temporal_variety, system_state)
      else
        temporal_variety
      end
    
    %{
      value: final_variety.total,
      timestamp: System.system_time(:millisecond),
      dimensions: final_variety.dimensions,
      confidence: calculate_confidence(final_variety, options),
      method: calculation_method,
      components: final_variety
    }
  end
  
  @doc """
  Calculates complexity metrics for the system.
  """
  def calculate_complexity(system_state, options \\ []) do
    include_emergence = Keyword.get(options, :include_emergence, true)
    
    structural = calculate_structural_complexity(system_state)
    dynamic = calculate_dynamic_complexity(system_state)
    
    emergent = 
      if include_emergence do
        calculate_emergent_complexity(system_state, structural, dynamic)
      else
        0.0
      end
    
    total = aggregate_complexity([structural, dynamic, emergent])
    
    %{
      structural: structural,
      dynamic: dynamic,
      emergent: emergent,
      total: total,
      breakdown: analyze_complexity_sources(system_state),
      trajectory: predict_complexity_trajectory(system_state, total)
    }
  end
  
  @doc """
  Assesses the balance between system and environment variety.
  """
  def assess_balance(system_variety, environment_variety, options \\ []) do
    tolerance = Keyword.get(options, :tolerance, 0.15)
    include_trends = Keyword.get(options, :include_trends, true)
    
    ratio = safe_divide(system_variety, environment_variety)
    
    state = determine_balance_state(ratio, tolerance)
    adjustment = calculate_adjustment_needed(ratio, state)
    recommendations = generate_recommendations(state, ratio, options)
    
    base_assessment = %{
      ratio: ratio,
      state: state,
      adjustment_needed: adjustment,
      recommendations: recommendations,
      confidence: calculate_balance_confidence(system_variety, environment_variety)
    }
    
    if include_trends do
      Map.put(base_assessment, :trend_analysis, analyze_balance_trends(ratio, options))
    else
      base_assessment
    end
  end
  
  @doc """
  Calculates variety absorption rate.
  """
  def calculate_absorption_rate(system_state, variety_flow, options \\ []) do
    time_period = Keyword.get(options, :period, :minute)
    
    current_capacity = calculate_current_capacity(system_state)
    incoming_variety = measure_variety_flow(variety_flow, time_period)
    absorbed_variety = calculate_absorbed_variety(system_state, incoming_variety)
    
    absorption_rate = safe_divide(absorbed_variety, incoming_variety)
    
    %{
      rate: absorption_rate,
      absorbed: absorbed_variety,
      incoming: incoming_variety,
      capacity_utilization: safe_divide(absorbed_variety, current_capacity),
      bottlenecks: identify_absorption_bottlenecks(system_state, absorption_rate),
      time_period: time_period
    }
  end
  
  @doc """
  Monitors variety dynamics over time.
  """
  def monitor_dynamics(measurements, options \\ []) do
    window_size = Keyword.get(options, :window_size, 100)
    analysis_depth = Keyword.get(options, :depth, :full)
    
    recent_measurements = 
      measurements
      |> Enum.take(-window_size)
    
    dynamics = 
      case analysis_depth do
        :basic -> analyze_basic_dynamics(recent_measurements)
        :standard -> analyze_standard_dynamics(recent_measurements)
        :full -> analyze_full_dynamics(recent_measurements)
      end
    
    %{
      trend: dynamics.trend,
      volatility: dynamics.volatility,
      cycles: dynamics.cycles,
      change_points: dynamics.change_points,
      predictions: generate_predictions(dynamics),
      health_score: calculate_dynamics_health(dynamics)
    }
  end
  
  @doc """
  Calculates variety efficiency metrics.
  """
  def calculate_efficiency(system_state, outcomes, options \\ []) do
    variety_used = calculate_variety(system_state, options).value
    variety_required = estimate_required_variety(outcomes)
    
    efficiency = safe_divide(variety_required, variety_used)
    
    %{
      efficiency_ratio: efficiency,
      variety_used: variety_used,
      variety_required: variety_required,
      waste: max(0, variety_used - variety_required),
      optimization_potential: calculate_optimization_potential(efficiency),
      recommendations: generate_efficiency_recommendations(efficiency)
    }
  end
  
  @doc """
  Performs variety forecasting.
  """
  def forecast_variety(historical_data, horizon, options \\ []) do
    method = Keyword.get(options, :method, :adaptive)
    confidence_level = Keyword.get(options, :confidence, 0.95)
    
    forecast = 
      case method do
        :linear -> linear_forecast(historical_data, horizon)
        :exponential -> exponential_forecast(historical_data, horizon)
        :adaptive -> adaptive_forecast(historical_data, horizon)
        :ensemble -> ensemble_forecast(historical_data, horizon)
      end
    
    add_confidence_intervals(forecast, confidence_level, historical_data)
  end
  
  @doc """
  Calculates variety distribution across system components.
  """
  def calculate_distribution(system_state, options \\ []) do
    components = extract_components(system_state)
    
    variety_by_component = 
      components
      |> Enum.map(fn {name, state} ->
        variety = calculate_variety(state, options).value
        {name, variety}
      end)
      |> Map.new()
    
    total_variety = variety_by_component |> Map.values() |> Enum.sum()
    
    distribution = 
      variety_by_component
      |> Enum.map(fn {name, variety} ->
        percentage = safe_divide(variety * 100, total_variety)
        {name, %{
          variety: variety,
          percentage: percentage,
          relative_load: variety / length(Map.keys(components))
        }}
      end)
      |> Map.new()
    
    %{
      distribution: distribution,
      total_variety: total_variety,
      concentration_index: calculate_concentration_index(distribution),
      balance_score: calculate_distribution_balance(distribution),
      recommendations: suggest_redistribution(distribution)
    }
  end
  
  # Private helper functions
  
  defp calculate_simple_variety(system_state) do
    states = Map.get(system_state, :possible_states, [])
    
    %{
      total: length(Enum.uniq(states)),
      dimensions: %{primary: length(Enum.uniq(states))},
      method: :count_based
    }
  end
  
  defp calculate_dimensional_variety(system_state, options) do
    dimensions = Keyword.get(options, :dimensions, [:state, :behavior, :structure])
    
    dimensional_varieties = 
      dimensions
      |> Enum.map(fn dimension ->
        variety = calculate_dimension_variety(system_state, dimension)
        {dimension, variety}
      end)
      |> Map.new()
    
    total = dimensional_varieties |> Map.values() |> Enum.sum()
    
    %{
      total: total,
      dimensions: dimensional_varieties,
      method: :dimensional
    }
  end
  
  defp calculate_comprehensive_variety(system_state, options) do
    # State variety
    state_variety = calculate_state_space_variety(system_state)
    
    # Behavioral variety
    behavioral_variety = calculate_behavioral_variety(system_state)
    
    # Structural variety
    structural_variety = calculate_structural_variety(system_state)
    
    # Interaction variety
    interaction_variety = calculate_interaction_variety(system_state)
    
    # Temporal variety
    temporal_variety = calculate_temporal_variety(system_state)
    
    dimensions = %{
      state: state_variety,
      behavioral: behavioral_variety,
      structural: structural_variety,
      interaction: interaction_variety,
      temporal: temporal_variety
    }
    
    # Weight and combine
    weights = Keyword.get(options, :weights, default_variety_weights())
    
    total = 
      dimensions
      |> Enum.map(fn {dim, value} ->
        weight = Map.get(weights, dim, 1.0)
        value * weight
      end)
      |> Enum.sum()
    
    %{
      total: total,
      dimensions: dimensions,
      weights: weights,
      method: :comprehensive
    }
  end
  
  defp calculate_dimension_variety(system_state, :state) do
    states = Map.get(system_state, :states, [])
    length(Enum.uniq(states))
  end
  
  defp calculate_dimension_variety(system_state, :behavior) do
    behaviors = Map.get(system_state, :behaviors, [])
    length(Enum.uniq(behaviors))
  end
  
  defp calculate_dimension_variety(system_state, :structure) do
    components = Map.get(system_state, :components, %{})
    connections = Map.get(system_state, :connections, [])
    
    map_size(components) + length(connections)
  end
  
  defp calculate_dimension_variety(_system_state, _dimension) do
    0
  end
  
  defp calculate_state_space_variety(system_state) do
    states = Map.get(system_state, :states, [])
    state_dimensions = Map.get(system_state, :state_dimensions, 1)
    
    if Enum.empty?(states) do
      0
    else
      unique_states = Enum.uniq(states) |> length()
      :math.pow(unique_states, state_dimensions)
    end
  end
  
  defp calculate_behavioral_variety(system_state) do
    behaviors = Map.get(system_state, :behaviors, [])
    behavior_patterns = Map.get(system_state, :behavior_patterns, [])
    
    base_variety = length(Enum.uniq(behaviors))
    pattern_variety = length(Enum.uniq(behavior_patterns))
    
    base_variety + pattern_variety * 0.5
  end
  
  defp calculate_structural_variety(system_state) do
    components = Map.get(system_state, :components, %{})
    connections = Map.get(system_state, :connections, [])
    hierarchies = Map.get(system_state, :hierarchies, 1)
    
    component_variety = map_size(components)
    connection_variety = length(connections)
    hierarchy_variety = :math.log2(hierarchies + 1)
    
    component_variety + connection_variety * 0.5 + hierarchy_variety * 2
  end
  
  defp calculate_interaction_variety(system_state) do
    interactions = Map.get(system_state, :interactions, [])
    protocols = Map.get(system_state, :protocols, [])
    
    interaction_types = interactions |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length()
    protocol_variety = length(Enum.uniq(protocols))
    
    interaction_types * protocol_variety
  end
  
  defp calculate_temporal_variety(system_state) do
    time_scales = Map.get(system_state, :time_scales, [])
    cycles = Map.get(system_state, :cycles, [])
    
    scale_variety = length(Enum.uniq(time_scales))
    cycle_variety = length(Enum.uniq(cycles))
    
    scale_variety + cycle_variety * 1.5
  end
  
  defp default_variety_weights do
    %{
      state: 1.0,
      behavioral: 1.2,
      structural: 0.8,
      interaction: 1.1,
      temporal: 0.9
    }
  end
  
  defp apply_temporal_window(variety, :current, _system_state) do
    variety
  end
  
  defp apply_temporal_window(variety, {:window, duration}, system_state) do
    historical_states = Map.get(system_state, :historical_states, [])
    current_time = System.system_time(:millisecond)
    window_start = current_time - duration
    
    windowed_states = 
      historical_states
      |> Enum.filter(fn {_state, timestamp} ->
        timestamp >= window_start
      end)
    
    if Enum.empty?(windowed_states) do
      variety
    else
      # Recalculate variety for windowed states
      windowed_system_state = Map.put(system_state, :states, windowed_states)
      calculate_comprehensive_variety(windowed_system_state, [])
    end
  end
  
  defp add_potential_variety(variety, system_state) do
    latent_states = Map.get(system_state, :latent_states, [])
    adaptability = Map.get(system_state, :adaptability, 0.5)
    
    potential = length(latent_states) * adaptability
    
    Map.update!(variety, :total, &(&1 + potential))
    |> Map.put(:potential, potential)
  end
  
  defp calculate_confidence(variety, options) do
    sample_size = Keyword.get(options, :sample_size, 100)
    measurement_quality = Keyword.get(options, :measurement_quality, 0.9)
    
    # Confidence based on sample size and measurement quality
    sample_confidence = :math.tanh(sample_size / 100)
    
    confidence = sample_confidence * measurement_quality
    
    # Adjust for method used
    method_adjustment = 
      case variety.method do
        :comprehensive -> 1.0
        :dimensional -> 0.9
        :simple -> 0.7
      end
    
    confidence * method_adjustment
  end
  
  defp calculate_structural_complexity(system_state) do
    components = Map.get(system_state, :components, %{})
    connections = Map.get(system_state, :connections, [])
    hierarchies = Map.get(system_state, :hierarchies, 1)
    
    # Component complexity
    component_complexity = :math.log2(map_size(components) + 1)
    
    # Connection complexity (network effects)
    connection_complexity = 
      if length(connections) > 0 do
        :math.log2(length(connections)) * 
        (:math.log2(map_size(components) + 1) / :math.log2(2.718))
      else
        0
      end
    
    # Hierarchical complexity
    hierarchy_complexity = :math.pow(hierarchies, 0.5)
    
    component_complexity + connection_complexity + hierarchy_complexity
  end
  
  defp calculate_dynamic_complexity(system_state) do
    behaviors = Map.get(system_state, :behaviors, [])
    state_transitions = Map.get(system_state, :state_transitions, [])
    feedback_loops = Map.get(system_state, :feedback_loops, [])
    
    # Behavioral complexity
    behavior_complexity = 
      behaviors
      |> Enum.uniq()
      |> length()
      |> :math.log2()
      |> max(0)
    
    # Transition complexity
    transition_complexity = 
      if length(state_transitions) > 0 do
        unique_transitions = state_transitions |> Enum.uniq() |> length()
        :math.log2(unique_transitions + 1)
      else
        0
      end
    
    # Feedback complexity
    feedback_complexity = length(feedback_loops) * 1.5
    
    behavior_complexity + transition_complexity + feedback_complexity
  end
  
  defp calculate_emergent_complexity(system_state, structural, dynamic) do
    interactions = Map.get(system_state, :interactions, [])
    emergence_indicators = Map.get(system_state, :emergence_indicators, [])
    
    # Base emergence from structure-dynamic interaction
    base_emergence = :math.sqrt(structural * dynamic)
    
    # Interaction effects
    interaction_complexity = 
      if length(interactions) > 0 do
        unique_interactions = interactions |> Enum.uniq() |> length()
        :math.log2(unique_interactions + 1)
      else
        0
      end
    
    # Known emergence patterns
    emergence_boost = length(emergence_indicators) * 0.5
    
    base_emergence + interaction_complexity + emergence_boost
  end
  
  defp aggregate_complexity(components) do
    # Weighted geometric mean for complexity aggregation
    weights = [0.3, 0.4, 0.3]  # structural, dynamic, emergent
    
    weighted_product = 
      components
      |> Enum.zip(weights)
      |> Enum.reduce(1.0, fn {value, weight}, acc ->
        acc * :math.pow(value + 1, weight)
      end)
    
    weighted_product - 1
  end
  
  defp analyze_complexity_sources(system_state) do
    %{
      primary_sources: identify_primary_complexity_sources(system_state),
      growth_drivers: identify_complexity_growth_drivers(system_state),
      reduction_opportunities: identify_complexity_reduction_opportunities(system_state)
    }
  end
  
  defp identify_primary_complexity_sources(system_state) do
    sources = []
    
    components = Map.get(system_state, :components, %{})
    connections = Map.get(system_state, :connections, [])
    behaviors = Map.get(system_state, :behaviors, [])
    
    sources = 
      if map_size(components) > 50 do
        [{:high_component_count, map_size(components)} | sources]
      else
        sources
      end
    
    sources = 
      if length(connections) > map_size(components) * 3 do
        [{:dense_connections, length(connections)} | sources]
      else
        sources
      end
    
    sources = 
      if length(Enum.uniq(behaviors)) > 20 do
        [{:diverse_behaviors, length(Enum.uniq(behaviors))} | sources]
      else
        sources
      end
    
    sources
  end
  
  defp identify_complexity_growth_drivers(system_state) do
    growth_rate = Map.get(system_state, :growth_rate, 0)
    interaction_rate = Map.get(system_state, :interaction_rate, 0)
    
    drivers = []
    
    drivers = 
      if growth_rate > 0.1 do
        [{:rapid_growth, growth_rate} | drivers]
      else
        drivers
      end
    
    drivers = 
      if interaction_rate > 0.5 do
        [{:high_interaction_rate, interaction_rate} | drivers]
      else
        drivers
      end
    
    drivers
  end
  
  defp identify_complexity_reduction_opportunities(system_state) do
    redundant_components = Map.get(system_state, :redundant_components, [])
    unused_connections = Map.get(system_state, :unused_connections, [])
    
    opportunities = []
    
    opportunities = 
      if length(redundant_components) > 0 do
        [{:remove_redundancy, length(redundant_components)} | opportunities]
      else
        opportunities
      end
    
    opportunities = 
      if length(unused_connections) > 0 do
        [{:prune_connections, length(unused_connections)} | opportunities]
      else
        opportunities
      end
    
    opportunities
  end
  
  defp predict_complexity_trajectory(system_state, current_complexity) do
    growth_rate = Map.get(system_state, :complexity_growth_rate, 0.05)
    time_horizon = 10  # periods
    
    trajectory = 
      0..time_horizon
      |> Enum.map(fn t ->
        predicted = current_complexity * :math.pow(1 + growth_rate, t)
        {t, predicted}
      end)
    
    %{
      trajectory: trajectory,
      growth_rate: growth_rate,
      doubling_time: if(growth_rate > 0, do: :math.log(2) / :math.log(1 + growth_rate), else: :infinity)
    }
  end
  
  defp determine_balance_state(ratio, tolerance) do
    cond do
      abs(ratio - 1.0) <= tolerance -> :balanced
      ratio < 1.0 - tolerance -> :overwhelmed
      ratio > 1.0 + tolerance -> :underutilized
    end
  end
  
  defp calculate_adjustment_needed(ratio, state) do
    case state do
      :balanced -> 0.0
      :overwhelmed -> 1.0 - ratio
      :underutilized -> 1.0 - ratio
    end
  end
  
  defp generate_recommendations(state, ratio, _options) do
    case state do
      :balanced ->
        [:maintain_current_approach, :monitor_for_changes]
        
      :overwhelmed ->
        severity = 1.0 - ratio
        if severity > 0.5 do
          [:urgent_amplification_needed, :delegate_immediately, :add_resources]
        else
          [:moderate_amplification_needed, :consider_delegation, :optimize_processes]
        end
        
      :underutilized ->
        excess = ratio - 1.0
        if excess > 0.5 do
          [:significant_attenuation_needed, :consolidate_functions, :reduce_redundancy]
        else
          [:moderate_attenuation_needed, :streamline_processes, :improve_efficiency]
        end
    end
  end
  
  defp calculate_balance_confidence(system_variety, environment_variety) do
    # Confidence decreases with very small or very large values
    min_variety = min(system_variety, environment_variety)
    max_variety = max(system_variety, environment_variety)
    
    if min_variety == 0 do
      0.0
    else
      ratio = min_variety / max_variety
      # Confidence peaks when varieties are similar
      :math.exp(-:math.pow(1 - ratio, 2))
    end
  end
  
  defp analyze_balance_trends(current_ratio, options) do
    historical_ratios = Keyword.get(options, :historical_ratios, [])
    
    if length(historical_ratios) < 3 do
      %{
        trend: :insufficient_data,
        direction: :unknown,
        stability: :unknown
      }
    else
      recent_ratios = Enum.take(historical_ratios, -10)
      
      trend = calculate_trend(recent_ratios)
      direction = determine_trend_direction(trend)
      stability = calculate_stability(recent_ratios)
      
      %{
        trend: trend,
        direction: direction,
        stability: stability,
        projection: project_future_ratio(recent_ratios ++ [current_ratio])
      }
    end
  end
  
  defp calculate_trend(ratios) do
    n = length(ratios)
    
    if n < 2 do
      0.0
    else
      # Simple linear regression for trend
      x_values = 0..(n-1) |> Enum.to_list()
      x_mean = Enum.sum(x_values) / n
      y_mean = Enum.sum(ratios) / n
      
      numerator = 
        x_values
        |> Enum.zip(ratios)
        |> Enum.reduce(0, fn {x, y}, acc ->
          acc + (x - x_mean) * (y - y_mean)
        end)
      
      denominator = 
        x_values
        |> Enum.reduce(0, fn x, acc ->
          acc + :math.pow(x - x_mean, 2)
        end)
      
      if denominator > 0 do
        numerator / denominator
      else
        0.0
      end
    end
  end
  
  defp determine_trend_direction(trend) do
    cond do
      abs(trend) < 0.01 -> :stable
      trend > 0 -> :increasing
      trend < 0 -> :decreasing
    end
  end
  
  defp calculate_stability(ratios) do
    if length(ratios) < 2 do
      :unknown
    else
      mean = Enum.sum(ratios) / length(ratios)
      
      variance = 
        ratios
        |> Enum.map(fn r -> :math.pow(r - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(ratios))
      
      cv = :math.sqrt(variance) / mean  # Coefficient of variation
      
      cond do
        cv < 0.1 -> :high
        cv < 0.3 -> :moderate
        cv < 0.5 -> :low
        true -> :very_low
      end
    end
  end
  
  defp project_future_ratio(ratios) do
    trend = calculate_trend(ratios)
    last_ratio = List.last(ratios)
    
    # Simple linear projection
    next_ratio = last_ratio + trend
    
    %{
      next_period: max(0, next_ratio),
      confidence: calculate_projection_confidence(ratios)
    }
  end
  
  defp calculate_projection_confidence(ratios) do
    stability = calculate_stability(ratios)
    
    case stability do
      :high -> 0.9
      :moderate -> 0.7
      :low -> 0.5
      :very_low -> 0.3
      :unknown -> 0.0
    end
  end
  
  defp calculate_current_capacity(system_state) do
    base_capacity = Map.get(system_state, :base_capacity, 100)
    utilization = Map.get(system_state, :utilization, 0.5)
    
    base_capacity * (1 - utilization)
  end
  
  defp measure_variety_flow(variety_flow, time_period) do
    case time_period do
      :second -> variety_flow
      :minute -> variety_flow * 60
      :hour -> variety_flow * 3600
      :day -> variety_flow * 86400
    end
  end
  
  defp calculate_absorbed_variety(system_state, incoming_variety) do
    capacity = calculate_current_capacity(system_state)
    absorption_efficiency = Map.get(system_state, :absorption_efficiency, 0.8)
    
    min(incoming_variety * absorption_efficiency, capacity)
  end
  
  defp identify_absorption_bottlenecks(system_state, absorption_rate) do
    bottlenecks = []
    
    processing_capacity = Map.get(system_state, :processing_capacity, 1.0)
    communication_bandwidth = Map.get(system_state, :communication_bandwidth, 1.0)
    decision_capacity = Map.get(system_state, :decision_capacity, 1.0)
    
    bottlenecks = 
      if processing_capacity < absorption_rate do
        [{:processing, processing_capacity} | bottlenecks]
      else
        bottlenecks
      end
    
    bottlenecks = 
      if communication_bandwidth < absorption_rate * 0.8 do
        [{:communication, communication_bandwidth} | bottlenecks]
      else
        bottlenecks
      end
    
    bottlenecks = 
      if decision_capacity < absorption_rate * 0.6 do
        [{:decision_making, decision_capacity} | bottlenecks]
      else
        bottlenecks
      end
    
    bottlenecks
  end
  
  defp analyze_basic_dynamics(measurements) do
    values = Enum.map(measurements, & &1.value)
    
    %{
      trend: calculate_trend(values),
      volatility: calculate_volatility(values),
      cycles: [],  # Not calculated in basic analysis
      change_points: []  # Not calculated in basic analysis
    }
  end
  
  defp analyze_standard_dynamics(measurements) do
    values = Enum.map(measurements, & &1.value)
    
    %{
      trend: calculate_trend(values),
      volatility: calculate_volatility(values),
      cycles: detect_simple_cycles(values),
      change_points: []  # Not calculated in standard analysis
    }
  end
  
  defp analyze_full_dynamics(measurements) do
    values = Enum.map(measurements, & &1.value)
    timestamps = Enum.map(measurements, & &1.timestamp)
    
    %{
      trend: calculate_trend(values),
      volatility: calculate_volatility(values),
      cycles: detect_cycles(values, timestamps),
      change_points: detect_change_points(values)
    }
  end
  
  defp calculate_volatility(values) do
    if length(values) < 2 do
      0.0
    else
      returns = 
        values
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] ->
          if a > 0 do
            (b - a) / a
          else
            0
          end
        end)
      
      mean_return = Enum.sum(returns) / length(returns)
      
      variance = 
        returns
        |> Enum.map(fn r -> :math.pow(r - mean_return, 2) end)
        |> Enum.sum()
        |> Kernel./(length(returns))
      
      :math.sqrt(variance)
    end
  end
  
  defp detect_simple_cycles(values) do
    # Simple cycle detection using autocorrelation
    if length(values) < 10 do
      []
    else
      max_lag = min(div(length(values), 2), 50)
      
      correlations = 
        1..max_lag
        |> Enum.map(fn lag ->
          corr = calculate_autocorrelation(values, lag)
          {lag, corr}
        end)
      
      # Find peaks in autocorrelation
      correlations
      |> find_correlation_peaks()
      |> Enum.map(fn {lag, corr} ->
        %{
          period: lag,
          strength: corr,
          type: :simple
        }
      end)
    end
  end
  
  defp detect_cycles(values, timestamps) do
    simple_cycles = detect_simple_cycles(values)
    
    # Add timestamp-based cycle detection
    time_cycles = detect_time_based_cycles(values, timestamps)
    
    (simple_cycles ++ time_cycles)
    |> Enum.uniq_by(& &1.period)
    |> Enum.sort_by(& &1.strength, &>=/2)
  end
  
  defp calculate_autocorrelation(values, lag) do
    n = length(values)
    
    if lag >= n do
      0.0
    else
      mean = Enum.sum(values) / n
      
      # Calculate covariance at lag
      covariance = 
        0..(n - lag - 1)
        |> Enum.reduce(0, fn i, acc ->
          acc + (Enum.at(values, i) - mean) * (Enum.at(values, i + lag) - mean)
        end)
        |> Kernel./(n - lag)
      
      # Calculate variance
      variance = 
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(n)
      
      if variance > 0 do
        covariance / variance
      else
        0.0
      end
    end
  end
  
  defp find_correlation_peaks(correlations) do
    correlations
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.filter(fn [{_, a}, {_, b}, {_, c}] ->
      b > a and b > c and b > 0.3  # Peak detection with threshold
    end)
    |> Enum.map(fn [_, peak, _] -> peak end)
  end
  
  defp detect_time_based_cycles(values, timestamps) do
    if length(values) < 20 do
      []
    else
      # Group by time intervals and look for patterns
      time_intervals = [:hour, :day, :week]
      
      time_intervals
      |> Enum.flat_map(fn interval ->
        grouped = group_by_time_interval(values, timestamps, interval)
        
        if map_size(grouped) > 3 do
          pattern_strength = calculate_pattern_strength(grouped)
          
          if pattern_strength > 0.3 do
            [%{
              period: interval,
              strength: pattern_strength,
              type: :time_based
            }]
          else
            []
          end
        else
          []
        end
      end)
    end
  end
  
  defp group_by_time_interval(values, timestamps, interval) do
    values
    |> Enum.zip(timestamps)
    |> Enum.group_by(fn {_value, timestamp} ->
      truncate_timestamp(timestamp, interval)
    end)
    |> Enum.map(fn {key, pairs} ->
      values = Enum.map(pairs, fn {v, _} -> v end)
      {key, Enum.sum(values) / length(values)}
    end)
    |> Map.new()
  end
  
  defp truncate_timestamp(timestamp, :hour) do
    div(timestamp, 3_600_000)
  end
  
  defp truncate_timestamp(timestamp, :day) do
    div(timestamp, 86_400_000)
  end
  
  defp truncate_timestamp(timestamp, :week) do
    div(timestamp, 604_800_000)
  end
  
  defp calculate_pattern_strength(grouped_data) do
    values = Map.values(grouped_data)
    
    if length(values) < 2 do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      
      variance = 
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values))
      
      if mean > 0 do
        # Coefficient of variation inverted - lower CV means stronger pattern
        cv = :math.sqrt(variance) / mean
        1 / (1 + cv)
      else
        0.0
      end
    end
  end
  
  defp detect_change_points(values) do
    if length(values) < 10 do
      []
    else
      # Simple change point detection using sliding window
      window_size = max(5, div(length(values), 10))
      
      0..(length(values) - window_size * 2)
      |> Enum.map(fn i ->
        before_window = Enum.slice(values, i, window_size)
        after_window = Enum.slice(values, i + window_size, window_size)
        
        before_mean = Enum.sum(before_window) / window_size
        after_mean = Enum.sum(after_window) / window_size
        
        change_magnitude = abs(after_mean - before_mean)
        
        {i + window_size, change_magnitude}
      end)
      |> Enum.filter(fn {_index, magnitude} ->
        # Threshold for significant change
        mean_value = Enum.sum(values) / length(values)
        magnitude > mean_value * 0.2
      end)
      |> Enum.map(fn {index, magnitude} ->
        %{
          index: index,
          magnitude: magnitude,
          type: determine_change_type(values, index)
        }
      end)
    end
  end
  
  defp determine_change_type(values, index) do
    before_idx = max(0, index - 5)
    after_idx = min(length(values) - 1, index + 5)
    
    before_mean = 
      values
      |> Enum.slice(before_idx, index - before_idx)
      |> Enum.sum()
      |> Kernel./(index - before_idx)
    
    after_mean = 
      values
      |> Enum.slice(index, after_idx - index)
      |> Enum.sum()
      |> Kernel./(after_idx - index)
    
    cond do
      after_mean > before_mean * 1.1 -> :increase
      after_mean < before_mean * 0.9 -> :decrease
      true -> :shift
    end
  end
  
  defp generate_predictions(dynamics) do
    %{
      short_term: predict_short_term(dynamics),
      medium_term: predict_medium_term(dynamics),
      confidence: calculate_prediction_confidence(dynamics)
    }
  end
  
  defp predict_short_term(dynamics) do
    # Simple linear extrapolation
    trend = dynamics.trend
    
    %{
      direction: if(trend > 0, do: :increasing, else: :decreasing),
      magnitude: abs(trend),
      volatility_impact: dynamics.volatility
    }
  end
  
  defp predict_medium_term(dynamics) do
    # Consider cycles and change points
    dominant_cycle = List.first(dynamics.cycles)
    recent_change = List.last(dynamics.change_points)
    
    %{
      cycle_influence: dominant_cycle,
      structural_change: recent_change,
      trend_persistence: estimate_trend_persistence(dynamics.trend, dynamics.volatility)
    }
  end
  
  defp estimate_trend_persistence(trend, volatility) do
    if volatility > 0 do
      abs(trend) / volatility
    else
      :infinity
    end
  end
  
  defp calculate_prediction_confidence(dynamics) do
    # Higher volatility and more change points reduce confidence
    base_confidence = 0.8
    volatility_penalty = min(dynamics.volatility * 2, 0.5)
    change_penalty = length(dynamics.change_points) * 0.05
    
    max(0.1, base_confidence - volatility_penalty - change_penalty)
  end
  
  defp calculate_dynamics_health(dynamics) do
    # Health score based on stability and predictability
    trend_score = if abs(dynamics.trend) < 0.1, do: 1.0, else: 0.5
    volatility_score = max(0, 1 - dynamics.volatility * 2)
    
    cycle_score = 
      if length(dynamics.cycles) > 0 do
        # Regular cycles are healthy
        strongest_cycle = dynamics.cycles |> List.first(%{strength: 0}) |> Map.get(:strength, 0)
        strongest_cycle
      else
        0.5  # No cycles - neutral
      end
    
    change_score = max(0, 1 - length(dynamics.change_points) * 0.1)
    
    scores = [trend_score, volatility_score, cycle_score, change_score]
    weights = [0.2, 0.3, 0.2, 0.3]
    
    scores
    |> Enum.zip(weights)
    |> Enum.reduce(0, fn {score, weight}, acc ->
      acc + score * weight
    end)
  end
  
  defp estimate_required_variety(outcomes) do
    # Estimate variety needed based on outcomes
    outcome_diversity = outcomes |> Enum.uniq() |> length()
    outcome_complexity = calculate_outcome_complexity(outcomes)
    
    outcome_diversity * (1 + outcome_complexity)
  end
  
  defp calculate_outcome_complexity(outcomes) do
    if Enum.empty?(outcomes) do
      0.0
    else
      # Simple complexity measure based on outcome structure
      avg_complexity = 
        outcomes
        |> Enum.map(&estimate_single_outcome_complexity/1)
        |> Enum.sum()
        |> Kernel./(length(outcomes))
      
      avg_complexity
    end
  end
  
  defp estimate_single_outcome_complexity(outcome) do
    case outcome do
      x when is_atom(x) -> 0.1
      x when is_number(x) -> 0.1
      x when is_binary(x) -> 0.2
      x when is_list(x) -> 0.3 + length(x) * 0.05
      x when is_map(x) -> 0.4 + map_size(x) * 0.1
      _ -> 0.5
    end
  end
  
  defp calculate_optimization_potential(efficiency) do
    cond do
      efficiency > 0.9 -> :low
      efficiency > 0.7 -> :moderate
      efficiency > 0.5 -> :high
      true -> :very_high
    end
  end
  
  defp generate_efficiency_recommendations(efficiency) do
    cond do
      efficiency > 0.9 ->
        [:maintain_current_approach, :monitor_for_degradation]
        
      efficiency > 0.7 ->
        [:minor_optimization_needed, :review_unused_capabilities]
        
      efficiency > 0.5 ->
        [:significant_optimization_needed, :reduce_variety_waste, :simplify_processes]
        
      true ->
        [:urgent_optimization_required, :major_restructuring_needed, :eliminate_redundancy]
    end
  end
  
  defp linear_forecast(historical_data, horizon) do
    values = Enum.map(historical_data, & &1.value)
    trend = calculate_trend(values)
    last_value = List.last(values, 0)
    
    1..horizon
    |> Enum.map(fn h ->
      forecast_value = last_value + trend * h
      %{
        period: h,
        value: max(0, forecast_value),
        method: :linear
      }
    end)
  end
  
  defp exponential_forecast(historical_data, horizon) do
    values = Enum.map(historical_data, & &1.value)
    
    # Simple exponential smoothing
    alpha = 0.3
    smoothed = exponential_smooth(values, alpha)
    last_smoothed = List.last(smoothed, 0)
    
    1..horizon
    |> Enum.map(fn h ->
      %{
        period: h,
        value: last_smoothed,
        method: :exponential
      }
    end)
  end
  
  defp exponential_smooth(values, alpha) do
    {smoothed, _} = 
      values
      |> Enum.reduce({[], nil}, fn value, {acc, prev_smooth} ->
        smooth = 
          if prev_smooth do
            alpha * value + (1 - alpha) * prev_smooth
          else
            value
          end
        
        {acc ++ [smooth], smooth}
      end)
    
    smoothed
  end
  
  defp adaptive_forecast(historical_data, horizon) do
    # Combine multiple methods adaptively
    linear = linear_forecast(historical_data, horizon)
    exponential = exponential_forecast(historical_data, horizon)
    
    # Weight based on recent performance
    recent_volatility = 
      historical_data
      |> Enum.map(& &1.value)
      |> calculate_volatility()
    
    linear_weight = if recent_volatility < 0.2, do: 0.7, else: 0.3
    exp_weight = 1 - linear_weight
    
    linear
    |> Enum.zip(exponential)
    |> Enum.map(fn {lin, exp} ->
      %{
        period: lin.period,
        value: lin.value * linear_weight + exp.value * exp_weight,
        method: :adaptive
      }
    end)
  end
  
  defp ensemble_forecast(historical_data, horizon) do
    # Ensemble of multiple methods
    methods = [:linear, :exponential, :adaptive]
    
    forecasts = 
      methods
      |> Enum.map(fn method ->
        apply(__MODULE__, :"#{method}_forecast", [historical_data, horizon])
      end)
    
    # Average the forecasts
    1..horizon
    |> Enum.map(fn h ->
      values = 
        forecasts
        |> Enum.map(fn forecast ->
          Enum.find(forecast, & &1.period == h).value
        end)
      
      %{
        period: h,
        value: Enum.sum(values) / length(values),
        method: :ensemble
      }
    end)
  end
  
  defp add_confidence_intervals(forecast, confidence_level, historical_data) do
    historical_volatility = 
      historical_data
      |> Enum.map(& &1.value)
      |> calculate_volatility()
    
    # Z-score for confidence level
    z_score = 
      case confidence_level do
        0.90 -> 1.645
        0.95 -> 1.96
        0.99 -> 2.576
        _ -> 1.96
      end
    
    forecast
    |> Enum.map(fn point ->
      # Uncertainty grows with horizon
      uncertainty = historical_volatility * :math.sqrt(point.period)
      interval = z_score * uncertainty
      
      Map.merge(point, %{
        lower_bound: max(0, point.value - interval),
        upper_bound: point.value + interval,
        confidence_level: confidence_level
      })
    end)
  end
  
  defp extract_components(system_state) do
    Map.get(system_state, :components, %{})
  end
  
  defp calculate_concentration_index(distribution) do
    # Herfindahl-Hirschman Index for concentration
    total_variety = 
      distribution
      |> Map.values()
      |> Enum.map(& &1.variety)
      |> Enum.sum()
    
    if total_variety == 0 do
      0.0
    else
      distribution
      |> Map.values()
      |> Enum.map(fn component ->
        share = component.variety / total_variety
        :math.pow(share, 2)
      end)
      |> Enum.sum()
    end
  end
  
  defp calculate_distribution_balance(distribution) do
    percentages = 
      distribution
      |> Map.values()
      |> Enum.map(& &1.percentage)
    
    if Enum.empty?(percentages) do
      1.0
    else
      expected = 100.0 / map_size(distribution)
      
      deviations = 
        percentages
        |> Enum.map(fn p -> abs(p - expected) end)
        |> Enum.sum()
      
      max_possible_deviation = (map_size(distribution) - 1) * expected
      
      if max_possible_deviation > 0 do
        1.0 - (deviations / max_possible_deviation)
      else
        1.0
      end
    end
  end
  
  defp suggest_redistribution(distribution) do
    avg_variety = 
      distribution
      |> Map.values()
      |> Enum.map(& &1.variety)
      |> Enum.sum()
      |> Kernel./(map_size(distribution))
    
    distribution
    |> Enum.flat_map(fn {component, data} ->
      cond do
        data.variety > avg_variety * 1.5 ->
          [{:reduce_variety, component, data.variety - avg_variety}]
          
        data.variety < avg_variety * 0.5 ->
          [{:increase_variety, component, avg_variety - data.variety}]
          
        true ->
          []
      end
    end)
    |> Enum.sort_by(fn {_, _, amount} -> amount end, &>=/2)
    |> Enum.take(3)
  end
  
  defp safe_divide(a, b) do
    if b == 0, do: 0.0, else: a / b
  end
end