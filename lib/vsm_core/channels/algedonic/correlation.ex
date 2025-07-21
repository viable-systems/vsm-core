defmodule VSMCore.Channels.Algedonic.Correlation do
  @moduledoc """
  Signal correlation and pattern analysis for the Algedonic Channel.
  
  This module analyzes relationships between signals to identify patterns,
  clusters, and trends that may indicate systemic issues or opportunities.
  It uses various correlation techniques to detect signal relationships.
  """
  
  require Logger
  
  @type pattern :: %{
    id: String.t(),
    type: pattern_type(),
    signal_ids: list(String.t()),
    confidence: float(),
    significance: float(),
    details: map(),
    discovered_at: DateTime.t()
  }
  
  @type pattern_type :: :temporal | :spatial | :causal | :threshold | :anomaly
  
  @type correlation_state :: %{
    signal_history: list(map()),
    pattern_cache: map(),
    correlation_matrix: map(),
    last_analysis: DateTime.t()
  }
  
  @doc """
  Analyzes signals to discover patterns and correlations.
  
  Returns discovered patterns and updated correlation state.
  """
  def analyze_patterns(signals, correlation_state) do
    updated_state = update_signal_history(signals, correlation_state)
    
    patterns = []
    |> discover_temporal_patterns(updated_state)
    |> discover_spatial_patterns(updated_state)
    |> discover_causal_patterns(updated_state)
    |> discover_threshold_patterns(updated_state)
    |> discover_anomaly_patterns(updated_state)
    |> filter_significant_patterns()
    
    new_state = %{updated_state | 
      pattern_cache: update_pattern_cache(patterns, updated_state.pattern_cache),
      last_analysis: DateTime.utc_now()
    }
    
    {:ok, patterns, new_state}
  rescue
    error ->
      Logger.error("Pattern analysis failed: #{inspect(error)}")
      {:error, error}
  end
  
  @doc """
  Calculates correlation coefficients between signals.
  """
  def calculate_correlation(signal1, signal2) do
    # Simple correlation based on timing and severity
    time_correlation = calculate_time_correlation(signal1, signal2)
    severity_correlation = calculate_severity_correlation(signal1, signal2)
    source_correlation = calculate_source_correlation(signal1, signal2)
    
    # Weighted average
    (time_correlation * 0.4 + severity_correlation * 0.3 + source_correlation * 0.3)
  end
  
  @doc """
  Clusters signals based on similarity metrics.
  """
  def cluster_signals(signals, options \\ []) do
    max_clusters = Keyword.get(options, :max_clusters, 5)
    min_cluster_size = Keyword.get(options, :min_cluster_size, 2)
    
    # Simple clustering based on signal characteristics
    clusters = signals
    |> group_by_characteristics()
    |> merge_similar_groups(max_clusters)
    |> filter_small_clusters(min_cluster_size)
    
    {:ok, clusters}
  end
  
  @doc """
  Detects anomalous signal patterns.
  """
  def detect_anomalies(signals, historical_patterns) do
    anomalies = Enum.filter(signals, fn signal ->
      is_anomalous?(signal, historical_patterns)
    end)
    
    {:ok, anomalies}
  end
  
  # Pattern Discovery Functions
  
  defp discover_temporal_patterns(patterns, state) do
    recent_signals = get_recent_signals(state.signal_history, 300_000) # 5 minutes
    
    temporal_patterns = recent_signals
    |> group_by_time_window(60_000) # 1 minute windows
    |> Enum.filter(fn {_window, signals} -> length(signals) > 3 end)
    |> Enum.map(fn {window, signals} ->
      create_temporal_pattern(window, signals)
    end)
    
    patterns ++ temporal_patterns
  end
  
  defp discover_spatial_patterns(patterns, state) do
    recent_signals = get_recent_signals(state.signal_history, 300_000)
    
    spatial_patterns = recent_signals
    |> Enum.group_by(& &1.source)
    |> Enum.filter(fn {_source, signals} -> length(signals) > 2 end)
    |> Enum.map(fn {source, signals} ->
      create_spatial_pattern(source, signals)
    end)
    
    patterns ++ spatial_patterns
  end
  
  defp discover_causal_patterns(patterns, state) do
    # Look for cause-effect relationships
    causal_patterns = state.signal_history
    |> find_causal_chains()
    |> Enum.map(&create_causal_pattern/1)
    
    patterns ++ causal_patterns
  end
  
  defp discover_threshold_patterns(patterns, state) do
    # Detect threshold breaches
    threshold_patterns = state.signal_history
    |> group_by_metric()
    |> Enum.flat_map(fn {metric, signals} ->
      detect_threshold_breaches(metric, signals)
    end)
    
    patterns ++ threshold_patterns
  end
  
  defp discover_anomaly_patterns(patterns, state) do
    # Detect anomalous patterns
    anomaly_patterns = state.signal_history
    |> detect_statistical_anomalies()
    |> Enum.map(&create_anomaly_pattern/1)
    
    patterns ++ anomaly_patterns
  end
  
  # Helper Functions
  
  defp update_signal_history(new_signals, state) do
    # Keep last 1000 signals or 1 hour of data
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)
    
    filtered_history = state.signal_history
    |> Enum.filter(fn signal -> 
      DateTime.compare(signal.timestamp, cutoff_time) == :gt
    end)
    
    updated_history = (filtered_history ++ new_signals)
    |> Enum.take(-1000)
    
    %{state | signal_history: updated_history}
  end
  
  defp calculate_time_correlation(signal1, signal2) do
    # Calculate temporal proximity
    time_diff = DateTime.diff(signal1.timestamp, signal2.timestamp, :millisecond)
    |> abs()
    
    cond do
      time_diff < 1000 -> 1.0      # Within 1 second
      time_diff < 10_000 -> 0.8    # Within 10 seconds
      time_diff < 60_000 -> 0.5    # Within 1 minute
      time_diff < 300_000 -> 0.2   # Within 5 minutes
      true -> 0.0
    end
  end
  
  defp calculate_severity_correlation(signal1, signal2) do
    if signal1.severity == signal2.severity do
      1.0
    else
      severity_distance = abs(severity_value(signal1.severity) - severity_value(signal2.severity))
      max(0, 1.0 - (severity_distance * 0.25))
    end
  end
  
  defp calculate_source_correlation(signal1, signal2) do
    cond do
      signal1.source == signal2.source -> 1.0
      same_system?(signal1.source, signal2.source) -> 0.5
      true -> 0.0
    end
  end
  
  defp severity_value(:critical), do: 4
  defp severity_value(:high), do: 3
  defp severity_value(:medium), do: 2
  defp severity_value(:low), do: 1
  
  defp same_system?(source1, source2) do
    # Check if sources belong to same system
    system1 = source1 |> to_string() |> String.split("_") |> List.first()
    system2 = source2 |> to_string() |> String.split("_") |> List.first()
    system1 == system2
  end
  
  defp group_by_characteristics(signals) do
    signals
    |> Enum.group_by(fn signal ->
      {signal.type, signal.severity, extract_metric(signal)}
    end)
  end
  
  defp extract_metric(signal) do
    Map.get(signal.data, "metric", "unknown")
  end
  
  defp merge_similar_groups(groups, max_groups) do
    # Simple merge strategy - keep largest groups
    groups
    |> Enum.map(fn {key, signals} -> {key, signals} end)
    |> Enum.sort_by(fn {_, signals} -> -length(signals) end)
    |> Enum.take(max_groups)
    |> Map.new()
  end
  
  defp filter_small_clusters(clusters, min_size) do
    Map.filter(clusters, fn {_, signals} -> length(signals) >= min_size end)
  end
  
  defp get_recent_signals(history, window_ms) do
    cutoff = DateTime.add(DateTime.utc_now(), -div(window_ms, 1000), :second)
    
    Enum.filter(history, fn signal ->
      DateTime.compare(signal.timestamp, cutoff) == :gt
    end)
  end
  
  defp group_by_time_window(signals, window_ms) do
    Enum.group_by(signals, fn signal ->
      timestamp_ms = DateTime.to_unix(signal.timestamp, :millisecond)
      div(timestamp_ms, window_ms)
    end)
  end
  
  defp create_temporal_pattern(window, signals) do
    %{
      id: generate_pattern_id(),
      type: :temporal,
      signal_ids: Enum.map(signals, & &1.id),
      confidence: calculate_pattern_confidence(signals),
      significance: calculate_temporal_significance(signals),
      details: %{
        window: window,
        duration_ms: 60_000,
        signal_count: length(signals),
        dominant_severity: find_dominant_severity(signals)
      },
      discovered_at: DateTime.utc_now()
    }
  end
  
  defp create_spatial_pattern(source, signals) do
    %{
      id: generate_pattern_id(),
      type: :spatial,
      signal_ids: Enum.map(signals, & &1.id),
      confidence: calculate_pattern_confidence(signals),
      significance: calculate_spatial_significance(signals),
      details: %{
        source: source,
        signal_count: length(signals),
        time_span_ms: calculate_time_span(signals),
        severity_distribution: calculate_severity_distribution(signals)
      },
      discovered_at: DateTime.utc_now()
    }
  end
  
  defp create_causal_pattern(chain) do
    %{
      id: generate_pattern_id(),
      type: :causal,
      signal_ids: chain,
      confidence: 0.7, # Simplified
      significance: 0.8,
      details: %{
        chain_length: length(chain),
        root_cause: List.first(chain),
        effects: Enum.drop(chain, 1)
      },
      discovered_at: DateTime.utc_now()
    }
  end
  
  defp create_anomaly_pattern(anomaly_group) do
    %{
      id: generate_pattern_id(),
      type: :anomaly,
      signal_ids: Enum.map(anomaly_group, & &1.id),
      confidence: 0.9,
      significance: 0.95,
      details: %{
        anomaly_type: :statistical,
        deviation: 3.0, # Standard deviations
        affected_metrics: extract_metrics(anomaly_group)
      },
      discovered_at: DateTime.utc_now()
    }
  end
  
  defp find_causal_chains(signals) do
    # Simplified causal chain detection
    []
  end
  
  defp group_by_metric(signals) do
    Enum.group_by(signals, &extract_metric/1)
  end
  
  defp detect_threshold_breaches(metric, signals) do
    # Simplified threshold detection
    []
  end
  
  defp detect_statistical_anomalies(signals) do
    # Simplified anomaly detection
    []
  end
  
  defp filter_significant_patterns(patterns) do
    Enum.filter(patterns, fn pattern ->
      pattern.confidence > 0.5 and pattern.significance > 0.3
    end)
  end
  
  defp update_pattern_cache(new_patterns, cache) do
    Enum.reduce(new_patterns, cache, fn pattern, acc ->
      Map.put(acc, pattern.id, pattern)
    end)
  end
  
  defp is_anomalous?(signal, historical_patterns) do
    # Check if signal deviates from historical patterns
    false # Simplified
  end
  
  defp generate_pattern_id do
    "pattern_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp calculate_pattern_confidence(signals) do
    # Higher confidence with more consistent signals
    min(1.0, length(signals) / 10.0)
  end
  
  defp calculate_temporal_significance(signals) do
    # Significance based on severity and frequency
    severity_score = signals
    |> Enum.map(fn s -> severity_value(s.severity) end)
    |> Enum.sum()
    
    min(1.0, severity_score / (length(signals) * 2))
  end
  
  defp calculate_spatial_significance(signals) do
    # Significance based on concentration from single source
    0.6 + (length(signals) / 100.0)
    |> min(1.0)
  end
  
  defp find_dominant_severity(signals) do
    signals
    |> Enum.map(& &1.severity)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_, count} -> count end)
    |> elem(0)
  end
  
  defp calculate_time_span(signals) do
    if length(signals) < 2 do
      0
    else
      timestamps = Enum.map(signals, & &1.timestamp)
      earliest = Enum.min(timestamps, DateTime)
      latest = Enum.max(timestamps, DateTime)
      DateTime.diff(latest, earliest, :millisecond)
    end
  end
  
  defp calculate_severity_distribution(signals) do
    signals
    |> Enum.map(& &1.severity)
    |> Enum.frequencies()
  end
  
  defp extract_metrics(signals) do
    signals
    |> Enum.map(&extract_metric/1)
    |> Enum.uniq()
  end
end