defmodule VSMCore.System4.IntelligenceTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.System4.Intelligence
  alias VSMCore.{Message, Registry}
  
  setup do
    # Start Registry if not already started
    Registry.start_link(keys: :unique, name: VSMCore.Registry)
    
    # Start S4 Intelligence
    {:ok, intelligence} = Intelligence.start_link()
    
    # Allow processes to initialize
    Process.sleep(100)
    
    %{intelligence: intelligence}
  end
  
  describe "environmental scanning" do
    test "scans environment with given patterns" do
      patterns = [:market_conditions, :competitor_activity]
      
      {:ok, results} = Intelligence.scan_environment(patterns)
      
      assert Map.has_key?(results, :market_conditions)
      assert Map.has_key?(results, :competitor_activity)
      assert results[:market_conditions].pattern == :market_conditions
      assert is_float(results[:market_conditions].confidence)
    end
    
    test "detects threats and opportunities" do
      patterns = [:all]
      
      {:ok, results} = Intelligence.scan_environment(patterns)
      
      # Check that scanning produces findings
      assert Enum.any?(results, fn {_pattern, result} ->
        length(result.findings) > 0
      end)
    end
  end
  
  describe "trend analysis" do
    test "analyzes trends in provided data" do
      data = %{
        sales: %{
          values: [100, 110, 120, 115, 125, 130],
          timestamps: generate_timestamps(6)
        }
      }
      
      {:ok, trends} = Intelligence.analyze_trends(data, :daily)
      
      assert Map.has_key?(trends, :sales)
      assert trends[:sales].direction in [:increasing, :decreasing, :stable]
      assert is_float(trends[:sales].confidence)
    end
    
    test "identifies significant trends" do
      data = %{
        growth: %{
          values: [100, 120, 140, 160, 180, 200],
          timestamps: generate_timestamps(6)
        }
      }
      
      {:ok, trends} = Intelligence.analyze_trends(data, :daily)
      
      assert trends[:growth].significant == true
      assert trends[:growth].direction == :increasing
    end
  end
  
  describe "forecasting" do
    test "generates forecast for given model and horizon" do
      model = %{type: :time_series, parameters: %{}}
      horizon = 7
      
      {:ok, forecast} = Intelligence.forecast(model, horizon)
      
      assert forecast.method in [:time_series, :simple_linear]
      assert forecast.horizon == horizon
      assert length(forecast.forecast) == horizon
      assert Enum.all?(forecast.forecast, &Map.has_key?(&1, :value))
    end
    
    test "includes confidence intervals in forecast" do
      model = %{type: :time_series, parameters: %{}}
      horizon = 3
      
      {:ok, forecast} = Intelligence.forecast(model, horizon)
      
      first_period = List.first(forecast.forecast)
      assert Map.has_key?(first_period, :confidence_80)
      assert Map.has_key?(first_period, :confidence_95)
      assert first_period.confidence_80.lower < first_period.value
      assert first_period.confidence_80.upper > first_period.value
    end
  end
  
  describe "anomaly detection" do
    test "detects anomalies in data" do
      data = %{
        metrics: %{
          cpu_usage: 45,
          memory_usage: 70,
          disk_usage: 95,  # Anomaly
          network_latency: 20
        }
      }
      
      {:ok, anomalies} = Intelligence.detect_anomalies(data)
      
      assert is_list(anomalies)
      # Should detect high disk usage as potential anomaly
    end
    
    test "filters anomalies by significance" do
      data = %{
        market_data: %{
          volatility: 45,  # High volatility
          volume: 1_000_000
        }
      }
      
      {:ok, anomalies} = Intelligence.detect_anomalies(data)
      
      assert Enum.all?(anomalies, &(&1.confidence >= 0.7))
    end
  end
  
  describe "model building" do
    test "builds model of specified type" do
      data = %{
        training: generate_training_data()
      }
      
      {:ok, model} = Intelligence.build_model(data, :regression)
      
      assert model.type == :regression
      assert Map.has_key?(model, :parameters)
      assert Map.has_key?(model, :created_at)
    end
    
    test "supports multiple model types" do
      data = %{training: generate_training_data()}
      
      model_types = [:regression, :classification, :clustering, :time_series, :ensemble]
      
      results = Enum.map(model_types, fn type ->
        {:ok, model} = Intelligence.build_model(data, type)
        model.type
      end)
      
      assert results == model_types
    end
  end
  
  describe "intelligence reporting" do
    test "provides comprehensive intelligence report" do
      # Perform some operations first
      Intelligence.scan_environment([:market_conditions])
      Process.sleep(50)
      
      {:ok, report} = Intelligence.get_intelligence_report()
      
      assert Map.has_key?(report, :environment)
      assert Map.has_key?(report, :trends)
      assert Map.has_key?(report, :alerts)
      assert Map.has_key?(report, :models)
      assert is_list(report.alerts)
    end
  end
  
  describe "integration with channels" do
    test "sends alerts through algedonic channel for critical issues" do
      # This would require mocking the AlgedonicChannel
      # For now, we just ensure the function doesn't crash
      patterns = [:regulatory_changes]
      
      assert {:ok, _results} = Intelligence.scan_environment(patterns)
    end
    
    test "notifies S3 of strategic changes" do
      # This would require mocking the CommandChannel
      data = %{
        market_share: %{
          values: [30, 28, 25, 22, 20, 18],  # Declining trend
          timestamps: generate_timestamps(6)
        }
      }
      
      assert {:ok, _trends} = Intelligence.analyze_trends(data, :daily)
    end
  end
  
  # Helper functions
  
  defp generate_timestamps(count) do
    now = DateTime.utc_now()
    
    Enum.map(0..(count-1), fn i ->
      DateTime.add(now, -i * 86400, :second)
    end)
    |> Enum.reverse()
  end
  
  defp generate_training_data do
    %{
      features: %{
        feature1: Enum.map(1..100, fn _ -> :rand.uniform() end),
        feature2: Enum.map(1..100, fn _ -> :rand.uniform() * 10 end)
      },
      target: Enum.map(1..100, fn _ -> :rand.uniform() * 100 end)
    }
  end
end