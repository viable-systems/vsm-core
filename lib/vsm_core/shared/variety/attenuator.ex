defmodule VSMCore.Shared.Variety.Attenuator do
  @moduledoc """
  Implements variety attenuation strategies for managing excessive complexity.
  
  Attenuators reduce variety through filtering, aggregation, and summarization
  to prevent system overload while preserving essential information.
  """
  
  @type attenuation_method :: :filter | :aggregate | :summarize | :sample | :categorize
  
  @type filter_strategy :: :threshold | :priority | :frequency | :recency | :relevance
  
  @type aggregation_strategy :: :sum | :average | :max | :min | :mode | :weighted
  
  @doc """
  Suggests appropriate attenuation methods based on variety ratio.
  """
  def suggest_methods(variety_ratio) when is_number(variety_ratio) do
    cond do
      variety_ratio > 10.0 ->
        [:categorize, :aggregate, :filter]
        
      variety_ratio > 5.0 ->
        [:aggregate, :summarize, :sample]
        
      variety_ratio > 2.0 ->
        [:summarize, :filter, :sample]
        
      variety_ratio > 1.5 ->
        [:filter, :sample]
        
      true ->
        [:filter]
    end
  end
  
  @doc """
  Filters inputs based on specified strategy and criteria.
  
  ## Strategies
    - `:threshold` - Keep only values above/below threshold
    - `:priority` - Keep highest priority items
    - `:frequency` - Keep most/least frequent items
    - `:recency` - Keep most recent items
    - `:relevance` - Keep items matching relevance criteria
  """
  def filter(items, strategy, options \\ [])
  
  def filter(items, :threshold, options) do
    threshold = Keyword.fetch!(options, :threshold)
    operator = Keyword.get(options, :operator, :gt)
    value_fn = Keyword.get(options, :value_fn, & &1)
    
    Enum.filter(items, fn item ->
      value = value_fn.(item)
      case operator do
        :gt -> value > threshold
        :gte -> value >= threshold
        :lt -> value < threshold
        :lte -> value <= threshold
        :eq -> value == threshold
        :neq -> value != threshold
      end
    end)
  end
  
  def filter(items, :priority, options) do
    limit = Keyword.get(options, :limit, 10)
    priority_fn = Keyword.get(options, :priority_fn, & &1.priority)
    
    items
    |> Enum.sort_by(priority_fn, &>=/2)
    |> Enum.take(limit)
  end
  
  def filter(items, :frequency, options) do
    limit = Keyword.get(options, :limit, 10)
    keep_most_frequent = Keyword.get(options, :most_frequent, true)
    key_fn = Keyword.get(options, :key_fn, & &1)
    
    frequencies = 
      items
      |> Enum.map(key_fn)
      |> Enum.frequencies()
    
    sorted_keys = 
      frequencies
      |> Enum.sort_by(fn {_key, count} -> count end, if(keep_most_frequent, do: &>=/2, else: &<=/2))
      |> Enum.take(limit)
      |> Enum.map(fn {key, _count} -> key end)
      |> MapSet.new()
    
    Enum.filter(items, fn item ->
      MapSet.member?(sorted_keys, key_fn.(item))
    end)
  end
  
  def filter(items, :recency, options) do
    limit = Keyword.get(options, :limit, 10)
    timestamp_fn = Keyword.get(options, :timestamp_fn, & &1.timestamp)
    
    items
    |> Enum.sort_by(timestamp_fn, &>=/2)
    |> Enum.take(limit)
  end
  
  def filter(items, :relevance, options) do
    relevance_fn = Keyword.fetch!(options, :relevance_fn)
    threshold = Keyword.get(options, :threshold, 0.5)
    
    Enum.filter(items, fn item ->
      relevance_fn.(item) >= threshold
    end)
  end
  
  @doc """
  Aggregates multiple inputs into summary values.
  
  ## Strategies
    - `:sum` - Sum of values
    - `:average` - Mean value
    - `:max` - Maximum value
    - `:min` - Minimum value
    - `:mode` - Most common value
    - `:weighted` - Weighted combination
  """
  def aggregate(items, strategy, options \\ [])
  
  def aggregate(items, :sum, options) do
    value_fn = Keyword.get(options, :value_fn, & &1)
    
    items
    |> Enum.map(value_fn)
    |> Enum.sum()
  end
  
  def aggregate(items, :average, options) do
    value_fn = Keyword.get(options, :value_fn, & &1)
    values = Enum.map(items, value_fn)
    
    if length(values) > 0 do
      Enum.sum(values) / length(values)
    else
      0
    end
  end
  
  def aggregate(items, :max, options) do
    value_fn = Keyword.get(options, :value_fn, & &1)
    default = Keyword.get(options, :default, nil)
    
    case Enum.map(items, value_fn) do
      [] -> default
      values -> Enum.max(values)
    end
  end
  
  def aggregate(items, :min, options) do
    value_fn = Keyword.get(options, :value_fn, & &1)
    default = Keyword.get(options, :default, nil)
    
    case Enum.map(items, value_fn) do
      [] -> default
      values -> Enum.min(values)
    end
  end
  
  def aggregate(items, :mode, options) do
    value_fn = Keyword.get(options, :value_fn, & &1)
    
    items
    |> Enum.map(value_fn)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_value, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end
  
  def aggregate(items, :weighted, options) do
    value_fn = Keyword.get(options, :value_fn, & &1)
    weight_fn = Keyword.get(options, :weight_fn, fn _ -> 1.0 end)
    
    {weighted_sum, total_weight} = 
      items
      |> Enum.reduce({0, 0}, fn item, {sum, weight_sum} ->
        value = value_fn.(item)
        weight = weight_fn.(item)
        {sum + value * weight, weight_sum + weight}
      end)
    
    if total_weight > 0 do
      weighted_sum / total_weight
    else
      0
    end
  end
  
  @doc """
  Summarizes complex information into digestible formats.
  """
  def summarize(items, format \\ :statistics, options \\ [])
  
  def summarize(items, :statistics, options) do
    value_fn = Keyword.get(options, :value_fn, & &1)
    values = Enum.map(items, value_fn)
    
    if length(values) > 0 do
      sorted_values = Enum.sort(values)
      count = length(values)
      
      %{
        count: count,
        min: List.first(sorted_values),
        max: List.last(sorted_values),
        mean: Enum.sum(values) / count,
        median: calculate_median(sorted_values),
        std_dev: calculate_std_dev(values),
        percentiles: %{
          p25: percentile(sorted_values, 0.25),
          p50: percentile(sorted_values, 0.50),
          p75: percentile(sorted_values, 0.75),
          p90: percentile(sorted_values, 0.90),
          p95: percentile(sorted_values, 0.95),
          p99: percentile(sorted_values, 0.99)
        }
      }
    else
      %{
        count: 0,
        min: nil,
        max: nil,
        mean: nil,
        median: nil,
        std_dev: nil,
        percentiles: %{}
      }
    end
  end
  
  def summarize(items, :categories, options) do
    category_fn = Keyword.get(options, :category_fn, & &1.category)
    value_fn = Keyword.get(options, :value_fn, fn _ -> 1 end)
    
    items
    |> Enum.group_by(category_fn)
    |> Enum.map(fn {category, cat_items} ->
      {category, %{
        count: length(cat_items),
        total_value: cat_items |> Enum.map(value_fn) |> Enum.sum(),
        percentage: length(cat_items) / length(items) * 100
      }}
    end)
    |> Map.new()
  end
  
  def summarize(items, :time_series, options) do
    time_fn = Keyword.get(options, :time_fn, & &1.timestamp)
    value_fn = Keyword.get(options, :value_fn, & &1.value)
    interval = Keyword.get(options, :interval, :hour)
    aggregation = Keyword.get(options, :aggregation, :average)
    
    items
    |> Enum.group_by(fn item ->
      timestamp = time_fn.(item)
      truncate_to_interval(timestamp, interval)
    end)
    |> Enum.map(fn {interval_start, interval_items} ->
      values = Enum.map(interval_items, value_fn)
      aggregated_value = aggregate(values, aggregation)
      
      {interval_start, %{
        value: aggregated_value,
        count: length(interval_items),
        min: Enum.min(values, fn -> nil end),
        max: Enum.max(values, fn -> nil end)
      }}
    end)
    |> Enum.sort_by(fn {time, _} -> time end)
  end
  
  @doc """
  Applies sampling to reduce data volume while maintaining representativeness.
  """
  def sample(items, method \\ :random, options \\ [])
  
  def sample(items, :random, options) do
    sample_size = Keyword.get(options, :size, 100)
    seed = Keyword.get(options, :seed, :os.system_time(:nanosecond))
    
    :rand.seed(:exsss, seed)
    Enum.take_random(items, sample_size)
  end
  
  def sample(items, :systematic, options) do
    sample_size = Keyword.get(options, :size, 100)
    
    total_items = length(items)
    
    if sample_size >= total_items do
      items
    else
      interval = div(total_items, sample_size)
      
      items
      |> Enum.with_index()
      |> Enum.filter(fn {_item, index} ->
        rem(index, interval) == 0
      end)
      |> Enum.map(fn {item, _index} -> item end)
      |> Enum.take(sample_size)
    end
  end
  
  def sample(items, :stratified, options) do
    stratum_fn = Keyword.fetch!(options, :stratum_fn)
    sample_size = Keyword.get(options, :size, 100)
    
    strata = Enum.group_by(items, stratum_fn)
    strata_count = map_size(strata)
    
    if strata_count == 0 do
      []
    else
      per_stratum = div(sample_size, strata_count)
      
      strata
      |> Enum.flat_map(fn {_stratum, stratum_items} ->
        sample(stratum_items, :random, size: per_stratum)
      end)
    end
  end
  
  @doc """
  Categorizes items to reduce variety through grouping.
  """
  def categorize(items, method \\ :auto, options \\ [])
  
  def categorize(items, :auto, options) do
    max_categories = Keyword.get(options, :max_categories, 10)
    feature_fn = Keyword.get(options, :feature_fn, & &1)
    
    features = Enum.map(items, feature_fn)
    
    # Simple clustering based on feature similarity
    # In production, use proper clustering algorithms
    clusters = simple_cluster(features, max_categories)
    
    items
    |> Enum.zip(clusters)
    |> Enum.group_by(fn {_item, cluster} -> cluster end)
    |> Enum.map(fn {cluster, clustered_items} ->
      items_only = Enum.map(clustered_items, fn {item, _} -> item end)
      {cluster, items_only}
    end)
    |> Map.new()
  end
  
  def categorize(items, :rules, options) do
    rules = Keyword.fetch!(options, :rules)
    default_category = Keyword.get(options, :default, :other)
    
    Enum.group_by(items, fn item ->
      Enum.find_value(rules, default_category, fn {category, rule_fn} ->
        if rule_fn.(item), do: category
      end)
    end)
  end
  
  def categorize(items, :quantiles, options) do
    value_fn = Keyword.get(options, :value_fn, & &1)
    buckets = Keyword.get(options, :buckets, 5)
    
    values = Enum.map(items, value_fn)
    
    if length(values) > 0 do
      sorted_values = Enum.sort(values)
      
      quantile_boundaries = 
        1..(buckets - 1)
        |> Enum.map(fn i ->
          percentile(sorted_values, i / buckets)
        end)
      
      items
      |> Enum.group_by(fn item ->
        value = value_fn.(item)
        
        boundary_index = 
          Enum.find_index(quantile_boundaries, fn boundary ->
            value <= boundary
          end)
        
        if boundary_index do
          "Q#{boundary_index + 1}"
        else
          "Q#{buckets}"
        end
      end)
    else
      %{}
    end
  end
  
  # Private helper functions
  
  defp calculate_median(sorted_values) do
    count = length(sorted_values)
    
    if rem(count, 2) == 1 do
      Enum.at(sorted_values, div(count, 2))
    else
      mid = div(count, 2)
      (Enum.at(sorted_values, mid - 1) + Enum.at(sorted_values, mid)) / 2
    end
  end
  
  defp calculate_std_dev(values) do
    count = length(values)
    
    if count > 1 do
      mean = Enum.sum(values) / count
      
      variance = 
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(count - 1)
      
      :math.sqrt(variance)
    else
      0
    end
  end
  
  defp percentile(sorted_values, p) when p >= 0 and p <= 1 do
    count = length(sorted_values)
    
    if count == 0 do
      nil
    else
      index = p * (count - 1)
      lower_index = trunc(index)
      upper_index = lower_index + 1
      
      if upper_index >= count do
        Enum.at(sorted_values, lower_index)
      else
        lower_value = Enum.at(sorted_values, lower_index)
        upper_value = Enum.at(sorted_values, upper_index)
        
        # Linear interpolation
        fraction = index - lower_index
        lower_value + fraction * (upper_value - lower_value)
      end
    end
  end
  
  defp truncate_to_interval(timestamp, :minute) do
    div(timestamp, 60_000) * 60_000
  end
  
  defp truncate_to_interval(timestamp, :hour) do
    div(timestamp, 3_600_000) * 3_600_000
  end
  
  defp truncate_to_interval(timestamp, :day) do
    div(timestamp, 86_400_000) * 86_400_000
  end
  
  defp simple_cluster(features, max_clusters) do
    # Very simple clustering - just assign based on hash
    # In production, use k-means or similar
    
    features
    |> Enum.map(fn feature ->
      :erlang.phash2(feature, max_clusters)
    end)
  end
end