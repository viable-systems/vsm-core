defmodule VSMCore.TelemetryReporter do
  @moduledoc """
  Telemetry reporter for VSM Core metrics.
  """
  
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting VSM Telemetry Reporter")
    {:ok, %{}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end