defmodule VSMCore.System3.Supervisor do
  @moduledoc """
  Supervisor for System 3 - Control subsystem.
  """
  
  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting System 3 (Control) Supervisor")
    
    children = [
      {VSMCore.System3.Control, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end