defmodule VsmCore.Shared.Variety.CalculatorTest do
  use ExUnit.Case, async: true
  alias VsmCore.Shared.Variety.Calculator

  describe "calculate_variety/2" do
    test "calculates simple variety" do
      system_state = %{
        possible_states: [:state1, :state2, :state3, :state1]
      }
      
      result = Calculator.calculate_variety(system_state, method: :simple)
      
      assert result.value == 3  # 3 unique states
      assert result.method == :simple
      assert is_integer(result.timestamp)
      assert result.confidence > 0
    end

    test "calculates dimensional variety" do
      system_state = %{
        states: [:s1, :s2],
        behaviors: [:b1, :b2, :b3],
        components: %{c1: %{}, c2: %{}}
      }
      
      result = Calculator.calculate_variety(system_state, 
        method: :dimensional,
        dimensions: [:state, :behavior, :structure]
      )
      
      assert result.method == :dimensional
      assert map_size(result.dimensions) == 3
      assert result.dimensions[:state] == 2
      assert result.dimensions[:behavior] == 3
    end

    test "calculates comprehensive variety" do
      system_state = %{
        states: [:s1, :s2, :s3],
        behaviors: [:b1, :b2],
        components: %{c1: %{}, c2: %{}, c3: %{}},
        connections: [{:c1, :c2}, {:c2, :c3}],
        interactions: [{:type1, :data}, {:type2, :data}],
        time_scales: [:ms, :sec, :min],
        state_dimensions: 2
      }
      
      result = Calculator.calculate_variety(system_state)
      
      assert result.method == :comprehensive
      assert Map.has_key?(result.components, :dimensions)
      assert Map.has_key?(result.components, :weights)
      assert result.value > 0
    end

    test "includes potential variety when requested" do
      system_state = %{
        states: [:s1, :s2],
        latent_states: [:ls1, :ls2, :ls3],
        adaptability: 0.7
      }
      
      result = Calculator.calculate_variety(system_state, include_potential: true)
      
      assert Map.has_key?(result.components, :potential)
      assert result.components.potential > 0
    end
  end

  describe "calculate_complexity/2" do
    test "calculates structural complexity" do
      system_state = %{
        components: %{a: %{}, b: %{}, c: %{}},
        connections: [{:a, :b}, {:b, :c}],
        hierarchies: 2
      }
      
      result = Calculator.calculate_complexity(system_state)
      
      assert result.structural > 0
      assert result.dynamic >= 0
      assert result.total > 0
      assert Map.has_key?(result, :breakdown)
      assert Map.has_key?(result, :trajectory)
    end

    test "includes emergent complexity" do
      system_state = %{
        components: %{a: %{}, b: %{}},
        interactions: [{:sync, :a, :b}],
        emergence_indicators: [:self_organization]
      }
      
      result = Calculator.calculate_complexity(system_state, include_emergence: true)
      
      assert result.emergent > 0
      assert result.total >= result.structural + result.dynamic
    end

    test "analyzes complexity sources" do
      system_state = %{
        components: Map.new(1..60, fn i -> {:"c#{i}", %{}} end),
        connections: List.duplicate({:a, :b}, 200),
        behaviors: List.duplicate(:behavior, 25) |> Enum.uniq()
      }
      
      result = Calculator.calculate_complexity(system_state)
      
      assert length(result.breakdown.primary_sources) > 0
      assert Enum.any?(result.breakdown.primary_sources, fn {type, _} -> 
        type == :high_component_count 
      end)
    end
  end

  describe "assess_balance/3" do
    test "identifies balanced system" do
      result = Calculator.assess_balance(100, 95, tolerance: 0.1)
      
      assert result.state == :balanced
      assert_in_delta result.ratio, 1.05, 0.01
      assert result.adjustment_needed == 0.0
      assert :maintain_current_approach in result.recommendations
    end

    test "identifies overwhelmed system" do
      result = Calculator.assess_balance(50, 150)
      
      assert result.state == :overwhelmed
      assert result.ratio < 1.0
      assert result.adjustment_needed > 0
      assert :urgent_amplification_needed in result.recommendations
    end

    test "identifies underutilized system" do
      result = Calculator.assess_balance(200, 100)
      
      assert result.state == :underutilized
      assert result.ratio > 1.0
      assert result.adjustment_needed < 0
      assert :significant_attenuation_needed in result.recommendations
    end

    test "includes trend analysis" do
      historical_ratios = [0.8, 0.85, 0.9, 0.95]
      
      result = Calculator.assess_balance(100, 100, 
        include_trends: true,
        historical_ratios: historical_ratios
      )
      
      assert Map.has_key?(result, :trend_analysis)
      assert result.trend_analysis.direction == :increasing
      assert result.trend_analysis.stability != :unknown
    end
  end

  describe "calculate_absorption_rate/3" do
    test "calculates absorption metrics" do
      system_state = %{
        base_capacity: 1000,
        utilization: 0.3,
        absorption_efficiency: 0.8
      }
      
      variety_flow = 100  # per second
      
      result = Calculator.calculate_absorption_rate(system_state, variety_flow)
      
      assert result.rate > 0 and result.rate <= 1
      assert result.absorbed <= result.incoming
      assert result.capacity_utilization >= 0
      assert is_list(result.bottlenecks)
    end

    test "identifies bottlenecks" do
      system_state = %{
        base_capacity: 1000,
        utilization: 0.1,
        absorption_efficiency: 1.0,
        processing_capacity: 0.5,
        communication_bandwidth: 0.3,
        decision_capacity: 0.2
      }
      
      result = Calculator.calculate_absorption_rate(system_state, 100)
      
      assert length(result.bottlenecks) > 0
      assert Enum.any?(result.bottlenecks, fn {type, _} -> 
        type in [:processing, :communication, :decision_making]
      end)
    end
  end

  describe "monitor_dynamics/2" do
    test "analyzes basic dynamics" do
      measurements = [
        %{value: 100, timestamp: 1000},
        %{value: 110, timestamp: 2000},
        %{value: 105, timestamp: 3000},
        %{value: 115, timestamp: 4000}
      ]
      
      result = Calculator.monitor_dynamics(measurements, depth: :basic)
      
      assert result.trend > 0  # Increasing trend
      assert result.volatility >= 0
      assert Map.has_key?(result, :predictions)
      assert result.health_score >= 0 and result.health_score <= 1
    end

    test "detects cycles in full analysis" do
      # Create cyclic data
      measurements = 
        0..50
        |> Enum.map(fn i ->
          value = 100 + 10 * :math.sin(i * :math.pi() / 5)  # Period of 10
          %{value: value, timestamp: i * 1000}
        end)
      
      result = Calculator.monitor_dynamics(measurements, depth: :full)
      
      assert length(result.cycles) > 0
      # Should detect cycle around period 10
      assert Enum.any?(result.cycles, fn cycle -> 
        cycle.period >= 8 and cycle.period <= 12 
      end)
    end

    test "detects change points" do
      # Data with sudden change
      measurements = 
        (Enum.map(1..10, fn i -> %{value: 100, timestamp: i * 1000} end) ++
         Enum.map(11..20, fn i -> %{value: 150, timestamp: i * 1000} end))
      
      result = Calculator.monitor_dynamics(measurements, depth: :full)
      
      assert length(result.change_points) > 0
      change_point = hd(result.change_points)
      assert change_point.type == :increase
      assert change_point.magnitude > 0
    end
  end

  describe "calculate_efficiency/3" do
    test "calculates variety efficiency" do
      system_state = %{states: List.duplicate(:s, 100)}
      outcomes = [:outcome1, :outcome2, :outcome1]  # Only 2 unique outcomes
      
      result = Calculator.calculate_efficiency(system_state, outcomes)
      
      assert result.efficiency_ratio < 1  # Inefficient
      assert result.variety_used > result.variety_required
      assert result.waste > 0
      assert result.optimization_potential == :very_high
    end

    test "identifies efficient system" do
      system_state = %{states: [:s1, :s2]}
      outcomes = [:o1, :o2]
      
      result = Calculator.calculate_efficiency(system_state, outcomes)
      
      assert result.efficiency_ratio > 0.9
      assert result.waste == 0
      assert :maintain_current_approach in result.recommendations
    end
  end

  describe "forecast_variety/3" do
    test "creates linear forecast" do
      historical = [
        %{value: 100, timestamp: 1},
        %{value: 110, timestamp: 2},
        %{value: 120, timestamp: 3}
      ]
      
      result = Calculator.forecast_variety(historical, 3, method: :linear)
      
      assert length(result) == 3
      assert Enum.all?(result, & &1.method == :linear)
      # Should continue linear trend
      assert hd(result).value > 120
    end

    test "adds confidence intervals" do
      historical = Enum.map(1..20, fn i -> 
        %{value: 100 + i + :rand.uniform(10), timestamp: i}
      end)
      
      result = Calculator.forecast_variety(historical, 5, confidence: 0.95)
      
      assert Enum.all?(result, fn point ->
        Map.has_key?(point, :lower_bound) and
        Map.has_key?(point, :upper_bound) and
        point.lower_bound <= point.value and
        point.value <= point.upper_bound
      end)
    end

    test "ensemble forecast combines methods" do
      historical = Enum.map(1..10, fn i -> 
        %{value: 100 + i * 5, timestamp: i}
      end)
      
      result = Calculator.forecast_variety(historical, 3, method: :ensemble)
      
      assert Enum.all?(result, & &1.method == :ensemble)
      # Ensemble should produce reasonable values
      assert Enum.all?(result, & &1.value > 100)
    end
  end

  describe "calculate_distribution/2" do
    test "calculates variety distribution" do
      system_state = %{
        components: %{
          subsys1: %{states: [:a, :b, :c]},
          subsys2: %{states: [:x, :y]},
          subsys3: %{states: [:p, :q, :r, :s]}
        }
      }
      
      result = Calculator.calculate_distribution(system_state)
      
      assert map_size(result.distribution) == 3
      assert result.total_variety > 0
      
      # Check percentages sum to ~100
      total_percentage = 
        result.distribution
        |> Map.values()
        |> Enum.map(& &1.percentage)
        |> Enum.sum()
      
      assert_in_delta total_percentage, 100.0, 0.1
      
      assert result.concentration_index >= 0 and result.concentration_index <= 1
      assert result.balance_score >= 0 and result.balance_score <= 1
      assert is_list(result.recommendations)
    end

    test "suggests redistribution for imbalanced system" do
      system_state = %{
        components: %{
          overloaded: %{states: List.duplicate(:s, 100)},
          underused: %{states: [:a]},
          normal: %{states: List.duplicate(:s, 10)}
        }
      }
      
      result = Calculator.calculate_distribution(system_state)
      
      assert length(result.recommendations) > 0
      assert Enum.any?(result.recommendations, fn {action, component, _} ->
        action == :reduce_variety and component == :overloaded
      end)
    end
  end
end