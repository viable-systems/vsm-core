defmodule VSMCore.System1.Supervisor do
  @moduledoc """
  Supervisor for System 1 (Operations) subsystem.
  
  Manages the lifecycle of all S1 components including the main operations
  server, metrics collector, and dynamic unit supervisor.
  """
  
  use Supervisor
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end
  
  @impl true
  def init(opts) do
    children = [
      # Metrics collector (started first to capture all events)
      {VSMCore.System1.Metrics, 
       [name: metrics_name(opts), config: Keyword.get(opts, :metrics_config, %{})]},
      
      # Main operations server
      {VSMCore.System1.Operations,
       [name: operations_name(opts), config: Keyword.get(opts, :config, %{})]},
       
      # Unit registry
      {Registry, keys: :unique, name: unit_registry_name(opts)},
      
      # Dynamic supervisor for units
      {DynamicSupervisor, 
       [name: unit_supervisor_name(opts), strategy: :one_for_one]}
    ]
    
    Supervisor.init(children, strategy: :one_for_all)
  end
  
  # Helper functions to generate process names
  
  defp operations_name(opts) do
    case Keyword.get(opts, :name) do
      nil -> VSMCore.System1.Operations
      name -> :"#{name}_operations"
    end
  end
  
  defp metrics_name(opts) do
    case Keyword.get(opts, :name) do
      nil -> VSMCore.System1.Metrics
      name -> :"#{name}_metrics"
    end
  end
  
  defp unit_registry_name(opts) do
    case Keyword.get(opts, :name) do
      nil -> :s1_unit_registry
      name -> :"#{name}_unit_registry"
    end
  end
  
  defp unit_supervisor_name(opts) do
    case Keyword.get(opts, :name) do
      nil -> VSMCore.System1.UnitSupervisor
      name -> :"#{name}_unit_supervisor"
    end
  end
end