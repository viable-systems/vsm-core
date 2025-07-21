# VSM Core Implementation Plan

## Overview

This document provides a detailed implementation plan for the VSM Core Elixir project, with specific tasks, code structures, and implementation priorities for the coder agent.

## Priority Implementation Order

### Phase 1: Foundation (Days 1-3)

#### 1.1 Project Setup
```bash
# Create new Phoenix project
mix phx.new vsm_core --no-html --no-assets --no-mailer
cd vsm_core

# Add dependencies to mix.exs
defp deps do
  [
    {:phoenix, "~> 1.7.0"},
    {:phoenix_pubsub, "~> 2.1"},
    {:telemetry, "~> 1.2"},
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.0"},
    {:jason, "~> 1.2"},
    {:plug_cowboy, "~> 2.5"},
    {:absinthe, "~> 1.7"},
    {:absinthe_phoenix, "~> 2.0"},
    {:eventstore, "~> 1.4"},
    {:commanded, "~> 1.4"},
    {:libgraph, "~> 0.16"},
    {:ex_doc, "~> 0.29", only: :dev, runtime: false},
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
    {:stream_data, "~> 0.5", only: :test}
  ]
end
```

#### 1.2 Core Module Structure
```elixir
# lib/vsm_core.ex
defmodule VsmCore do
  @moduledoc """
  Main API for VSM Core functionality.
  """
  
  @doc """
  Starts a new VSM system with the given configuration.
  """
  def start_system(name, config \\ %{}) do
    VsmCore.SystemRegistry.start_system(name, config)
  end
  
  @doc """
  Sends an operational command to System 1.
  """
  def execute_operation(system, operation) do
    VsmCore.Systems.System1.execute(system, operation)
  end
  
  @doc """
  Retrieves current variety metrics.
  """
  def get_variety_metrics(system) do
    VsmCore.Variety.Calculator.calculate_system_variety(system)
  end
end
```

#### 1.3 Application Supervisor
```elixir
# lib/vsm_core/application.ex
defmodule VsmCore.Application do
  use Application
  
  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      VsmCoreWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: VsmCore.PubSub},
      # Start the System Registry
      VsmCore.SystemRegistry,
      # Start the Endpoint (http/https)
      VsmCoreWeb.Endpoint
    ]
    
    opts = [strategy: :one_for_one, name: VsmCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Phase 2: System Implementation (Days 4-8)

#### 2.1 System 1 - Operations
```elixir
# lib/vsm_core/systems/system1/operational_unit.ex
defmodule VsmCore.Systems.System1.OperationalUnit do
  use GenServer
  require Logger
  
  defstruct [
    :id,
    :name,
    :type,
    :state,
    :environment_interface,
    :local_regulator,
    :performance_metrics,
    :resource_allocation,
    :variety_state,
    :operational_capacity,
    :constraints
  ]
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:id]))
  end
  
  def execute_operation(unit_id, operation) do
    GenServer.call(via_tuple(unit_id), {:execute, operation})
  end
  
  def get_performance_metrics(unit_id) do
    GenServer.call(via_tuple(unit_id), :get_metrics)
  end
  
  def report_to_system3(unit_id, report_type \\ :routine) do
    GenServer.cast(via_tuple(unit_id), {:report, report_type})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: opts[:id],
      name: opts[:name],
      type: opts[:type] || :generic,
      state: :initializing,
      environment_interface: init_environment_interface(opts),
      local_regulator: init_local_regulator(opts),
      performance_metrics: %{},
      resource_allocation: %{},
      variety_state: %{states: 0, entropy: 0.0},
      operational_capacity: opts[:capacity] || 100,
      constraints: opts[:constraints] || []
    }
    
    # Schedule periodic tasks
    schedule_performance_update()
    schedule_variety_calculation()
    
    {:ok, %{state | state: :operational}}
  end
  
  @impl true
  def handle_call({:execute, operation}, _from, state) do
    case validate_operation(operation, state) do
      :ok ->
        {result, new_state} = perform_operation(operation, state)
        emit_telemetry(:operation_executed, %{operation: operation, result: result})
        {:reply, {:ok, result}, new_state}
      
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
  def handle_cast({:report, report_type}, state) do
    report = generate_report(report_type, state)
    send_to_system3(report)
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:update_performance, state) do
    new_metrics = measure_performance(state)
    new_state = %{state | performance_metrics: new_metrics}
    
    # Notify System 2 for coordination
    notify_system2(:performance_update, new_metrics)
    
    schedule_performance_update()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:calculate_variety, state) do
    variety = VsmCore.Variety.Calculator.calculate_operational_variety(state)
    new_state = %{state | variety_state: variety}
    
    # Check if variety management needed
    if variety.entropy > state.operational_capacity do
      request_variety_attenuation(variety)
    end
    
    schedule_variety_calculation()
    {:noreply, new_state}
  end
  
  # Private functions
  
  defp via_tuple(id) do
    {:via, Registry, {VsmCore.Registry, {:system1_unit, id}}}
  end
  
  defp schedule_performance_update do
    Process.send_after(self(), :update_performance, 5_000)
  end
  
  defp schedule_variety_calculation do
    Process.send_after(self(), :calculate_variety, 10_000)
  end
  
  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:vsm_core, :system1, event],
      %{count: 1},
      metadata
    )
  end
end
```

#### 2.2 System 2 - Coordination
```elixir
# lib/vsm_core/systems/system2/coordinator.ex
defmodule VsmCore.Systems.System2.Coordinator do
  use GenServer
  require Logger
  
  defstruct [
    :coordination_protocols,
    :anti_oscillation_rules,
    :shared_resources,
    :scheduling_constraints,
    :harmony_metrics,
    :unit_states,
    :conflict_history
  ]
  
  # Anti-oscillation implementation
  def prevent_oscillation(unit_states) do
    detect_patterns(unit_states)
    |> apply_dampening()
    |> generate_coordination_signals()
  end
  
  defp detect_patterns(states) do
    # Implement pattern detection algorithm
    # Look for repeating state changes that indicate oscillation
  end
  
  defp apply_dampening(patterns) do
    # Apply control theory dampening to prevent oscillations
  end
end
```

#### 2.3 System 3 - Control
```elixir
# lib/vsm_core/systems/system3/controller.ex
defmodule VsmCore.Systems.System3.Controller do
  use GenServer
  
  defstruct [
    :control_policies,
    :resource_pools,
    :performance_standards,
    :synergy_targets,
    :audit_schedule,
    :operational_data,
    :optimization_state
  ]
  
  # Resource allocation algorithm
  def allocate_resources(requests, available_resources, constraints) do
    requests
    |> prioritize_by_policy()
    |> optimize_allocation(available_resources)
    |> apply_constraints(constraints)
    |> generate_allocation_plan()
  end
  
  # Synergy creation
  def create_synergy(unit_performances) do
    identify_complementary_capabilities(unit_performances)
    |> design_collaborative_processes()
    |> implement_synergy_protocols()
  end
end
```

#### 2.4 System 4 - Intelligence
```elixir
# lib/vsm_core/systems/system4/intelligence.ex
defmodule VsmCore.Systems.System4.Intelligence do
  use GenServer
  
  defstruct [
    :environmental_model,
    :future_scenarios,
    :opportunity_radar,
    :threat_matrix,
    :innovation_pipeline,
    :scanning_frequency,
    :prediction_horizon
  ]
  
  # Environmental scanning with pattern recognition
  def scan_environment(data_sources) do
    aggregate_external_data(data_sources)
    |> identify_trends()
    |> detect_weak_signals()
    |> assess_implications()
  end
  
  # Future modeling using probabilistic methods
  def model_future(current_state, time_horizon) do
    generate_scenarios(current_state)
    |> calculate_probabilities()
    |> evaluate_impacts()
    |> rank_by_likelihood_and_impact()
  end
end
```

#### 2.5 System 5 - Policy
```elixir
# lib/vsm_core/systems/system5/policy_maker.ex
defmodule VsmCore.Systems.System5.PolicyMaker do
  use GenServer
  
  defstruct [
    :identity,
    :purpose,
    :values,
    :policies,
    :ethos,
    :decision_log,
    :conflict_resolution_matrix
  ]
  
  # Conflict resolution between S3 and S4
  def resolve_conflict(s3_perspective, s4_perspective) do
    analyze_perspectives(s3_perspective, s4_perspective)
    |> apply_value_framework()
    |> generate_balanced_decision()
    |> communicate_rationale()
  end
  
  # Identity maintenance
  def maintain_identity(internal_state, external_pressures) do
    assess_identity_alignment(internal_state)
    |> evaluate_adaptation_needs(external_pressures)
    |> update_while_preserving_core()
  end
end
```

### Phase 3: Channel Implementation (Days 9-14)

#### 3.1 Temporal Variety Channel (Target: 1,368 lines)
```elixir
# lib/vsm_core/channels/temporal_channel.ex
defmodule VsmCore.Channels.TemporalChannel do
  @moduledoc """
  Temporal Variety Channel - Manages time-based complexity and variety dynamics.
  
  This channel handles:
  - Multi-timescale variety tracking
  - Temporal pattern recognition
  - Causality chain analysis
  - Time-based variety prediction
  - Synchronization across different time horizons
  """
  
  use GenServer
  require Logger
  
  alias VsmCore.Variety.Calculator
  alias VsmCore.Channels.TemporalChannel.{
    TimeWindow,
    TemporalPattern,
    CausalityAnalyzer,
    VarietyPredictor,
    Synchronizer
  }
  
  @type time_window :: %{
    start: DateTime.t(),
    end: DateTime.t(),
    granularity: atom(),
    data: list()
  }
  
  @type temporal_pattern :: %{
    pattern_type: atom(),
    frequency: float(),
    amplitude: float(),
    phase: float(),
    confidence: float()
  }
  
  defstruct [
    :id,
    :time_windows,
    :variety_history,
    :temporal_patterns,
    :prediction_models,
    :synchronization_state,
    :causality_chains,
    :buffer_size,
    :analysis_interval
  ]
  
  # Client API
  
  @doc """
  Records variety data with timestamp for temporal analysis.
  """
  def record_variety(channel, variety_data, timestamp \\ DateTime.utc_now()) do
    GenServer.cast(channel, {:record_variety, variety_data, timestamp})
  end
  
  @doc """
  Analyzes temporal patterns within the specified window.
  """
  def analyze_patterns(channel, window_size, opts \\ []) do
    GenServer.call(channel, {:analyze_patterns, window_size, opts})
  end
  
  @doc """
  Predicts future variety based on historical patterns.
  """
  def predict_variety(channel, time_horizon, confidence_level \\ 0.95) do
    GenServer.call(channel, {:predict_variety, time_horizon, confidence_level})
  end
  
  @doc """
  Synchronizes temporal states across multiple systems.
  """
  def synchronize_states(channel, system_states) do
    GenServer.call(channel, {:synchronize, system_states})
  end
  
  @doc """
  Analyzes causality relationships in the temporal data.
  """
  def analyze_causality(channel, events, time_range) do
    GenServer.call(channel, {:analyze_causality, events, time_range})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: opts[:id] || generate_id(),
      time_windows: initialize_time_windows(opts),
      variety_history: CircularBuffer.new(opts[:buffer_size] || 10_000),
      temporal_patterns: %{},
      prediction_models: initialize_models(opts),
      synchronization_state: %{},
      causality_chains: %{},
      buffer_size: opts[:buffer_size] || 10_000,
      analysis_interval: opts[:analysis_interval] || 60_000
    }
    
    # Schedule periodic analysis
    schedule_pattern_analysis()
    schedule_prediction_update()
    schedule_synchronization()
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_variety, variety_data, timestamp}, state) do
    # Record in appropriate time windows
    updated_windows = update_time_windows(state.time_windows, variety_data, timestamp)
    
    # Add to history buffer
    history_entry = %{
      timestamp: timestamp,
      variety: variety_data,
      entropy: Calculator.calculate_entropy(variety_data)
    }
    updated_history = CircularBuffer.add(state.variety_history, history_entry)
    
    # Check for immediate patterns
    if should_trigger_analysis?(updated_history) do
      send(self(), :analyze_immediate_patterns)
    end
    
    new_state = %{state | 
      time_windows: updated_windows,
      variety_history: updated_history
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:analyze_patterns, window_size, opts}, _from, state) do
    patterns = TemporalPattern.detect(
      state.variety_history,
      window_size,
      opts
    )
    
    # Update pattern registry
    updated_patterns = Map.merge(state.temporal_patterns, patterns)
    
    # Generate pattern report
    report = generate_pattern_report(patterns, state)
    
    {:reply, {:ok, report}, %{state | temporal_patterns: updated_patterns}}
  end
  
  @impl true
  def handle_call({:predict_variety, time_horizon, confidence_level}, _from, state) do
    prediction = VarietyPredictor.predict(
      state.variety_history,
      state.temporal_patterns,
      state.prediction_models,
      time_horizon,
      confidence_level
    )
    
    # Update models based on prediction
    updated_models = VarietyPredictor.update_models(
      state.prediction_models,
      prediction
    )
    
    {:reply, {:ok, prediction}, %{state | prediction_models: updated_models}}
  end
  
  @impl true
  def handle_call({:synchronize, system_states}, _from, state) do
    sync_result = Synchronizer.synchronize(
      system_states,
      state.synchronization_state
    )
    
    # Update synchronization state
    new_sync_state = Map.merge(state.synchronization_state, sync_result.state)
    
    # Generate synchronization report
    report = generate_sync_report(sync_result, state)
    
    {:reply, {:ok, report}, %{state | synchronization_state: new_sync_state}}
  end
  
  @impl true
  def handle_call({:analyze_causality, events, time_range}, _from, state) do
    causality_result = CausalityAnalyzer.analyze(
      events,
      state.variety_history,
      time_range
    )
    
    # Update causality chains
    updated_chains = update_causality_chains(
      state.causality_chains,
      causality_result
    )
    
    {:reply, {:ok, causality_result}, %{state | causality_chains: updated_chains}}
  end
  
  @impl true
  def handle_info(:pattern_analysis, state) do
    # Perform scheduled pattern analysis
    patterns = analyze_all_timescales(state)
    
    # Notify interested systems
    broadcast_pattern_update(patterns)
    
    schedule_pattern_analysis()
    {:noreply, %{state | temporal_patterns: patterns}}
  end
  
  @impl true
  def handle_info(:update_predictions, state) do
    # Update all prediction models
    updated_models = update_all_predictions(state)
    
    schedule_prediction_update()
    {:noreply, %{state | prediction_models: updated_models}}
  end
  
  @impl true
  def handle_info(:synchronize_systems, state) do
    # Perform periodic synchronization
    sync_state = perform_system_synchronization(state)
    
    schedule_synchronization()
    {:noreply, %{state | synchronization_state: sync_state}}
  end
  
  # Private Functions
  
  defp initialize_time_windows(opts) do
    %{
      millisecond: TimeWindow.new(:millisecond, opts[:ms_window] || 1000),
      second: TimeWindow.new(:second, opts[:sec_window] || 60),
      minute: TimeWindow.new(:minute, opts[:min_window] || 60),
      hour: TimeWindow.new(:hour, opts[:hour_window] || 24),
      day: TimeWindow.new(:day, opts[:day_window] || 30),
      week: TimeWindow.new(:week, opts[:week_window] || 52),
      month: TimeWindow.new(:month, opts[:month_window] || 12)
    }
  end
  
  defp initialize_models(opts) do
    %{
      arima: VarietyPredictor.init_arima(opts[:arima_config] || %{}),
      lstm: VarietyPredictor.init_lstm(opts[:lstm_config] || %{}),
      prophet: VarietyPredictor.init_prophet(opts[:prophet_config] || %{}),
      ensemble: VarietyPredictor.init_ensemble(opts[:ensemble_config] || %{})
    }
  end
  
  defp update_time_windows(windows, variety_data, timestamp) do
    Enum.reduce(windows, %{}, fn {scale, window}, acc ->
      updated_window = TimeWindow.add_data(window, variety_data, timestamp)
      Map.put(acc, scale, updated_window)
    end)
  end
  
  defp should_trigger_analysis?(history) do
    # Implement trigger logic based on:
    # - Buffer fullness
    # - Variance in recent data
    # - Time since last analysis
    # - Anomaly detection
    
    recent_variance = calculate_recent_variance(history)
    recent_variance > threshold_for_immediate_analysis()
  end
  
  defp analyze_all_timescales(state) do
    Enum.reduce(state.time_windows, %{}, fn {scale, window}, acc ->
      patterns = TemporalPattern.detect_in_window(window)
      Map.put(acc, scale, patterns)
    end)
  end
  
  defp update_all_predictions(state) do
    Enum.reduce(state.prediction_models, %{}, fn {model_type, model}, acc ->
      updated_model = VarietyPredictor.update_model(
        model,
        state.variety_history,
        state.temporal_patterns
      )
      Map.put(acc, model_type, updated_model)
    end)
  end
  
  defp perform_system_synchronization(state) do
    # Get current states from all systems
    system_states = gather_system_states()
    
    # Perform synchronization
    Synchronizer.synchronize_all(
      system_states,
      state.synchronization_state,
      state.time_windows
    )
  end
  
  defp broadcast_pattern_update(patterns) do
    Phoenix.PubSub.broadcast(
      VsmCore.PubSub,
      "temporal_patterns",
      {:patterns_updated, patterns}
    )
  end
  
  defp generate_pattern_report(patterns, state) do
    %{
      detected_patterns: patterns,
      confidence_scores: calculate_pattern_confidence(patterns),
      dominant_frequencies: extract_dominant_frequencies(patterns),
      phase_relationships: analyze_phase_relationships(patterns),
      recommendations: generate_pattern_recommendations(patterns, state)
    }
  end
  
  defp generate_sync_report(sync_result, state) do
    %{
      synchronized_systems: sync_result.synchronized,
      lag_analysis: sync_result.lag_analysis,
      coordination_quality: sync_result.quality_score,
      recommendations: sync_result.recommendations
    }
  end
  
  defp update_causality_chains(existing_chains, new_results) do
    Map.merge(existing_chains, new_results.chains, fn _k, v1, v2 ->
      merge_causality_chains(v1, v2)
    end)
  end
  
  defp schedule_pattern_analysis do
    Process.send_after(self(), :pattern_analysis, 60_000)
  end
  
  defp schedule_prediction_update do
    Process.send_after(self(), :update_predictions, 300_000)
  end
  
  defp schedule_synchronization do
    Process.send_after(self(), :synchronize_systems, 30_000)
  end
  
  # Additional 500+ lines of implementation details...
  # Including TimeWindow, TemporalPattern, CausalityAnalyzer modules
end
```

#### 3.2 Algedonic Channel (Target: 814 lines)
```elixir
# lib/vsm_core/channels/algedonic_channel.ex
defmodule VsmCore.Channels.AlgedonicChannel do
  @moduledoc """
  High-priority bypass channel for critical signals.
  
  Implements sophisticated filtering, routing, and escalation
  for pain/pleasure signals that require immediate attention.
  """
  
  use GenServer
  require Logger
  
  alias VsmCore.Channels.AlgedonicChannel.{
    SignalFilter,
    Router,
    EscalationEngine,
    ResponseProtocol
  }
  
  @type severity :: :low | :medium | :high | :critical | :emergency
  @type signal :: %{
    id: String.t(),
    severity: severity(),
    source: atom(),
    timestamp: DateTime.t(),
    payload: map(),
    metadata: map()
  }
  
  defstruct [
    :signal_queue,
    :severity_filters,
    :routing_rules,
    :escalation_matrix,
    :response_protocols,
    :signal_history,
    :dampening_state,
    :correlation_engine
  ]
  
  # Client API
  
  @doc """
  Emits an algedonic signal with specified severity.
  """
  def emit_signal(channel, severity, source, payload) do
    signal = create_signal(severity, source, payload)
    GenServer.cast(channel, {:emit_signal, signal})
  end
  
  @doc """
  Emergency signal that bypasses all filters.
  """
  def emergency!(channel, source, payload) do
    signal = create_signal(:emergency, source, payload)
    GenServer.call(channel, {:emergency_signal, signal})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      signal_queue: :queue.new(),
      severity_filters: init_severity_filters(opts),
      routing_rules: init_routing_rules(opts),
      escalation_matrix: init_escalation_matrix(opts),
      response_protocols: init_response_protocols(opts),
      signal_history: CircularBuffer.new(opts[:history_size] || 1000),
      dampening_state: %{},
      correlation_engine: init_correlation_engine(opts)
    }
    
    # Start signal processor
    schedule_signal_processing()
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:emit_signal, signal}, state) do
    # Apply initial filtering
    case SignalFilter.filter(signal, state.severity_filters) do
      {:ok, filtered_signal} ->
        # Add to queue for processing
        updated_queue = :queue.in(filtered_signal, state.signal_queue)
        {:noreply, %{state | signal_queue: updated_queue}}
      
      {:filtered, reason} ->
        log_filtered_signal(signal, reason)
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_call({:emergency_signal, signal}, _from, state) do
    # Bypass all filters for emergency
    result = process_emergency_signal(signal, state)
    
    # Update history
    updated_history = CircularBuffer.add(state.signal_history, signal)
    
    {:reply, result, %{state | signal_history: updated_history}}
  end
  
  @impl true
  def handle_info(:process_signals, state) do
    # Process queued signals
    {processed_state, results} = process_signal_queue(state)
    
    # Handle results
    Enum.each(results, &handle_signal_result/1)
    
    # Schedule next processing
    schedule_signal_processing()
    
    {:noreply, processed_state}
  end
  
  # Private Functions
  
  defp process_signal_queue(state) do
    case :queue.out(state.signal_queue) do
      {{:value, signal}, remaining_queue} ->
        # Process signal through routing and escalation
        result = process_signal(signal, state)
        
        # Update state based on processing
        updated_state = update_state_after_processing(state, signal, result)
        updated_state = %{updated_state | signal_queue: remaining_queue}
        
        # Continue processing
        process_signal_queue(updated_state)
      
      {:empty, _queue} ->
        {state, []}
    end
  end
  
  defp process_signal(signal, state) do
    signal
    |> apply_dampening(state.dampening_state)
    |> correlate_with_history(state.correlation_engine, state.signal_history)
    |> route_signal(state.routing_rules)
    |> check_escalation(state.escalation_matrix)
    |> execute_response(state.response_protocols)
  end
  
  defp process_emergency_signal(signal, state) do
    # Direct routing to System 5
    Router.route_to_system5(signal)
    
    # Execute emergency protocols
    ResponseProtocol.execute_emergency(signal, state.response_protocols)
    
    # Notify all systems
    broadcast_emergency(signal)
    
    {:ok, :emergency_handled}
  end
  
  # Additional 400+ lines of implementation...
end
```

### Phase 4: Variety Engineering (Days 15-17)

#### 4.1 Shannon Entropy Calculator
```elixir
# lib/vsm_core/variety/calculator.ex
defmodule VsmCore.Variety.Calculator do
  @moduledoc """
  Implements variety calculations using Shannon entropy and other measures.
  """
  
  @doc """
  Calculates Shannon entropy: H = -Σ(p_i * log2(p_i))
  """
  def calculate_entropy(state_distribution) when is_map(state_distribution) do
    total = Enum.sum(Map.values(state_distribution))
    
    if total == 0 do
      0.0
    else
      state_distribution
      |> Enum.map(fn {_state, count} -> count / total end)
      |> Enum.reject(&(&1 == 0))
      |> Enum.reduce(0, fn prob, acc ->
        acc - (prob * :math.log2(prob))
      end)
    end
  end
  
  @doc """
  Calculates variety as the number of possible states.
  """
  def calculate_variety(states) when is_list(states) do
    states
    |> Enum.uniq()
    |> length()
  end
  
  @doc """
  Calculates the variety ratio between controller and controlled.
  """
  def calculate_variety_ratio(controller_variety, controlled_variety) do
    if controlled_variety == 0 do
      :infinity
    else
      controller_variety / controlled_variety
    end
  end
  
  @doc """
  Determines if requisite variety is satisfied (Ashby's Law).
  """
  def requisite_variety_satisfied?(controller_variety, controlled_variety) do
    calculate_variety_ratio(controller_variety, controlled_variety) >= 1.0
  end
  
  @doc """
  Calculates the variety gap that needs to be addressed.
  """
  def variety_gap(environmental_variety, system_variety) do
    max(0, environmental_variety - system_variety)
  end
  
  @doc """
  Calculates variety amplification needed.
  """
  def amplification_needed(current_variety, required_variety) do
    if current_variety == 0 do
      required_variety
    else
      required_variety / current_variety
    end
  end
  
  @doc """
  Calculates variety attenuation needed.
  """
  def attenuation_needed(current_variety, maximum_variety) do
    if maximum_variety == 0 do
      0
    else
      max(0, current_variety - maximum_variety) / current_variety
    end
  end
end
```

#### 4.2 Variety Attenuator
```elixir
# lib/vsm_core/variety/attenuator.ex
defmodule VsmCore.Variety.Attenuator do
  @moduledoc """
  Implements variety reduction strategies.
  """
  
  def attenuate(variety_source, strategy) do
    case strategy do
      :filtering -> apply_filtering(variety_source)
      :categorization -> apply_categorization(variety_source)
      :aggregation -> apply_aggregation(variety_source)
      :sampling -> apply_sampling(variety_source)
      :threshold -> apply_threshold(variety_source)
      _ -> {:error, :unknown_strategy}
    end
  end
  
  defp apply_filtering(source) do
    # Implement filtering logic
  end
  
  defp apply_categorization(source) do
    # Group similar states
  end
  
  defp apply_aggregation(source) do
    # Combine multiple states
  end
end
```

### Phase 5: Integration & Testing (Days 18-21)

#### 5.1 Phoenix LiveView Dashboard
```elixir
# lib/vsm_core_web/live/dashboard_live.ex
defmodule VsmCoreWeb.DashboardLive do
  use VsmCoreWeb, :live_view
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to updates
      Phoenix.PubSub.subscribe(VsmCore.PubSub, "vsm_updates")
      
      # Start periodic updates
      :timer.send_interval(1000, self(), :update_metrics)
    end
    
    {:ok, assign(socket, 
      systems_status: load_systems_status(),
      variety_metrics: load_variety_metrics(),
      channel_activity: load_channel_activity()
    )}
  end
  
  @impl true
  def handle_info(:update_metrics, socket) do
    {:noreply, 
     socket
     |> assign(:systems_status, load_systems_status())
     |> assign(:variety_metrics, load_variety_metrics())
     |> assign(:channel_activity, load_channel_activity())
    }
  end
end
```

#### 5.2 GraphQL Schema
```elixir
# lib/vsm_core_web/schema.ex
defmodule VsmCoreWeb.Schema do
  use Absinthe.Schema
  
  query do
    field :system_status, :system_status do
      arg :system_id, non_null(:id)
      resolve &Resolvers.System.get_status/3
    end
    
    field :variety_metrics, :variety_metrics do
      arg :system_id, non_null(:id)
      resolve &Resolvers.Variety.get_metrics/3
    end
  end
  
  mutation do
    field :execute_operation, :operation_result do
      arg :system_id, non_null(:id)
      arg :operation, non_null(:operation_input)
      resolve &Resolvers.System.execute_operation/3
    end
  end
  
  subscription do
    field :system_updates, :system_update do
      arg :system_id, non_null(:id)
      
      config fn args, _ ->
        {:ok, topic: "system:#{args.system_id}"}
      end
      
      trigger :execute_operation, topic: fn operation ->
        "system:#{operation.system_id}"
      end
    end
  end
end
```

## Testing Strategy

### Unit Tests
```elixir
# test/vsm_core/variety/calculator_test.exs
defmodule VsmCore.Variety.CalculatorTest do
  use ExUnit.Case, async: true
  
  alias VsmCore.Variety.Calculator
  
  describe "calculate_entropy/1" do
    test "returns 0 for single state" do
      assert Calculator.calculate_entropy(%{state1: 100}) == 0.0
    end
    
    test "calculates correct entropy for uniform distribution" do
      # For uniform distribution of n states, H = log2(n)
      distribution = %{a: 25, b: 25, c: 25, d: 25}
      assert_in_delta Calculator.calculate_entropy(distribution), 2.0, 0.001
    end
  end
end
```

### Property-Based Tests
```elixir
# test/vsm_core/properties/variety_test.exs
defmodule VsmCore.Properties.VarietyTest do
  use ExUnit.Case
  use ExUnitProperties
  
  property "entropy is always non-negative" do
    check all distribution <- distribution_generator() do
      entropy = Calculator.calculate_entropy(distribution)
      assert entropy >= 0
    end
  end
  
  property "requisite variety law holds" do
    check all controller <- positive_integer(),
              controlled <- positive_integer() do
      satisfied = Calculator.requisite_variety_satisfied?(controller, controlled)
      assert satisfied == (controller >= controlled)
    end
  end
end
```

## Implementation Priorities

### Week 1: Core Foundation
1. Project setup and dependencies
2. Basic supervision tree
3. System 1 implementation
4. System 2 coordination
5. Basic telemetry

### Week 2: Complete Systems
1. System 3 control mechanisms
2. System 4 intelligence
3. System 5 policy
4. Inter-system communication
5. Basic channels

### Week 3: Advanced Channels
1. Temporal variety channel (1,368 lines)
2. Algedonic channel (814 lines)
3. Channel integration
4. Channel testing

### Week 4: Variety & Integration
1. Variety calculations
2. Attenuation/Amplification
3. Phoenix LiveView dashboard
4. GraphQL API
5. Final testing and documentation

## Key Implementation Notes

1. **Use GenServer for all subsystems** - Provides state management and fault tolerance
2. **Implement proper supervision trees** - Ensure system resilience
3. **Use Phoenix.PubSub for broadcasting** - Efficient message distribution
4. **Implement CircularBuffer for history** - Memory-efficient time series
5. **Use Telemetry for all metrics** - Consistent observability
6. **Property-based testing for variety calculations** - Ensure mathematical correctness
7. **Event sourcing for audit trail** - Complete system history
8. **CQRS pattern for read/write separation** - Performance optimization

## Success Metrics

- All tests passing (100% critical path coverage)
- Temporal channel: 1,368+ lines with full functionality
- Algedonic channel: 814+ lines with sophisticated filtering
- Performance: <10ms variety calculations, <1ms channel routing
- Documentation: Complete ExDoc for all public APIs
- LiveView dashboard: Real-time updates with <100ms latency