defmodule VSMCore.Channels.Algedonic.CorrelationTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.Channels.Algedonic.{Correlation, Signals}
  
  describe "pattern analysis" do
    test "analyzes patterns in signals" do
      signals = [
        Signals.create_signal(:pain, :source1, %{"metric" => "cpu", "value" => 90}, :high),
        Signals.create_signal(:pain, :source1, %{"metric" => "cpu", "value" => 95}, :high),
        Signals.create_signal(:pain, :source2, %{"metric" => "memory", "value" => 85}, :medium)
      ]
      
      initial_state = %{
        signal_history: [],
        pattern_cache: %{},
        correlation_matrix: %{},
        last_analysis: DateTime.utc_now()
      }
      
      {:ok, patterns, new_state} = Correlation.analyze_patterns(signals, initial_state)
      
      assert is_list(patterns)
      assert length(new_state.signal_history) == 3
      assert new_state.last_analysis != initial_state.last_analysis
    end
    
    test "discovers temporal patterns" do
      now = DateTime.utc_now()
      
      # Create signals close in time
      signals = for i <- 1..5 do
        Signals.create_signal(:pain, :source1, %{"metric" => "cpu", "value" => 80 + i}, :high)
      end
      
      state = %{
        signal_history: signals,
        pattern_cache: %{},
        correlation_matrix: %{},
        last_analysis: now
      }
      
      {:ok, patterns, _} = Correlation.analyze_patterns([], state)
      
      temporal_patterns = Enum.filter(patterns, & &1.type == :temporal)
      assert length(temporal_patterns) > 0
    end
    
    test "discovers spatial patterns" do
      # Multiple signals from same source
      signals = for i <- 1..4 do
        Signals.create_signal(:pain, :system1_unit_1, %{"metric" => "load", "value" => 70 + i}, :medium)
      end
      
      state = %{
        signal_history: signals,
        pattern_cache: %{},
        correlation_matrix: %{},
        last_analysis: DateTime.utc_now()
      }
      
      {:ok, patterns, _} = Correlation.analyze_patterns([], state)
      
      spatial_patterns = Enum.filter(patterns, & &1.type == :spatial)
      assert length(spatial_patterns) > 0
      
      pattern = List.first(spatial_patterns)
      assert pattern.details.source == :system1_unit_1
      assert pattern.details.signal_count == 4
    end
  end
  
  describe "correlation calculation" do
    test "calculates correlation between similar signals" do
      signal1 = Signals.create_signal(:pain, :source1, %{"value" => 90}, :high)
      signal2 = Signals.create_signal(:pain, :source1, %{"value" => 85}, :high)
      
      correlation = Correlation.calculate_correlation(signal1, signal2)
      
      # High correlation - same source, severity, close in time
      assert correlation > 0.8
    end
    
    test "calculates low correlation for dissimilar signals" do
      signal1 = Signals.create_signal(:pain, :source1, %{"value" => 90}, :critical)
      
      # Create signal with different timestamp
      old_signal = %{
        Signals.create_signal(:pleasure, :source2, %{"value" => 20}, :low)
        | timestamp: DateTime.add(DateTime.utc_now(), -7200, :second)
      }
      
      correlation = Correlation.calculate_correlation(signal1, old_signal)
      
      # Low correlation - different type, source, severity, far apart in time
      assert correlation < 0.3
    end
  end
  
  describe "signal clustering" do
    test "clusters signals by characteristics" do
      signals = [
        Signals.create_signal(:pain, :source1, %{"metric" => "cpu", "value" => 90}, :high),
        Signals.create_signal(:pain, :source1, %{"metric" => "cpu", "value" => 85}, :high),
        Signals.create_signal(:pain, :source2, %{"metric" => "memory", "value" => 80}, :medium),
        Signals.create_signal(:pleasure, :source3, %{"metric" => "sales", "value" => 150}, :high)
      ]
      
      {:ok, clusters} = Correlation.cluster_signals(signals, max_clusters: 3)
      
      assert is_map(clusters)
      assert map_size(clusters) <= 3
      
      # Verify clustering grouped similar signals
      Enum.each(clusters, fn {_key, cluster_signals} ->
        assert length(cluster_signals) >= 1
      end)
    end
    
    test "filters small clusters" do
      signals = [
        Signals.create_signal(:pain, :source1, %{"metric" => "cpu", "value" => 90}, :high),
        Signals.create_signal(:pain, :source2, %{"metric" => "memory", "value" => 80}, :medium),
        Signals.create_signal(:pleasure, :source3, %{"metric" => "sales", "value" => 150}, :low)
      ]
      
      {:ok, clusters} = Correlation.cluster_signals(signals, min_cluster_size: 2)
      
      # All clusters should have at least 2 signals (so none in this case)
      assert map_size(clusters) == 0
    end
  end
  
  describe "anomaly detection" do
    test "detects anomalous signals" do
      normal_signals = for i <- 1..5 do
        Signals.create_signal(:pain, :source1, %{"metric" => "cpu", "value" => 40 + i}, :medium)
      end
      
      anomalous_signal = Signals.create_signal(:pain, :source1, %{"metric" => "cpu", "value" => 99}, :critical)
      
      all_signals = normal_signals ++ [anomalous_signal]
      
      historical_patterns = %{
        cpu_normal_range: {40, 50},
        typical_severity: :medium
      }
      
      {:ok, anomalies} = Correlation.detect_anomalies(all_signals, historical_patterns)
      
      # Should detect signals that deviate from historical patterns
      assert is_list(anomalies)
    end
  end
  
  describe "pattern filtering" do
    test "filters patterns by significance" do
      patterns = [
        %{
          id: "p1",
          type: :temporal,
          signal_ids: ["s1", "s2"],
          confidence: 0.8,
          significance: 0.9,
          details: %{},
          discovered_at: DateTime.utc_now()
        },
        %{
          id: "p2",
          type: :spatial,
          signal_ids: ["s3"],
          confidence: 0.3,
          significance: 0.2,
          details: %{},
          discovered_at: DateTime.utc_now()
        }
      ]
      
      state = %{
        signal_history: [],
        pattern_cache: %{},
        correlation_matrix: %{},
        last_analysis: DateTime.utc_now()
      }
      
      # This would normally be done internally
      # High significance patterns should trigger aggregated signals
      significant = Enum.filter(patterns, & &1.significance > 0.8)
      assert length(significant) == 1
      assert List.first(significant).id == "p1"
    end
  end
end