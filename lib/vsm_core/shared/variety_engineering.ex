defmodule VsmCore.Shared.VarietyEngineering do
  @moduledoc """
  Implements Ashby's Law of Requisite Variety and variety management techniques.
  
  This module provides tools for measuring, attenuating, and amplifying variety
  in viable systems, ensuring proper balance between system complexity and
  environmental demands.
  """
  
  alias VsmCore.Shared.Variety.{Attenuator, Amplifier, Calculator}
  
  @type variety_state :: %{
    internal: float(),
    external: float(),
    balance: :balanced | :overwhelmed | :underutilized,
    entropy: float(),
    complexity_index: float()
  }
  
  @type variety_action :: :attenuate | :amplify | :balance
  
  @doc """
  Calculates Shannon entropy for a given distribution.
  
  ## Examples
  
      iex> VsmCore.Shared.VarietyEngineering.shannon_entropy([0.5, 0.5])
      1.0
      
      iex> VsmCore.Shared.VarietyEngineering.shannon_entropy([1.0])
      0.0
  """
  def shannon_entropy(probabilities) when is_list(probabilities) do
    probabilities
    |> Enum.filter(&(&1 > 0))
    |> Enum.reduce(0, fn p, acc ->
      acc - p * :math.log2(p)
    end)
  end
  
  @doc """
  Measures variety based on multiple dimensions of system state.
  
  ## Parameters
    - states: List of possible states or events
    - options: Configuration options including:
      - :dimensions - Number of dimensions to consider
      - :weights - Weights for each dimension
      - :time_window - Time period for measurement
  """
  def measure_variety(states, options \\ []) do
    dimensions = Keyword.get(options, :dimensions, 1)
    weights = Keyword.get(options, :weights, List.duplicate(1.0, dimensions))
    time_window = Keyword.get(options, :time_window, :current)
    
    # Calculate variety for each dimension
    dimensional_varieties = 
      states
      |> group_by_dimensions(dimensions)
      |> Enum.map(fn {_dim, dim_states} ->
        calculate_dimensional_variety(dim_states, time_window)
      end)
    
    # Apply weights and combine
    weighted_variety = 
      dimensional_varieties
      |> Enum.zip(weights)
      |> Enum.reduce(0, fn {variety, weight}, acc ->
        acc + variety * weight
      end)
    
    %{
      raw_variety: length(states),
      dimensional_varieties: dimensional_varieties,
      weighted_variety: weighted_variety,
      entropy: calculate_state_entropy(states),
      complexity: calculate_complexity_index(states, dimensions)
    }
  end
  
  @doc """
  Implements Ashby's Law by ensuring requisite variety match.
  
  Returns recommendations for variety management based on the law that
  "only variety can destroy variety."
  """
  def apply_ashbys_law(system_variety, environment_variety, options \\ []) do
    tolerance = Keyword.get(options, :tolerance, 0.1)
    
    variety_ratio = system_variety / environment_variety
    
    cond do
      abs(variety_ratio - 1.0) <= tolerance ->
        {:balanced, %{
          ratio: variety_ratio,
          action: :maintain,
          recommendation: "System variety matches environmental variety"
        }}
        
      variety_ratio < 1.0 ->
        {:insufficient, %{
          ratio: variety_ratio,
          deficit: environment_variety - system_variety,
          action: :amplify,
          recommendation: "Increase system variety through amplification",
          suggested_methods: Amplifier.suggest_methods(variety_ratio)
        }}
        
      variety_ratio > 1.0 ->
        {:excessive, %{
          ratio: variety_ratio,
          surplus: system_variety - environment_variety,
          action: :attenuate,
          recommendation: "Reduce system variety through attenuation",
          suggested_methods: Attenuator.suggest_methods(variety_ratio)
        }}
    end
  end
  
  @doc """
  Balances variety between system components.
  """
  def balance_variety(components) when is_map(components) do
    total_variety = components |> Map.values() |> Enum.sum()
    component_count = map_size(components)
    target_variety = total_variety / component_count
    
    adjustments = 
      components
      |> Enum.map(fn {name, variety} ->
        adjustment = target_variety - variety
        action = cond do
          abs(adjustment) < 0.05 * target_variety -> :maintain
          adjustment > 0 -> :amplify
          adjustment < 0 -> :attenuate
        end
        
        {name, %{
          current: variety,
          target: target_variety,
          adjustment: adjustment,
          action: action,
          percentage_change: adjustment / variety * 100
        }}
      end)
      |> Map.new()
    
    %{
      total_variety: total_variety,
      target_per_component: target_variety,
      adjustments: adjustments,
      balance_index: calculate_balance_index(components)
    }
  end
  
  @doc """
  Calculates the variety absorption capacity of a system.
  """
  def absorption_capacity(system_state, options \\ []) do
    current_load = Keyword.get(options, :current_load, 0.5)
    buffer_capacity = Keyword.get(options, :buffer_capacity, 0.2)
    adaptability = Keyword.get(options, :adaptability, 0.7)
    
    # Base capacity from system structure
    structural_capacity = calculate_structural_capacity(system_state)
    
    # Dynamic capacity from adaptability
    dynamic_capacity = structural_capacity * adaptability
    
    # Available capacity considering current load
    available_capacity = (1 - current_load) * dynamic_capacity
    
    # Buffer for unexpected variety
    buffered_capacity = available_capacity * (1 - buffer_capacity)
    
    %{
      structural_capacity: structural_capacity,
      dynamic_capacity: dynamic_capacity,
      available_capacity: available_capacity,
      buffered_capacity: buffered_capacity,
      utilization: current_load,
      headroom: available_capacity / dynamic_capacity
    }
  end
  
  # Private functions
  
  defp group_by_dimensions(states, dimensions) do
    states
    |> Enum.group_by(fn state ->
      # Extract dimensional key based on state structure
      case state do
        {dim, _value} when dimensions == 1 -> dim
        tuple when is_tuple(tuple) and tuple_size(tuple) >= dimensions ->
          tuple |> Tuple.to_list() |> Enum.take(dimensions) |> List.to_tuple()
        _ -> :default
      end
    end)
  end
  
  defp calculate_dimensional_variety(states, :current) do
    states |> Enum.uniq() |> length()
  end
  
  defp calculate_dimensional_variety(states, {:window, duration}) do
    # Filter states within time window
    current_time = System.system_time(:millisecond)
    window_start = current_time - duration
    
    states
    |> Enum.filter(fn
      {_state, timestamp} -> timestamp >= window_start
      _ -> true
    end)
    |> Enum.map(fn
      {state, _timestamp} -> state
      state -> state
    end)
    |> Enum.uniq()
    |> length()
  end
  
  defp calculate_state_entropy(states) do
    # Calculate probability distribution
    state_counts = 
      states
      |> Enum.frequencies()
      |> Map.values()
    
    total = Enum.sum(state_counts)
    
    probabilities = Enum.map(state_counts, &(&1 / total))
    shannon_entropy(probabilities)
  end
  
  defp calculate_complexity_index(states, dimensions) do
    unique_states = states |> Enum.uniq() |> length()
    total_states = length(states)
    
    # Complexity increases with unique states and dimensions
    base_complexity = :math.log2(unique_states + 1)
    dimensional_factor = :math.log2(dimensions + 1)
    redundancy_factor = 1 - (unique_states / total_states)
    
    base_complexity * dimensional_factor * (1 + redundancy_factor)
  end
  
  defp calculate_balance_index(components) do
    varieties = Map.values(components)
    mean = Enum.sum(varieties) / length(varieties)
    
    variance = 
      varieties
      |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(varieties))
    
    std_dev = :math.sqrt(variance)
    
    # Balance index: 1.0 is perfect balance, 0.0 is maximum imbalance
    1.0 - (std_dev / mean)
  end
  
  defp calculate_structural_capacity(system_state) do
    # Calculate capacity based on system structure
    # This is a simplified model - real implementation would consider
    # actual system architecture
    
    nodes = Map.get(system_state, :nodes, 1)
    connections = Map.get(system_state, :connections, 0)
    hierarchy_levels = Map.get(system_state, :levels, 1)
    
    # Metcalfe's law-inspired capacity calculation
    network_effect = :math.sqrt(connections + 1)
    hierarchical_effect = :math.log2(hierarchy_levels + 1)
    
    nodes * network_effect * hierarchical_effect
  end
end