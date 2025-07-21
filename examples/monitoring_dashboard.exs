#!/usr/bin/env elixir

# VSM Core Monitoring Dashboard Example
# 
# This script provides a simple monitoring dashboard for the VSM Core system.
# It displays real-time metrics, health status, and system activities.
# 
# Run with: elixir examples/monitoring_dashboard.exs

Mix.install([{:vsm_core, path: "."}])

defmodule VSMDashboard do
  @moduledoc """
  Simple monitoring dashboard for VSM Core system.
  """
  
  def start do
    # Ensure system is running
    {:ok, _} = VSMCore.start()
    
    IO.puts("\n" <> IO.ANSI.clear())
    IO.puts("🖥️  VSM Core Monitoring Dashboard")
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("Press Ctrl+C to exit\n")
    
    # Start monitoring loop
    monitor_loop()
  end
  
  defp monitor_loop do
    display_dashboard()
    Process.sleep(2000)  # Update every 2 seconds
    monitor_loop()
  end
  
  defp display_dashboard do
    # Clear screen and move cursor to top
    IO.write(IO.ANSI.cursor_up(1000) <> IO.ANSI.clear_line())
    
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    IO.puts("🕐 Last Updated: #{timestamp}")
    IO.puts("")
    
    # System Status Section
    display_system_status()
    IO.puts("")
    
    # Subsystem Health Section  
    display_subsystem_health()
    IO.puts("")
    
    # Channel Status Section
    display_channel_status()
    IO.puts("")
    
    # Performance Metrics Section
    display_performance_metrics()
    IO.puts("")
    
    # Active Alerts Section
    display_active_alerts()
    IO.puts("")
    
    # Variety Engineering Section
    display_variety_metrics()
    IO.puts("")
    
    # Recent Activity Section
    display_recent_activity()
    
    IO.puts("\n" <> String.duplicate("-", 50))
  end
  
  defp display_system_status do
    status = VSMCore.status()
    health = VSMCore.health()
    
    system_emoji = case status.system do
      :running -> "🟢"
      :stopping -> "🟡"
      :stopped -> "🔴"
      _ -> "⚪"
    end
    
    health_emoji = case health.status do
      :healthy -> "💚"
      :degraded -> "💛"
      :unhealthy -> "❤️"
      _ -> "🤍"
    end
    
    IO.puts("📊 SYSTEM STATUS")
    IO.puts("  #{system_emoji} System: #{status.system}")
    IO.puts("  #{health_emoji} Health: #{health.status}")
    IO.puts("  ⏱️  Uptime: #{format_uptime(health.uptime)}")
  end
  
  defp display_subsystem_health do
    status = VSMCore.status()
    
    IO.puts("🏗️  SUBSYSTEM HEALTH")
    subsystems = [
      {:s1, "Operations"},
      {:s2, "Coordination"}, 
      {:s3, "Control"},
      {:s4, "Intelligence"},
      {:s5, "Policy"}
    ]
    
    for {key, name} <- subsystems do
      subsystem_status = Map.get(status.subsystems, key, :unknown)
      emoji = case subsystem_status do
        :running -> "✅"
        :degraded -> "⚠️"
        :error -> "❌"
        :stopped -> "⏹️"
        _ -> "❓"
      end
      IO.puts("  #{emoji} #{name} (#{key}): #{subsystem_status}")
    end
  end
  
  defp display_channel_status do
    status = VSMCore.status()
    
    IO.puts("📡 COMMUNICATION CHANNELS")
    channels = [
      {:algedonic, "Emergency Channel"},
      {:temporal_variety, "Variety Buffer"}
    ]
    
    for {key, name} <- channels do
      channel_status = Map.get(status.channels, key, :unknown)
      emoji = case channel_status do
        :running -> "📶"
        :degraded -> "📶"  # Could show different signal strength
        :error -> "📵"
        :stopped -> "⏹️"
        _ -> "❓"
      end
      IO.puts("  #{emoji} #{name}: #{channel_status}")
    end
    
    # Show algedonic signal count
    try do
      signals = VSMCore.System5.Policy.get_algedonic_signals()
      active_count = length(signals)
      if active_count > 0 do
        urgent_count = Enum.count(signals, &(&1.urgency in [:high, :critical]))
        IO.puts("  🚨 Active Signals: #{active_count} (#{urgent_count} urgent)")
      end
    rescue
      _ -> :ok  # Ignore errors during monitoring
    end
  end
  
  defp display_performance_metrics do
    status = VSMCore.status()
    metrics = status.metrics
    
    IO.puts("⚡ PERFORMANCE METRICS")
    IO.puts("  📨 Messages: #{metrics.message_count}")
    IO.puts("  ❌ Error Rate: #{format_percentage(metrics.error_rate)}")
    IO.puts("  ⏱️  Avg Processing: #{metrics.processing_time}ms")
    
    # Try to get more detailed metrics
    try do
      s1_metrics = VSMCore.System1.Metrics.get_system_metrics()
      IO.puts("  🏭 S1 Throughput: #{s1_metrics.transactions_per_second || 0}/sec")
      IO.puts("  📊 S1 Success Rate: #{format_percentage(s1_metrics.success_rate || 0)}")
    rescue
      _ -> :ok
    end
  end
  
  defp display_active_alerts do
    health = VSMCore.health()
    alerts = health.alerts
    
    IO.puts("🚨 ACTIVE ALERTS")
    if length(alerts) == 0 do
      IO.puts("  ✅ No active alerts")
    else
      IO.puts("  📢 #{length(alerts)} active alert(s)")
      
      # Show top 3 most recent alerts
      recent_alerts = Enum.take(alerts, 3)
      for alert <- recent_alerts do
        level_emoji = case alert.level do
          :critical -> "🔴"
          :high -> "🟠"
          :medium -> "🟡"
          :low -> "🟢"
          _ -> "⚪"
        end
        
        timestamp = format_alert_time(alert.timestamp)
        IO.puts("    #{level_emoji} [#{timestamp}] #{String.slice(alert.message, 0..40)}...")
      end
      
      if length(alerts) > 3 do
        IO.puts("    ... and #{length(alerts) - 3} more")
      end
    end
  end
  
  defp display_variety_metrics do
    IO.puts("🌈 VARIETY ENGINEERING")
    
    try do
      # Get variety metrics from different subsystems
      s1_variety = VSMCore.System1.Metrics.get_system_variety()
      
      # Try to get temporal variety buffer status
      buffer_status = VSMCore.Channels.TemporalVariety.buffer_status()
      
      IO.puts("  📈 S1 System Variety: #{s1_variety}")
      IO.puts("  📊 Buffer Utilization: #{buffer_status.count}/#{buffer_status.capacity}")
      
      if buffer_status.overflow_count > 0 do
        IO.puts("  ⚠️  Buffer Overflows: #{buffer_status.overflow_count}")
      end
      
      # Show variety distribution
      capacity_info = VSMCore.health().capacity
      if Map.has_key?(capacity_info, :variety_handling) do
        for {subsystem, capacity} <- capacity_info.variety_handling do
          bar = create_progress_bar(capacity / 100, 10)
          IO.puts("  #{subsystem}: #{bar} #{capacity}%")
        end
      end
    rescue
      _ -> 
        IO.puts("  📊 Variety metrics temporarily unavailable")
    end
  end
  
  defp display_recent_activity do
    IO.puts("📋 RECENT ACTIVITY")
    
    try do
      # Try to get recent activities from different subsystems
      activities = get_recent_activities()
      
      if length(activities) == 0 do
        IO.puts("  💤 No recent activity")
      else
        for activity <- Enum.take(activities, 5) do
          time = format_activity_time(activity.timestamp)
          icon = get_activity_icon(activity.type)
          IO.puts("  #{icon} [#{time}] #{activity.description}")
        end
      end
    rescue
      _ ->
        IO.puts("  📊 Activity log temporarily unavailable")
    end
  end
  
  # Helper functions
  
  defp format_uptime(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)
    "#{hours}h #{minutes}m #{secs}s"
  end
  defp format_uptime(_), do: "Unknown"
  
  defp format_percentage(rate) when is_number(rate) do
    "#{Float.round(rate * 100, 1)}%"
  end
  defp format_percentage(_), do: "0.0%"
  
  defp format_alert_time(timestamp) when is_integer(timestamp) do
    # Simple time format - in real implementation would use proper time formatting
    minutes_ago = div(System.system_time(:second) - timestamp, 60)
    cond do
      minutes_ago < 1 -> "now"
      minutes_ago < 60 -> "#{minutes_ago}m ago"
      true -> "#{div(minutes_ago, 60)}h ago"
    end
  end
  defp format_alert_time(_), do: "unknown"
  
  defp format_activity_time(timestamp) when is_integer(timestamp) do
    seconds_ago = System.system_time(:second) - timestamp
    cond do
      seconds_ago < 60 -> "#{seconds_ago}s"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)}m"
      true -> "#{div(seconds_ago, 3600)}h"
    end
  end
  defp format_activity_time(_), do: "?"
  
  defp create_progress_bar(percentage, width) when percentage >= 0 and percentage <= 1 do
    filled = round(percentage * width)
    empty = width - filled
    "█" <> String.duplicate("█", filled - 1) <> String.duplicate("░", empty)
  end
  defp create_progress_bar(_, width), do: String.duplicate("?", width)
  
  defp get_activity_icon(type) do
    case type do
      :transaction -> "💳"
      :coordination -> "🤝"
      :control -> "🎛️"
      :intelligence -> "🧠"
      :policy -> "📜"
      :algedonic -> "🚨"
      :variety -> "🌈"
      _ -> "📝"
    end
  end
  
  defp get_recent_activities do
    # In a real implementation, this would aggregate activities from all subsystems
    # For now, return some mock recent activities
    base_time = System.system_time(:second)
    [
      %{
        timestamp: base_time - 10,
        type: :transaction,
        description: "Processed transaction in sales_unit_1"
      },
      %{
        timestamp: base_time - 25,
        type: :coordination,
        description: "S2 coordinated load balancing"
      },
      %{
        timestamp: base_time - 40,
        type: :control,
        description: "S3 applied throttling control"
      },
      %{
        timestamp: base_time - 60,
        type: :intelligence,
        description: "S4 detected pattern in data"
      },
      %{
        timestamp: base_time - 80,
        type: :policy,
        description: "S5 updated efficiency policy"
      }
    ]
  end
end

# Start the dashboard
IO.puts("Starting VSM Core Monitoring Dashboard...")
VSMDashboard.start()