defmodule VSMCore.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias VSMCore.System1
  alias VSMCore.System2
  alias VSMCore.System3
  alias VSMCore.System4
  alias VSMCore.System5
  alias VSMCore.Channels.Algedonic
  alias VSMCore.Channels.TemporalVariety
  
  describe "VSM Core Application" do
    test "all subsystems start properly" do
      # Application should already be started by test helper
      assert Process.whereis(VSMCore.Supervisor) != nil
      
      # Check all subsystem supervisors
      assert Process.whereis(System1.Supervisor) != nil
      assert Process.whereis(System2.Supervisor) != nil
      assert Process.whereis(System3.Supervisor) != nil
      assert Process.whereis(System4.Supervisor) != nil
      assert Process.whereis(System5.Supervisor) != nil
      
      # Check channels
      assert Process.whereis(VSMCore.Channels.Supervisor) != nil
    end
    
    test "VSMCore.status/0 returns correct system status" do
      status = VSMCore.status()
      
      assert status.system == :running
      assert status.subsystems.s1 == :running
      assert status.subsystems.s2 == :running
      assert status.subsystems.s3 == :running
      assert status.subsystems.s4 == :running
      assert status.subsystems.s5 == :running
      assert status.channels.algedonic == :running
      assert status.channels.temporal_variety == :running
    end
    
    test "VSMCore.health/0 returns system health information" do
      health = VSMCore.health()
      
      assert health.status == :healthy
      assert is_integer(health.uptime)
      assert is_map(health.metrics)
      assert is_list(health.alerts)
      assert is_map(health.capacity)
    end
  end
  
  describe "Cross-subsystem communication" do
    test "S1 operations are monitored by S2" do
      # Start monitoring S2 coordination events
      :ok = VSMCore.System2.Coordination.subscribe()
      
      # Perform an S1 operation
      {:ok, _result} = System1.Operations.process_transaction(%{
        type: :sale,
        amount: 100,
        unit_id: "unit_test"
      })
      
      # S2 should receive coordination event
      assert_receive {:coordination_event, event}, 1000
      assert event.source == :s1
      assert event.type == :transaction_completed
    end
    
    test "S3 can control S1 operations" do
      # Set a control rule in S3
      :ok = VSMCore.System3.Control.add_rule(%{
        id: "test_rule",
        condition: {:transaction_amount, :>, 1000},
        action: :require_approval
      })
      
      # Try to process a large transaction in S1
      result = System1.Operations.process_transaction(%{
        type: :sale,
        amount: 2000,
        unit_id: "unit_test"
      })
      
      # Should be blocked by S3 control
      assert {:error, :requires_approval} = result
    end
    
    test "S4 receives intelligence from all subsystems" do
      # Subscribe to S4 intelligence updates
      :ok = VSMCore.System4.Intelligence.subscribe()
      
      # Generate activity in S1
      {:ok, _} = System1.Operations.process_transaction(%{
        type: :sale,
        amount: 100,
        unit_id: "unit_1"
      })
      
      # S4 should analyze the pattern
      assert_receive {:intelligence_update, update}, 1000
      assert update.type == :pattern_detected
      assert update.source_subsystems == [:s1]
    end
    
    test "S5 policies affect all subsystems" do
      # Set a system-wide policy
      :ok = VSMCore.System5.Policy.set_policy(%{
        id: "efficiency_policy",
        type: :system_wide,
        rules: [
          {:max_processing_time, 100},
          {:min_variety_ratio, 0.5}
        ]
      })
      
      # Check that subsystems receive the policy
      s1_config = System1.Operations.get_config()
      assert s1_config.max_processing_time == 100
      
      s3_constraints = VSMCore.System3.Control.get_constraints()
      assert s3_constraints.min_variety_ratio == 0.5
    end
  end
  
  describe "Variety engineering integration" do
    test "variety calculations propagate through the system" do
      # Create variety in S1
      {:ok, unit} = System1.Unit.create(%{
        id: "var_test_unit",
        variety_capacity: 100
      })
      
      # Generate transactions with different variety
      for i <- 1..10 do
        System1.Operations.process_transaction(%{
          type: :sale,
          amount: i * 10,
          unit_id: unit.id,
          complexity: rem(i, 3) + 1
        })
      end
      
      # Check variety metrics
      metrics = System1.Metrics.get_unit_metrics(unit.id)
      assert metrics.variety_generated > 0
      assert metrics.variety_absorbed > 0
      
      # S3 should show variety balancing
      control_metrics = VSMCore.System3.Control.get_variety_metrics()
      assert control_metrics.total_variety_managed > 0
    end
    
    test "variety attenuation works across subsystems" do
      # Configure S2 to attenuate variety
      :ok = VSMCore.System2.Coordination.configure_attenuation(%{
        method: :filtering,
        threshold: 0.7
      })
      
      # Generate high variety in S1
      for i <- 1..20 do
        System1.Operations.process_transaction(%{
          type: Enum.random([:sale, :return, :exchange]),
          amount: :rand.uniform(1000),
          unit_id: "unit_#{rem(i, 5)}"
        })
      end
      
      # Measure variety at different levels
      s1_variety = System1.Metrics.get_system_variety()
      s2_variety = VSMCore.System2.Coordination.get_output_variety()
      
      # S2 should have attenuated the variety
      assert s2_variety < s1_variety
      assert s2_variety / s1_variety < 0.7
    end
    
    test "variety amplification for policy implementation" do
      # S5 sets a policy requiring variety amplification
      :ok = VSMCore.System5.Policy.set_policy(%{
        id: "diversity_policy",
        type: :variety_amplification,
        target_variety: 500,
        methods: [:rule_generation, :option_expansion]
      })
      
      # S4 should detect the need for amplification
      intelligence = VSMCore.System4.Intelligence.analyze_variety_gap()
      assert intelligence.gap_detected == true
      assert intelligence.recommended_actions != []
      
      # S3 should implement amplification
      {:ok, _} = VSMCore.System3.Control.amplify_variety(
        intelligence.recommended_actions
      )
      
      # Check resulting variety
      system_variety = VSMCore.status().metrics
      assert system_variety.total_variety >= 400
    end
  end
  
  describe "Temporal variety channel" do
    test "buffers environmental variety correctly" do
      # Send multiple environmental inputs rapidly
      for i <- 1..50 do
        TemporalVariety.process_input(%{
          source: :environment,
          data: "input_#{i}",
          timestamp: System.system_time(:millisecond)
        })
      end
      
      # Check buffer status
      buffer_status = TemporalVariety.buffer_status()
      assert buffer_status.count > 0
      assert buffer_status.count <= 50
      
      # Verify S4 receives aggregated data
      :ok = VSMCore.System4.Intelligence.subscribe()
      
      # Trigger buffer processing
      TemporalVariety.trigger_processing()
      
      assert_receive {:intelligence_update, update}, 2000
      assert update.type == :temporal_variety_batch
      assert length(update.data) > 0
    end
    
    test "handles overflow gracefully" do
      # Configure small buffer for testing
      :ok = TemporalVariety.configure(%{max_buffer_size: 10})
      
      # Send more inputs than buffer can handle
      for i <- 1..20 do
        TemporalVariety.process_input(%{
          source: :environment,
          data: "overflow_#{i}",
          priority: rem(i, 3)
        })
      end
      
      buffer_status = TemporalVariety.buffer_status()
      assert buffer_status.count == 10
      assert buffer_status.overflow_count == 10
      
      # High priority items should be retained
      {:ok, items} = TemporalVariety.peek_buffer()
      priorities = Enum.map(items, & &1.priority)
      assert Enum.count(priorities, &(&1 == 0)) < Enum.count(priorities, &(&1 == 2))
    end
  end
  
  describe "Algedonic channel" do
    test "routes emergency signals directly to S5" do
      # Subscribe to S5 policy events
      :ok = VSMCore.System5.Policy.subscribe()
      
      # Send an algedonic signal
      {:ok, signal_id} = Algedonic.send_signal(%{
        urgency: :critical,
        source: :s1,
        content: "System overload detected",
        metrics: %{cpu: 98, memory: 95}
      })
      
      # S5 should receive it immediately
      assert_receive {:policy_event, event}, 500
      assert event.type == :algedonic_signal
      assert event.signal.urgency == :critical
      assert event.signal.id == signal_id
    end
    
    test "filters signals based on urgency" do
      # Configure filtering
      :ok = Algedonic.configure_filter(%{
        s5_threshold: :high,
        s3_threshold: :medium,
        s4_threshold: :low
      })
      
      # Send signals of different urgencies
      {:ok, _} = Algedonic.send_signal(%{urgency: :low, source: :s1, content: "Info"})
      {:ok, _} = Algedonic.send_signal(%{urgency: :medium, source: :s2, content: "Warning"})
      {:ok, _} = Algedonic.send_signal(%{urgency: :critical, source: :s1, content: "Critical"})
      
      # Check signal routing
      s5_signals = VSMCore.System5.Policy.get_algedonic_signals()
      assert length(s5_signals) == 1
      assert hd(s5_signals).urgency == :critical
      
      s3_signals = VSMCore.System3.Control.get_algedonic_signals()
      assert length(s3_signals) >= 1
      assert Enum.any?(s3_signals, &(&1.urgency == :medium))
    end
    
    test "correlates related signals" do
      # Send related signals
      {:ok, _} = Algedonic.send_signal(%{
        urgency: :high,
        source: :s1,
        content: "High memory usage",
        correlation_id: "perf_issue_1"
      })
      
      {:ok, _} = Algedonic.send_signal(%{
        urgency: :high,
        source: :s1,
        content: "Slow response times",
        correlation_id: "perf_issue_1"
      })
      
      # Check correlation
      correlated = Algedonic.get_correlated_signals("perf_issue_1")
      assert length(correlated) == 2
      assert Enum.all?(correlated, &(&1.correlation_id == "perf_issue_1"))
    end
  end
  
  describe "System resilience" do
    test "system continues operating when S4 is down" do
      # Stop S4
      :ok = Supervisor.stop(VSMCore.System4.Supervisor)
      
      # Other subsystems should continue
      assert VSMCore.status().subsystems.s1 == :running
      assert VSMCore.status().subsystems.s2 == :running
      assert VSMCore.status().subsystems.s3 == :running
      assert VSMCore.status().subsystems.s5 == :running
      
      # S1 operations should still work
      assert {:ok, _} = System1.Operations.process_transaction(%{
        type: :sale,
        amount: 100,
        unit_id: "resilience_test"
      })
    end
    
    test "algedonic channel bypasses failed subsystems" do
      # Stop S3 and S4
      :ok = Supervisor.stop(VSMCore.System3.Supervisor)
      :ok = Supervisor.stop(VSMCore.System4.Supervisor)
      
      # Subscribe to S5
      :ok = VSMCore.System5.Policy.subscribe()
      
      # Send critical signal
      {:ok, _} = Algedonic.send_signal(%{
        urgency: :critical,
        source: :s1,
        content: "Emergency signal during partial failure"
      })
      
      # S5 should still receive it
      assert_receive {:policy_event, event}, 1000
      assert event.type == :algedonic_signal
      assert event.signal.urgency == :critical
    end
  end
  
  describe "Performance and monitoring" do
    test "telemetry events are emitted for key operations" do
      # Attach telemetry handler
      test_pid = self()
      handler_id = :test_telemetry_handler
      
      :telemetry.attach(
        handler_id,
        [:vsm_core, :transaction, :complete],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )
      
      # Perform operation
      {:ok, _} = System1.Operations.process_transaction(%{
        type: :sale,
        amount: 100,
        unit_id: "telemetry_test"
      })
      
      # Should receive telemetry
      assert_receive {:telemetry, measurements, metadata}, 1000
      assert is_number(measurements.duration)
      assert metadata.unit_id == "telemetry_test"
      
      :telemetry.detach(handler_id)
    end
    
    test "system can handle high load" do
      # Generate concurrent load
      tasks = for i <- 1..100 do
        Task.async(fn ->
          System1.Operations.process_transaction(%{
            type: :sale,
            amount: :rand.uniform(1000),
            unit_id: "load_test_#{rem(i, 10)}"
          })
        end)
      end
      
      # Wait for all tasks
      results = Task.await_many(tasks, 5000)
      
      # Most should succeed
      successful = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)
      
      assert successful > 90
      
      # System should still be healthy
      assert VSMCore.health().status == :healthy
    end
  end
end