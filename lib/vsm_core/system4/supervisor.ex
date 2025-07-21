defmodule VSMCore.System4.Supervisor do
  @moduledoc """
  Supervisor for System 4 - Intelligence subsystem.
  """
  
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting System 4 (Intelligence) Supervisor")
    
    children = [
      {VSMCore.System4.Intelligence, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end