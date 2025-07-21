defmodule VSMCore.Channels.Algedonic.Alerting do
  @moduledoc """
  Alert generation and notification dispatch for the Algedonic Channel.
  
  This module handles the creation and delivery of alerts based on
  algedonic signals. It provides multiple notification mechanisms
  and ensures critical alerts reach the appropriate management levels.
  """
  
  require Logger
  
  @type alert_type :: :critical | :warning | :info
  @type delivery_method :: :direct | :broadcast | :escalating
  
  @type alert :: %{
    id: String.t(),
    type: alert_type(),
    signal_id: String.t(),
    destination: atom(),
    title: String.t(),
    message: String.t(),
    severity: atom(),
    metadata: map(),
    created_at: DateTime.t()
  }
  
  @doc """
  Sends a critical alert for emergency signals.
  
  Critical alerts bypass normal notification channels and are
  delivered immediately to the specified destination.
  """
  def send_critical_alert(signal, route_info) do
    alert = create_alert(:critical, signal, route_info)
    
    # Log critical alert
    Logger.error("CRITICAL ALERT: #{alert.title} - #{alert.message}")
    
    # Deliver through multiple channels
    results = [
      deliver_direct(alert),
      deliver_telemetry(alert),
      store_alert(alert)
    ]
    
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, alert}
    else
      {:error, :partial_delivery}
    end
  end
  
  @doc """
  Sends a standard alert based on signal severity.
  """
  def send_alert(signal, route_info) do
    alert_type = severity_to_alert_type(signal.severity)
    alert = create_alert(alert_type, signal, route_info)
    
    case deliver_alert(alert) do
      {:ok, _} = result ->
        store_alert(alert)
        result
        
      error ->
        Logger.error("Failed to deliver alert: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Creates a batch alert for multiple related signals.
  """
  def send_batch_alert(signals, pattern, route_info) do
    alert = create_batch_alert(signals, pattern, route_info)
    deliver_alert(alert)
  end
  
  @doc """
  Retrieves alert history for analysis.
  """
  def get_alert_history(options \\ []) do
    # In production, this would query a persistent store
    {:ok, []}
  end
  
  # Private Functions
  
  defp create_alert(type, signal, route_info) do
    %{
      id: generate_alert_id(),
      type: type,
      signal_id: signal.id,
      destination: route_info.destination,
      title: generate_alert_title(type, signal),
      message: generate_alert_message(signal),
      severity: signal.severity,
      metadata: %{
        signal_type: signal.type,
        source: signal.source,
        route_info: route_info,
        signal_data: signal.data
      },
      created_at: DateTime.utc_now()
    }
  end
  
  defp create_batch_alert(signals, pattern, route_info) do
    %{
      id: generate_alert_id(),
      type: :warning,
      signal_id: pattern.id,
      destination: route_info.destination,
      title: "Pattern Alert: #{pattern.type}",
      message: generate_pattern_message(pattern, signals),
      severity: pattern.details[:dominant_severity] || :medium,
      metadata: %{
        pattern_type: pattern.type,
        signal_count: length(signals),
        pattern_details: pattern.details,
        route_info: route_info
      },
      created_at: DateTime.utc_now()
    }
  end
  
  defp deliver_alert(alert) do
    case alert.type do
      :critical -> deliver_critical(alert)
      :warning -> deliver_warning(alert)
      :info -> deliver_info(alert)
    end
  end
  
  defp deliver_critical(alert) do
    # Multiple delivery attempts for critical alerts
    with {:ok, _} <- deliver_direct(alert),
         {:ok, _} <- deliver_broadcast(alert),
         {:ok, _} <- deliver_telemetry(alert) do
      {:ok, alert}
    else
      error -> error
    end
  end
  
  defp deliver_warning(alert) do
    # Standard delivery for warnings
    with {:ok, _} <- deliver_direct(alert),
         {:ok, _} <- deliver_telemetry(alert) do
      {:ok, alert}
    else
      error -> error
    end
  end
  
  defp deliver_info(alert) do
    # Low-priority delivery for info alerts
    deliver_telemetry(alert)
  end
  
  defp deliver_direct(alert) do
    # Direct delivery to destination system
    :telemetry.execute(
      [:vsm_core, :algedonic, :alert, :delivered],
      %{count: 1},
      %{
        alert_id: alert.id,
        destination: alert.destination,
        method: :direct
      }
    )
    
    {:ok, alert}
  end
  
  defp deliver_broadcast(alert) do
    # Broadcast to all relevant systems
    destinations = determine_broadcast_destinations(alert)
    
    Enum.each(destinations, fn dest ->
      :telemetry.execute(
        [:vsm_core, :algedonic, :alert, :broadcast],
        %{count: 1},
        %{
          alert_id: alert.id,
          destination: dest
        }
      )
    end)
    
    {:ok, alert}
  end
  
  defp deliver_telemetry(alert) do
    # Emit telemetry event for monitoring
    :telemetry.execute(
      [:vsm_core, :algedonic, :alert],
      %{
        severity_value: severity_value(alert.severity)
      },
      Map.take(alert, [:id, :type, :destination, :severity])
    )
    
    {:ok, alert}
  end
  
  defp store_alert(alert) do
    # In production, persist to database
    Logger.info("Alert stored: #{alert.id}")
    {:ok, alert}
  end
  
  defp generate_alert_id do
    "alert_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp generate_alert_title(type, signal) do
    type_text = type |> to_string() |> String.upcase()
    "#{type_text}: #{signal.type} signal from #{signal.source}"
  end
  
  defp generate_alert_message(signal) do
    metric = Map.get(signal.data, "metric", "unknown")
    value = Map.get(signal.data, "value", "N/A")
    
    "#{String.capitalize(to_string(signal.type))} signal detected. " <>
    "Metric: #{metric}, Value: #{value}. " <>
    "Severity: #{signal.severity}."
  end
  
  defp generate_pattern_message(pattern, signals) do
    "Pattern type: #{pattern.type}. " <>
    "Detected across #{length(signals)} signals. " <>
    "Confidence: #{round(pattern.confidence * 100)}%, " <>
    "Significance: #{round(pattern.significance * 100)}%."
  end
  
  defp severity_to_alert_type(:critical), do: :critical
  defp severity_to_alert_type(:high), do: :warning
  defp severity_to_alert_type(:medium), do: :warning
  defp severity_to_alert_type(:low), do: :info
  
  defp severity_value(:critical), do: 4
  defp severity_value(:high), do: 3
  defp severity_value(:medium), do: 2
  defp severity_value(:low), do: 1
  
  defp determine_broadcast_destinations(alert) do
    case alert.severity do
      :critical -> [:system5, :system4, :system3]
      :high -> [:system4, :system3]
      _ -> [alert.destination]
    end
  end
end