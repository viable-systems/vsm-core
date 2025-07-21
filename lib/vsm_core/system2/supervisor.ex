defmodule VSMCore.System2.Supervisor do
  @moduledoc """
  Supervisor for System 2 - Coordination subsystem.
  """
  
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting System 2 (Coordination) Supervisor")
    
    children = [
      {VSMCore.System2.Coordination, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end