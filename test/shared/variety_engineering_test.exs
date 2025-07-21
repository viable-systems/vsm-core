defmodule VsmCore.Shared.VarietyEngineeringTest do
  use ExUnit.Case, async: true
  alias VsmCore.Shared.VarietyEngineering

  describe "shannon_entropy/1" do
    test "calculates entropy for uniform distribution" do
      assert VarietyEngineering.shannon_entropy([0.5, 0.5]) == 1.0
    end

    test "calculates entropy for certain outcome" do
      assert VarietyEngineering.shannon_entropy([1.0]) == 0.0
    end

    test "calculates entropy for varied distribution" do
      entropy = VarietyEngineering.shannon_entropy([0.25, 0.25, 0.25, 0.25])
      assert_in_delta entropy, 2.0, 0.001
    end

    test "handles zero probabilities" do
      entropy = VarietyEngineering.shannon_entropy([0.5, 0.5, 0.0])
      assert entropy == 1.0
    end
  end

  describe "measure_variety/2" do
    test "measures simple variety" do
      states = [:state1, :state2, :state3, :state1]
      result = VarietyEngineering.measure_variety(states)
      
      assert result.raw_variety == 4
      assert result.weighted_variety > 0
      assert is_float(result.entropy)
      assert is_float(result.complexity)
    end

    test "measures variety with dimensions" do
      states = [
        {:dim1, :value1},
        {:dim1, :value2},
        {:dim2, :value1}
      ]
      
      result = VarietyEngineering.measure_variety(states, dimensions: 2)
      assert length(result.dimensional_varieties) == 2
    end

    test "applies custom weights" do
      states = [{:dim1, :val1}, {:dim2, :val2}]
      weights = [2.0, 0.5]
      
      result = VarietyEngineering.measure_variety(states, dimensions: 2, weights: weights)
      assert result.weighted_variety > 0
    end
  end

  describe "apply_ashbys_law/3" do
    test "identifies balanced variety" do
      result = VarietyEngineering.apply_ashbys_law(100, 100)
      assert {:balanced, details} = result
      assert details.ratio == 1.0
      assert details.action == :maintain
    end

    test "identifies insufficient variety" do
      result = VarietyEngineering.apply_ashbys_law(50, 100)
      assert {:insufficient, details} = result
      assert details.ratio == 0.5
      assert details.deficit == 50
      assert details.action == :amplify
      assert is_list(details.suggested_methods)
    end

    test "identifies excessive variety" do
      result = VarietyEngineering.apply_ashbys_law(150, 100)
      assert {:excessive, details} = result
      assert details.ratio == 1.5
      assert details.surplus == 50
      assert details.action == :attenuate
      assert is_list(details.suggested_methods)
    end

    test "respects tolerance parameter" do
      result = VarietyEngineering.apply_ashbys_law(105, 100, tolerance: 0.1)
      assert {:balanced, _} = result
    end
  end

  describe "balance_variety/1" do
    test "balances variety across components" do
      components = %{
        system1: 100,
        system2: 50,
        system3: 150
      }
      
      result = VarietyEngineering.balance_variety(components)
      
      assert result.total_variety == 300
      assert result.target_per_component == 100
      assert result.adjustments.system1.action == :maintain
      assert result.adjustments.system2.action == :amplify
      assert result.adjustments.system3.action == :attenuate
      assert is_float(result.balance_index)
    end

    test "handles single component" do
      components = %{only_system: 100}
      result = VarietyEngineering.balance_variety(components)
      
      assert result.total_variety == 100
      assert result.target_per_component == 100
      assert result.balance_index == 1.0
    end
  end

  describe "absorption_capacity/2" do
    test "calculates absorption capacity" do
      system_state = %{
        nodes: 10,
        connections: 20,
        levels: 3
      }
      
      result = VarietyEngineering.absorption_capacity(system_state)
      
      assert result.structural_capacity > 0
      assert result.dynamic_capacity > 0
      assert result.available_capacity > 0
      assert result.buffered_capacity < result.available_capacity
      assert result.utilization == 0.5
      assert result.headroom > 0
    end

    test "applies custom parameters" do
      system_state = %{nodes: 5, connections: 10, levels: 2}
      
      result = VarietyEngineering.absorption_capacity(system_state,
        current_load: 0.8,
        buffer_capacity: 0.3,
        adaptability: 0.9
      )
      
      assert result.utilization == 0.8
      assert result.dynamic_capacity > result.structural_capacity
    end
  end
end