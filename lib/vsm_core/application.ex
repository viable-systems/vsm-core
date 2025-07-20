defmodule VSMCore.Application do
  @moduledoc """
  The VSM Core OTP Application.
  
  This module starts the supervision tree for the Viable System Model,
  including all five subsystems and their communication channels.
  """
  
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting VSM Core Application...")
    
    children = [
      # Shared infrastructure
      {Registry, keys: :unique, name: VSMCore.Registry},
      {DynamicSupervisor, name: VSMCore.DynamicSupervisor, strategy: :one_for_one},
      
      # Channel management
      VSMCore.Channels.Supervisor,
      
      # Subsystem supervisors (started in order)
      VSMCore.System1.Supervisor,
      VSMCore.System2.Supervisor,
      VSMCore.System3.Supervisor,
      VSMCore.System4.Supervisor,
      VSMCore.System5.Supervisor,
      
      # Telemetry and monitoring
      VSMCore.TelemetryReporter
    ]

    opts = [strategy: :one_for_one, name: VSMCore.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("VSM Core Application started successfully")
        {:ok, pid}
        
      {:error, reason} ->
        Logger.error("Failed to start VSM Core Application: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping VSM Core Application...")
    :ok
  end
end