defmodule VSMCore.Channels.Algedonic do
  @moduledoc """
  Algedonic Channel implementation for VSM Core.
  
  The algedonic channel provides direct pain/pleasure signal routing from S1 units
  to S5 (policy), bypassing normal hierarchical channels when critical conditions
  are detected. This enables rapid response to emergencies and critical situations.
  
  ## Features
  
  - Pain/pleasure signal detection and classification
  - Emergency bypass routing directly to S5
  - Signal prioritization and queuing
  - Noise reduction and filtering
  - Pattern correlation and analysis
  - Real-time alerting and notifications
  
  ## Signal Types
  
  - `:pain` - Negative signals indicating problems or threats
  - `:pleasure` - Positive signals indicating opportunities or successes
  
  ## Severity Levels
  
  - `:critical` - Immediate action required, bypass all filters
  - `:high` - Urgent attention needed, high priority routing
  - `:medium` - Important but not immediate, normal priority
  - `:low` - Informational, subject to filtering
  """
  
  use GenServer
  require Logger
  
  alias VSMCore.Channels.Algedonic.{Signals, Filtering, Routing, Correlation, Alerting}
  alias VSMCore.Shared.Message
  
  @type state :: %{
    active_signals: map(),
    signal_queue: :queue.queue(),
    filters: list(),
    routing_rules: map(),
    correlation_state: map(),
    metrics: map()
  }
  
  # Client API
  
  @doc """
  Starts the algedonic channel process.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Sends a pain signal through the algedonic channel.
  """
  def send_pain_signal(server \\ __MODULE__, source, data, severity \\ :medium) do
    signal = Signals.create_signal(:pain, source, data, severity)
    GenServer.cast(server, {:signal, signal})
  end
  
  @doc """
  Sends a pleasure signal through the algedonic channel.
  """
  def send_pleasure_signal(server \\ __MODULE__, source, data, severity \\ :medium) do
    signal = Signals.create_signal(:pleasure, source, data, severity)
    GenServer.cast(server, {:signal, signal})
  end
  
  @doc """
  Gets the current state of active signals.
  """
  def get_active_signals(server \\ __MODULE__) do
    GenServer.call(server, :get_active_signals)
  end
  
  @doc """
  Configures filtering rules for the channel.
  """
  def configure_filters(server \\ __MODULE__, filters) do
    GenServer.call(server, {:configure_filters, filters})
  end
  
  @doc """
  Gets channel metrics and statistics.
  """
  def get_metrics(server \\ __MODULE__) do
    GenServer.call(server, :get_metrics)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("Starting Algedonic Channel")
    
    state = %{
      active_signals: %{},
      signal_queue: :queue.new(),
      filters: Filtering.default_filters(),
      routing_rules: Routing.default_rules(),
      correlation_state: %{
        signal_history: [],
        pattern_cache: %{},
        correlation_matrix: %{},
        last_analysis: DateTime.utc_now()
      },
      metrics: init_metrics()
    }
    
    # Schedule periodic tasks
    schedule_signal_processing()
    schedule_correlation_analysis()
    schedule_metric_collection()
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:signal, signal}, state) do
    Logger.debug("Received algedonic signal: #{inspect(signal)}")
    
    state = update_metrics(state, :signals_received)
    
    # Validate signal
    case Signals.validate_signal(signal) do
      {:ok, validated_signal} ->
        state = process_signal(validated_signal, state)
        {:noreply, state}
        
      {:error, reason} ->
        Logger.warn("Invalid signal rejected: #{reason}")
        state = update_metrics(state, :signals_rejected)
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_call(:get_active_signals, _from, state) do
    {:reply, {:ok, state.active_signals}, state}
  end
  
  @impl true
  def handle_call({:configure_filters, filters}, _from, state) do
    case Filtering.validate_filters(filters) do
      {:ok, validated_filters} ->
        {:reply, :ok, %{state | filters: validated_filters}}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = calculate_current_metrics(state)
    {:reply, {:ok, metrics}, state}
  end
  
  @impl true
  def handle_info(:process_signals, state) do
    state = process_signal_queue(state)
    schedule_signal_processing()
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:analyze_correlations, state) do
    state = perform_correlation_analysis(state)
    schedule_correlation_analysis()
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:collect_metrics, state) do
    publish_telemetry_metrics(state)
    schedule_metric_collection()
    {:noreply, state}
  end
  
  # Private Functions
  
  defp process_signal(signal, state) do
    # Apply filters
    case Filtering.apply_filters(signal, state.filters) do
      {:pass, filtered_signal} ->
        # Check for emergency bypass
        if Signals.requires_emergency_bypass?(filtered_signal) do
          route_emergency_signal(filtered_signal, state)
        else
          queue_signal_for_processing(filtered_signal, state)
        end
        
      {:block, reason} ->
        Logger.debug("Signal blocked by filter: #{reason}")
        update_metrics(state, :signals_filtered)
    end
  end
  
  defp route_emergency_signal(signal, state) do
    Logger.warn("Emergency bypass activated for signal: #{signal.id}")
    
    # Direct routing to S5
    case Routing.emergency_route(signal) do
      {:ok, route_info} ->
        # Send directly to S5
        Alerting.send_critical_alert(signal, route_info)
        
        state
        |> Map.update(:active_signals, %{}, &Map.put(&1, signal.id, signal))
        |> update_metrics(:emergency_signals_routed)
        
      {:error, reason} ->
        Logger.error("Failed to route emergency signal: #{reason}")
        state
    end
  end
  
  defp queue_signal_for_processing(signal, state) do
    queue = :queue.in(signal, state.signal_queue)
    
    state
    |> Map.put(:signal_queue, queue)
    |> update_metrics(:signals_queued)
  end
  
  defp process_signal_queue(state) do
    case :queue.out(state.signal_queue) do
      {{:value, signal}, new_queue} ->
        state = %{state | signal_queue: new_queue}
        
        # Process signal based on severity
        state = case Routing.route_signal(signal, state.routing_rules) do
          {:ok, route_info} ->
            send_to_destination(signal, route_info, state)
            
          {:error, reason} ->
            Logger.error("Failed to route signal: #{reason}")
            state
        end
        
        # Continue processing if more signals in queue
        if :queue.is_empty(new_queue) do
          state
        else
          process_signal_queue(state)
        end
        
      {:empty, _} ->
        state
    end
  end
  
  defp send_to_destination(signal, route_info, state) do
    # Create VSM message
    message = Message.new(
      :algedonic_channel,
      route_info.destination,
      :algedonic_channel,
      :alert,
      signal,
      metadata: %{
        severity: signal.severity,
        routing: route_info
      }
    )
    
    # Send through appropriate channel
    case route_info.destination do
      :system5 -> VSMCore.System5.handle_algedonic_signal(message)
      :system4 -> VSMCore.System4.handle_algedonic_signal(message)
      :system3 -> VSMCore.System3.handle_algedonic_signal(message)
      _ -> Logger.warn("Unknown destination: #{route_info.destination}")
    end
    
    state
    |> Map.update(:active_signals, %{}, &Map.put(&1, signal.id, signal))
    |> update_metrics(:signals_routed)
  end
  
  defp perform_correlation_analysis(state) do
    # Analyze active signals for patterns
    active_signals = Map.values(state.active_signals)
    
    case Correlation.analyze_patterns(active_signals, state.correlation_state) do
      {:ok, patterns, new_correlation_state} ->
        # Process discovered patterns
        Enum.each(patterns, fn pattern ->
          if pattern.significance > 0.8 do
            # Create aggregated signal for significant patterns
            aggregated_signal = Signals.create_aggregated_signal(pattern)
            process_signal(aggregated_signal, state)
          end
        end)
        
        %{state | correlation_state: new_correlation_state}
        
      {:error, _reason} ->
        state
    end
  end
  
  defp init_metrics do
    %{
      signals_received: 0,
      signals_rejected: 0,
      signals_filtered: 0,
      signals_queued: 0,
      signals_routed: 0,
      emergency_signals_routed: 0,
      patterns_detected: 0,
      alerts_sent: 0
    }
  end
  
  defp update_metrics(state, metric) do
    Map.update_in(state, [:metrics, metric], &(&1 + 1))
  end
  
  defp calculate_current_metrics(state) do
    queue_depth = :queue.len(state.signal_queue)
    active_count = map_size(state.active_signals)
    
    Map.merge(state.metrics, %{
      queue_depth: queue_depth,
      active_signals: active_count,
      timestamp: DateTime.utc_now()
    })
  end
  
  defp publish_telemetry_metrics(state) do
    metrics = calculate_current_metrics(state)
    
    :telemetry.execute(
      [:vsm_core, :algedonic, :metrics],
      metrics,
      %{channel: :algedonic}
    )
  end
  
  defp schedule_signal_processing do
    Process.send_after(self(), :process_signals, 100)
  end
  
  defp schedule_correlation_analysis do
    Process.send_after(self(), :analyze_correlations, 5_000)
  end
  
  defp schedule_metric_collection do
    Process.send_after(self(), :collect_metrics, 10_000)
  end
end