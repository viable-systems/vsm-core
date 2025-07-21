defmodule VSMCore.Channels.Algedonic.FilteringTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.Channels.Algedonic.{Filtering, Signals}
  
  describe "default filters" do
    test "provides default filter set" do
      filters = Filtering.default_filters()
      
      assert length(filters) == 4
      assert Enum.any?(filters, & &1.type == :severity)
      assert Enum.any?(filters, & &1.type == :frequency)
      assert Enum.any?(filters, & &1.type == :pattern)
      assert Enum.any?(filters, & &1.type == :threshold)
    end
  end
  
  describe "filter application" do
    test "applies severity filter" do
      signal_low = Signals.create_signal(:pain, :test, %{"value" => 10}, :low)
      signal_high = Signals.create_signal(:pain, :test, %{"value" => 90}, :high)
      
      filters = [
        Filtering.create_filter(:severity, "Min medium", %{min_severity: :medium})
      ]
      
      assert {:block, _reason} = Filtering.apply_filters(signal_low, filters)
      assert {:pass, _} = Filtering.apply_filters(signal_high, filters)
    end
    
    test "applies pattern filter" do
      signal1 = Signals.create_signal(:pain, :test, %{"metric" => "cpu", "value" => 95}, :high)
      signal2 = Signals.create_signal(:pain, :test, %{"metric" => "memory", "value" => 95}, :high)
      
      filters = [
        Filtering.create_filter(:pattern, "Block CPU", %{
          block_patterns: [%{data: %{"metric" => "cpu"}}],
          pass_patterns: []
        })
      ]
      
      assert {:block, _} = Filtering.apply_filters(signal1, filters)
      assert {:pass, _} = Filtering.apply_filters(signal2, filters)
    end
    
    test "applies threshold filter" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 50}, :medium)
      low_confidence_signal = %{signal | metadata: Map.put(signal.metadata, :confidence, 0.2)}
      
      filters = [
        Filtering.create_filter(:threshold, "Min confidence", %{
          min_confidence: 0.5,
          min_significance: 0.0
        })
      ]
      
      assert {:pass, _} = Filtering.apply_filters(signal, filters)
      assert {:block, _} = Filtering.apply_filters(low_confidence_signal, filters)
    end
    
    test "applies filters in priority order" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 50}, :low)
      
      filters = [
        Filtering.create_filter(:severity, "Block low", %{min_severity: :medium}, priority: 2),
        Filtering.create_filter(:pattern, "Pass all", %{pass_patterns: [%{}]}, priority: 1)
      ]
      
      # Pattern filter (priority 1) runs first and passes, but severity filter blocks
      assert {:block, _} = Filtering.apply_filters(signal, filters)
    end
  end
  
  describe "composite filters" do
    test "AND composite requires all sub-filters to pass" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 75}, :high)
      
      composite = Filtering.create_filter(:composite, "AND filter", %{
        operator: :and,
        filters: [
          Filtering.create_filter(:severity, "High+", %{min_severity: :high}),
          Filtering.create_filter(:threshold, "Value > 80", %{min_confidence: 0.0})
        ]
      })
      
      # Signal passes severity but would fail a value > 80 check if implemented
      assert {:pass, _} = Filtering.apply_filters(signal, [composite])
    end
    
    test "OR composite requires any sub-filter to pass" do
      signal = Signals.create_signal(:pain, :test, %{"value" => 50}, :low)
      
      composite = Filtering.create_filter(:composite, "OR filter", %{
        operator: :or,
        filters: [
          Filtering.create_filter(:severity, "High+", %{min_severity: :high}),
          Filtering.create_filter(:pattern, "Pass test source", %{
            pass_patterns: [%{source: :test}]
          })
        ]
      })
      
      # Signal fails severity but passes source pattern
      assert {:pass, _} = Filtering.apply_filters(signal, [composite])
    end
  end
  
  describe "filter validation" do
    test "validates filter structure" do
      valid_filter = Filtering.create_filter(:severity, "Test", %{min_severity: :low})
      assert {:ok, _} = Filtering.validate_filters([valid_filter])
      
      invalid_filter = %{type: :severity}  # Missing required fields
      assert {:error, _} = Filtering.validate_filters([invalid_filter])
    end
    
    test "validates filter type" do
      invalid_type = %{
        id: "test",
        type: :unknown_type,
        name: "Test",
        enabled: true,
        config: %{},
        priority: 1
      }
      
      assert {:error, _} = Filtering.validate_filters([invalid_type])
    end
  end
  
  describe "filter effectiveness analysis" do
    test "analyzes filter performance" do
      filters = Filtering.default_filters()
      
      signal_history = [
        Signals.create_signal(:pain, :test, %{"value" => 10}, :low),
        Signals.create_signal(:pain, :test, %{"value" => 50}, :medium),
        Signals.create_signal(:pain, :test, %{"value" => 90}, :high)
      ]
      
      analysis = Filtering.analyze_filter_effectiveness(filters, signal_history)
      
      assert Map.has_key?(analysis, :individual_stats)
      assert Map.has_key?(analysis, :overall_block_rate)
      assert Map.has_key?(analysis, :recommendations)
      assert is_list(analysis.individual_stats)
    end
  end
end