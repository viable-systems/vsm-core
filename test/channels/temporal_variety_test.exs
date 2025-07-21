defmodule VSMCore.Channels.TemporalVarietyTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.Channels.TemporalVariety
  alias VSMCore.Channels.Temporal.{
    Timescales,
    Patterns,
    Forecasting,
    Causality,
    Aggregation,
    Visualization
  }
  
  describe "TemporalVariety" do
    setup do
      {:ok, pid} = TemporalVariety.start_link()
      %{pid: pid}
    end
    
    test "records variety measurements", %{pid: _pid} do
      measurement = %{
        "users" => 100,
        "products" => 50,
        "orders" => 25
      }
      
      assert :ok = TemporalVariety.record_variety(measurement)
    end
    
    test "retrieves variety by timescale", %{pid: _pid} do
      # Record some measurements
      for _ <- 1..10 do
        measurement = %{
          "metric_a" => :rand.uniform(100),
          "metric_b" => :rand.uniform(50)
        }
        TemporalVariety.record_variety(measurement)
        Process.sleep(10)
      end
      
      {:ok, metrics} = TemporalVariety.get_variety(:real_time)
      assert is_list(metrics)
    end
    
    test "detects patterns", %{pid: _pid} do
      # Generate pattern data
      for i <- 1..50 do
        # Create cyclic pattern
        value = 50 + 30 * :math.sin(i * :math.pi() / 10)
        measurement = %{"cyclic_metric" => round(value)}
        TemporalVariety.record_variety(measurement)
        Process.sleep(5)
      end
      
      {:ok, patterns} = TemporalVariety.get_patterns()
      assert is_map(patterns)
    end
    
    test "generates forecasts", %{pid: _pid} do
      # Record historical data
      for i <- 1..20 do
        measurement = %{"forecast_metric" => i * 10 + :rand.uniform(10)}
        TemporalVariety.record_variety(measurement)
      end
      
      {:ok, forecasts} = TemporalVariety.get_forecasts([10, 30, 60])
      assert Map.has_key?(forecasts, 10)
      assert Map.has_key?(forecasts, 30)
      assert Map.has_key?(forecasts, 60)
    end
    
    test "analyzes causality", %{pid: _pid} do
      # Create causal relationship
      for i <- 1..30 do
        cause = i * 5
        effect = cause * 2 + :rand.uniform(5)
        
        measurement = %{
          "cause_metric" => cause,
          "effect_metric" => effect
        }
        TemporalVariety.record_variety(measurement)
      end
      
      {:ok, causality} = TemporalVariety.get_causality()
      assert Map.has_key?(causality, :causal_chains)
      assert Map.has_key?(causality, :correlations)
    end
    
    test "generates summary", %{pid: _pid} do
      # Add varied data
      for _ <- 1..15 do
        measurement = %{
          "summary_a" => :rand.uniform(100),
          "summary_b" => :rand.uniform(50),
          "summary_c" => :rand.uniform(25)
        }
        TemporalVariety.record_variety(measurement)
      end
      
      {:ok, summary} = TemporalVariety.get_summary()
      assert Map.has_key?(summary, :overview)
      assert Map.has_key?(summary, :timescale_summaries)
      assert Map.has_key?(summary, :dimensional_breakdown)
    end
    
    test "prepares visualization data", %{pid: _pid} do
      # Add data for visualization
      for i <- 1..25 do
        measurement = %{
          "viz_metric" => 50 + 20 * :math.sin(i / 5)
        }
        TemporalVariety.record_variety(measurement)
      end
      
      {:ok, viz_data} = TemporalVariety.get_visualization_data(type: :time_series)
      assert viz_data.type == :time_series
      assert Map.has_key?(viz_data, :series)
      assert Map.has_key?(viz_data, :metadata)
    end
  end
  
  describe "Timescales" do
    test "initializes timescale windows" do
      timescales = Timescales.initialize()
      
      assert Map.has_key?(timescales, :real_time)
      assert Map.has_key?(timescales, :minute)
      assert Map.has_key?(timescales, :hour)
      assert Map.has_key?(timescales, :day)
      assert Map.has_key?(timescales, :week)
      assert Map.has_key?(timescales, :month)
    end
    
    test "updates windows with new metrics" do
      timescales = Timescales.initialize()
      
      metric = %{
        timestamp: DateTime.utc_now(),
        value: 5.5,
        dimensions: %{"test" => 10},
        confidence: 0.9
      }
      
      updated = Timescales.update(timescales, metric)
      
      assert Map.has_key?(updated, :real_time)
      assert length(updated.real_time.data) == 1
    end
    
    test "calculates cross-scale analysis" do
      timescales = Timescales.initialize()
      
      # Add data
      for i <- 1..50 do
        metric = %{
          timestamp: DateTime.utc_now(),
          value: i * 1.5,
          dimensions: %{},
          confidence: 0.95
        }
        timescales = Timescales.update(timescales, metric)
        Process.sleep(10)
      end
      
      analysis = Timescales.cross_scale_analysis(timescales)
      
      assert Map.has_key?(analysis, :alignment)
      assert Map.has_key?(analysis, :propagation)
      assert Map.has_key?(analysis, :coherence)
    end
  end
  
  describe "Patterns" do
    test "detects cyclic patterns" do
      # Generate cyclic data
      data = for i <- 0..99 do
        %{
          timestamp: DateTime.add(DateTime.utc_now(), i * 60, :second),
          value: 50 + 25 * :math.sin(2 * :math.pi() * i / 24),
          dimensions: %{}
        }
      end
      
      patterns = Patterns.detect_cycles(data)
      
      assert length(patterns) > 0
      assert Enum.any?(patterns, fn p -> p.type == :cyclic end)
    end
    
    test "detects trend patterns" do
      # Generate trending data
      data = for i <- 0..49 do
        %{
          timestamp: DateTime.add(DateTime.utc_now(), i * 60, :second),
          value: 10 + i * 2 + :rand.uniform() * 5,
          dimensions: %{}
        }
      end
      
      patterns = Patterns.detect_trends(data)
      
      assert length(patterns) > 0
      assert Enum.any?(patterns, fn p -> p.type == :trend end)
    end
    
    test "detects anomalies" do
      # Generate data with anomalies
      data = for i <- 0..49 do
        value = if i in [15, 30, 45] do
          150 + :rand.uniform(50)  # Anomalies
        else
          50 + :rand.uniform(10)   # Normal
        end
        
        %{
          timestamp: DateTime.add(DateTime.utc_now(), i * 60, :second),
          value: value,
          dimensions: %{}
        }
      end
      
      anomalies = Patterns.detect_anomalies(data)
      
      assert length(anomalies) > 0
      assert Enum.any?(anomalies, fn a -> a.type == :anomaly end)
    end
    
    test "analyzes comprehensive patterns" do
      timescales = Timescales.initialize()
      
      # Add varied data
      for i <- 0..99 do
        metric = %{
          timestamp: DateTime.add(DateTime.utc_now(), i * 30, :second),
          value: 50 + 20 * :math.sin(i / 10) + i * 0.5,
          dimensions: %{"test" => i},
          confidence: 0.9
        }
        timescales = Timescales.update(timescales, metric)
      end
      
      result = Patterns.analyze(timescales)
      
      assert Map.has_key?(result, :patterns)
      assert Map.has_key?(result, :dominant_pattern)
      assert Map.has_key?(result, :pattern_strength)
      assert Map.has_key?(result, :next_expected)
    end
  end
  
  describe "Forecasting" do
    test "generates forecasts for multiple horizons" do
      timescales = setup_timescales_with_data()
      
      forecasts = Forecasting.generate_forecasts(timescales, [10, 30, 60])
      
      assert Map.has_key?(forecasts, 10)
      assert Map.has_key?(forecasts, 30)
      assert Map.has_key?(forecasts, 60)
      
      # Check forecast structure
      if length(forecasts[10]) > 0 do
        forecast = List.first(forecasts[10])
        assert Map.has_key?(forecast, :timestamp)
        assert Map.has_key?(forecast, :value)
        assert Map.has_key?(forecast, :confidence_interval)
        assert Map.has_key?(forecast, :method)
      end
    end
    
    test "detects anomalies from forecasts" do
      actual_data = for i <- 0..19 do
        %{
          timestamp: DateTime.add(DateTime.utc_now(), i * 60, :second),
          value: if(i == 10, do: 100, else: 50 + :rand.uniform(10))
        }
      end
      
      forecasts = for i <- 0..19 do
        %{
          timestamp: DateTime.add(DateTime.utc_now(), i * 60, :second),
          value: 55.0,
          confidence_interval: {45.0, 65.0},
          method: :test
        }
      end
      
      anomalies = Forecasting.detect_anomalies(actual_data, forecasts)
      
      assert length(anomalies) > 0
      assert Enum.any?(anomalies, fn a -> a.severity > 2.0 end)
    end
    
    test "generates ensemble forecasts" do
      timescales = setup_timescales_with_data()
      
      forecasts = Forecasting.ensemble_forecast(timescales, 20)
      
      assert is_list(forecasts)
      if length(forecasts) > 0 do
        assert List.first(forecasts).method == :ensemble
      end
    end
  end
  
  describe "Causality" do
    test "performs Granger causality test" do
      # Create two related time series
      series_x = for i <- 0..49, do: i + :rand.uniform() * 5
      series_y = for i <- 0..49, do: i * 1.5 + Enum.at(series_x, max(0, i-2), 0) * 0.5
      
      result = Causality.granger_causality_test(series_x, series_y)
      
      assert Map.has_key?(result, :causality)
      assert Map.has_key?(result, :f_statistic)
      assert Map.has_key?(result, :p_value)
      assert Map.has_key?(result, :optimal_lag)
    end
    
    test "calculates transfer entropy" do
      source = for _ <- 0..99, do: :rand.uniform()
      target = for i <- 0..99, do: 
        if i > 0, do: Enum.at(source, i-1) * 0.7 + :rand.uniform() * 0.3, else: :rand.uniform()
      
      te = Causality.transfer_entropy(source, target)
      
      assert is_float(te)
      assert te >= 0
    end
    
    test "builds causal graph" do
      links = [
        %{from: :a, to: :b, strength: 0.8, lag: 1, confidence: 0.9, type: :strong_causal},
        %{from: :b, to: :c, strength: 0.6, lag: 2, confidence: 0.7, type: :granger_causal},
        %{from: :a, to: :c, strength: 0.4, lag: 3, confidence: 0.5, type: :weak_association}
      ]
      
      graph = Causality.build_causal_graph(links)
      
      assert Map.has_key?(graph, :nodes)
      assert Map.has_key?(graph, :edges)
      assert Map.has_key?(graph, :adjacency)
      assert Map.has_key?(graph, :root_causes)
      assert Map.has_key?(graph, :terminal_effects)
    end
  end
  
  describe "Aggregation" do
    test "generates comprehensive summary" do
      state = %{
        timescales: setup_timescales_with_data(),
        patterns: %{patterns: []},
        forecasts: %{},
        causal_chains: [],
        buffer: generate_buffer_data()
      }
      
      summary = Aggregation.generate_summary(state)
      
      assert Map.has_key?(summary, :overview)
      assert Map.has_key?(summary, :timescale_summaries)
      assert Map.has_key?(summary, :pattern_summary)
      assert Map.has_key?(summary, :dimensional_breakdown)
    end
    
    test "performs hierarchical aggregation" do
      timescales = setup_timescales_with_data()
      
      result = Aggregation.hierarchical_aggregation(timescales)
      
      assert Map.has_key?(result, :hierarchy)
      assert Map.has_key?(result, :roll_up_metrics)
      assert Map.has_key?(result, :consistency_score)
    end
    
    test "creates time-based summary" do
      state = %{
        buffer: generate_buffer_data(),
        patterns: %{patterns: []},
        forecasts: %{anomalies: []}
      }
      
      start_time = DateTime.add(DateTime.utc_now(), -3600, :second)
      end_time = DateTime.utc_now()
      
      summary = Aggregation.time_based_summary(state, start_time, end_time)
      
      assert Map.has_key?(summary, :period)
      assert Map.has_key?(summary, :metrics)
      assert summary.start_time == start_time
      assert summary.end_time == end_time
    end
  end
  
  describe "Visualization" do
    test "prepares time series data" do
      state = %{
        timescales: setup_timescales_with_data(),
        patterns: %{patterns: []},
        forecasts: %{anomalies: []},
        buffer: []
      }
      
      viz_data = Visualization.prepare_data(state, type: :time_series)
      
      assert viz_data.type == :time_series
      assert Map.has_key?(viz_data, :series)
      assert Map.has_key?(viz_data, :annotations)
      assert is_list(viz_data.series)
    end
    
    test "prepares heatmap data" do
      state = %{buffer: generate_buffer_data()}
      
      viz_data = Visualization.prepare_data(state, type: :heatmap)
      
      assert viz_data.type == :heatmap
      assert Map.has_key?(viz_data, :data)
      assert Map.has_key?(viz_data, :metadata)
    end
    
    test "prepares network data" do
      chains = [
        %{
          id: "chain_1",
          root_cause: :metric_a,
          effects: [:metric_b, :metric_c],
          links: [
            %{from: :metric_a, to: :metric_b, strength: 0.8, lag: 1},
            %{from: :metric_b, to: :metric_c, strength: 0.6, lag: 2}
          ],
          total_lag: 3
        }
      ]
      
      state = %{causal_chains: chains}
      
      viz_data = Visualization.prepare_data(state, type: :network)
      
      assert viz_data.type == :network
      assert Map.has_key?(viz_data, :nodes)
      assert Map.has_key?(viz_data, :edges)
      assert length(viz_data.nodes) == 3
      assert length(viz_data.edges) == 2
    end
    
    test "prepares dashboard data" do
      state = %{
        timescales: setup_timescales_with_data(),
        patterns: %{patterns: []},
        forecasts: %{anomalies: []},
        buffer: []
      }
      
      viz_data = Visualization.prepare_data(state, type: :dashboard)
      
      assert viz_data.type == :dashboard
      assert Map.has_key?(viz_data, :current_metrics)
      assert Map.has_key?(viz_data, :trend_indicators)
      assert Map.has_key?(viz_data, :mini_charts)
      assert Map.has_key?(viz_data, :alerts)
    end
  end
  
  # Helper functions
  
  defp setup_timescales_with_data do
    timescales = Timescales.initialize()
    
    # Add data to timescales
    for i <- 0..49 do
      metric = %{
        timestamp: DateTime.add(DateTime.utc_now(), i * 60, :second),
        value: 50 + 20 * :math.sin(i / 5) + :rand.uniform() * 10,
        dimensions: %{"test" => i},
        confidence: 0.9
      }
      timescales = Timescales.update(timescales, metric)
    end
    
    timescales
  end
  
  defp generate_buffer_data do
    for i <- 0..99 do
      %{
        timestamp: DateTime.add(DateTime.utc_now(), -i * 60, :second),
        value: 50 + :rand.uniform() * 50,
        dimensions: %{
          "dim_a" => :rand.uniform(100),
          "dim_b" => :rand.uniform(50),
          "dim_c" => :rand.uniform(25)
        },
        confidence: 0.8 + :rand.uniform() * 0.2
      }
    end
  end
end