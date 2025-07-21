defmodule VSMCore.System5.Supervisor do
  @moduledoc """
  Supervisor for System 5 - Policy subsystem.
  """
  
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting System 5 (Policy) Supervisor")
    
    children = [
      {VSMCore.System5.Policy, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end