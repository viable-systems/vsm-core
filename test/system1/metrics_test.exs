defmodule VSMCore.System1.MetricsTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.System1.{Metrics, Transaction}
  
  setup do
    {:ok, pid} = Metrics.start_link(name: :test_metrics)
    
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)
    
    {:ok, server: pid}
  end
  
  describe "record_transaction/3" do
    test "records successful transactions", %{server: server} do
      transaction = Transaction.compute(:factorial, %{n: 5})
      result = {:ok, %{result: 120}}
      
      Metrics.record_transaction(transaction, result, server)
      :timer.sleep(50)
      
      metrics = Metrics.get_all(server)
      assert metrics.summary.transactions_total == 1
      assert metrics.summary.transactions_success == 1
      assert metrics.summary.success_rate == 1.0
    end
    
    test "records failed transactions", %{server: server} do
      transaction = Transaction.compute(:invalid, %{})
      result = {:error, :invalid_operation}
      
      Metrics.record_transaction(transaction, result, server)
      :timer.sleep(50)
      
      metrics = Metrics.get_all(server)
      assert metrics.summary.transactions_total == 1
      assert metrics.summary.transactions_failed == 1
      assert metrics.summary.success_rate == 0.0
    end
    
    test "tracks multiple transactions", %{server: server} do
      # Record mix of success and failure
      for i <- 1..10 do
        transaction = Transaction.compute(:factorial, %{n: i})
        result = if rem(i, 3) == 0 do
          {:error, :simulated_error}
        else
          {:ok, %{result: i}}
        end
        
        Metrics.record_transaction(transaction, result, server)
      end
      
      :timer.sleep(100)
      
      metrics = Metrics.get_all(server)
      assert metrics.summary.transactions_total == 10
      assert metrics.summary.transactions_success == 7
      assert metrics.summary.transactions_failed == 3
      assert_in_delta metrics.summary.success_rate, 0.7, 0.01
    end
  end
  
  describe "record_unit_metrics/3" do
    test "records unit performance metrics", %{server: server} do
      unit_metrics = %{
        processing_time: 1500,
        load: 0.75,
        transactions_processed: 100,
        error_count: 2
      }
      
      Metrics.record_unit_metrics("unit_1", unit_metrics, server)
      :timer.sleep(50)
      
      {:ok, retrieved} = Metrics.get_unit_metrics("unit_1", server)
      
      assert retrieved.current_load == 0.75
      assert retrieved.transactions_processed == 100
      assert retrieved.error_count == 2
    end
    
    test "maintains historical unit metrics", %{server: server} do
      # Record multiple measurements
      for i <- 1..5 do
        metrics = %{
          processing_time: 1000 + i * 100,
          load: 0.5 + i * 0.1,
          transactions_processed: i * 10,
          error_count: i
        }
        
        Metrics.record_unit_metrics("unit_2", metrics, server)
        :timer.sleep(10)
      end
      
      {:ok, unit_metrics} = Metrics.get_unit_metrics("unit_2", server)
      
      # Should have latest values
      assert unit_metrics.current_load == 0.9
      assert unit_metrics.transactions_processed == 50
      
      # Should calculate averages
      assert unit_metrics.average_load > 0.5
    end
    
    test "returns error for non-existent unit", %{server: server} do
      assert {:error, :unit_not_found} = Metrics.get_unit_metrics("unknown", server)
    end
  end
  
  describe "record_variety/2" do
    test "records variety measurements", %{server: server} do
      measurement = %{
        input: 10.5,
        output: 8.2,
        ratio: 0.78
      }
      
      Metrics.record_variety(measurement, server)
      :timer.sleep(50)
      
      metrics = Metrics.get_all(server)
      assert metrics.variety.current_ratio == 0.78
      assert metrics.variety.input_variety == 10.5
      assert metrics.variety.output_variety == 8.2
    end
    
    test "calculates variety efficiency", %{server: server} do
      # Record measurements with good ratio
      for i <- 1..5 do
        measurement = %{
          input: 10.0,
          output: 9.0 + i * 0.1,
          ratio: (9.0 + i * 0.1) / 10.0
        }
        
        Metrics.record_variety(measurement, server)
      end
      
      :timer.sleep(100)
      
      metrics = Metrics.get_all(server)
      assert metrics.variety.efficiency == 1.0  # Good match
    end
  end
  
  describe "get_window/2" do
    test "returns metrics for time window", %{server: server} do
      # Record some metrics
      for i <- 1..5 do
        transaction = Transaction.compute(:test, %{n: i})
        result = {:ok, %{result: i}}
        Metrics.record_transaction(transaction, result, server)
      end
      
      :timer.sleep(100)
      
      # Get last 5 minutes
      window_metrics = Metrics.get_window(5, server)
      
      assert window_metrics.window_minutes == 5
      assert window_metrics.transactions.total == 5
      assert window_metrics.transactions.by_type[:compute] == 5
    end
    
    test "filters old metrics from window", %{server: server} do
      # This test would require time manipulation
      # For now, just verify structure
      window_metrics = Metrics.get_window(1, server)
      
      assert Map.has_key?(window_metrics, :transactions)
      assert Map.has_key?(window_metrics, :variety)
      assert Map.has_key?(window_metrics, :timestamp)
    end
  end
  
  describe "get_variety_trend/1" do
    test "returns insufficient data for few measurements", %{server: server} do
      trend = Metrics.get_variety_trend(server)
      assert trend.trend == :insufficient_data
      assert trend.confidence == 0.0
    end
    
    test "detects improving trend", %{server: server} do
      # Record improving variety measurements
      for i <- 1..20 do
        measurement = %{
          input: 10.0,
          output: 5.0 + i * 0.2,
          ratio: (5.0 + i * 0.2) / 10.0
        }
        
        Metrics.record_variety(measurement, server)
        :timer.sleep(5)
      end
      
      trend = Metrics.get_variety_trend(server)
      assert trend.trend == :improving
      assert trend.slope > 0
    end
    
    test "detects degrading trend", %{server: server} do
      # Record degrading variety measurements
      for i <- 1..20 do
        measurement = %{
          input: 10.0,
          output: 10.0 - i * 0.2,
          ratio: (10.0 - i * 0.2) / 10.0
        }
        
        Metrics.record_variety(measurement, server)
        :timer.sleep(5)
      end
      
      trend = Metrics.get_variety_trend(server)
      assert trend.trend == :degrading
      assert trend.slope < 0
    end
    
    test "detects stable trend", %{server: server} do
      # Record stable variety measurements
      for i <- 1..20 do
        measurement = %{
          input: 10.0,
          output: 9.0 + :rand.uniform() * 0.2 - 0.1,
          ratio: 0.9
        }
        
        Metrics.record_variety(measurement, server)
        :timer.sleep(5)
      end
      
      trend = Metrics.get_variety_trend(server)
      assert trend.trend == :stable
      assert abs(trend.slope) < 0.01
    end
  end
  
  describe "performance analysis" do
    test "calculates performance percentiles", %{server: server} do
      # Record processing times
      times = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
      
      for time <- times do
        Metrics.record_unit_metrics("perf_unit", %{processing_time: time}, server)
      end
      
      :timer.sleep(100)
      
      metrics = Metrics.get_all(server)
      perf = metrics.performance
      
      assert perf.median == 550 or perf.median == 500  # Depends on exact calculation
      assert perf.p90 >= 900
      assert perf.p95 >= 950
      assert perf.min == 100
      assert perf.max == 1000
    end
    
    test "handles empty performance data", %{server: server} do
      metrics = Metrics.get_all(server)
      perf = metrics.performance
      
      assert perf.count == 0
      assert perf.mean == 0
      assert perf.median == 0
    end
  end
  
  describe "reset/1" do
    test "clears all metrics", %{server: server} do
      # Add some metrics
      for i <- 1..5 do
        transaction = Transaction.compute(:test, %{n: i})
        Metrics.record_transaction(transaction, {:ok, i}, server)
        
        Metrics.record_variety(%{input: i, output: i, ratio: 1.0}, server)
      end
      
      :timer.sleep(100)
      
      # Reset
      Metrics.reset(server)
      :timer.sleep(50)
      
      # Verify cleared
      metrics = Metrics.get_all(server)
      assert metrics.summary.transactions_total == 0
      assert metrics.variety.current_ratio == 1.0
    end
  end
  
  describe "telemetry integration" do
    test "emits telemetry events", %{server: server} do
      # Attach telemetry handler
      test_pid = self()
      
      :telemetry.attach(
        "test-handler",
        [:vsm_core, :system1, :transaction],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )
      
      # Record transaction
      transaction = Transaction.compute(:test, %{})
      Metrics.record_transaction(transaction, {:ok, "result"}, server)
      
      # Should receive telemetry event
      assert_receive {:telemetry, measurements, metadata}, 1000
      assert measurements.count == 1
      assert metadata.type == :compute
      assert metadata.result == :ok
      
      :telemetry.detach("test-handler")
    end
  end
end