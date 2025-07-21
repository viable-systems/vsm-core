defmodule VSMCore.Channels.Supervisor do
  @moduledoc """
  Supervisor for VSM communication channels.
  """
  
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting VSM Channels Supervisor")
    
    children = [
      # Core VSM communication channels
      {VSMCore.Channels.CommandChannel, []},
      {VSMCore.Channels.CoordinationChannel, []},
      {VSMCore.Channels.AuditChannel, []},
      {VSMCore.Channels.AlgedonicChannel, []},
      
      # Advanced channels
      {VSMCore.Channels.TemporalVariety, []},
      {VSMCore.Channels.Algedonic, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end