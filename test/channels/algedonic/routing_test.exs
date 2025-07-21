defmodule VSMCore.Channels.Algedonic.RoutingTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.Channels.Algedonic.{Routing, Signals}
  
  describe "default routing rules" do
    test "provides categorized routing rules" do
      rules = Routing.default_rules()
      
      assert Map.has_key?(rules, :emergency)
      assert Map.has_key?(rules, :normal)
      assert Map.has_key?(rules, :aggregated)
      
      # Check emergency rules
      assert length(rules.emergency) >= 2
      assert Enum.any?(rules.emergency, & &1.destination == :system5)
    end
  end
  
  describe "emergency routing" do
    test "routes critical signals to S5" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 100}, :critical)
      
      assert {:ok, route_info} = Routing.emergency_route(signal)
      assert route_info.destination == :system5
      assert route_info.strategy == :direct
      assert route_info.priority == 100
      assert route_info.metadata.emergency == true
    end
  end
  
  describe "normal routing" do
    test "routes signals based on severity" do
      rules = Routing.default_rules()
      
      # High severity to S4
      high_signal = Signals.create_signal(:pain, :test, %{"value" => 80}, :high)
      {:ok, route} = Routing.route_signal(high_signal, rules)
      assert route.destination == :system4
      
      # Medium severity to S3
      medium_signal = Signals.create_signal(:pain, :test, %{"value" => 50}, :medium)
      {:ok, route} = Routing.route_signal(medium_signal, rules)
      assert route.destination == :system3
      
      # Low severity to S3*
      low_signal = Signals.create_signal(:pain, :test, %{"value" => 20}, :low)
      {:ok, route} = Routing.route_signal(low_signal, rules)
      assert route.destination == :system3_star
    end
    
    test "routes aggregated signals to S4" do
      rules = Routing.default_rules()
      
      aggregated_signal = %{
        id: "agg_123",
        type: :aggregated,
        severity: :high,
        data: %{},
        timestamp: DateTime.utc_now()
      }
      
      {:ok, route} = Routing.route_signal(aggregated_signal, rules)
      assert route.destination == :system4
    end
    
    test "applies highest priority matching rule" do
      custom_rules = %{
        test: [
          %{
            id: "rule1",
            name: "Low priority",
            condition: fn s -> s.severity == :high end,
            destination: :system3,
            strategy: :direct,
            priority: 10
          },
          %{
            id: "rule2", 
            name: "High priority",
            condition: fn s -> s.severity == :high end,
            destination: :system5,
            strategy: :direct,
            priority: 90
          }
        ]
      }
      
      signal = Signals.create_signal(:pain, :test, %{"value" => 80}, :high)
      {:ok, route} = Routing.route_signal(signal, custom_rules)
      
      # Should use high priority rule
      assert route.destination == :system5
      assert route.metadata.rule_id == "rule2"
    end
  end
  
  describe "routing paths" do
    test "direct strategy creates single-hop path" do
      signal = %{source: :test}
      path = Routing.calculate_route_path(signal, :system5, :direct)
      assert path == [:system5]
    end
    
    test "escalating strategy creates multi-hop path" do
      signal = %{source: :test}
      path = Routing.calculate_route_path(signal, :system5, :escalating)
      assert path == [:system3, :system4, :system5]
    end
    
    test "broadcast strategy includes multiple destinations" do
      signal = %{source: :test}
      path = Routing.calculate_route_path(signal, :system4, :broadcast)
      assert :system3 in path
      assert :system4 in path
    end
    
    test "conditional strategy adapts based on signal" do
      signal1 = %{source: :test, metadata: %{requires_audit: true}}
      signal2 = %{source: :test, metadata: %{}}
      
      path1 = Routing.calculate_route_path(signal1, :system4, :conditional)
      path2 = Routing.calculate_route_path(signal2, :system4, :conditional)
      
      assert :system3_star in path1
      assert :system3_star not in path2
    end
  end
  
  describe "routing analysis" do
    test "analyzes routing patterns" do
      history = [
        %{destination: :system5, metadata: %{emergency: true}, path: [:system5]},
        %{destination: :system4, metadata: %{emergency: false}, path: [:system4]},
        %{destination: :system4, metadata: %{emergency: false}, path: [:system4]},
        %{destination: :system3, metadata: %{emergency: false}, path: [:system3]}
      ]
      
      analysis = Routing.analyze_routing_patterns(history)
      
      assert analysis.total_routes == 4
      assert analysis.emergency_routes == 1
      assert analysis.emergency_rate == 0.25
      assert analysis.most_used_destination == :system4
      assert is_map(analysis.destination_distribution)
      assert is_list(analysis.recommendations)
    end
    
    test "generates recommendations for high emergency rate" do
      history = for _ <- 1..10 do
        %{
          destination: :system5,
          metadata: %{emergency: true},
          path: [:system5]
        }
      end
      
      analysis = Routing.analyze_routing_patterns(history)
      assert length(analysis.recommendations) > 0
      assert Enum.any?(analysis.recommendations, &String.contains?(&1, "emergency"))
    end
  end
  
  describe "routing validation" do
    test "validates routing rules" do
      valid_rules = %{
        test: [
          %{
            id: "rule1",
            name: "Test rule",
            condition: fn _ -> true end,
            destination: :system5,
            strategy: :direct,
            priority: 50
          }
        ]
      }
      
      assert {:ok, _} = Routing.validate_routing_rules(valid_rules)
    end
    
    test "detects duplicate rule IDs" do
      duplicate_rules = %{
        test: [
          %{
            id: "duplicate",
            name: "Rule 1",
            condition: fn _ -> true end,
            destination: :system5,
            strategy: :direct,
            priority: 50
          },
          %{
            id: "duplicate",
            name: "Rule 2",
            condition: fn _ -> true end,
            destination: :system4,
            strategy: :direct,
            priority: 60
          }
        ]
      }
      
      assert {:error, :duplicate_rule_ids} = Routing.validate_routing_rules(duplicate_rules)
    end
    
    test "validates rule fields" do
      invalid_rule = %{
        test: [
          %{
            id: "invalid",
            name: "Invalid rule",
            condition: fn _ -> true end,
            destination: :invalid_system,  # Invalid destination
            strategy: :direct,
            priority: 50
          }
        ]
      }
      
      assert {:error, {:invalid_rule, "invalid"}} = Routing.validate_routing_rules(invalid_rule)
    end
  end
end