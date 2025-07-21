defmodule VSMCore.System2.Balancer do
  @moduledoc """
  Resource balancing module for System 2.
  
  Implements algorithms for optimal resource distribution across S1 units,
  preventing resource starvation and ensuring efficient utilization.
  """
  
  require Logger
  
  @type resource_request :: %{
    unit_id: atom(),
    requested: map(),
    priority: float(),
    current_allocation: map()
  }
  
  @type allocation :: %{atom() => map()}
  
  @doc """
  Balances resources across S1 units based on requests and current allocations.
  """
  @spec balance([resource_request()], map()) :: allocation()
  def balance(requests, current_allocations) do
    # Calculate total available resources
    total_resources = calculate_total_resources()
    
    # Sort requests by priority and need
    sorted_requests = sort_requests(requests)
    
    # Apply balancing algorithm
    balanced = apply_balancing_algorithm(sorted_requests, total_resources, current_allocations)
    
    # Validate allocations don't exceed limits
    validate_allocations(balanced, total_resources)
  end
  
  @doc """
  Calculates the efficiency of current resource allocation.
  """
  @spec calculate_efficiency(allocation()) :: float()
  def calculate_efficiency(allocations) do
    total_allocated = sum_allocations(allocations)
    total_available = calculate_total_resources()
    
    utilization = calculate_utilization(total_allocated, total_available)
    balance_score = calculate_balance_score(allocations)
    
    # Combined efficiency score
    (utilization * 0.6) + (balance_score * 0.4)
  end
  
  @doc """
  Detects resource imbalances that need correction.
  """
  @spec detect_imbalance(allocation()) :: {:ok, :balanced} | {:imbalanced, map()}
  def detect_imbalance(allocations) do
    variance = calculate_allocation_variance(allocations)
    threshold = 0.3 # 30% variance threshold
    
    if variance > threshold do
      {:imbalanced, %{
        variance: variance,
        overallocated: find_overallocated_units(allocations),
        underallocated: find_underallocated_units(allocations)
      }}
    else
      {:ok, :balanced}
    end
  end
  
  @doc """
  Suggests rebalancing actions to improve resource distribution.
  """
  @spec suggest_rebalancing(allocation()) :: list()
  def suggest_rebalancing(allocations) do
    case detect_imbalance(allocations) do
      {:ok, :balanced} ->
        []
        
      {:imbalanced, details} ->
        generate_rebalancing_suggestions(details, allocations)
    end
  end
  
  # Private Functions
  
  defp calculate_total_resources() do
    # In a real system, this would query actual resource availability
    %{
      cpu: 100.0,
      memory: 100.0,
      io: 100.0,
      network: 100.0
    }
  end
  
  defp sort_requests(requests) do
    Enum.sort_by(requests, fn request ->
      # Sort by priority and resource deficit
      deficit = calculate_resource_deficit(request)
      {-request.priority, -deficit}
    end)
  end
  
  defp calculate_resource_deficit(request) do
    Enum.reduce(request.requested, 0, fn {resource, requested}, acc ->
      current = get_in(request.current_allocation, [resource]) || 0
      deficit = max(0, requested - current)
      acc + deficit
    end)
  end
  
  defp apply_balancing_algorithm(requests, total_resources, current_allocations) do
    # Progressive fill algorithm with priority weighting
    initial_state = %{
      allocations: %{},
      remaining: total_resources
    }
    
    final_state = Enum.reduce(requests, initial_state, fn request, state ->
      allocation = calculate_unit_allocation(
        request,
        state.remaining,
        length(requests),
        current_allocations
      )
      
      new_allocations = Map.put(state.allocations, request.unit_id, allocation)
      new_remaining = subtract_resources(state.remaining, allocation)
      
      %{
        allocations: new_allocations,
        remaining: new_remaining
      }
    end)
    
    final_state.allocations
  end
  
  defp calculate_unit_allocation(request, available, total_units, current_allocations) do
    # Base allocation (fair share)
    fair_share = divide_resources(available, total_units)
    
    # Adjust based on priority
    priority_adjusted = scale_resources(fair_share, request.priority)
    
    # Consider current allocation (smooth transitions)
    current = Map.get(current_allocations, request.unit_id, %{})
    smoothed = smooth_allocation_transition(current, priority_adjusted)
    
    # Cap by actual request
    cap_by_request(smoothed, request.requested)
  end
  
  defp divide_resources(resources, divisor) when divisor > 0 do
    Map.new(resources, fn {key, value} ->
      {key, value / divisor}
    end)
  end
  
  defp scale_resources(resources, scale_factor) do
    Map.new(resources, fn {key, value} ->
      {key, value * scale_factor}
    end)
  end
  
  defp smooth_allocation_transition(current, target) do
    # Smooth transition to prevent abrupt changes
    alpha = 0.7 # Smoothing factor
    
    Map.merge(target, current, fn _key, target_val, current_val ->
      current_val + alpha * (target_val - current_val)
    end)
  end
  
  defp cap_by_request(allocation, requested) do
    Map.merge(allocation, requested, fn _key, alloc_val, req_val ->
      min(alloc_val, req_val)
    end)
  end
  
  defp subtract_resources(resources, to_subtract) do
    Map.merge(resources, to_subtract, fn _key, remaining, used ->
      max(0, remaining - used)
    end)
  end
  
  defp validate_allocations(allocations, total_resources) do
    # Sum all allocations
    total_allocated = Enum.reduce(allocations, %{}, fn {_unit, alloc}, acc ->
      Map.merge(acc, alloc, fn _key, sum, val -> sum + val end)
    end)
    
    # Ensure we don't exceed total resources
    validated = Map.new(total_allocated, fn {resource, allocated} ->
      total = Map.get(total_resources, resource, 0)
      if allocated > total do
        Logger.warning("Resource #{resource} overallocated: #{allocated} > #{total}")
        # Scale down all allocations proportionally
        scale_factor = total / allocated
        scale_allocations(allocations, resource, scale_factor)
      end
      {resource, min(allocated, total)}
    end)
    
    allocations
  end
  
  defp scale_allocations(allocations, resource, scale_factor) do
    Map.new(allocations, fn {unit, alloc} ->
      scaled_value = Map.get(alloc, resource, 0) * scale_factor
      new_alloc = Map.put(alloc, resource, scaled_value)
      {unit, new_alloc}
    end)
  end
  
  defp sum_allocations(allocations) do
    Enum.reduce(allocations, %{}, fn {_unit, alloc}, acc ->
      Map.merge(acc, alloc, fn _key, sum, val -> sum + val end)
    end)
  end
  
  defp calculate_utilization(allocated, available) do
    resource_utilizations = Enum.map(available, fn {resource, total} ->
      used = Map.get(allocated, resource, 0)
      if total > 0, do: used / total, else: 0
    end)
    
    # Average utilization across all resources
    Enum.sum(resource_utilizations) / length(resource_utilizations)
  end
  
  defp calculate_balance_score(allocations) do
    # Calculate how evenly resources are distributed
    if map_size(allocations) == 0 do
      1.0
    else
      resource_scores = [:cpu, :memory, :io, :network]
      |> Enum.map(fn resource ->
        values = Enum.map(allocations, fn {_unit, alloc} ->
          Map.get(alloc, resource, 0)
        end)
        
        if length(values) > 0 do
          mean = Enum.sum(values) / length(values)
          variance = calculate_variance(values, mean)
          
          # Convert variance to a 0-1 score (lower variance = higher score)
          if mean > 0 do
            1.0 - min(1.0, variance / mean)
          else
            1.0
          end
        else
          1.0
        end
      end)
      
      Enum.sum(resource_scores) / length(resource_scores)
    end
  end
  
  defp calculate_variance(values, mean) do
    sum_squared_diff = Enum.reduce(values, 0, fn val, acc ->
      diff = val - mean
      acc + (diff * diff)
    end)
    
    sum_squared_diff / length(values)
  end
  
  defp calculate_allocation_variance(allocations) do
    # Calculate overall variance in resource allocation
    1.0 - calculate_balance_score(allocations)
  end
  
  defp find_overallocated_units(allocations) do
    mean_allocation = calculate_mean_allocation(allocations)
    
    Enum.filter(allocations, fn {unit, alloc} ->
      unit_total = Enum.sum(Map.values(alloc))
      unit_total > mean_allocation * 1.3
    end)
    |> Enum.map(fn {unit, _} -> unit end)
  end
  
  defp find_underallocated_units(allocations) do
    mean_allocation = calculate_mean_allocation(allocations)
    
    Enum.filter(allocations, fn {unit, alloc} ->
      unit_total = Enum.sum(Map.values(alloc))
      unit_total < mean_allocation * 0.7
    end)
    |> Enum.map(fn {unit, _} -> unit end)
  end
  
  defp calculate_mean_allocation(allocations) do
    total = Enum.reduce(allocations, 0, fn {_unit, alloc}, acc ->
      acc + Enum.sum(Map.values(alloc))
    end)
    
    if map_size(allocations) > 0 do
      total / map_size(allocations)
    else
      0
    end
  end
  
  defp generate_rebalancing_suggestions(imbalance_details, allocations) do
    suggestions = []
    
    # Suggest transfers from overallocated to underallocated
    overallocated = imbalance_details.overallocated
    underallocated = imbalance_details.underallocated
    
    Enum.flat_map(overallocated, fn over_unit ->
      Enum.map(underallocated, fn under_unit ->
        %{
          action: :transfer,
          from: over_unit,
          to: under_unit,
          amount: calculate_transfer_amount(
            allocations[over_unit],
            allocations[under_unit]
          )
        }
      end)
    end)
  end
  
  defp calculate_transfer_amount(from_alloc, to_alloc) do
    # Calculate optimal transfer amount
    from_total = Enum.sum(Map.values(from_alloc))
    to_total = Enum.sum(Map.values(to_alloc))
    
    transfer_ratio = min(0.2, (from_total - to_total) / (2 * from_total))
    
    Map.new(from_alloc, fn {resource, value} ->
      {resource, value * transfer_ratio}
    end)
  end
end