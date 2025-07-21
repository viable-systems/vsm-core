defmodule VSMCore.SubsystemCommunicationTest do
  use ExUnit.Case, async: false
  
  alias VSMCore.System1
  alias VSMCore.System2
  alias VSMCore.System3
  alias VSMCore.System4
  alias VSMCore.System5
  
  describe "S1 to S2 communication" do
    test "operational data flows to coordination" do
      # Subscribe to S2 coordination events
      :ok = VSMCore.System2.Coordination.subscribe()
      
      # Create multiple units and transactions
      {:ok, unit1} = System1.Unit.create(%{id: "comm_test_1", variety_capacity: 50})
      {:ok, unit2} = System1.Unit.create(%{id: "comm_test_2", variety_capacity: 75})
      
      # Generate transactions
      {:ok, _} = System1.Operations.process_transaction(%{
        type: :sale,
        amount: 100,
        unit_id: unit1.id
      })
      
      {:ok, _} = System1.Operations.process_transaction(%{
        type: :sale,
        amount: 200,
        unit_id: unit2.id
      })
      
      # S2 should coordinate based on the data
      assert_receive {:coordination_event, event1}, 1000
      assert_receive {:coordination_event, event2}, 1000
      
      assert event1.source == :s1
      assert event2.source == :s1
      assert event1.unit_id != event2.unit_id
    end
    
    test "S2 can request data from S1" do
      # S2 requests specific metrics
      {:ok, request_id} = VSMCore.System2.Coordination.request_data(:s1, %{
        type: :unit_metrics,
        unit_ids: ["test_unit_1", "test_unit_2"],
        time_range: {System.system_time(), System.system_time()}
      })
      
      # S1 should respond
      assert_receive {:data_response, response}, 2000
      assert response.request_id == request_id
      assert response.source == :s1
      assert is_map(response.data)
    end
  end
  
  describe "S2 to S3 communication" do
    test "coordination influences control decisions" do
      # S2 identifies a coordination issue
      :ok = VSMCore.System2.Coordination.report_issue(%{
        type: :resource_contention,
        units: ["unit_a", "unit_b"],
        severity: :medium,
        suggested_action: :load_balancing
      })
      
      # S3 should implement control measures
      :ok = VSMCore.System3.Control.subscribe()
      
      assert_receive {:control_action, action}, 1000
      assert action.type == :load_balancing
      assert action.triggered_by == :s2_coordination
      assert "unit_a" in action.affected_units
      assert "unit_b" in action.affected_units
    end
    
    test "S3 can override S2 coordination" do
      # S2 suggests one approach
      :ok = VSMCore.System2.Coordination.suggest_action(%{
        type: :increase_throughput,
        target_units: ["unit_x"]
      })
      
      # S3 has a control rule that overrides
      :ok = VSMCore.System3.Control.add_rule(%{
        id: "override_rule",
        condition: {:suggestion_type, :==, :increase_throughput},
        action: {:replace_with, :maintain_stability}
      })
      
      # Check final action
      final_action = VSMCore.System3.Control.get_current_action("unit_x")
      assert final_action.type == :maintain_stability
      assert final_action.overridden_from == :increase_throughput
    end
  end
  
  describe "S3 to S4 communication" do
    test "control decisions are analyzed by intelligence" do
      # S3 makes a control decision
      {:ok, action_id} = VSMCore.System3.Control.execute_action(%{
        id: "test_control_1",
        type: :throttle_operations,
        target: "unit_performance_test",
        parameters: %{max_rate: 10}
      })
      
      # S4 should analyze the decision
      :ok = VSMCore.System4.Intelligence.subscribe()
      
      assert_receive {:intelligence_update, update}, 1000
      assert update.type == :control_analysis
      assert update.action_id == action_id
      assert update.effectiveness_prediction != nil
    end
    
    test "S4 provides intelligence to guide S3 control" do
      # S4 detects a pattern
      :ok = VSMCore.System4.Intelligence.report_pattern(%{
        type: :performance_degradation,
        affected_units: ["unit_pattern_1", "unit_pattern_2"],
        predicted_impact: :high,
        recommended_controls: [:reduce_load, :increase_monitoring]
      })
      
      # S3 should implement recommended controls
      :ok = VSMCore.System3.Control.subscribe()
      
      assert_receive {:control_action, action}, 1000
      assert action.type in [:reduce_load, :increase_monitoring]
      assert action.triggered_by == :s4_intelligence
    end
  end
  
  describe "S4 to S5 communication" do
    test "intelligence informs policy decisions" do
      # S4 provides strategic intelligence
      :ok = VSMCore.System4.Intelligence.provide_strategic_insight(%{
        type: :system_capacity_analysis,
        findings: %{
          current_utilization: 0.75,
          bottlenecks: [:s1_processing, :s3_control_overhead],
          growth_trend: :increasing,
          recommended_policies: [:capacity_expansion, :efficiency_optimization]
        }
      })
      
      # S5 should consider this for policy
      :ok = VSMCore.System5.Policy.subscribe()
      
      assert_receive {:policy_event, event}, 1000
      assert event.type == :strategic_analysis_received
      assert event.insights.current_utilization == 0.75
      assert :capacity_expansion in event.insights.recommended_policies
    end
    
    test "S5 requests specific intelligence from S4" do
      # S5 requests analysis for policy decision
      {:ok, request_id} = VSMCore.System5.Policy.request_intelligence(%{
        type: :impact_analysis,
        policy_proposal: %{
          id: "new_efficiency_policy",
          changes: [:reduce_variety_threshold, :increase_automation]
        },
        required_metrics: [:performance_impact, :risk_assessment]
      })
      
      # S4 should provide the analysis
      assert_receive {:intelligence_response, response}, 2000
      assert response.request_id == request_id
      assert response.analysis_type == :impact_analysis
      assert Map.has_key?(response.metrics, :performance_impact)
      assert Map.has_key?(response.metrics, :risk_assessment)
    end
  end
  
  describe "S5 to all subsystems communication" do
    test "policy changes propagate to all subsystems" do
      # Subscribe to all subsystem policy updates
      :ok = System1.Operations.subscribe_to_policies()
      :ok = VSMCore.System2.Coordination.subscribe_to_policies()
      :ok = VSMCore.System3.Control.subscribe_to_policies()
      :ok = VSMCore.System4.Intelligence.subscribe_to_policies()
      
      # S5 updates a system-wide policy
      {:ok, policy_id} = VSMCore.System5.Policy.update_policy(%{
        id: "global_efficiency_policy",
        scope: :system_wide,
        parameters: %{
          max_processing_time: 50,
          min_success_rate: 0.95,
          energy_efficiency_target: 0.8
        }
      })
      
      # All subsystems should receive the update
      assert_receive {:policy_update, update1}, 1000
      assert_receive {:policy_update, update2}, 1000
      assert_receive {:policy_update, update3}, 1000
      assert_receive {:policy_update, update4}, 1000
      
      policy_updates = [update1, update2, update3, update4]
      assert Enum.all?(policy_updates, &(&1.policy_id == policy_id))
      assert Enum.all?(policy_updates, &(&1.scope == :system_wide))
    end
    
    test "emergency policies override local decisions" do
      # Set normal operations in S1 and S3
      :ok = System1.Operations.set_mode(:normal)
      :ok = VSMCore.System3.Control.set_mode(:normal)
      
      # S5 declares emergency policy
      {:ok, _} = VSMCore.System5.Policy.declare_emergency(%{
        level: :critical,
        type: :system_protection,
        overrides: %{
          s1_mode: :safe,
          s3_mode: :restrictive,
          s2_coordination: :minimal
        },
        duration: :until_revoked
      })
      
      # Check that subsystems switched modes
      assert System1.Operations.get_mode() == :safe
      assert VSMCore.System3.Control.get_mode() == :restrictive
      assert VSMCore.System2.Coordination.get_mode() == :minimal
    end
  end
  
  describe "Bidirectional feedback loops" do
    test "S1 performance affects S3 control which affects S1" do
      # S1 starts with normal performance
      initial_metrics = System1.Metrics.get_system_metrics()
      
      # Simulate load that causes performance degradation
      for _i <- 1..50 do
        System1.Operations.process_transaction(%{
          type: :complex_operation,
          amount: :rand.uniform(1000),
          unit_id: "feedback_test_#{:rand.uniform(10)}"
        })
      end
      
      # Wait for feedback loop to stabilize
      Process.sleep(1000)
      
      # S3 should have implemented controls
      control_actions = VSMCore.System3.Control.get_recent_actions()
      assert length(control_actions) > 0
      assert Enum.any?(control_actions, &(&1.type in [:throttle, :load_balance, :prioritize]))
      
      # S1 performance should improve
      final_metrics = System1.Metrics.get_system_metrics()
      assert final_metrics.avg_processing_time <= initial_metrics.avg_processing_time * 1.2
    end
    
    test "S4 learning improves S2 coordination" do
      # S4 starts learning from S2 coordination patterns
      :ok = VSMCore.System4.Intelligence.start_learning(%{
        target: :s2_coordination,
        focus: :efficiency_optimization
      })
      
      # Generate various coordination scenarios
      scenarios = [
        {:resource_contention, [:unit_a, :unit_b]},
        {:load_balancing, [:unit_c, :unit_d, :unit_e]},
        {:priority_adjustment, [:unit_f]},
        {:capacity_scaling, [:unit_g, :unit_h]}
      ]
      
      for {scenario_type, units} <- scenarios do
        VSMCore.System2.Coordination.handle_scenario(scenario_type, units)
        Process.sleep(100)
      end
      
      # S4 should provide improved coordination suggestions
      suggestions = VSMCore.System4.Intelligence.get_coordination_suggestions()
      assert length(suggestions) > 0
      assert Enum.all?(suggestions, &(&1.confidence > 0.5))
      assert Enum.any?(suggestions, &(&1.improvement_potential > 0.1))
    end
  end
  
  describe "Multi-subsystem scenarios" do
    test "complex transaction processing involves all subsystems" do
      # Create a complex scenario that requires all subsystems
      scenario = %{
        type: :multi_unit_coordination,
        units: ["unit_1", "unit_2", "unit_3"],
        operations: [
          {:transfer, "unit_1", "unit_2", 500},
          {:process, "unit_2", %{complexity: :high}},
          {:report, "unit_3", %{frequency: :real_time}}
        ],
        constraints: %{
          max_total_time: 1000,
          min_success_rate: 0.99,
          resource_limits: %{cpu: 0.8, memory: 0.7}
        }
      }
      
      # Execute the scenario
      {:ok, execution_id} = VSMCore.execute_complex_scenario(scenario)
      
      # All subsystems should be involved
      execution_trace = VSMCore.get_execution_trace(execution_id)
      
      involved_subsystems = execution_trace
                          |> Enum.map(& &1.subsystem)
                          |> Enum.uniq()
      
      assert :s1 in involved_subsystems  # Operations
      assert :s2 in involved_subsystems  # Coordination
      assert :s3 in involved_subsystems  # Control
      assert :s4 in involved_subsystems  # Intelligence
      assert :s5 in involved_subsystems  # Policy
    end
    
    test "system-wide optimization involves coordinated changes" do
      # Trigger system-wide optimization
      {:ok, optimization_id} = VSMCore.optimize_system(%{
        target: :overall_efficiency,
        constraints: %{
          max_disruption: :low,
          preserve_functionality: true
        },
        focus_areas: [:throughput, :resource_utilization, :response_time]
      })
      
      # Wait for optimization to complete
      :ok = VSMCore.wait_for_optimization(optimization_id, 5000)
      
      # Check that improvements were made across subsystems
      optimization_results = VSMCore.get_optimization_results(optimization_id)
      
      assert optimization_results.status == :completed
      assert optimization_results.improvements.s1_throughput > 0
      assert optimization_results.improvements.s2_coordination_efficiency > 0
      assert optimization_results.improvements.s3_control_precision > 0
      assert optimization_results.improvements.s4_analysis_speed > 0
      assert optimization_results.improvements.s5_policy_effectiveness > 0
    end
  end
end