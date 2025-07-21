defmodule VSMCore.Channels.Algedonic.Filtering do
  @moduledoc """
  Signal filtering and noise reduction for the Algedonic Channel.
  
  This module implements sophisticated filtering mechanisms to reduce noise
  and ensure only relevant signals reach higher management levels. It provides
  configurable filters based on severity, patterns, frequency, and context.
  """
  
  require Logger
  
  @type filter_type :: :severity | :frequency | :pattern | :source | :threshold | :composite
  @type filter_action :: :pass | :block | :modify
  
  @type filter :: %{
    id: String.t(),
    type: filter_type(),
    name: String.t(),
    enabled: boolean(),
    config: map(),
    priority: integer()
  }
  
  @type filter_result :: {:pass, signal :: map()} | {:block, reason :: String.t()}
  
  @doc """
  Returns the default set of filters for the algedonic channel.
  """
  def default_filters do
    [
      %{
        id: "severity_filter",
        type: :severity,
        name: "Severity-based Filter",
        enabled: true,
        config: %{min_severity: :low},
        priority: 1
      },
      %{
        id: "frequency_filter",
        type: :frequency,
        name: "Frequency Limiter",
        enabled: true,
        config: %{
          window_ms: 60_000,
          max_signals_per_source: 10,
          burst_allowance: 3
        },
        priority: 2
      },
      %{
        id: "pattern_filter",
        type: :pattern,
        name: "Pattern Matcher",
        enabled: true,
        config: %{
          block_patterns: [],
          pass_patterns: []
        },
        priority: 3
      },
      %{
        id: "noise_filter",
        type: :threshold,
        name: "Noise Reduction",
        enabled: true,
        config: %{
          min_confidence: 0.3,
          min_significance: 0.2
        },
        priority: 4
      }
    ]
  end
  
  @doc """
  Applies a chain of filters to a signal.
  
  Filters are applied in priority order. The first filter to block
  the signal stops the chain.
  """
  def apply_filters(signal, filters) do
    enabled_filters = filters
    |> Enum.filter(& &1.enabled)
    |> Enum.sort_by(& &1.priority)
    
    apply_filter_chain(signal, enabled_filters)
  end
  
  @doc """
  Validates a list of filter configurations.
  """
  def validate_filters(filters) do
    results = Enum.map(filters, &validate_filter/1)
    
    case Enum.find(results, fn
      {:error, _} -> true
      _ -> false
    end) do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, filters}
    end
  end
  
  @doc """
  Creates a custom filter with the given configuration.
  """
  def create_filter(type, name, config, opts \\ []) do
    %{
      id: Keyword.get(opts, :id, generate_filter_id()),
      type: type,
      name: name,
      enabled: Keyword.get(opts, :enabled, true),
      config: config,
      priority: Keyword.get(opts, :priority, 10)
    }
  end
  
  @doc """
  Analyzes filter effectiveness over a set of signals.
  """
  def analyze_filter_effectiveness(filters, signal_history) do
    results = Enum.map(filters, fn filter ->
      stats = calculate_filter_stats(filter, signal_history)
      
      %{
        filter_id: filter.id,
        filter_name: filter.name,
        signals_processed: stats.total,
        signals_blocked: stats.blocked,
        block_rate: safe_divide(stats.blocked, stats.total),
        avg_processing_time_us: stats.avg_time
      }
    end)
    
    %{
      individual_stats: results,
      overall_block_rate: calculate_overall_block_rate(results),
      recommendations: generate_filter_recommendations(results)
    }
  end
  
  # Filter Implementation Functions
  
  defp apply_filter_chain(signal, []), do: {:pass, signal}
  
  defp apply_filter_chain(signal, [filter | rest]) do
    case apply_single_filter(signal, filter) do
      {:pass, modified_signal} ->
        apply_filter_chain(modified_signal, rest)
        
      {:block, reason} ->
        {:block, reason}
    end
  end
  
  defp apply_single_filter(signal, filter) do
    start_time = System.monotonic_time(:microsecond)
    
    result = case filter.type do
      :severity -> apply_severity_filter(signal, filter.config)
      :frequency -> apply_frequency_filter(signal, filter.config)
      :pattern -> apply_pattern_filter(signal, filter.config)
      :source -> apply_source_filter(signal, filter.config)
      :threshold -> apply_threshold_filter(signal, filter.config)
      :composite -> apply_composite_filter(signal, filter.config)
      _ -> {:pass, signal}
    end
    
    duration = System.monotonic_time(:microsecond) - start_time
    log_filter_application(filter, signal, result, duration)
    
    result
  end
  
  defp apply_severity_filter(signal, config) do
    min_severity = Map.get(config, :min_severity, :low)
    
    if severity_meets_threshold?(signal.severity, min_severity) do
      {:pass, signal}
    else
      {:block, "Signal severity #{signal.severity} below threshold #{min_severity}"}
    end
  end
  
  defp apply_frequency_filter(signal, config) do
    # In production, this would check against a time-series store
    # For now, we'll implement a simple rate check
    window_ms = Map.get(config, :window_ms, 60_000)
    max_signals = Map.get(config, :max_signals_per_source, 10)
    
    # Simplified: always pass critical signals
    if signal.severity == :critical do
      {:pass, signal}
    else
      # TODO: Implement actual frequency tracking
      {:pass, signal}
    end
  end
  
  defp apply_pattern_filter(signal, config) do
    block_patterns = Map.get(config, :block_patterns, [])
    pass_patterns = Map.get(config, :pass_patterns, [])
    
    cond do
      # Check pass patterns first (whitelist)
      Enum.any?(pass_patterns, &pattern_matches?(signal, &1)) ->
        {:pass, signal}
        
      # Then check block patterns (blacklist)
      Enum.any?(block_patterns, &pattern_matches?(signal, &1)) ->
        {:block, "Signal matches blocked pattern"}
        
      # Default behavior depends on configuration
      true ->
        {:pass, signal}
    end
  end
  
  defp apply_source_filter(signal, config) do
    allowed_sources = Map.get(config, :allowed_sources, :all)
    blocked_sources = Map.get(config, :blocked_sources, [])
    
    cond do
      signal.source in blocked_sources ->
        {:block, "Source #{signal.source} is blocked"}
        
      allowed_sources == :all ->
        {:pass, signal}
        
      signal.source in allowed_sources ->
        {:pass, signal}
        
      true ->
        {:block, "Source #{signal.source} not in allowed list"}
    end
  end
  
  defp apply_threshold_filter(signal, config) do
    min_confidence = Map.get(config, :min_confidence, 0.0)
    min_significance = Map.get(config, :min_significance, 0.0)
    
    confidence = get_signal_confidence(signal)
    significance = get_signal_significance(signal)
    
    cond do
      confidence < min_confidence ->
        {:block, "Confidence #{confidence} below threshold #{min_confidence}"}
        
      significance < min_significance ->
        {:block, "Significance #{significance} below threshold #{min_significance}"}
        
      true ->
        {:pass, signal}
    end
  end
  
  defp apply_composite_filter(signal, config) do
    sub_filters = Map.get(config, :filters, [])
    operator = Map.get(config, :operator, :and)
    
    results = Enum.map(sub_filters, fn filter_config ->
      apply_single_filter(signal, filter_config)
    end)
    
    case operator do
      :and ->
        # All filters must pass
        case Enum.find(results, fn
          {:block, _} -> true
          _ -> false
        end) do
          {:block, reason} -> {:block, reason}
          _ -> {:pass, signal}
        end
        
      :or ->
        # At least one filter must pass
        case Enum.find(results, fn
          {:pass, _} -> true
          _ -> false
        end) do
          {:pass, _} -> {:pass, signal}
          _ -> {:block, "No filters passed in OR composite"}
        end
    end
  end
  
  # Helper Functions
  
  defp validate_filter(filter) do
    with :ok <- validate_filter_structure(filter),
         :ok <- validate_filter_type(filter.type),
         :ok <- validate_filter_config(filter.type, filter.config) do
      {:ok, filter}
    end
  end
  
  defp validate_filter_structure(filter) do
    required_fields = [:id, :type, :name, :enabled, :config, :priority]
    
    if Enum.all?(required_fields, &Map.has_key?(filter, &1)) do
      :ok
    else
      {:error, :invalid_filter_structure}
    end
  end
  
  defp validate_filter_type(type) when type in [:severity, :frequency, :pattern, :source, :threshold, :composite], do: :ok
  defp validate_filter_type(_), do: {:error, :invalid_filter_type}
  
  defp validate_filter_config(:severity, config) do
    if Map.has_key?(config, :min_severity) do
      :ok
    else
      {:error, :missing_min_severity}
    end
  end
  
  defp validate_filter_config(_, _), do: :ok
  
  defp severity_meets_threshold?(signal_severity, threshold_severity) do
    severity_value(signal_severity) >= severity_value(threshold_severity)
  end
  
  defp severity_value(:critical), do: 4
  defp severity_value(:high), do: 3
  defp severity_value(:medium), do: 2
  defp severity_value(:low), do: 1
  
  defp pattern_matches?(signal, pattern) do
    # Simple pattern matching implementation
    Enum.all?(pattern, fn {key, expected} ->
      actual = get_in(signal, [key])
      
      case expected do
        {:regex, regex} -> Regex.match?(regex, to_string(actual))
        func when is_function(func) -> func.(actual)
        value -> actual == value
      end
    end)
  end
  
  defp get_signal_confidence(signal) do
    Map.get(signal.metadata, :confidence, 1.0)
  end
  
  defp get_signal_significance(signal) do
    Map.get(signal.metadata, :significance, 1.0)
  end
  
  defp generate_filter_id do
    "filter_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp log_filter_application(filter, signal, result, duration_us) do
    :telemetry.execute(
      [:vsm_core, :algedonic, :filter],
      %{duration_us: duration_us},
      %{
        filter_id: filter.id,
        filter_type: filter.type,
        signal_id: signal.id,
        result: elem(result, 0)
      }
    )
  end
  
  defp calculate_filter_stats(filter, signal_history) do
    # Simplified stats calculation
    %{
      total: length(signal_history),
      blocked: 0,  # TODO: Implement actual tracking
      avg_time: 100  # microseconds
    }
  end
  
  defp safe_divide(_, 0), do: 0.0
  defp safe_divide(num, denom), do: num / denom
  
  defp calculate_overall_block_rate(results) do
    total_processed = Enum.sum(Enum.map(results, & &1.signals_processed))
    total_blocked = Enum.sum(Enum.map(results, & &1.signals_blocked))
    
    safe_divide(total_blocked, total_processed)
  end
  
  defp generate_filter_recommendations(results) do
    recommendations = []
    
    # Check for filters with very high block rates
    high_block_filters = Enum.filter(results, & &1.block_rate > 0.9)
    
    recommendations = if length(high_block_filters) > 0 do
      ["Some filters are blocking >90% of signals. Consider adjusting thresholds." | recommendations]
    else
      recommendations
    end
    
    # Check for filters with very low block rates
    low_block_filters = Enum.filter(results, & &1.block_rate < 0.01)
    
    recommendations = if length(low_block_filters) > 0 do
      ["Some filters are blocking <1% of signals. Consider if they are necessary." | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
end