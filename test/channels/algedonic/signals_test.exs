defmodule VSMCore.Channels.Algedonic.SignalsTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.Channels.Algedonic.Signals
  
  describe "signal creation" do
    test "creates valid pain signal" do
      signal = Signals.create_signal(:pain, :test_source, %{"metric" => "cpu", "value" => 95}, :high)
      
      assert signal.type == :pain
      assert signal.source == :test_source
      assert signal.severity == :high
      assert signal.data == %{"metric" => "cpu", "value" => 95}
      assert String.starts_with?(signal.id, "sig_")
      assert %DateTime{} = signal.timestamp
    end
    
    test "creates valid pleasure signal" do
      signal = Signals.create_signal(:pleasure, :test_source, %{"metric" => "sales", "value" => 150}, :medium)
      
      assert signal.type == :pleasure
      assert signal.severity == :medium
    end
    
    test "creates aggregated signal from pattern" do
      pattern = %{
        id: "pattern_123",
        type: :temporal,
        signal_ids: ["sig_1", "sig_2", "sig_3"],
        confidence: 0.85,
        significance: 0.92,
        details: %{window: 1}
      }
      
      signal = Signals.create_aggregated_signal(pattern)
      
      assert signal.type == :aggregated
      assert signal.pattern_id == "pattern_123"
      assert signal.severity == :critical  # High significance
      assert signal.data.confidence == 0.85
    end
  end
  
  describe "signal validation" do
    test "validates correct signal structure" do
      valid_signal = Signals.create_signal(:pain, :source, %{"data" => "value"}, :high)
      assert {:ok, ^valid_signal} = Signals.validate_signal(valid_signal)
    end
    
    test "rejects invalid signal type" do
      invalid_signal = %{
        id: "test",
        type: :invalid,
        source: :test,
        severity: :high,
        data: %{},
        timestamp: DateTime.utc_now()
      }
      
      assert {:error, :invalid_type} = Signals.validate_signal(invalid_signal)
    end
    
    test "rejects invalid severity" do
      invalid_signal = %{
        id: "test",
        type: :pain,
        source: :test,
        severity: :extreme,
        data: %{"test" => "data"},
        timestamp: DateTime.utc_now()
      }
      
      assert {:error, :invalid_severity} = Signals.validate_signal(invalid_signal)
    end
    
    test "rejects empty data" do
      invalid_signal = %{
        id: "test",
        type: :pain,
        source: :test,
        severity: :high,
        data: %{},
        timestamp: DateTime.utc_now()
      }
      
      assert {:error, :invalid_data} = Signals.validate_signal(invalid_signal)
    end
  end
  
  describe "emergency bypass detection" do
    test "critical signals require emergency bypass" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 100}, :critical)
      assert Signals.requires_emergency_bypass?(signal)
    end
    
    test "signals with emergency flag require bypass" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 50}, :medium)
      signal = %{signal | metadata: Map.put(signal.metadata, :emergency, true)}
      assert Signals.requires_emergency_bypass?(signal)
    end
    
    test "normal signals don't require bypass" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 50}, :medium)
      refute Signals.requires_emergency_bypass?(signal)
    end
  end
  
  describe "signal classification" do
    test "classifies urgent signals" do
      critical_signal = Signals.create_signal(:pain, :test, %{"value" => 95}, :critical)
      classifications = Signals.classify_signal(critical_signal)
      assert :urgent in classifications
    end
    
    test "classifies anomalous signals" do
      anomalous_signal = Signals.create_signal(:pain, :test, %{"value" => 95}, :high)
      classifications = Signals.classify_signal(anomalous_signal)
      assert :anomalous in classifications
    end
  end
  
  describe "priority calculation" do
    test "critical signals get highest priority" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 100}, :critical)
      priority = Signals.calculate_priority(signal)
      assert priority >= 100  # Max priority with adjustments
    end
    
    test "pain signals get priority boost" do
      pain_signal = Signals.create_signal(:pain, :test, %{"value" => 50}, :medium)
      pleasure_signal = Signals.create_signal(:pleasure, :test, %{"value" => 50}, :medium)
      
      pain_priority = Signals.calculate_priority(pain_signal)
      pleasure_priority = Signals.calculate_priority(pleasure_signal)
      
      assert pain_priority > pleasure_priority
    end
  end
  
  describe "signal filtering and grouping" do
    test "filters signals by criteria" do
      signals = [
        Signals.create_signal(:pain, :source1, %{"value" => 10}, :low),
        Signals.create_signal(:pain, :source2, %{"value" => 50}, :medium),
        Signals.create_signal(:pleasure, :source1, %{"value" => 80}, :high),
        Signals.create_signal(:pain, :source2, %{"value" => 90}, :critical)
      ]
      
      # Filter by type
      pain_signals = Signals.filter_signals(signals, type: :pain)
      assert length(pain_signals) == 3
      
      # Filter by severity
      high_severity = Signals.filter_signals(signals, severity: :high)
      assert length(high_severity) == 1
      
      # Filter by source
      source1_signals = Signals.filter_signals(signals, source: :source1)
      assert length(source1_signals) == 2
    end
    
    test "groups signals by attribute" do
      signals = [
        Signals.create_signal(:pain, :source1, %{"value" => 10}, :low),
        Signals.create_signal(:pain, :source2, %{"value" => 50}, :medium),
        Signals.create_signal(:pleasure, :source1, %{"value" => 80}, :high),
        Signals.create_signal(:pain, :source2, %{"value" => 90}, :low)
      ]
      
      # Group by type
      by_type = Signals.group_signals(signals, :type)
      assert map_size(by_type) == 2
      assert length(by_type[:pain]) == 3
      assert length(by_type[:pleasure]) == 1
      
      # Group by severity
      by_severity = Signals.group_signals(signals, :severity)
      assert length(by_severity[:low]) == 2
      assert length(by_severity[:medium]) == 1
      assert length(by_severity[:high]) == 1
    end
  end
  
  describe "signal enrichment" do
    test "enriches signal with metadata" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 75}, :high)
      context = %{region: "us-east", customer: "vip"}
      
      enriched = Signals.enrich_signal(signal, context)
      
      assert enriched.metadata.context == context
      assert is_list(enriched.metadata.classifications)
      assert is_number(enriched.metadata.priority)
      assert Map.has_key?(enriched.metadata, :enriched_at)
    end
  end
end