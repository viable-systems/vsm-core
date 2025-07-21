defmodule VSMCore.System3.Resources do
  @moduledoc """
  Resource management module for System 3.
  
  Handles resource allocation algorithms, availability tracking,
  and optimization strategies for S1 units.
  """
  
  require Logger
  
  @type resource_pool :: %{atom() => float()}
  @type allocation :: %{atom() => float()}
  @type resource_request :: %{
    unit_id: atom(),
    resources: resource_pool(),
    priority: float(),
    purpose: atom()
  }
  
  @doc """
  Allocates resources based on requests, availability, performance, and policies.
  """
  @spec allocate([resource_request()], resource_pool(), map(), list()) :: %{atom() => allocation()}
  def allocate(requests, available, performance_data, policies) do
    # Sort requests by priority and performance
    sorted_requests = prioritize_requests(requests, performance_data)
    
    # Apply allocation strategy based on policies
    strategy = determine_allocation_strategy(policies)
    
    case strategy do
      :performance_based ->
        allocate_by_performance(sorted_requests, available, performance_data)
        
      :fair_share ->
        allocate_fair_share(sorted_requests, available)
        
      :priority_weighted ->
        allocate_by_priority(sorted_requests, available)
        
      :adaptive ->
        allocate_adaptive(sorted_requests, available, performance_data, policies)
    end
  end
  
  @doc """
  Calculates available resources given current pool and allocations.
  """
  @spec calculate_available(resource_pool(), %{atom() => allocation()}) :: resource_pool()
  def calculate_available(pool, allocations) do
    total_allocated = Enum.reduce(allocations, %{}, fn {_unit, alloc}, acc ->
      Map.merge(acc, alloc, fn _k, sum, val -> sum + val end)
    end)
    
    Map.merge(pool, total_allocated, fn _k, pool_val, alloc_val ->
      max(0, pool_val - alloc_val)
    end)
  end
  
  @doc """
  Checks if requested resources are available.
  """
  @spec available?(resource_pool(), resource_pool()) :: boolean()
  def available?(pool, requested) do
    Enum.all?(requested, fn {resource, amount} ->
      Map.get(pool, resource, 0) >= amount
    end)
  end
  
  @doc """
  Deducts resources from pool.
  """
  @spec deduct(resource_pool(), resource_pool()) :: resource_pool()
  def deduct(pool, to_deduct) do
    Map.merge(pool, to_deduct, fn _k, pool_val, deduct_val ->
      max(0, pool_val - deduct_val)
    end)
  end
  
  @doc """
  Optimizes resource distribution to maximize overall efficiency.
  """
  @spec optimize_distribution(%{atom() => allocation()}, resource_pool()) :: %{atom() => allocation()}
  def optimize_distribution(current_allocations, total_resources) do
    # Calculate efficiency scores for current allocations
    efficiency_scores = calculate_efficiency_scores(current_allocations)
    
    # Identify underutilized resources
    underutilized = find_underutilized_resources(current_allocations, total_resources)
    
    # Redistribute underutilized resources to high-efficiency units
    redistribute_resources(current_allocations, efficiency_scores, underutilized)
  end
  
  @doc """
  Predicts future resource needs based on historical data.
  """
  @spec predict_resource_needs(map(), integer()) :: resource_pool()
  def predict_resource_needs(historical_data, lookahead_minutes) do
    # Simple prediction based on recent trends
    recent_usage = extract_recent_usage(historical_data, 60) # Last hour
    
    # Calculate trend
    trend = calculate_usage_trend(recent_usage)
    
    # Project forward
    project_resource_needs(trend, lookahead_minutes)
  end
  
  @doc """
  Validates resource allocations against constraints.
  """
  @spec validate_allocations(%{atom() => allocation()}, list()) :: {:ok, %{atom() => allocation()}} | {:error, list()}
  def validate_allocations(allocations, constraints) do
    violations = Enum.flat_map(constraints, fn constraint ->
      check_constraint(allocations, constraint)
    end)
    
    if Enum.empty?(violations) do
      {:ok, allocations}
    else
      {:error, violations}
    end
  end
  
  # Private Functions
  
  defp prioritize_requests(requests, performance_data) do
    Enum.sort_by(requests, fn request ->
      performance_score = get_in(performance_data, [request.unit_id, :score]) || 0.5
      combined_priority = request.priority * performance_score
      -combined_priority # Negative for descending order
    end)
  end
  
  defp determine_allocation_strategy(policies) do
    # Determine strategy based on active policies
    cond do
      has_policy_type?(policies, :adaptive_allocation) -> :adaptive
      has_policy_type?(policies, :performance_priority) -> :performance_based
      has_policy_type?(policies, :fair_distribution) -> :fair_share
      true -> :priority_weighted
    end
  end
  
  defp has_policy_type?(policies, type) do
    Enum.any?(policies, & &1.type == type)
  end
  
  defp allocate_by_performance(requests, available, performance_data) do
    initial_state = %{
      allocations: %{},
      remaining: available
    }
    
    final_state = Enum.reduce(requests, initial_state, fn request, state ->
      performance_multiplier = get_performance_multiplier(request.unit_id, performance_data)
      
      adjusted_request = scale_request(request.resources, performance_multiplier)
      actual_allocation = fulfill_request(adjusted_request, state.remaining)
      
      new_allocations = Map.put(state.allocations, request.unit_id, actual_allocation)
      new_remaining = deduct(state.remaining, actual_allocation)
      
      %{
        allocations: new_allocations,
        remaining: new_remaining
      }
    end)
    
    final_state.allocations
  end
  
  defp allocate_fair_share(requests, available) do
    if Enum.empty?(requests) do
      %{}
    else
      # Calculate equal share for each unit
      num_units = length(requests)
      fair_share = divide_resources(available, num_units)
      
      # Allocate fair share to each unit, capped by their request
      Enum.reduce(requests, %{}, fn request, allocations ->
        actual_allocation = cap_allocation(fair_share, request.resources)
        Map.put(allocations, request.unit_id, actual_allocation)
      end)
    end
  end
  
  defp allocate_by_priority(requests, available) do
    # Calculate total priority weight
    total_priority = Enum.reduce(requests, 0, & &1.priority + &2)
    
    if total_priority == 0 do
      allocate_fair_share(requests, available)
    else
      initial_state = %{
        allocations: %{},
        remaining: available
      }
      
      final_state = Enum.reduce(requests, initial_state, fn request, state ->
        # Allocate proportional to priority
        priority_ratio = request.priority / total_priority
        priority_share = scale_resources(available, priority_ratio)
        
        # Cap by actual request and availability
        actual_allocation = priority_share
        |> cap_allocation(request.resources)
        |> cap_allocation(state.remaining)
        
        new_allocations = Map.put(state.allocations, request.unit_id, actual_allocation)
        new_remaining = deduct(state.remaining, actual_allocation)
        
        %{
          allocations: new_allocations,
          remaining: new_remaining
        }
      end)
      
      final_state.allocations
    end
  end
  
  defp allocate_adaptive(requests, available, performance_data, policies) do
    # Adaptive allocation based on multiple factors
    
    # Start with priority-based allocation
    base_allocations = allocate_by_priority(requests, available)
    
    # Adjust based on performance
    performance_adjusted = adjust_for_performance(base_allocations, performance_data)
    
    # Apply policy constraints
    policy_constrained = apply_policy_constraints(performance_adjusted, policies)
    
    # Optimize for overall efficiency
    optimize_distribution(policy_constrained, available)
  end
  
  defp get_performance_multiplier(unit_id, performance_data) do
    case Map.get(performance_data, unit_id) do
      nil -> 1.0
      data ->
        score = Map.get(data, :score, 0.5)
        # Convert score (0-1) to multiplier (0.5-1.5)
        0.5 + score
    end
  end
  
  defp scale_request(resources, multiplier) do
    Map.new(resources, fn {resource, amount} ->
      {resource, amount * multiplier}
    end)
  end
  
  defp fulfill_request(requested, available) do
    Map.new(requested, fn {resource, amount} ->
      available_amount = Map.get(available, resource, 0)
      allocated = min(amount, available_amount)
      {resource, allocated}
    end)
  end
  
  defp divide_resources(resources, divisor) when divisor > 0 do
    Map.new(resources, fn {resource, amount} ->
      {resource, amount / divisor}
    end)
  end
  
  defp cap_allocation(allocation, cap) do
    Map.merge(allocation, cap, fn _resource, alloc_amount, cap_amount ->
      min(alloc_amount, cap_amount)
    end)
  end
  
  defp scale_resources(resources, scale) do
    Map.new(resources, fn {resource, amount} ->
      {resource, amount * scale}
    end)
  end
  
  defp calculate_efficiency_scores(allocations) do
    Map.new(allocations, fn {unit_id, allocation} ->
      # Simple efficiency based on resource utilization balance
      values = Map.values(allocation)
      if Enum.empty?(values) do
        {unit_id, 0.5}
      else
        mean = Enum.sum(values) / length(values)
        variance = calculate_variance(values, mean)
        
        # Lower variance = better balance = higher efficiency
        efficiency = if mean > 0 do
          1.0 - min(1.0, variance / mean)
        else
          0.5
        end
        
        {unit_id, efficiency}
      end
    end)
  end
  
  defp calculate_variance(values, mean) do
    sum_squared_diff = Enum.reduce(values, 0, fn val, acc ->
      diff = val - mean
      acc + (diff * diff)
    end)
    
    if length(values) > 0 do
      sum_squared_diff / length(values)
    else
      0
    end
  end
  
  defp find_underutilized_resources(allocations, total_resources) do
    # Calculate total allocated for each resource
    total_allocated = Enum.reduce(allocations, %{}, fn {_unit, alloc}, acc ->
      Map.merge(acc, alloc, fn _k, sum, val -> sum + val end)
    end)
    
    # Find resources with low utilization
    Map.new(total_resources, fn {resource, total} ->
      allocated = Map.get(total_allocated, resource, 0)
      utilization = if total > 0, do: allocated / total, else: 0
      
      available = total - allocated
      underutilized = utilization < 0.7 && available > 10
      
      {resource, %{
        available: available,
        utilization: utilization,
        underutilized: underutilized
      }}
    end)
    |> Enum.filter(fn {_resource, info} -> info.underutilized end)
    |> Map.new(fn {resource, info} -> {resource, info.available} end)
  end
  
  defp redistribute_resources(allocations, efficiency_scores, underutilized) do
    if map_size(underutilized) == 0 do
      allocations
    else
      # Sort units by efficiency
      sorted_units = Enum.sort_by(efficiency_scores, fn {_unit, score} -> -score end)
      
      # Redistribute to top performers
      top_units = Enum.take(sorted_units, 3)
      
      Enum.reduce(top_units, allocations, fn {unit_id, _score}, acc ->
        bonus_resources = calculate_bonus_allocation(underutilized, length(top_units))
        
        Map.update(acc, unit_id, bonus_resources, fn current ->
          Map.merge(current, bonus_resources, fn _k, curr, bonus -> curr + bonus end)
        end)
      end)
    end
  end
  
  defp calculate_bonus_allocation(underutilized, num_units) when num_units > 0 do
    Map.new(underutilized, fn {resource, available} ->
      {resource, available / num_units * 0.5} # Redistribute 50% of underutilized
    end)
  end
  
  defp adjust_for_performance(allocations, performance_data) do
    Map.new(allocations, fn {unit_id, allocation} ->
      case Map.get(performance_data, unit_id) do
        nil -> 
          {unit_id, allocation}
          
        perf_data ->
          score = Map.get(perf_data, :score, 0.5)
          adjustment_factor = 0.8 + (score * 0.4) # 0.8 to 1.2
          
          adjusted = Map.new(allocation, fn {resource, amount} ->
            {resource, amount * adjustment_factor}
          end)
          
          {unit_id, adjusted}
      end
    end)
  end
  
  defp apply_policy_constraints(allocations, policies) do
    Enum.reduce(policies, allocations, fn policy, acc ->
      apply_single_policy(acc, policy)
    end)
  end
  
  defp apply_single_policy(allocations, policy) do
    case policy.type do
      :resource_limit ->
        enforce_resource_limits(allocations, policy)
        
      :minimum_guarantee ->
        enforce_minimum_guarantees(allocations, policy)
        
      :maximum_allocation ->
        enforce_maximum_allocations(allocations, policy)
        
      _ ->
        allocations
    end
  end
  
  defp enforce_resource_limits(allocations, policy) do
    max_percentage = Map.get(policy, :max_percentage, 0.9)
    
    Map.new(allocations, fn {unit_id, allocation} ->
      limited = Map.new(allocation, fn {resource, amount} ->
        # This is simplified - in reality would check against total pool
        {resource, min(amount, 100 * max_percentage)}
      end)
      
      {unit_id, limited}
    end)
  end
  
  defp enforce_minimum_guarantees(allocations, policy) do
    min_guarantee = Map.get(policy, :min_resources, %{})
    
    Map.new(allocations, fn {unit_id, allocation} ->
      guaranteed = Map.merge(min_guarantee, allocation, fn _resource, min_val, alloc_val ->
        max(min_val, alloc_val)
      end)
      
      {unit_id, guaranteed}
    end)
  end
  
  defp enforce_maximum_allocations(allocations, policy) do
    max_per_unit = Map.get(policy, :max_per_unit, %{})
    
    Map.new(allocations, fn {unit_id, allocation} ->
      capped = Map.merge(allocation, max_per_unit, fn _resource, alloc_val, max_val ->
        min(alloc_val, max_val)
      end)
      
      {unit_id, capped}
    end)
  end
  
  defp extract_recent_usage(historical_data, minutes) do
    cutoff = DateTime.add(DateTime.utc_now(), -minutes * 60, :second)
    
    historical_data
    |> Enum.filter(fn {timestamp, _data} ->
      DateTime.compare(timestamp, cutoff) == :gt
    end)
    |> Map.new()
  end
  
  defp calculate_usage_trend(recent_usage) do
    if map_size(recent_usage) < 2 do
      %{cpu: 0, memory: 0, io: 0, network: 0}
    else
      # Simple linear trend
      sorted_entries = Enum.sort_by(recent_usage, fn {timestamp, _} -> timestamp end, DateTime)
      
      {first_time, first_usage} = List.first(sorted_entries)
      {last_time, last_usage} = List.last(sorted_entries)
      
      time_diff = DateTime.diff(last_time, first_time, :second)
      
      if time_diff > 0 do
        Map.new([:cpu, :memory, :io, :network], fn resource ->
          first_val = get_in(first_usage, [:resources, resource]) || 0
          last_val = get_in(last_usage, [:resources, resource]) || 0
          
          trend_per_second = (last_val - first_val) / time_diff
          {resource, trend_per_second}
        end)
      else
        %{cpu: 0, memory: 0, io: 0, network: 0}
      end
    end
  end
  
  defp project_resource_needs(trend, lookahead_minutes) do
    lookahead_seconds = lookahead_minutes * 60
    
    Map.new(trend, fn {resource, trend_per_second} ->
      projected_change = trend_per_second * lookahead_seconds
      
      # Add some baseline and ensure non-negative
      baseline = case resource do
        :cpu -> 10
        :memory -> 20
        :io -> 5
        :network -> 5
        _ -> 0
      end
      
      {resource, max(baseline, baseline + projected_change)}
    end)
  end
  
  defp check_constraint(allocations, constraint) do
    case constraint.type do
      :total_limit ->
        check_total_limit(allocations, constraint)
        
      :per_unit_limit ->
        check_per_unit_limit(allocations, constraint)
        
      :resource_ratio ->
        check_resource_ratio(allocations, constraint)
        
      _ ->
        []
    end
  end
  
  defp check_total_limit(allocations, constraint) do
    total = Enum.reduce(allocations, %{}, fn {_unit, alloc}, acc ->
      Map.merge(acc, alloc, fn _k, sum, val -> sum + val end)
    end)
    
    violations = Enum.filter(constraint.limits, fn {resource, limit} ->
      Map.get(total, resource, 0) > limit
    end)
    
    if Enum.empty?(violations) do
      []
    else
      [%{
        type: :total_limit_exceeded,
        constraint: constraint,
        violations: violations,
        total_allocated: total
      }]
    end
  end
  
  defp check_per_unit_limit(allocations, constraint) do
    Enum.flat_map(allocations, fn {unit_id, allocation} ->
      violations = Enum.filter(constraint.limits, fn {resource, limit} ->
        Map.get(allocation, resource, 0) > limit
      end)
      
      if Enum.empty?(violations) do
        []
      else
        [%{
          type: :unit_limit_exceeded,
          unit_id: unit_id,
          constraint: constraint,
          violations: violations
        }]
      end
    end)
  end
  
  defp check_resource_ratio(allocations, constraint) do
    # Check if resource allocations maintain required ratios
    Enum.flat_map(allocations, fn {unit_id, allocation} ->
      ratio_violations = check_unit_ratios(allocation, constraint.ratios)
      
      if Enum.empty?(ratio_violations) do
        []
      else
        [%{
          type: :ratio_violation,
          unit_id: unit_id,
          constraint: constraint,
          violations: ratio_violations
        }]
      end
    end)
  end
  
  defp check_unit_ratios(allocation, required_ratios) do
    Enum.filter(required_ratios, fn {resources, expected_ratio} ->
      [res1, res2] = resources
      val1 = Map.get(allocation, res1, 0)
      val2 = Map.get(allocation, res2, 0)
      
      if val2 > 0 do
        actual_ratio = val1 / val2
        abs(actual_ratio - expected_ratio) > 0.2 # 20% tolerance
      else
        false
      end
    end)
  end
end