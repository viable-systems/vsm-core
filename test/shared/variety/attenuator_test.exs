defmodule VsmCore.Shared.Variety.AttenuatorTest do
  use ExUnit.Case, async: true
  alias VsmCore.Shared.Variety.Attenuator

  describe "suggest_methods/1" do
    test "suggests methods for high variety ratio" do
      methods = Attenuator.suggest_methods(15.0)
      assert methods == [:categorize, :aggregate, :filter]
    end

    test "suggests methods for moderate variety ratio" do
      methods = Attenuator.suggest_methods(3.0)
      assert methods == [:summarize, :filter, :sample]
    end

    test "suggests minimal methods for low variety ratio" do
      methods = Attenuator.suggest_methods(1.2)
      assert methods == [:filter]
    end
  end

  describe "filter/3 with :threshold strategy" do
    test "filters values above threshold" do
      items = [1, 2, 3, 4, 5]
      result = Attenuator.filter(items, :threshold, threshold: 3, operator: :gt)
      assert result == [4, 5]
    end

    test "filters with custom value function" do
      items = [%{val: 1}, %{val: 5}, %{val: 3}]
      result = Attenuator.filter(items, :threshold, 
        threshold: 3, 
        value_fn: & &1.val
      )
      assert result == [%{val: 5}]
    end

    test "supports different operators" do
      items = [1, 2, 3, 4, 5]
      
      assert Attenuator.filter(items, :threshold, threshold: 3, operator: :gte) == [3, 4, 5]
      assert Attenuator.filter(items, :threshold, threshold: 3, operator: :lt) == [1, 2]
      assert Attenuator.filter(items, :threshold, threshold: 3, operator: :eq) == [3]
    end
  end

  describe "filter/3 with :priority strategy" do
    test "keeps highest priority items" do
      items = [
        %{name: "A", priority: 1},
        %{name: "B", priority: 5},
        %{name: "C", priority: 3}
      ]
      
      result = Attenuator.filter(items, :priority, limit: 2)
      assert length(result) == 2
      assert hd(result).name == "B"
    end
  end

  describe "filter/3 with :frequency strategy" do
    test "keeps most frequent items" do
      items = ["a", "b", "a", "c", "a", "b"]
      result = Attenuator.filter(items, :frequency, limit: 2)
      
      assert "a" in result
      assert "b" in result
      assert not ("c" in result)
    end

    test "keeps least frequent items when specified" do
      items = ["a", "b", "a", "c", "a", "b"]
      result = Attenuator.filter(items, :frequency, limit: 1, most_frequent: false)
      
      assert result == ["c"]
    end
  end

  describe "filter/3 with :recency strategy" do
    test "keeps most recent items" do
      now = System.system_time(:millisecond)
      items = [
        %{id: 1, timestamp: now - 1000},
        %{id: 2, timestamp: now},
        %{id: 3, timestamp: now - 2000}
      ]
      
      result = Attenuator.filter(items, :recency, limit: 2)
      assert length(result) == 2
      assert hd(result).id == 2
    end
  end

  describe "aggregate/3" do
    test "calculates sum" do
      items = [1, 2, 3, 4, 5]
      assert Attenuator.aggregate(items, :sum) == 15
    end

    test "calculates average" do
      items = [2, 4, 6, 8]
      assert Attenuator.aggregate(items, :average) == 5.0
    end

    test "finds max and min" do
      items = [1, 5, 3, 2, 4]
      assert Attenuator.aggregate(items, :max) == 5
      assert Attenuator.aggregate(items, :min) == 1
    end

    test "finds mode" do
      items = [1, 2, 2, 3, 2, 4]
      assert Attenuator.aggregate(items, :mode) == 2
    end

    test "calculates weighted average" do
      items = [
        %{value: 10, weight: 1},
        %{value: 20, weight: 2},
        %{value: 30, weight: 1}
      ]
      
      result = Attenuator.aggregate(items, :weighted,
        value_fn: & &1.value,
        weight_fn: & &1.weight
      )
      
      assert result == 20.0  # (10*1 + 20*2 + 30*1) / (1+2+1)
    end
  end

  describe "summarize/3" do
    test "generates statistics summary" do
      items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      result = Attenuator.summarize(items, :statistics)
      
      assert result.count == 10
      assert result.min == 1
      assert result.max == 10
      assert result.mean == 5.5
      assert result.median == 5.5
      assert result.std_dev > 0
      assert result.percentiles.p50 == result.median
    end

    test "generates category summary" do
      items = [
        %{category: :a, value: 10},
        %{category: :a, value: 20},
        %{category: :b, value: 30}
      ]
      
      result = Attenuator.summarize(items, :categories,
        value_fn: & &1.value
      )
      
      assert result[:a].count == 2
      assert result[:a].total_value == 30
      assert_in_delta result[:a].percentage, 66.67, 0.01
    end

    test "generates time series summary" do
      now = System.system_time(:millisecond)
      items = [
        %{timestamp: now, value: 10},
        %{timestamp: now + 1000, value: 20},
        %{timestamp: now + 3_600_000, value: 30}
      ]
      
      result = Attenuator.summarize(items, :time_series,
        interval: :hour
      )
      
      assert length(result) == 2
      assert {_time, data} = hd(result)
      assert Map.has_key?(data, :value)
      assert Map.has_key?(data, :count)
    end
  end

  describe "sample/3" do
    test "random sampling" do
      items = Enum.to_list(1..100)
      result = Attenuator.sample(items, :random, size: 10)
      
      assert length(result) == 10
      assert Enum.all?(result, & &1 in items)
    end

    test "systematic sampling" do
      items = Enum.to_list(1..20)
      result = Attenuator.sample(items, :systematic, size: 5)
      
      assert length(result) == 5
      # Should take every 4th item
      assert result == [1, 5, 9, 13, 17]
    end

    test "stratified sampling" do
      items = [
        %{type: :a, value: 1},
        %{type: :a, value: 2},
        %{type: :b, value: 3},
        %{type: :b, value: 4}
      ]
      
      result = Attenuator.sample(items, :stratified,
        stratum_fn: & &1.type,
        size: 2
      )
      
      assert length(result) == 2
      types = Enum.map(result, & &1.type)
      assert :a in types
      assert :b in types
    end
  end

  describe "categorize/3" do
    test "categorizes by rules" do
      items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      
      rules = [
        {:small, &(&1 <= 3)},
        {:medium, &(&1 > 3 and &1 <= 7)},
        {:large, &(&1 > 7)}
      ]
      
      result = Attenuator.categorize(items, :rules, rules: rules)
      
      assert result[:small] == [1, 2, 3]
      assert result[:medium] == [4, 5, 6, 7]
      assert result[:large] == [8, 9, 10]
    end

    test "categorizes by quantiles" do
      items = Enum.to_list(1..20)
      result = Attenuator.categorize(items, :quantiles, buckets: 4)
      
      assert Map.has_key?(result, "Q1")
      assert Map.has_key?(result, "Q2")
      assert Map.has_key?(result, "Q3")
      assert Map.has_key?(result, "Q4")
      
      # Each quantile should have roughly equal items
      assert length(result["Q1"]) == 5
      assert length(result["Q4"]) == 5
    end
  end
end