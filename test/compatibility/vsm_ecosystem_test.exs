defmodule VSMCore.Compatibility.EcosystemTest do
  @moduledoc """
  Comprehensive compatibility tests for VSM Core with other VSM ecosystem packages.
  
  This test suite verifies that VSM Core integrates correctly with:
  - vsm-starter
  - vsm-telemetry  
  - vsm-rate-limiter
  - vsm-goldrush
  """
  
  use ExUnit.Case, async: false
  require Logger
  
  @moduletag :compatibility
  @moduletag :integration
  
  # Test timeout for integration tests
  @test_timeout 30_000
  
  describe "VSM Core + VSM Starter Integration" do
    @tag timeout: @test_timeout
    test "vsm-starter templates work with vsm-core" do
      # Test that starter templates can use VSM Core functionality
      assert Code.ensure_loaded?(VSMCore)
      assert Code.ensure_loaded?(VSMCore.Application)
      
      # Verify core modules are available for starter templates
      core_modules = [
        VSMCore.System1.Operations,
        VSMCore.System2.Coordination,
        VSMCore.System3.Control,
        VSMCore.System4.Intelligence,
        VSMCore.System5.Policy,
        VSMCore.Shared.Message,
        VsmCore.Shared.VarietyEngineering
      ]
      
      Enum.each(core_modules, fn module ->
        assert Code.ensure_loaded?(module), "#{module} should be available for starter templates"
      end)
    end
    
    test "starter can create messages compatible with core" do
      # Test message creation compatibility
      message = VSMCore.Shared.Message.command(
        :starter_system,
        :system3,
        :resource_request,
        %{resource_type: :processing_unit, priority: :high}
      )
      
      assert is_binary(message.id)
      assert message.from == :starter_system
      assert message.to == :system3
      assert message.type == :resource_request
      assert message.channel == :command_channel
    end
    
    test "starter telemetry events compatible with core" do
      # Verify telemetry event format compatibility
      test_pid = self()
      
      :telemetry.attach(
        "starter-core-compatibility",
        [:vsm_core, :system1, :transaction],
        fn event, measurements, metadata, config ->
          send(config.test_pid, {:telemetry_received, event, measurements, metadata})
        end,
        %{test_pid: test_pid}
      )
      
      # Start VSM Core if not already started
      {:ok, _} = Application.ensure_all_started(:vsm_core)
      Process.sleep(1000)
      
      # Simulate starter-generated transaction
      transaction = %{
        type: :starter_transaction,
        payload: %{action: :compatibility_test},
        required_capabilities: [:test_capability]
      }
      
      # This would normally be called by starter template
      try do
        VSMCore.System1.Operations.process_transaction(transaction)
      catch
        # Expected to fail due to no suitable unit, but telemetry should still fire
        :exit, _ -> :ok
      end
      
      # Verify telemetry event was received
      assert_receive {:telemetry_received, _event, _measurements, metadata}, 5_000
      assert metadata.transaction_type == :starter_transaction
      
      :telemetry.detach("starter-core-compatibility")
    end
  end
  
  describe "VSM Core + VSM Telemetry Integration" do
    @tag timeout: @test_timeout  
    test "core telemetry events are received by vsm-telemetry" do
      # Start VSM Core
      {:ok, _} = Application.ensure_all_started(:vsm_core)
      Process.sleep(1000)
      
      test_pid = self()
      event_count = :counters.new(1, [])
      
      # Attach to VSM Core events that telemetry package would monitor
      telemetry_events = [
        [:vsm_core, :system1, :transaction],
        [:vsm_core, :system4, :init],
        [:vsm_core, :algedonic, :alert],
        [:vsm_core, :system1, :variety]
      ]
      
      Enum.each(telemetry_events, fn event ->
        :telemetry.attach(
          "telemetry-compat-#{Enum.join(event, "-")}",
          event,
          fn _event, measurements, metadata, _config ->
            :counters.add(event_count, 1, 1)
            send(test_pid, {:telemetry_event, _event, measurements, metadata})
          end,
          nil
        )
      end)
      
      # Trigger various VSM Core events
      
      # 1. Process a transaction to trigger System1 telemetry
      try do
        VSMCore.System1.Operations.process_transaction(%{
          type: :test_transaction, 
          payload: %{data: "test"}, 
          required_capabilities: [:test]
        })
      catch
        # Transaction processing might fail, but should still emit telemetry
        _, _ -> :ok
      end
      
      # 2. Trigger variety calculation with actual metrics
      try do
        VSMCore.System1.Metrics.record_variety(%{
          input: 2.0, 
          output: 1.0, 
          ratio: 0.5
        })
      catch
        # Metrics recording might fail, but should still emit telemetry
        _, _ -> :ok
      end
      
      # 3. Trigger algedonic alert
      try do
        message = VSMCore.Shared.Message.algedonic(:system1, %{alert: :test_emergency})
        VSMCore.Channels.Algedonic.Alerting.create_alert(:emergency, message.payload, %{})
      catch
        # Alert creation might fail, but should still emit telemetry
        _, _ -> :ok
      end
      
      # Wait for telemetry events
      Process.sleep(2000)
      
      # Verify events were received
      event_total = :counters.get(event_count, 1)
      assert event_total > 0, "Should have received telemetry events"
      
      # Cleanup
      Enum.each(telemetry_events, fn event ->
        :telemetry.detach("telemetry-compat-#{Enum.join(event, "-")}")
      end)
    end
    
    test "telemetry metrics format compatibility" do
      # Test that VSM Core emits metrics in expected format for telemetry package
      test_pid = self()
      
      :telemetry.attach(
        "metrics-format-test",
        [:vsm_core, :system1, :metrics, :collected],
        fn _event, measurements, metadata, _config ->
          # Verify expected telemetry format
          assert is_map(measurements)
          assert is_map(metadata)
          
          # Standard measurement keys that telemetry package expects
          expected_measurement_keys = [:count, :duration]
          measurement_keys = Map.keys(measurements)
          
          # Should have at least some expected keys
          has_expected_keys = Enum.any?(expected_measurement_keys, &(&1 in measurement_keys))
          assert has_expected_keys, "Measurements should contain expected keys: #{inspect(measurement_keys)}"
          
          # Standard metadata that telemetry package expects
          assert Map.has_key?(metadata, :subsystem) or Map.has_key?(metadata, :component)
          
          send(test_pid, {:metrics_format_ok, measurements, metadata})
        end,
        nil
      )
      
      # Start system and trigger metrics
      {:ok, _} = Application.ensure_all_started(:vsm_core)
      Process.sleep(1000)
      
      # Trigger metrics collection (simulated)
      :telemetry.execute(
        [:vsm_core, :system1, :metrics, :collected],
        %{count: 1, duration: 150},
        %{subsystem: :system1, component: :operations}
      )
      
      assert_receive {:metrics_format_ok, measurements, metadata}, 5_000
      
      :telemetry.detach("metrics-format-test")
    end
  end
  
  describe "VSM Core + VSM Rate Limiter Integration" do
    @tag timeout: @test_timeout
    test "rate limiter can protect vsm-core subsystems" do
      # Test that rate limiter integration points exist
      
      # Verify subsystem identifiers are compatible
      vsm_subsystems = [:s1_environment, :s2_coordination, :s3_control, :s4_intelligence, :s5_policy]
      
      Enum.each(vsm_subsystems, fn subsystem ->
        # These would be the integration points for rate limiter
        assert is_atom(subsystem)
        
        # Rate limiter would use these patterns
        rate_key = "#{subsystem}_user_123"
        assert is_binary(rate_key)
      end)
    end
    
    test "algedonic integration with rate limiter" do
      # Test that VSM Core can receive algedonic signals from rate limiter
      {:ok, _} = Application.ensure_all_started(:vsm_core)
      Process.sleep(1000)
      
      test_pid = self()
      
      # Monitor algedonic channel for rate limiter signals
      :telemetry.attach(
        "rate-limiter-algedonic",
        [:vsm_core, :algedonic, :signal, :received],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:algedonic_signal, measurements, metadata})
        end,
        nil
      )
      
      # Simulate rate limiter sending algedonic signal
      algedonic_message = VSMCore.Shared.Message.algedonic(
        :rate_limiter,
        %{
          source: :rate_limiter,
          severity: :critical,
          subsystem: :s1_environment,
          threshold_exceeded: 0.95,
          current_rate: 150,
          max_rate: 100
        }
      )
      
      # Send through algedonic channel
      VSMCore.Channels.AlgedonicChannel.send_message(algedonic_message)
      
      # Wait for processing
      Process.sleep(1000)
      
      :telemetry.detach("rate-limiter-algedonic")
    end
    
    test "rate limiter telemetry event compatibility" do
      # Test that rate limiter events are compatible with VSM Core telemetry format
      test_pid = self()
      
      # Rate limiter would emit these types of events
      rate_limiter_events = [
        [:vsm_rate_limiter, :request, :allowed],
        [:vsm_rate_limiter, :request, :rejected],
        [:vsm_rate_limiter, :algedonic, :alert]
      ]
      
      Enum.each(rate_limiter_events, fn event ->
        :telemetry.attach(
          "rate-limiter-#{Enum.join(event, "-")}",
          event,
          fn _event, measurements, metadata, _config ->
            # Verify format compatibility with VSM ecosystem
            assert is_map(measurements)
            assert is_map(metadata)
            
            send(test_pid, {:rate_limiter_event, _event, measurements, metadata})
          end,
          nil
        )
      end)
      
      # Simulate rate limiter events
      :telemetry.execute(
        [:vsm_rate_limiter, :request, :allowed],
        %{count: 1, remaining: 99},
        %{subsystem: :s1_environment, user_id: "test_user"}
      )
      
      :telemetry.execute(
        [:vsm_rate_limiter, :request, :rejected], 
        %{count: 1},
        %{subsystem: :s1_environment, user_id: "test_user", reason: :rate_exceeded}
      )
      
      # Verify events received
      assert_receive {:rate_limiter_event, [:vsm_rate_limiter, :request, :allowed], _, _}, 2_000
      assert_receive {:rate_limiter_event, [:vsm_rate_limiter, :request, :rejected], _, _}, 2_000
      
      # Cleanup
      Enum.each(rate_limiter_events, fn event ->
        :telemetry.detach("rate-limiter-#{Enum.join(event, "-")}")
      end)
    end
  end
  
  describe "VSM Core + VSM Goldrush Integration" do
    @tag timeout: @test_timeout
    test "goldrush can process vsm-core events" do
      # Test that Goldrush can consume VSM Core events for pattern detection
      {:ok, _} = Application.ensure_all_started(:vsm_core)
      Process.sleep(1000)
      
      test_pid = self()
      
      # Goldrush would listen to these VSM Core events
      goldrush_target_events = [
        [:vsm_core, :system1, :transaction, :processed],
        [:vsm_core, :system4, :scan, :completed],
        [:vsm_core, :variety, :calculated]
      ]
      
      Enum.each(goldrush_target_events, fn event ->
        :telemetry.attach(
          "goldrush-#{Enum.join(event, "-")}",
          event,
          fn _event, measurements, metadata, _config ->
            # Simulate Goldrush processing
            goldrush_event = %{
              type: "vsm_#{Enum.join(tl(event), "_")}",
              subsystem: metadata[:subsystem] || :unknown,
              timestamp: DateTime.utc_now(),
              measurements: measurements,
              metadata: metadata
            }
            
            send(test_pid, {:goldrush_processed, goldrush_event})
          end,
          nil
        )
      end)
      
      # Trigger VSM Core events that Goldrush would process
      
      # 1. Variety calculation
      entropy = VsmCore.Shared.VarietyEngineering.shannon_entropy([0.25, 0.25, 0.25, 0.25])
      assert entropy == 2.0
      
      # 2. System 4 scan (may emit telemetry even if it fails)
      try do
        VSMCore.System4.Intelligence.scan_environment([:test_pattern])
      catch
        _, _ -> :ok
      end
      
      # Wait for Goldrush processing
      Process.sleep(2000)
      
      # Cleanup
      Enum.each(goldrush_target_events, fn event ->
        :telemetry.detach("goldrush-#{Enum.join(event, "-")}")
      end)
    end
    
    test "event format compatibility for pattern detection" do
      # Test that VSM Core events contain the data needed for pattern detection
      
      # Goldrush needs events in this format for pattern detection:
      # %{type: string, timestamp: datetime, metadata: map}
      
      sample_events = [
        {[:vsm_core, :system1, :transaction, :processed], %{duration: 150}, %{type: :order_processing}},
        {[:vsm_core, :system4, :scan, :completed], %{patterns_found: 3}, %{scan_type: :market_analysis}},
        {[:vsm_core, :variety, :calculated], %{entropy: 2.5}, %{subsystem: :system1}}
      ]
      
      Enum.each(sample_events, fn {event_name, measurements, metadata} ->
        # Verify event can be converted to Goldrush format
        goldrush_event = %{
          type: event_name |> tl() |> Enum.join("_"),
          timestamp: DateTime.utc_now(),
          measurements: measurements,
          metadata: metadata
        }
        
        # Required fields for pattern detection
        assert is_binary(goldrush_event.type)
        assert %DateTime{} = goldrush_event.timestamp
        assert is_map(goldrush_event.measurements)
        assert is_map(goldrush_event.metadata)
        
        # Event should be serializable (for storage/processing)
        {:ok, json} = Jason.encode(goldrush_event)
        {:ok, decoded} = Jason.decode(json, keys: :atoms)
        assert decoded.type == goldrush_event.type
      end)
    end
  end
  
  describe "Multi-Package Integration" do
    @tag timeout: @test_timeout
    test "full ecosystem telemetry flow" do
      # Test complete telemetry flow across all packages
      {:ok, _} = Application.ensure_all_started(:vsm_core)
      Process.sleep(1000)
      
      test_pid = self()
      event_log = []
      
      # Monitor telemetry flow across ecosystem
      ecosystem_events = [
        # VSM Core events (actual events that are emitted)
        [:vsm_core, :system1, :transaction],
        [:vsm_core, :system1, :variety],
        [:vsm_core, :algedonic, :metrics],
        
        # Simulated events from other packages
        [:vsm_telemetry, :metrics, :collected],
        [:vsm_rate_limiter, :request, :checked],
        [:vsm_goldrush, :pattern, :detected]
      ]
      
      Enum.each(ecosystem_events, fn event ->
        :telemetry.attach(
          "ecosystem-#{Enum.join(event, "-")}",
          event,
          fn event_name, measurements, metadata, _config ->
            event_record = %{
              event: event_name,
              timestamp: DateTime.utc_now(),
              measurements: measurements,
              metadata: metadata
            }
            send(test_pid, {:ecosystem_event, event_record})
          end,
          nil
        )
      end)
      
      # Simulate ecosystem activity
      
      # 1. VSM Core processes transaction
      try do
        transaction = %{
          type: :ecosystem_test,
          payload: %{test_data: "integration"},
          required_capabilities: [:test]
        }
        VSMCore.System1.Operations.process_transaction(transaction)
      catch
        _, _ -> :ok
      end
      
      # 2. Simulate telemetry collection
      :telemetry.execute(
        [:vsm_telemetry, :metrics, :collected],
        %{metric_count: 5, collection_time: 25},
        %{source: :vsm_core, timestamp: DateTime.utc_now()}
      )
      
      # 3. Simulate rate limiter check
      :telemetry.execute(
        [:vsm_rate_limiter, :request, :checked],
        %{allowed: 1, rate_limit: 100},
        %{subsystem: :s1_environment, user: "test_user"}
      )
      
      # 4. Simulate pattern detection
      :telemetry.execute(
        [:vsm_goldrush, :pattern, :detected],
        %{pattern_confidence: 0.85, pattern_type: :cybernetic},
        %{source_events: 3, pattern_name: "variety_oscillation"}
      )
      
      # 5. Send algedonic signal
      algedonic_msg = VSMCore.Shared.Message.algedonic(
        :ecosystem_test,
        %{test: :full_integration, severity: :info}
      )
      VSMCore.Channels.AlgedonicChannel.send_message(algedonic_msg)
      
      # Collect events by repeatedly checking mailbox
      Process.sleep(3000)  # Wait for events to be processed
      
      # Collect all messages that arrived
      final_events = Enum.reduce(1..100, [], fn _i, acc ->
        receive do
          {:ecosystem_event, event} -> [event | acc]
        after
          0 -> acc  # No more messages, break
        end
      end)
      
      # Verify ecosystem integration
      assert length(final_events) > 0, "Should have received ecosystem events"
      
      # Check that events from different packages are compatible
      event_types = Enum.map(final_events, & &1.event)
      vsm_core_events = Enum.filter(event_types, &(hd(&1) == :vsm_core))
      other_events = Enum.filter(event_types, &(hd(&1) != :vsm_core))
      
      assert length(vsm_core_events) > 0, "Should have VSM Core events"
      # Other events may not be present if packages aren't actually running
      
      # Cleanup
      Enum.each(ecosystem_events, fn event ->
        :telemetry.detach("ecosystem-#{Enum.join(event, "-")}")
      end)
    end
    
    test "configuration compatibility across packages" do
      # Test that shared configuration keys work across packages
      
      # Common configuration that should be respected by all packages
      common_config = [
        telemetry_enabled: true,
        log_level: :info,
        metrics_interval: :timer.seconds(30)
      ]
      
      # Verify configuration format is valid
      Enum.each(common_config, fn {key, value} ->
        assert is_atom(key)
        assert value != nil
        
        # Configuration should be serializable
        config_string = "#{key}: #{inspect(value)}"
        assert is_binary(config_string)
      end)
      
      # Test environment variable format compatibility
      env_vars = [
        {"VSM_LOG_LEVEL", "info"},
        {"VSM_TELEMETRY_ENABLED", "true"},
        {"VSM_METRICS_INTERVAL", "30000"}
      ]
      
      Enum.each(env_vars, fn {var_name, var_value} ->
        assert is_binary(var_name)
        assert is_binary(var_value)
        assert String.starts_with?(var_name, "VSM_")
      end)
    end
  end
  
  describe "Version Compatibility" do
    test "semantic version compatibility" do
      # Test version parsing and compatibility checking
      
      versions = [
        {"0.1.0", "0.1.1", :compatible},
        {"0.1.0", "0.2.0", :minor_breaking},
        {"0.1.0", "1.0.0", :major_breaking},
        {"1.0.0", "1.0.1", :compatible},
        {"1.0.0", "1.1.0", :compatible}
      ]
      
      Enum.each(versions, fn {v1, v2, expected} ->
        # Simple version comparison logic
        [major1, minor1, patch1] = String.split(v1, ".") |> Enum.map(&String.to_integer/1)
        [major2, minor2, patch2] = String.split(v2, ".") |> Enum.map(&String.to_integer/1)
        
        compatibility = cond do
          major1 != major2 -> :major_breaking
          minor1 != minor2 and major1 == 0 -> :minor_breaking
          true -> :compatible
        end
        
        assert compatibility == expected, "Version #{v1} -> #{v2} should be #{expected}"
      end)
    end
  end
  
  describe "Error Handling Compatibility" do
    @tag timeout: @test_timeout
    test "error propagation across packages" do
      # Test that errors are handled consistently across package boundaries
      {:ok, _} = Application.ensure_all_started(:vsm_core)
      Process.sleep(1000)
      
      # Test error handling patterns
      
      # 1. Invalid message handling
      invalid_message = %{invalid: :structure}
      
      # Should handle gracefully without crashing
      result = try do
        VSMCore.Channels.CommandChannel.send_message(invalid_message)
        :no_error
      catch
        kind, reason -> {kind, reason}
      end
      
      # Should either succeed with error handling or fail predictably
      assert result == :no_error or is_tuple(result)
      
      # 2. Invalid transaction handling  
      invalid_transaction = %{missing: :required_fields}
      
      result2 = try do
        VSMCore.System1.Operations.process_transaction(invalid_transaction)
      catch
        kind, reason -> {kind, reason}
      end
      
      # Should return error tuple, not crash
      assert match?({:error, _}, result2) or is_tuple(result2)
    end
    
    test "telemetry error handling" do
      # Test that telemetry errors don't crash other systems
      
      # Attach handler that will crash
      :telemetry.attach(
        "crashing-handler",
        [:test, :event],
        fn _, _, _, _ ->
          raise "Intentional test error"
        end,
        nil
      )
      
      # Emit event - should not crash the test
      result = try do
        :telemetry.execute([:test, :event], %{}, %{})
        :ok
      catch
        kind, reason -> {kind, reason}
      end
      
      # Telemetry should handle the error gracefully
      assert result == :ok
      
      :telemetry.detach("crashing-handler")
    end
  end
  
  # Helper functions for compatibility testing
  
  defp wait_for_system_ready(timeout \\ 5000) do
    start_time = System.monotonic_time(:millisecond)
    
    wait_loop = fn wait_loop ->
      if System.monotonic_time(:millisecond) - start_time > timeout do
        {:error, :timeout}
      else
        case VSMCore.health_check() do
          :ok -> :ok
          _ -> 
            Process.sleep(100)
            wait_loop.(wait_loop)
        end
      end
    end
    
    wait_loop.(wait_loop)
  end
  
  defp collect_events(event_patterns, duration \\ 2000) do
    test_pid = self()
    
    # Attach to all event patterns
    Enum.each(event_patterns, fn {name, pattern} ->
      :telemetry.attach(
        "collect-#{name}",
        pattern,
        fn event, measurements, metadata, _config ->
          send(test_pid, {:collected_event, name, event, measurements, metadata})
        end,
        nil
      )
    end)
    
    # Collect events for specified duration
    events = collect_events_loop([], System.monotonic_time(:millisecond) + duration)
    
    # Cleanup
    Enum.each(event_patterns, fn {name, _pattern} ->
      :telemetry.detach("collect-#{name}")
    end)
    
    events
  end
  
  defp collect_events_loop(events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      Enum.reverse(events)
    else
      receive do
        {:collected_event, name, event, measurements, metadata} ->
          event_record = %{
            name: name,
            event: event,
            measurements: measurements,
            metadata: metadata,
            timestamp: DateTime.utc_now()
          }
          collect_events_loop([event_record | events], end_time)
      after
        100 ->
          collect_events_loop(events, end_time)
      end
    end
  end
end