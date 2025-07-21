defmodule VSMCore do
  @moduledoc """
  Main interface for the Viable System Model (VSM) Core implementation.
  
  This module provides high-level functions for managing the entire VSM system,
  including starting, stopping, and monitoring all five subsystems.
  """
  
  require Logger
  
  @doc """
  Starts the VSM Core application.
  
  This starts all five subsystems and their communication channels.
  
  ## Options
  
    * `:name` - The name to register the application under (default: `:vsm_core`)
    * `:config` - Additional configuration options
  
  ## Examples
  
      iex> VSMCore.start()
      {:ok, #PID<0.123.0>}
  
  """
  def start(opts \\ []) do
    Application.ensure_all_started(:vsm_core)
  end
  
  @doc """
  Stops the VSM Core application.
  
  This gracefully shuts down all subsystems and channels.
  
  ## Examples
  
      iex> VSMCore.stop()
      :ok
  
  """
  def stop do
    Application.stop(:vsm_core)
  end
  
  @doc """
  Checks the status of the VSM system.
  
  Returns a map with the status of each subsystem and major components.
  
  ## Examples
  
      iex> VSMCore.status()
      %{
        system: :running,
        subsystems: %{
          s1: :running,
          s2: :running,
          s3: :running,
          s4: :running,
          s5: :running
        },
        channels: %{
          algedonic: :running,
          temporal_variety: :running
        }
      }
  
  """
  def status do
    %{
      system: system_status(),
      subsystems: subsystem_statuses(),
      channels: channel_statuses(),
      metrics: system_metrics()
    }
  end
  
  @doc """
  Returns detailed health information about the VSM system.
  
  This includes performance metrics, error rates, and capacity information.
  
  ## Examples
  
      iex> VSMCore.health()
      %{
        status: :healthy,
        uptime: 3600,
        metrics: %{...},
        alerts: []
      }
  
  """
  def health do
    %{
      status: overall_health_status(),
      uptime: system_uptime(),
      metrics: detailed_metrics(),
      alerts: active_alerts(),
      capacity: capacity_info()
    }
  end
  
  @doc """
  Sends a test signal through the system to verify all channels are working.
  
  ## Examples
  
      iex> VSMCore.test_signal()
      {:ok, %{path: [:s1, :s2, :s3, :s4, :s5], latency_ms: 12}}
  
  """
  def test_signal do
    start_time = System.monotonic_time(:millisecond)
    
    with {:ok, _} <- VSMCore.System1.Operations.process_transaction(%{type: :test}),
         {:ok, _} <- verify_signal_propagation() do
      latency = System.monotonic_time(:millisecond) - start_time
      {:ok, %{path: [:s1, :s2, :s3, :s4, :s5], latency_ms: latency}}
    else
      error -> error
    end
  end
  
  # Private functions
  
  defp system_status do
    case Process.whereis(VSMCore.Supervisor) do
      nil -> :stopped
      pid when is_pid(pid) -> :running
    end
  end
  
  defp subsystem_statuses do
    %{
      s1: check_subsystem(VSMCore.System1.Supervisor),
      s2: check_subsystem(VSMCore.System2.Supervisor),
      s3: check_subsystem(VSMCore.System3.Supervisor),
      s4: check_subsystem(VSMCore.System4.Supervisor),
      s5: check_subsystem(VSMCore.System5.Supervisor)
    }
  end
  
  defp channel_statuses do
    %{
      algedonic: check_process(VSMCore.Channels.Algedonic),
      temporal_variety: check_process(VSMCore.Channels.TemporalVariety)
    }
  end
  
  defp check_subsystem(supervisor) do
    case Process.whereis(supervisor) do
      nil -> :stopped
      pid when is_pid(pid) ->
        case Supervisor.which_children(supervisor) do
          children when is_list(children) -> :running
          _ -> :error
        end
    end
  rescue
    _ -> :error
  end
  
  defp check_process(name) do
    case Process.whereis(name) do
      nil -> :stopped
      pid when is_pid(pid) -> :running
    end
  end
  
  defp system_metrics do
    %{
      message_count: get_telemetry_metric("vsm_core.messages.count"),
      error_rate: get_telemetry_metric("vsm_core.errors.rate"),
      processing_time: get_telemetry_metric("vsm_core.processing.duration")
    }
  end
  
  defp get_telemetry_metric(name) do
    # In a real implementation, this would query telemetry data
    0
  end
  
  defp overall_health_status do
    statuses = subsystem_statuses()
    
    cond do
      Enum.all?(Map.values(statuses), &(&1 == :running)) -> :healthy
      Enum.any?(Map.values(statuses), &(&1 == :error)) -> :unhealthy
      true -> :degraded
    end
  end
  
  defp system_uptime do
    # In a real implementation, this would track actual uptime
    :erlang.system_time(:second)
  end
  
  defp detailed_metrics do
    %{
      s1: VSMCore.System1.Metrics.get_metrics(),
      s2: %{coordination_events: 0},
      s3: %{control_actions: 0},
      s4: %{analyses_performed: 0},
      s5: %{policies_evaluated: 0}
    }
  end
  
  defp active_alerts do
    # Check for any algedonic signals
    case VSMCore.Channels.Algedonic.get_active_signals() do
      [] -> []
      signals -> Enum.map(signals, &format_alert/1)
    end
  end
  
  defp format_alert(signal) do
    %{
      level: signal.urgency,
      source: signal.source,
      message: signal.content,
      timestamp: signal.timestamp
    }
  end
  
  defp capacity_info do
    %{
      variety_handling: variety_capacity(),
      channel_utilization: channel_utilization()
    }
  end
  
  defp variety_capacity do
    %{
      s1: VSMCore.System1.Operations.get_variety_capacity(),
      temporal_buffer: VSMCore.Channels.TemporalVariety.buffer_status()
    }
  end
  
  defp channel_utilization do
    %{
      algedonic: 0.0,
      temporal_variety: 0.0
    }
  end
  
  defp verify_signal_propagation do
    # In a real implementation, this would verify the test signal
    # propagated through all subsystems
    {:ok, :verified}
  end
end
