defmodule VSMCore.Channels.Algedonic.Routing do
  @moduledoc """
  Signal routing logic for the Algedonic Channel.
  
  This module implements the routing mechanisms that direct algedonic signals
  to appropriate management levels. It provides emergency bypass routing for
  critical signals directly to S5, as well as normal routing based on severity
  and signal characteristics.
  """
  
  require Logger
  
  @type destination :: :system5 | :system4 | :system3 | :system3_star
  @type routing_strategy :: :direct | :escalating | :broadcast | :conditional
  
  @type route_info :: %{
    destination: destination(),
    strategy: routing_strategy(),
    priority: integer(),
    path: list(destination()),
    metadata: map()
  }
  
  @type routing_rule :: %{
    id: String.t(),
    name: String.t(),
    condition: function() | map(),
    destination: destination(),
    strategy: routing_strategy(),
    priority: integer()
  }
  
  @doc """
  Returns the default routing rules for the algedonic channel.
  """
  def default_rules do
    %{
      emergency: [
        %{
          id: "critical_to_s5",
          name: "Critical signals direct to S5",
          condition: &(&1.severity == :critical),
          destination: :system5,
          strategy: :direct,
          priority: 100
        },
        %{
          id: "security_to_s5",
          name: "Security breaches to S5",
          condition: &(get_in(&1, [:data, "metric"]) == "security_breach"),
          destination: :system5,
          strategy: :direct,
          priority: 95
        }
      ],
      normal: [
        %{
          id: "high_to_s4",
          name: "High severity to S4",
          condition: &(&1.severity == :high),
          destination: :system4,
          strategy: :escalating,
          priority: 80
        },
        %{
          id: "medium_to_s3",
          name: "Medium severity to S3",
          condition: &(&1.severity == :medium),
          destination: :system3,
          strategy: :direct,
          priority: 60
        },
        %{
          id: "low_to_s3_star",
          name: "Low severity to S3*",
          condition: &(&1.severity == :low),
          destination: :system3_star,
          strategy: :conditional,
          priority: 40
        }
      ],
      aggregated: [
        %{
          id: "patterns_to_s4",
          name: "Aggregated patterns to S4",
          condition: &(&1.type == :aggregated),
          destination: :system4,
          strategy: :direct,
          priority: 70
        }
      ]
    }
  end
  
  @doc """
  Routes a signal according to emergency bypass rules.
  
  Emergency routing bypasses all normal channels and sends
  the signal directly to the specified destination (usually S5).
  """
  def emergency_route(signal) do
    route_info = %{
      destination: :system5,
      strategy: :direct,
      priority: 100,
      path: [:system5],
      metadata: %{
        bypass_reason: determine_bypass_reason(signal),
        routed_at: System.system_time(:millisecond),
        emergency: true
      }
    }
    
    Logger.warn("Emergency routing activated for signal #{signal.id} to #{route_info.destination}")
    
    {:ok, route_info}
  end
  
  @doc """
  Routes a signal according to normal routing rules.
  """
  def route_signal(signal, routing_rules) do
    applicable_rules = find_applicable_rules(signal, routing_rules)
    
    case applicable_rules do
      [] ->
        # No matching rules, use default routing
        default_route(signal)
        
      rules ->
        # Use highest priority matching rule
        rule = Enum.max_by(rules, & &1.priority)
        apply_routing_rule(signal, rule)
    end
  end
  
  @doc """
  Calculates the optimal routing path for a signal.
  """
  def calculate_route_path(signal, destination, strategy) do
    case strategy do
      :direct ->
        [destination]
        
      :escalating ->
        build_escalation_path(signal.source, destination)
        
      :broadcast ->
        build_broadcast_path(destination)
        
      :conditional ->
        build_conditional_path(signal, destination)
    end
  end
  
  @doc """
  Analyzes routing patterns to identify bottlenecks and inefficiencies.
  """
  def analyze_routing_patterns(routing_history) do
    destinations = Enum.map(routing_history, & &1.destination)
    destination_counts = Enum.frequencies(destinations)
    
    total_routes = length(routing_history)
    emergency_routes = Enum.count(routing_history, & &1.metadata[:emergency])
    
    %{
      total_routes: total_routes,
      emergency_routes: emergency_routes,
      emergency_rate: safe_divide(emergency_routes, total_routes),
      destination_distribution: destination_counts,
      most_used_destination: find_most_used_destination(destination_counts),
      average_path_length: calculate_average_path_length(routing_history),
      recommendations: generate_routing_recommendations(routing_history)
    }
  end
  
  @doc """
  Validates a routing configuration.
  """
  def validate_routing_rules(rules) do
    all_rules = Enum.flat_map(rules, fn {_category, category_rules} -> category_rules end)
    
    # Check for duplicate rule IDs
    rule_ids = Enum.map(all_rules, & &1.id)
    if length(rule_ids) != length(Enum.uniq(rule_ids)) do
      {:error, :duplicate_rule_ids}
    else
      # Validate each rule
      case Enum.find(all_rules, &(validate_rule(&1) != :ok)) do
        nil -> {:ok, rules}
        invalid_rule -> {:error, {:invalid_rule, invalid_rule.id}}
      end
    end
  end
  
  # Private Functions
  
  defp determine_bypass_reason(signal) do
    cond do
      signal.severity == :critical ->
        "Critical severity signal"
        
      get_in(signal, [:metadata, :emergency]) ->
        "Emergency flag set"
        
      get_in(signal, [:data, "metric"]) == "security_breach" ->
        "Security breach detected"
        
      true ->
        "Emergency pattern matched"
    end
  end
  
  defp find_applicable_rules(signal, routing_rules) do
    all_rules = routing_rules
    |> Map.values()
    |> List.flatten()
    
    Enum.filter(all_rules, fn rule ->
      evaluate_rule_condition(signal, rule.condition)
    end)
  end
  
  defp evaluate_rule_condition(signal, condition) when is_function(condition) do
    try do
      condition.(signal)
    rescue
      _ -> false
    end
  end
  
  defp evaluate_rule_condition(signal, condition) when is_map(condition) do
    Enum.all?(condition, fn {key, expected} ->
      actual = get_in(signal, [key])
      actual == expected
    end)
  end
  
  defp apply_routing_rule(signal, rule) do
    path = calculate_route_path(signal, rule.destination, rule.strategy)
    
    route_info = %{
      destination: rule.destination,
      strategy: rule.strategy,
      priority: rule.priority,
      path: path,
      metadata: %{
        rule_id: rule.id,
        rule_name: rule.name,
        routed_at: System.system_time(:millisecond),
        emergency: false
      }
    }
    
    {:ok, route_info}
  end
  
  defp default_route(signal) do
    # Default routing based on severity
    destination = case signal.severity do
      :critical -> :system5
      :high -> :system4
      :medium -> :system3
      :low -> :system3_star
    end
    
    route_info = %{
      destination: destination,
      strategy: :direct,
      priority: 50,
      path: [destination],
      metadata: %{
        rule_id: "default",
        rule_name: "Default severity-based routing",
        routed_at: System.system_time(:millisecond),
        emergency: false
      }
    }
    
    {:ok, route_info}
  end
  
  defp build_escalation_path(source, destination) do
    # Build path that escalates through management levels
    case destination do
      :system5 -> [:system3, :system4, :system5]
      :system4 -> [:system3, :system4]
      :system3 -> [:system3]
      :system3_star -> [:system3_star]
    end
  end
  
  defp build_broadcast_path(primary_destination) do
    # Broadcast to multiple destinations
    case primary_destination do
      :system5 -> [:system3, :system4, :system5]
      :system4 -> [:system3, :system4]
      _ -> [primary_destination]
    end
  end
  
  defp build_conditional_path(signal, destination) do
    # Build path based on signal conditions
    if Map.get(signal.metadata, :requires_audit, false) do
      [:system3_star, destination]
    else
      [destination]
    end
  end
  
  defp validate_rule(rule) do
    required_fields = [:id, :name, :condition, :destination, :strategy, :priority]
    
    cond do
      not Enum.all?(required_fields, &Map.has_key?(rule, &1)) ->
        :invalid_structure
        
      rule.destination not in [:system5, :system4, :system3, :system3_star] ->
        :invalid_destination
        
      rule.strategy not in [:direct, :escalating, :broadcast, :conditional] ->
        :invalid_strategy
        
      not is_integer(rule.priority) or rule.priority < 0 or rule.priority > 100 ->
        :invalid_priority
        
      true ->
        :ok
    end
  end
  
  defp safe_divide(_, 0), do: 0.0
  defp safe_divide(num, denom), do: num / denom
  
  defp find_most_used_destination(destination_counts) do
    case Enum.max_by(destination_counts, fn {_, count} -> count end, fn -> nil end) do
      {destination, _count} -> destination
      nil -> nil
    end
  end
  
  defp calculate_average_path_length(routing_history) do
    total_length = routing_history
    |> Enum.map(& length(&1.path))
    |> Enum.sum()
    
    safe_divide(total_length, length(routing_history))
  end
  
  defp generate_routing_recommendations(routing_history) do
    recommendations = []
    
    # Check for excessive emergency routing
    emergency_rate = safe_divide(
      Enum.count(routing_history, & &1.metadata[:emergency]),
      length(routing_history)
    )
    
    recommendations = if emergency_rate > 0.1 do
      ["High emergency routing rate (#{round(emergency_rate * 100)}%). Review signal severity classification." | recommendations]
    else
      recommendations
    end
    
    # Check for underutilized destinations
    destination_counts = Enum.frequencies(Enum.map(routing_history, & &1.destination))
    underutilized = Enum.filter([:system5, :system4, :system3, :system3_star], fn dest ->
      Map.get(destination_counts, dest, 0) < length(routing_history) * 0.05
    end)
    
    recommendations = if length(underutilized) > 0 do
      ["Destinations #{inspect(underutilized)} are underutilized. Review routing rules." | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
end