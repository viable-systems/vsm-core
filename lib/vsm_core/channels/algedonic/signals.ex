defmodule VSMCore.Channels.Algedonic.Signals do
  @moduledoc """
  Signal management for the Algedonic Channel.
  
  This module handles the creation, validation, and classification of algedonic
  signals. It defines signal types, severity levels, and provides utilities for
  signal analysis and transformation.
  """
  
  require Logger
  
  @type signal_type :: :pain | :pleasure
  @type severity :: :critical | :high | :medium | :low
  
  @type signal :: %{
    id: String.t(),
    type: signal_type(),
    source: atom() | String.t(),
    severity: severity(),
    data: map(),
    timestamp: DateTime.t(),
    metadata: map()
  }
  
  @type aggregated_signal :: %{
    id: String.t(),
    type: :aggregated,
    pattern_id: String.t(),
    signals: list(String.t()),
    severity: severity(),
    data: map(),
    timestamp: DateTime.t()
  }
  
  @doc """
  Creates a new algedonic signal.
  
  ## Parameters
  
  - `type` - Signal type (:pain or :pleasure)
  - `source` - Source system or component
  - `data` - Signal payload data
  - `severity` - Signal severity level
  
  ## Examples
  
      iex> Signals.create_signal(:pain, :system1_unit_1, %{metric: "cpu", value: 95}, :high)
      %{id: "...", type: :pain, source: :system1_unit_1, ...}
  """
  def create_signal(type, source, data, severity \\ :medium) do
    %{
      id: generate_signal_id(),
      type: type,
      source: source,
      severity: severity,
      data: data,
      timestamp: DateTime.utc_now(),
      metadata: %{
        created_at: System.system_time(:millisecond),
        ttl: calculate_ttl(severity)
      }
    }
  end
  
  @doc """
  Creates an aggregated signal from a detected pattern.
  """
  def create_aggregated_signal(pattern) do
    %{
      id: generate_signal_id(),
      type: :aggregated,
      pattern_id: pattern.id,
      signals: pattern.signal_ids,
      severity: determine_aggregated_severity(pattern),
      data: %{
        pattern_type: pattern.type,
        confidence: pattern.confidence,
        significance: pattern.significance,
        details: pattern.details
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  @doc """
  Validates a signal structure and content.
  """
  def validate_signal(signal) do
    with :ok <- validate_structure(signal),
         :ok <- validate_type(signal.type),
         :ok <- validate_severity(signal.severity),
         :ok <- validate_data(signal.data) do
      {:ok, signal}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Determines if a signal requires emergency bypass routing.
  
  Emergency bypass is triggered for:
  - Critical severity signals
  - Signals with emergency flags
  - Signals matching emergency patterns
  """
  def requires_emergency_bypass?(signal) do
    signal.severity == :critical ||
      Map.get(signal.metadata, :emergency, false) ||
      matches_emergency_pattern?(signal)
  end
  
  @doc """
  Classifies a signal based on its characteristics.
  """
  def classify_signal(signal) do
    classifications = []
    
    classifications = if signal.severity in [:critical, :high] do
      [:urgent | classifications]
    else
      classifications
    end
    
    classifications = if is_recurring_signal?(signal) do
      [:recurring | classifications]
    else
      classifications
    end
    
    classifications = if is_anomalous_signal?(signal) do
      [:anomalous | classifications]
    else
      classifications
    end
    
    classifications
  end
  
  @doc """
  Calculates signal priority based on multiple factors.
  """
  def calculate_priority(signal) do
    base_priority = severity_to_priority(signal.severity)
    
    adjustments = 0
    adjustments = adjustments + if signal.type == :pain, do: 10, else: 0
    adjustments = adjustments + if is_anomalous_signal?(signal), do: 5, else: 0
    adjustments = adjustments + if get_signal_age(signal) > 60_000, do: -5, else: 0
    
    max(0, min(100, base_priority + adjustments))
  end
  
  @doc """
  Enriches a signal with additional context and metadata.
  """
  def enrich_signal(signal, context \\ %{}) do
    enriched_metadata = Map.merge(signal.metadata, %{
      classifications: classify_signal(signal),
      priority: calculate_priority(signal),
      context: context,
      enriched_at: System.system_time(:millisecond)
    })
    
    %{signal | metadata: enriched_metadata}
  end
  
  @doc """
  Filters signals by criteria.
  """
  def filter_signals(signals, criteria) do
    Enum.filter(signals, fn signal ->
      Enum.all?(criteria, fn {key, value} ->
        case key do
          :type -> signal.type == value
          :severity -> signal.severity == value
          :source -> signal.source == value
          :min_priority -> calculate_priority(signal) >= value
          :max_age -> get_signal_age(signal) <= value
          _ -> true
        end
      end)
    end)
  end
  
  @doc """
  Groups signals by specified attribute.
  """
  def group_signals(signals, by) do
    Enum.group_by(signals, fn signal ->
      case by do
        :type -> signal.type
        :severity -> signal.severity
        :source -> signal.source
        :hour -> DateTime.truncate(signal.timestamp, :hour)
        _ -> :unknown
      end
    end)
  end
  
  # Private Functions
  
  defp generate_signal_id do
    "sig_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp validate_structure(signal) do
    required_fields = [:id, :type, :source, :severity, :data, :timestamp]
    
    if Enum.all?(required_fields, &Map.has_key?(signal, &1)) do
      :ok
    else
      {:error, :invalid_structure}
    end
  end
  
  defp validate_type(type) when type in [:pain, :pleasure, :aggregated], do: :ok
  defp validate_type(_), do: {:error, :invalid_type}
  
  defp validate_severity(severity) when severity in [:critical, :high, :medium, :low], do: :ok
  defp validate_severity(_), do: {:error, :invalid_severity}
  
  defp validate_data(data) when is_map(data) and map_size(data) > 0, do: :ok
  defp validate_data(_), do: {:error, :invalid_data}
  
  defp calculate_ttl(:critical), do: :infinity
  defp calculate_ttl(:high), do: 3600_000  # 1 hour
  defp calculate_ttl(:medium), do: 1800_000  # 30 minutes
  defp calculate_ttl(:low), do: 300_000  # 5 minutes
  
  defp determine_aggregated_severity(pattern) do
    cond do
      pattern.significance > 0.9 -> :critical
      pattern.significance > 0.7 -> :high
      pattern.significance > 0.5 -> :medium
      true -> :low
    end
  end
  
  defp matches_emergency_pattern?(signal) do
    emergency_patterns = [
      {[:pain], %{"metric" => "system_failure"}},
      {[:pain], %{"metric" => "security_breach"}},
      {[:pain, :recurring], :high_value}
    ]
    
    Enum.any?(emergency_patterns, fn {required_classes, data_pattern} ->
      classifications = classify_signal(signal)
      
      Enum.all?(required_classes, &(&1 in classifications)) and
        matches_data_pattern?(signal.data, data_pattern)
    end)
  end
  
  defp matches_data_pattern?(data, pattern) when is_map(pattern) do
    Enum.all?(pattern, fn {key, expected} ->
      case Map.get(data, key) do
        nil -> false
        actual when is_function(expected) -> expected.(actual)
        actual -> actual == expected
      end
    end)
  end
  
  defp matches_data_pattern?(data, :high_value) do
    case Map.get(data, "value") do
      value when is_number(value) -> value > 90
      _ -> false
    end
  end
  
  defp matches_data_pattern?(_data, _pattern), do: false
  
  defp is_recurring_signal?(_signal) do
    # TODO: Implement pattern detection for recurring signals
    false
  end
  
  defp is_anomalous_signal?(signal) do
    # Simple anomaly detection based on value thresholds
    case Map.get(signal.data, "value") do
      value when is_number(value) ->
        (signal.type == :pain and value > 80) or
        (signal.type == :pleasure and value > 95)
      _ ->
        false
    end
  end
  
  defp severity_to_priority(:critical), do: 100
  defp severity_to_priority(:high), do: 75
  defp severity_to_priority(:medium), do: 50
  defp severity_to_priority(:low), do: 25
  
  defp get_signal_age(signal) do
    current_time = System.system_time(:millisecond)
    created_at = Map.get(signal.metadata, :created_at, current_time)
    current_time - created_at
  end
end