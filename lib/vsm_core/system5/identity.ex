defmodule VSMCore.System5.Identity do
  @moduledoc """
  Identity Management for System 5
  
  Responsible for:
  - Defining and maintaining organizational identity
  - Purpose and mission management
  - Vision and strategic direction
  - Brand and cultural identity
  - Stakeholder relationship definitions
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def set_identity(identity_server, identity_config) do
    GenServer.call(identity_server, {:set_identity, identity_config})
  end
  
  def get_current_identity(identity_server) do
    GenServer.call(identity_server, :get_current_identity)
  end
  
  def check_alignment(identity_server, proposal) do
    GenServer.call(identity_server, {:check_alignment, proposal})
  end
  
  def get_relevant_aspects(identity_server, context) do
    GenServer.call(identity_server, {:get_relevant_aspects, context})
  end
  
  def update_aspect(identity_server, aspect, value) do
    GenServer.call(identity_server, {:update_aspect, aspect, value})
  end
  
  def evolve_identity(identity_server, evolution_data) do
    GenServer.call(identity_server, {:evolve_identity, evolution_data})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("S5 Identity Manager initializing...")
    
    state = %{
      identity: initialize_default_identity(),
      evolution_history: [],
      stakeholders: initialize_stakeholders(),
      brand_elements: %{},
      config: Keyword.get(opts, :config, default_config())
    }
    
    # Schedule periodic identity review
    schedule_identity_review(state.config.review_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:set_identity, identity_config}, _from, state) do
    Logger.info("Identity: Setting organizational identity")
    
    # Validate identity configuration
    case validate_identity_config(identity_config) do
      {:ok, validated_config} ->
        # Merge with existing identity
        new_identity = merge_identity(state.identity, validated_config)
        
        # Record evolution
        state = record_identity_evolution(state, new_identity)
        
        # Update state
        state = %{state | identity: new_identity}
        
        # Update brand elements
        state = update_brand_elements(state, new_identity)
        
        {:reply, {:ok, new_identity}, state}
        
      {:error, reason} = error ->
        Logger.error("Identity: Invalid configuration - #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:get_current_identity, _from, state) do
    identity_summary = %{
      purpose: state.identity.purpose,
      mission: state.identity.mission,
      vision: state.identity.vision,
      core_values: Enum.take(state.identity.core_values, 5),
      strategic_focus: state.identity.strategic_focus,
      stakeholders: summarize_stakeholders(state.stakeholders),
      brand_essence: Map.get(state.brand_elements, :essence, "Not defined"),
      last_updated: state.identity.last_updated
    }
    
    {:reply, identity_summary, state}
  end
  
  @impl true
  def handle_call({:check_alignment, proposal}, _from, state) do
    Logger.debug("Identity: Checking alignment for proposal")
    
    alignment_score = calculate_alignment_score(proposal, state.identity)
    
    {:reply, alignment_score, state}
  end
  
  @impl true
  def handle_call({:get_relevant_aspects, context}, _from, state) do
    Logger.debug("Identity: Getting relevant aspects for context: #{inspect(context.subject)}")
    
    relevant_aspects = extract_relevant_aspects(context, state.identity)
    
    {:reply, relevant_aspects, state}
  end
  
  @impl true
  def handle_call({:update_aspect, aspect, value}, _from, state) do
    Logger.info("Identity: Updating aspect #{aspect}")
    
    case update_identity_aspect(state.identity, aspect, value) do
      {:ok, updated_identity} ->
        state = %{state | identity: updated_identity}
        state = record_identity_evolution(state, updated_identity)
        {:reply, :ok, state}
        
      {:error, reason} = error ->
        Logger.error("Identity: Failed to update aspect - #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:evolve_identity, evolution_data}, _from, state) do
    Logger.info("Identity: Evolving organizational identity")
    
    # Analyze evolution requirements
    evolution_plan = analyze_evolution_needs(evolution_data, state.identity)
    
    # Apply evolutionary changes
    evolved_identity = apply_evolution(state.identity, evolution_plan)
    
    # Validate coherence
    if identity_coherent?(evolved_identity) do
      state = %{state | identity: evolved_identity}
      state = record_identity_evolution(state, evolved_identity)
      
      {:reply, {:ok, evolution_plan}, state}
    else
      {:reply, {:error, :evolution_would_break_coherence}, state}
    end
  end
  
  @impl true
  def handle_info(:review_identity, state) do
    Logger.debug("Identity: Performing periodic identity review")
    
    # Check identity health
    health_report = assess_identity_health(state)
    
    # Take corrective action if needed
    state = if health_report.needs_attention do
      initiate_identity_refresh(state, health_report)
    else
      state
    end
    
    # Schedule next review
    schedule_identity_review(state.config.review_interval)
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp default_config do
    %{
      review_interval: :timer.days(90),
      max_evolution_history: 100,
      coherence_threshold: 0.7,
      brand_consistency_check: true
    }
  end
  
  defp initialize_default_identity do
    %{
      purpose: %{
        statement: "To create sustainable value through viable systems",
        why_we_exist: "Enable organizations to thrive in complexity",
        core_contribution: "Systematic viability and resilience"
      },
      mission: %{
        statement: "Implement and maintain viable system models",
        key_activities: [
          "Design adaptive organizational structures",
          "Enable autonomous operation",
          "Ensure system viability",
          "Foster continuous evolution"
        ],
        success_metrics: ["viability_score", "adaptation_rate", "resilience_index"]
      },
      vision: %{
        statement: "A world of self-organizing, viable systems",
        time_horizon: "10 years",
        key_milestones: [
          "Full VSM implementation",
          "Autonomous operation achieved",
          "Ecosystem leadership established"
        ]
      },
      core_values: [
        %{name: "Autonomy", description: "Empower independent operation", weight: 0.25},
        %{name: "Adaptation", description: "Continuous evolution and learning", weight: 0.25},
        %{name: "Viability", description: "Long-term sustainability", weight: 0.25},
        %{name: "Integration", description: "Holistic system thinking", weight: 0.25}
      ],
      strategic_focus: %{
        primary: "System viability",
        secondary: ["Innovation", "Efficiency", "Resilience"],
        excluded: ["Short-term profit maximization", "Rigid hierarchy"]
      },
      cultural_dna: %{
        behaviors: ["Collaborative", "Adaptive", "Systemic", "Innovative"],
        mindsets: ["Growth", "Systems thinking", "Long-term orientation"],
        practices: ["Continuous learning", "Experimentation", "Feedback loops"]
      },
      last_updated: DateTime.utc_now()
    }
  end
  
  defp initialize_stakeholders do
    %{
      primary: %{
        employees: %{importance: :critical, relationship: :partnership},
        customers: %{importance: :critical, relationship: :service},
        shareholders: %{importance: :high, relationship: :accountability}
      },
      secondary: %{
        suppliers: %{importance: :high, relationship: :collaboration},
        community: %{importance: :medium, relationship: :contribution},
        regulators: %{importance: :medium, relationship: :compliance}
      },
      ecosystem: %{
        partners: %{importance: :high, relationship: :synergy},
        competitors: %{importance: :medium, relationship: :coopetition},
        industry: %{importance: :medium, relationship: :leadership}
      }
    }
  end
  
  defp validate_identity_config(config) do
    required_fields = [:purpose, :mission, :vision]
    
    missing_fields = required_fields -- Map.keys(config)
    
    if Enum.empty?(missing_fields) do
      {:ok, config}
    else
      {:error, "Missing required fields: #{inspect(missing_fields)}"}
    end
  end
  
  defp merge_identity(current_identity, new_config) do
    # Deep merge, preserving structure
    Map.merge(current_identity, new_config, fn
      _key, current_val, new_val when is_map(current_val) and is_map(new_val) ->
        Map.merge(current_val, new_val)
      _key, _current_val, new_val ->
        new_val
    end)
    |> Map.put(:last_updated, DateTime.utc_now())
  end
  
  defp record_identity_evolution(state, new_identity) do
    evolution_entry = %{
      timestamp: DateTime.utc_now(),
      changes: calculate_identity_changes(state.identity, new_identity),
      reason: "Identity update",
      version: length(state.evolution_history) + 1
    }
    
    history = [evolution_entry | state.evolution_history]
    |> Enum.take(state.config.max_evolution_history)
    
    %{state | evolution_history: history}
  end
  
  defp calculate_identity_changes(old_identity, new_identity) do
    # Simple change detection
    changed_fields = Map.keys(new_identity)
    |> Enum.filter(fn key ->
      Map.get(old_identity, key) != Map.get(new_identity, key)
    end)
    
    %{
      changed_fields: changed_fields,
      change_count: length(changed_fields)
    }
  end
  
  defp update_brand_elements(state, identity) do
    brand_elements = %{
      essence: extract_brand_essence(identity),
      personality: derive_brand_personality(identity),
      promise: formulate_brand_promise(identity),
      attributes: identify_brand_attributes(identity)
    }
    
    %{state | brand_elements: brand_elements}
  end
  
  defp extract_brand_essence(identity) do
    # Distill identity into brand essence
    purpose_keywords = extract_keywords(identity.purpose.statement)
    mission_keywords = extract_keywords(identity.mission.statement)
    
    common_themes = MapSet.intersection(
      MapSet.new(purpose_keywords),
      MapSet.new(mission_keywords)
    )
    
    if MapSet.size(common_themes) > 0 do
      Enum.join(Enum.take(common_themes, 3), ", ")
    else
      "Viability, Adaptation, Excellence"
    end
  end
  
  defp extract_keywords(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(&(String.length(&1) > 4))
    |> Enum.uniq()
  end
  
  defp derive_brand_personality(identity) do
    # Map values to personality traits
    identity.core_values
    |> Enum.map(fn value ->
      case value.name do
        "Autonomy" -> "Independent"
        "Adaptation" -> "Flexible"
        "Viability" -> "Reliable"
        "Integration" -> "Holistic"
        _ -> "Professional"
      end
    end)
  end
  
  defp formulate_brand_promise(identity) do
    "#{identity.purpose.core_contribution} through #{identity.mission.key_activities |> List.first()}"
  end
  
  defp identify_brand_attributes(identity) do
    %{
      functional: extract_functional_attributes(identity),
      emotional: extract_emotional_attributes(identity),
      experiential: extract_experiential_attributes(identity)
    }
  end
  
  defp extract_functional_attributes(identity) do
    identity.mission.key_activities
    |> Enum.take(3)
    |> Enum.map(&String.split(&1, " ") |> List.first())
  end
  
  defp extract_emotional_attributes(identity) do
    identity.cultural_dna.mindsets
  end
  
  defp extract_experiential_attributes(identity) do
    identity.cultural_dna.practices
  end
  
  defp calculate_alignment_score(proposal, identity) do
    # Calculate multi-dimensional alignment
    scores = %{
      purpose_alignment: calculate_purpose_alignment(proposal, identity.purpose),
      mission_alignment: calculate_mission_alignment(proposal, identity.mission),
      values_alignment: calculate_values_alignment(proposal, identity.core_values),
      strategic_alignment: calculate_strategic_alignment(proposal, identity.strategic_focus)
    }
    
    # Weighted average
    weights = %{
      purpose_alignment: 0.3,
      mission_alignment: 0.25,
      values_alignment: 0.25,
      strategic_alignment: 0.2
    }
    
    overall_score = scores
    |> Enum.map(fn {key, score} -> score * Map.get(weights, key, 0) end)
    |> Enum.sum()
    
    overall_score
  end
  
  defp calculate_purpose_alignment(proposal, purpose) do
    # Check if proposal aligns with organizational purpose
    proposal_keywords = extract_keywords(Map.get(proposal, :description, ""))
    purpose_keywords = extract_keywords(purpose.statement)
    
    common_keywords = MapSet.intersection(
      MapSet.new(proposal_keywords),
      MapSet.new(purpose_keywords)
    )
    
    if MapSet.size(MapSet.new(purpose_keywords)) > 0 do
      MapSet.size(common_keywords) / MapSet.size(MapSet.new(purpose_keywords))
    else
      0.5
    end
  end
  
  defp calculate_mission_alignment(proposal, mission) do
    # Check if proposal supports mission activities
    proposal_activities = Map.get(proposal, :activities, [])
    
    if Enum.empty?(proposal_activities) do
      0.5
    else
      matching_activities = Enum.count(proposal_activities, fn activity ->
        Enum.any?(mission.key_activities, &String.contains?(&1, activity))
      end)
      
      matching_activities / length(proposal_activities)
    end
  end
  
  defp calculate_values_alignment(proposal, core_values) do
    # Check if proposal reflects core values
    proposal_values = Map.get(proposal, :values_impact, %{})
    
    if map_size(proposal_values) == 0 do
      0.5
    else
      value_scores = core_values
      |> Enum.map(fn value ->
        impact = Map.get(proposal_values, String.downcase(value.name), 0)
        if impact >= 0, do: 1.0, else: 0.0
      end)
      
      Enum.sum(value_scores) / length(value_scores)
    end
  end
  
  defp calculate_strategic_alignment(proposal, strategic_focus) do
    # Check if proposal aligns with strategic focus
    proposal_focus = Map.get(proposal, :strategic_impact, [])
    
    primary_match = strategic_focus.primary in proposal_focus
    secondary_matches = Enum.count(proposal_focus, &(&1 in strategic_focus.secondary))
    excluded_matches = Enum.count(proposal_focus, &(&1 in strategic_focus.excluded))
    
    score = 0.0
    score = if primary_match, do: score + 0.5, else: score
    score = score + (secondary_matches * 0.2)
    score = score - (excluded_matches * 0.3)
    
    max(0, min(1, score))
  end
  
  defp extract_relevant_aspects(context, identity) do
    aspects = %{}
    
    # Always include purpose
    aspects = Map.put(aspects, :purpose, identity.purpose.statement)
    
    # Include relevant values
    relevant_values = identity.core_values
    |> Enum.filter(fn value ->
      context_relevant?(value, context)
    end)
    |> Enum.map(& &1.name)
    
    aspects = Map.put(aspects, :relevant_values, relevant_values)
    
    # Include strategic considerations
    if Map.get(context, :strategic_impact, false) do
      aspects = Map.put(aspects, :strategic_focus, identity.strategic_focus)
    end
    
    # Include stakeholder considerations
    affected_stakeholders = identify_affected_stakeholders(context)
    if length(affected_stakeholders) > 0 do
      aspects = Map.put(aspects, :stakeholder_impact, affected_stakeholders)
    end
    
    aspects
  end
  
  defp context_relevant?(value, context) do
    # Determine if a value is relevant to the context
    case {value.name, context.subject} do
      {"Autonomy", subject} when subject in [:delegation, :decentralization] -> true
      {"Adaptation", subject} when subject in [:change, :innovation] -> true
      {"Viability", subject} when subject in [:sustainability, :risk] -> true
      {"Integration", subject} when subject in [:coordination, :alignment] -> true
      _ -> false
    end
  end
  
  defp identify_affected_stakeholders(context) do
    stakeholder_impact = Map.get(context, :stakeholder_impact, %{})
    
    stakeholder_impact
    |> Map.keys()
    |> Enum.map(&Atom.to_string/1)
  end
  
  defp update_identity_aspect(identity, aspect, value) do
    case aspect do
      :purpose ->
        {:ok, put_in(identity, [:purpose, :statement], value)}
      :mission ->
        {:ok, put_in(identity, [:mission, :statement], value)}
      :vision ->
        {:ok, put_in(identity, [:vision, :statement], value)}
      :values ->
        {:ok, %{identity | core_values: value}}
      _ ->
        {:error, :unknown_aspect}
    end
  end
  
  defp analyze_evolution_needs(evolution_data, current_identity) do
    %{
      drivers: Map.get(evolution_data, :drivers, []),
      constraints: Map.get(evolution_data, :constraints, []),
      opportunities: Map.get(evolution_data, :opportunities, []),
      required_changes: identify_required_changes(evolution_data, current_identity),
      evolution_strategy: determine_evolution_strategy(evolution_data)
    }
  end
  
  defp identify_required_changes(evolution_data, current_identity) do
    changes = []
    
    # Environmental pressure changes
    if :market_shift in Map.get(evolution_data, :drivers, []) do
      changes = [{:strategic_focus, :adapt_to_market} | changes]
    end
    
    # Stakeholder pressure changes
    if :stakeholder_expectations in Map.get(evolution_data, :drivers, []) do
      changes = [{:stakeholder_priorities, :rebalance} | changes]
    end
    
    # Innovation pressure changes
    if :technological_disruption in Map.get(evolution_data, :drivers, []) do
      changes = [{:values, :increase_innovation_weight} | changes]
    end
    
    changes
  end
  
  defp determine_evolution_strategy(evolution_data) do
    urgency = Map.get(evolution_data, :urgency, :moderate)
    scope = Map.get(evolution_data, :scope, :focused)
    
    case {urgency, scope} do
      {:high, :comprehensive} -> :transformation
      {:high, :focused} -> :rapid_adaptation
      {:moderate, :comprehensive} -> :gradual_evolution
      {:moderate, :focused} -> :targeted_adjustment
      _ -> :minimal_change
    end
  end
  
  defp apply_evolution(identity, evolution_plan) do
    evolution_plan.required_changes
    |> Enum.reduce(identity, fn change, acc_identity ->
      apply_evolutionary_change(acc_identity, change, evolution_plan.evolution_strategy)
    end)
    |> Map.put(:last_updated, DateTime.utc_now())
  end
  
  defp apply_evolutionary_change(identity, {:strategic_focus, :adapt_to_market}, _strategy) do
    update_in(identity, [:strategic_focus, :secondary], fn secondary ->
      ["Market responsiveness" | secondary] |> Enum.uniq() |> Enum.take(4)
    end)
  end
  
  defp apply_evolutionary_change(identity, {:stakeholder_priorities, :rebalance}, _strategy) do
    # Rebalance stakeholder importance
    identity
  end
  
  defp apply_evolutionary_change(identity, {:values, :increase_innovation_weight}, _strategy) do
    update_in(identity, [:core_values], fn values ->
      Enum.map(values, fn value ->
        if value.name == "Innovation" || value.name == "Adaptation" do
          %{value | weight: min(0.35, value.weight * 1.2)}
        else
          value
        end
      end)
      |> normalize_value_weights()
    end)
  end
  
  defp apply_evolutionary_change(identity, _change, _strategy) do
    identity
  end
  
  defp normalize_value_weights(values) do
    total_weight = values |> Enum.map(& &1.weight) |> Enum.sum()
    
    if total_weight > 0 do
      Enum.map(values, fn value ->
        %{value | weight: value.weight / total_weight}
      end)
    else
      values
    end
  end
  
  defp identity_coherent?(identity) do
    # Check internal consistency
    coherence_checks = [
      purpose_mission_aligned?(identity),
      mission_vision_connected?(identity),
      values_integrated?(identity),
      no_contradictions?(identity)
    ]
    
    Enum.all?(coherence_checks)
  end
  
  defp purpose_mission_aligned?(identity) do
    # Check if mission supports purpose
    purpose_keywords = extract_keywords(identity.purpose.statement)
    mission_keywords = extract_keywords(identity.mission.statement)
    
    common_keywords = MapSet.intersection(
      MapSet.new(purpose_keywords),
      MapSet.new(mission_keywords)
    )
    
    MapSet.size(common_keywords) > 0
  end
  
  defp mission_vision_connected?(identity) do
    # Check if vision is achievable through mission
    true  # Simplified for now
  end
  
  defp values_integrated?(identity) do
    # Check if values are properly weighted
    total_weight = identity.core_values
    |> Enum.map(& &1.weight)
    |> Enum.sum()
    
    abs(total_weight - 1.0) < 0.01
  end
  
  defp no_contradictions?(identity) do
    # Check for internal contradictions
    excluded = identity.strategic_focus.excluded
    current_focus = [identity.strategic_focus.primary | identity.strategic_focus.secondary]
    
    Enum.empty?(MapSet.intersection(
      MapSet.new(excluded),
      MapSet.new(current_focus)
    ))
  end
  
  defp assess_identity_health(state) do
    identity = state.identity
    
    health_metrics = %{
      age: calculate_identity_age(identity),
      evolution_rate: calculate_evolution_rate(state.evolution_history),
      coherence: if(identity_coherent?(identity), do: 1.0, else: 0.0),
      completeness: calculate_completeness(identity),
      relevance: estimate_relevance(identity)
    }
    
    overall_health = health_metrics
    |> Map.values()
    |> Enum.sum()
    |> Kernel./(map_size(health_metrics))
    
    %{
      metrics: health_metrics,
      overall: overall_health,
      needs_attention: overall_health < 0.7,
      recommendations: generate_health_recommendations(health_metrics)
    }
  end
  
  defp calculate_identity_age(identity) do
    days_old = DateTime.diff(DateTime.utc_now(), identity.last_updated, :day)
    
    cond do
      days_old < 90 -> 1.0
      days_old < 180 -> 0.8
      days_old < 365 -> 0.6
      true -> 0.4
    end
  end
  
  defp calculate_evolution_rate(evolution_history) do
    recent_evolutions = evolution_history
    |> Enum.take(10)
    |> length()
    
    cond do
      recent_evolutions >= 5 -> 0.8  # Healthy evolution
      recent_evolutions >= 2 -> 1.0  # Optimal
      recent_evolutions >= 1 -> 0.8  # Acceptable
      true -> 0.5  # Stagnant
    end
  end
  
  defp calculate_completeness(identity) do
    required_elements = [
      identity.purpose.statement != "",
      identity.mission.statement != "",
      identity.vision.statement != "",
      length(identity.core_values) >= 3,
      map_size(identity.strategic_focus) >= 2
    ]
    
    complete_count = Enum.count(required_elements, & &1)
    complete_count / length(required_elements)
  end
  
  defp estimate_relevance(_identity) do
    # Simplified relevance estimation
    0.8
  end
  
  defp generate_health_recommendations(metrics) do
    recommendations = []
    
    recommendations = if metrics.age < 0.6 do
      ["Review and update identity statements" | recommendations]
    else
      recommendations
    end
    
    recommendations = if metrics.evolution_rate < 0.5 do
      ["Consider identity evolution to adapt to changes" | recommendations]
    else
      recommendations
    end
    
    recommendations = if metrics.coherence < 1.0 do
      ["Address identity coherence issues" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
  
  defp initiate_identity_refresh(state, health_report) do
    Logger.info("Identity: Initiating identity refresh based on health report")
    
    # Apply recommendations
    Enum.each(health_report.recommendations, fn recommendation ->
      Logger.info("Identity: Recommendation - #{recommendation}")
    end)
    
    # Mark for review
    Map.update!(state, :identity, &Map.put(&1, :needs_review, true))
  end
  
  defp summarize_stakeholders(stakeholders) do
    all_stakeholders = stakeholders
    |> Map.values()
    |> Enum.flat_map(&Map.keys/1)
    
    %{
      primary_count: map_size(stakeholders.primary),
      total_count: length(all_stakeholders),
      categories: Map.keys(stakeholders)
    }
  end
  
  defp schedule_identity_review(interval) do
    Process.send_after(self(), :review_identity, interval)
  end
end