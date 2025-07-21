defmodule VsmCore.Shared.Variety.AmplifierTest do
  use ExUnit.Case, async: true
  alias VsmCore.Shared.Variety.Amplifier

  describe "suggest_methods/1" do
    test "suggests methods for severe deficit" do
      methods = Amplifier.suggest_methods(0.1)  # 90% deficit
      assert methods == [:multiply, :distribute, :delegate, :parallelize]
    end

    test "suggests methods for moderate deficit" do
      methods = Amplifier.suggest_methods(0.6)  # 40% deficit
      assert methods == [:delegate, :empower, :parallelize]
    end

    test "suggests minimal methods for small deficit" do
      methods = Amplifier.suggest_methods(0.95)  # 5% deficit
      assert methods == [:empower]
    end
  end

  describe "delegate/3 with :hierarchical strategy" do
    test "delegates variety across hierarchy levels" do
      variety_load = %{
        task1: %{complexity: :high},
        task2: %{complexity: :medium},
        task3: %{complexity: :low},
        task4: %{complexity: :high}
      }
      
      result = Amplifier.delegate(variety_load, :hierarchical, levels: 2)
      
      assert Map.has_key?(result, :retained)
      assert Map.has_key?(result, :delegated)
      assert length(result.delegated) <= 2
      assert result.total_delegated > 0
    end

    test "retains critical items when specified" do
      variety_load = %{
        critical: %{priority: :critical},
        normal: %{priority: :normal}
      }
      
      result = Amplifier.delegate(variety_load, :hierarchical,
        levels: 1,
        retain_critical: true,
        critical_fn: fn {_k, v} -> v.priority == :critical end
      )
      
      assert Map.has_key?(result.retained, :critical)
      assert not Map.has_key?(result.delegated |> hd() |> Map.get(:items), :critical)
    end
  end

  describe "delegate/3 with :functional strategy" do
    test "delegates by function" do
      variety_load = %{
        ui_task: %{function: :frontend},
        api_task: %{function: :backend},
        db_task: %{function: :backend}
      }
      
      result = Amplifier.delegate(variety_load, :functional,
        functions: [:frontend, :backend]
      )
      
      assert length(result.delegated_by_function) == 2
      
      frontend = Enum.find(result.delegated_by_function, & &1.function == :frontend)
      assert frontend.count == 1
      
      backend = Enum.find(result.delegated_by_function, & &1.function == :backend)
      assert backend.count == 2
    end
  end

  describe "empower/3" do
    test "empowers subsystems with minimal level" do
      subsystems = [
        %{id: "sub1", authority_level: 0.2},
        %{id: "sub2", authority_level: 0.3}
      ]
      
      result = Amplifier.empower(subsystems, :minimal)
      
      assert length(result.empowered_subsystems) == 2
      assert result.empowerment_level == :minimal
      
      sub1 = Enum.find(result.empowered_subsystems, & &1.id == "sub1")
      assert sub1.new_authority_level == 0.3  # 0.2 + 0.1
    end

    test "empowers with substantial level" do
      subsystems = [%{id: "sub1", authority_level: 0.2}]
      
      result = Amplifier.empower(subsystems, :substantial)
      
      sub1 = hd(result.empowered_subsystems)
      assert sub1.new_authority_level == 0.8  # 0.2 + 0.6
      assert :strategic in sub1.decision_rights
      assert Map.has_key?(result, :governance_model)
      assert Map.has_key?(result, :risk_assessment)
    end
  end

  describe "multiply/3" do
    test "multiplies resources proportionally" do
      resources = %{cpu: 100, memory: 200, storage: 300}
      
      result = Amplifier.multiply(resources, 2.0)
      
      assert result.multiplied_resources.cpu == 200
      assert result.multiplied_resources.memory == 400
      assert result.multiplied_resources.storage == 600
      assert result.multiplication_factor == 2.0
    end

    test "respects constraints" do
      resources = %{cpu: 100, memory: 200}
      constraints = %{cpu: 150}  # Max CPU = 150
      
      result = Amplifier.multiply(resources, 2.0, constraints: constraints)
      
      assert result.multiplied_resources.cpu == 150  # Capped
      assert result.multiplied_resources.memory == 400  # Not capped
    end

    test "multiplies by priority" do
      resources = %{critical: 100, normal: 100}
      priority_fn = fn
        :critical -> 2.0
        :normal -> 1.0
      end
      
      result = Amplifier.multiply(resources, 1.5, 
        strategy: :prioritized,
        priority_fn: priority_fn
      )
      
      # Critical gets more multiplication
      assert result.multiplied_resources.critical > result.multiplied_resources.normal
    end
  end

  describe "distribute/3" do
    test "distributes round-robin" do
      variety_load = %{
        task1: %{},
        task2: %{},
        task3: %{},
        task4: %{}
      }
      
      result = Amplifier.distribute(variety_load, 2)
      
      assert map_size(result.distribution) == 2
      assert result.distribution[0] |> length() == 2
      assert result.distribution[1] |> length() == 2
    end

    test "distributes with load balancing" do
      variety_load = %{
        heavy: %{load: 10},
        medium: %{load: 5},
        light: %{load: 1}
      }
      
      result = Amplifier.distribute(variety_load, 2,
        strategy: :load_balanced,
        capacity_fn: fn _ -> 15 end
      )
      
      assert result.processor_count == 2
      assert result.distribution_balance > 0
    end

    test "calculates distribution metrics" do
      variety_load = Map.new(1..10, fn i -> {:"task#{i}", %{}} end)
      
      result = Amplifier.distribute(variety_load, 3)
      
      assert Map.has_key?(result, :expected_throughput)
      assert Map.has_key?(result, :communication_overhead)
      assert Map.has_key?(result, :fault_tolerance)
    end
  end

  describe "parallelize/3" do
    test "creates parallel execution plan" do
      tasks = [:task1, :task2, :task3, :task4]
      
      result = Amplifier.parallelize(tasks, 2)
      
      assert result.parallelism_level == 2
      assert Map.has_key?(result, :parallel_groups)
      assert Map.has_key?(result, :execution_plan)
      assert Map.has_key?(result, :estimated_speedup)
    end

    test "handles task dependencies" do
      tasks = [:a, :b, :c, :d]
      dependencies = %{
        b: [:a],      # b depends on a
        c: [:a],      # c depends on a
        d: [:b, :c]   # d depends on b and c
      }
      
      result = Amplifier.parallelize(tasks, 4, dependencies: dependencies)
      
      # Should identify critical path
      assert result.critical_path == [:a, :b, :d] or result.critical_path == [:a, :c, :d]
      
      # Should identify synchronization points
      assert length(result.synchronization_points) > 0
    end

    test "calculates Amdahl's law speedup" do
      tasks = List.duplicate(:task, 100)
      
      result = Amplifier.parallelize(tasks, 8)
      
      # Speedup should be less than parallelism level (Amdahl's law)
      assert result.estimated_speedup > 1
      assert result.estimated_speedup < 8
    end
  end

  describe "integration scenarios" do
    test "combines delegation and empowerment" do
      # First delegate
      variety_load = Map.new(1..20, fn i -> {:"task#{i}", %{}} end)
      
      delegation = Amplifier.delegate(variety_load, :hierarchical, levels: 3)
      
      # Then empower the delegates
      subsystems = Enum.map(delegation.delegated, fn plan ->
        %{id: "level_#{plan.level}", authority_level: plan.authority_level}
      end)
      
      empowerment = Amplifier.empower(subsystems, :moderate)
      
      assert length(empowerment.empowered_subsystems) == length(delegation.delegated)
    end

    test "multiplies then distributes resources" do
      # Start with limited resources
      resources = %{workers: 10, compute: 100}
      
      # Multiply resources
      multiplied = Amplifier.multiply(resources, 3.0)
      
      # Distribute work across new resources
      work = Map.new(1..50, fn i -> {:"work#{i}", %{}} end)
      distributed = Amplifier.distribute(work, multiplied.multiplied_resources.workers)
      
      assert distributed.processor_count == 30
    end
  end
end