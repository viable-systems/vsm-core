defmodule VSMCore.System5.Decisions do
  @moduledoc """
  Strategic Decision Making for System 5
  
  Responsible for:
  - Ultimate decision authority
  - Strategic choice evaluation
  - Decision framework management
  - Critical decision escalation
  - Decision history and learning
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def make_decision(decisions_server, decision_context, identity_input, values_input) do
    GenServer.call(decisions_server, {:make_decision, decision_context, identity_input, values_input})
  end
  
  def evaluate_options(decisions_server, options, criteria) do
    GenServer.call(decisions_server, {:evaluate_options, options, criteria})
  end
  
  def get_decision_history(decisions_server, filters \\ %{}) do
    GenServer.call(decisions_server, {:get_decision_history, filters})
  end
  
  def review_decision(decisions_server, decision_id, outcome_data) do
    GenServer.call(decisions_server, {:review_decision, decision_id, outcome_data})
  end
  
  def get_decision_framework(decisions_server) do
    GenServer.call(decisions_server, :get_decision_framework)
  end
  
  def update_decision_criteria(decisions_server, criteria_updates) do
    GenServer.call(decisions_server, {:update_decision_criteria, criteria_updates})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("S5 Decision Engine initializing...")
    
    state = %{
      decision_framework: initialize_decision_framework(),
      decision_history: [],
      decision_patterns: %{},
      learning_data: %{},
      active_decisions: %{},
      config: Keyword.get(opts, :config, default_config())
    }
    
    # Schedule periodic decision review
    schedule_decision_review(state.config.review_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:make_decision, decision_context, identity_input, values_input}, _from, state) do
    Logger.info("Decisions: Making decision on: #{decision_context.subject}")
    
    # Generate decision ID
    decision_id = generate_decision_id()
    
    # Analyze decision context
    analysis = analyze_decision_context(decision_context, identity_input, values_input, state)
    
    # Generate options if not provided
    options = Map.get(decision_context, :options, generate_decision_options(decision_context, analysis))
    
    # Evaluate options
    evaluated_options = evaluate_all_options(options, analysis, state)
    
    # Select best option
    selected_option = select_best_option(evaluated_options, decision_context)
    
    # Formulate decision
    decision = formulate_decision(
      decision_id,
      decision_context,
      selected_option,
      analysis,
      evaluated_options
    )
    
    # Record decision
    state = record_decision(state, decision)
    
    # Track active decision
    state = if decision.requires_monitoring do
      track_active_decision(state, decision)
    else
      state
    end
    
    {:reply, decision, state}
  end
  
  @impl true
  def handle_call({:evaluate_options, options, criteria}, _from, state) do
    Logger.debug("Decisions: Evaluating #{length(options)} options")
    
    evaluations = options
    |> Enum.map(fn option ->
      score = evaluate_option(option, criteria, state.decision_framework)
      {option, score}
    end)
    |> Enum.sort_by(fn {_option, score} -> score.total end, :desc)
    
    {:reply, {:ok, evaluations}, state}
  end
  
  @impl true
  def handle_call({:get_decision_history, filters}, _from, state) do
    Logger.debug("Decisions: Retrieving decision history")
    
    filtered_history = apply_history_filters(state.decision_history, filters)
    
    {:reply, {:ok, filtered_history}, state}
  end
  
  @impl true
  def handle_call({:review_decision, decision_id, outcome_data}, _from, state) do
    Logger.info("Decisions: Reviewing decision #{decision_id}")
    
    case find_decision(state.decision_history, decision_id) do
      nil ->
        {:reply, {:error, :decision_not_found}, state}
        
      decision ->
        # Analyze outcome
        review = analyze_decision_outcome(decision, outcome_data)
        
        # Update decision record
        updated_decision = Map.merge(decision, %{
          review: review,
          reviewed_at: DateTime.utc_now()
        })
        
        # Update history
        state = update_decision_in_history(state, updated_decision)
        
        # Learn from outcome
        state = learn_from_decision(state, updated_decision, review)
        
        {:reply, {:ok, review}, state}
    end
  end
  
  @impl true
  def handle_call(:get_decision_framework, _from, state) do
    framework_summary = %{
      criteria: summarize_criteria(state.decision_framework.criteria),
      weights: state.decision_framework.weights,
      thresholds: state.decision_framework.thresholds,
      patterns: Map.keys(state.decision_patterns),
      learning_enabled: state.config.enable_learning
    }
    
    {:reply, framework_summary, state}
  end
  
  @impl true
  def handle_call({:update_decision_criteria, criteria_updates}, _from, state) do
    Logger.info("Decisions: Updating decision criteria")
    
    updated_framework = update_framework_criteria(state.decision_framework, criteria_updates)
    state = %{state | decision_framework: updated_framework}
    
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_info(:review_decisions, state) do
    Logger.debug("Decisions: Performing periodic decision review")
    
    # Review active decisions
    state = review_active_decisions(state)
    
    # Analyze patterns
    patterns = analyze_decision_patterns(state.decision_history)
    state = %{state | decision_patterns: patterns}
    
    # Update learning data
    state = update_learning_data(state)
    
    # Schedule next review
    schedule_decision_review(state.config.review_interval)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:decision_timeout, decision_id}, state) do
    Logger.warn("Decisions: Decision #{decision_id} timed out")
    
    state = handle_decision_timeout(state, decision_id)
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp default_config do
    %{
      review_interval: :timer.hours(24),
      max_history_size: 1000,
      decision_timeout: :timer.hours(72),
      enable_learning: true,
      confidence_threshold: 0.7
    }
  end
  
  defp initialize_decision_framework do
    %{
      criteria: %{
        strategic_alignment: %{
          description: "Alignment with organizational strategy",
          weight: 0.25,
          evaluation_method: :score_based
        },
        value_consistency: %{
          description: "Consistency with core values",
          weight: 0.20,
          evaluation_method: :binary_check
        },
        risk_assessment: %{
          description: "Risk level and mitigation",
          weight: 0.15,
          evaluation_method: :risk_matrix
        },
        resource_efficiency: %{
          description: "Efficient use of resources",
          weight: 0.15,
          evaluation_method: :ratio_analysis
        },
        stakeholder_impact: %{
          description: "Impact on stakeholders",
          weight: 0.15,
          evaluation_method: :impact_assessment
        },
        long_term_viability: %{
          description: "Long-term sustainability",
          weight: 0.10,
          evaluation_method: :projection_based
        }
      },
      weights: %{
        immediate: 0.3,
        short_term: 0.3,
        long_term: 0.4
      },
      thresholds: %{
        minimum_score: 0.6,
        auto_approve: 0.85,
        requires_review: 0.7
      },
      decision_types: %{
        strategic: %{priority: 1, authority: :system5},
        tactical: %{priority: 2, authority: :system3},
        operational: %{priority: 3, authority: :system1}
      }
    }
  end
  
  defp generate_decision_id do
    "DEC-#{DateTime.utc_now() |> DateTime.to_unix()}-#{:rand.uniform(9999)}"
  end
  
  defp analyze_decision_context(context, identity_input, values_input, state) do
    %{
      urgency: assess_urgency(context),
      importance: assess_importance(context, identity_input),
      complexity: assess_complexity(context),
      constraints: identify_constraints(context),
      opportunities: identify_opportunities(context),
      identity_factors: identity_input,
      values_factors: values_input,
      historical_context: find_similar_decisions(context, state.decision_history),
      risk_profile: assess_risk_profile(context)
    }
  end
  
  defp assess_urgency(context) do
    deadline = Map.get(context, :deadline)
    
    cond do
      Map.get(context, :crisis_mode, false) -> :critical
      deadline && DateTime.diff(deadline, DateTime.utc_now(), :hour) < 24 -> :high
      deadline && DateTime.diff(deadline, DateTime.utc_now(), :day) < 7 -> :medium
      true -> :low
    end
  end
  
  defp assess_importance(context, identity_input) do
    factors = [
      affects_core_purpose?(context, identity_input),
      strategic_impact_level(context),
      stakeholder_count(context) > 3,
      financial_impact(context) > 1_000_000
    ]
    
    importance_score = Enum.count(factors, & &1) / length(factors)
    
    cond do
      importance_score >= 0.75 -> :critical
      importance_score >= 0.5 -> :high
      importance_score >= 0.25 -> :medium
      true -> :low
    end
  end
  
  defp affects_core_purpose?(context, identity_input) do
    purpose = Map.get(identity_input, :purpose, "")
    subject = String.downcase(context.subject)
    
    String.contains?(purpose, subject) ||
    Enum.any?(["mission", "vision", "identity"], &String.contains?(subject, &1))
  end
  
  defp strategic_impact_level(context) do
    Map.get(context, :strategic_impact, :low)
  end
  
  defp stakeholder_count(context) do
    context
    |> Map.get(:affected_stakeholders, [])
    |> length()
  end
  
  defp financial_impact(context) do
    Map.get(context, :financial_impact, 0)
  end
  
  defp assess_complexity(context) do
    factors = [
      map_size(Map.get(context, :variables, %{})),
      length(Map.get(context, :dependencies, [])),
      length(Map.get(context, :constraints, [])),
      if(Map.get(context, :uncertainty_level, :low) == :high, do: 5, else: 0)
    ]
    
    complexity_score = Enum.sum(factors)
    
    cond do
      complexity_score >= 15 -> :very_high
      complexity_score >= 10 -> :high
      complexity_score >= 5 -> :medium
      true -> :low
    end
  end
  
  defp identify_constraints(context) do
    explicit_constraints = Map.get(context, :constraints, [])
    
    # Add implicit constraints
    implicit_constraints = []
    
    implicit_constraints = if Map.get(context, :budget_limit) do
      [{:financial, "Budget limit: #{context.budget_limit}"} | implicit_constraints]
    else
      implicit_constraints
    end
    
    implicit_constraints = if Map.get(context, :deadline) do
      [{:temporal, "Deadline: #{context.deadline}"} | implicit_constraints]
    else
      implicit_constraints
    end
    
    explicit_constraints ++ implicit_constraints
  end
  
  defp identify_opportunities(context) do
    Map.get(context, :opportunities, [])
    |> Enum.map(fn opp ->
      if is_binary(opp) do
        %{description: opp, potential: :medium}
      else
        opp
      end
    end)
  end
  
  defp find_similar_decisions(context, history) do
    # Find decisions with similar subjects or characteristics
    similar = history
    |> Enum.filter(fn decision ->
      similarity_score(decision.context, context) > 0.6
    end)
    |> Enum.take(3)
    
    %{
      count: length(similar),
      decisions: Enum.map(similar, &summarize_decision/1),
      patterns: extract_patterns(similar)
    }
  end
  
  defp similarity_score(context1, context2) do
    # Simple similarity based on subject and type
    subject_similarity = if context1.subject == context2.subject, do: 0.5, else: 0
    type_similarity = if Map.get(context1, :type) == Map.get(context2, :type), do: 0.3, else: 0
    
    # Check for common stakeholders
    stakeholders1 = MapSet.new(Map.get(context1, :affected_stakeholders, []))
    stakeholders2 = MapSet.new(Map.get(context2, :affected_stakeholders, []))
    stakeholder_overlap = MapSet.intersection(stakeholders1, stakeholders2) |> MapSet.size()
    stakeholder_similarity = if max(MapSet.size(stakeholders1), MapSet.size(stakeholders2)) > 0 do
      stakeholder_overlap / max(MapSet.size(stakeholders1), MapSet.size(stakeholders2)) * 0.2
    else
      0
    end
    
    subject_similarity + type_similarity + stakeholder_similarity
  end
  
  defp summarize_decision(decision) do
    %{
      id: decision.id,
      subject: decision.context.subject,
      selected_option: get_in(decision, [:selected_option, :name]),
      outcome: get_in(decision, [:review, :outcome]) || :pending,
      date: decision.timestamp
    }
  end
  
  defp extract_patterns(similar_decisions) do
    if length(similar_decisions) >= 2 do
      %{
        common_option: most_common_option(similar_decisions),
        average_success: calculate_average_success(similar_decisions),
        typical_challenges: identify_common_challenges(similar_decisions)
      }
    else
      %{}
    end
  end
  
  defp most_common_option(decisions) do
    decisions
    |> Enum.map(&get_in(&1, [:selected_option, :name]))
    |> Enum.frequencies()
    |> Enum.max_by(fn {_option, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end
  
  defp calculate_average_success(decisions) do
    success_rates = decisions
    |> Enum.map(&get_in(&1, [:review, :success_rate]))
    |> Enum.reject(&is_nil/1)
    
    if length(success_rates) > 0 do
      Enum.sum(success_rates) / length(success_rates)
    else
      nil
    end
  end
  
  defp identify_common_challenges(decisions) do
    decisions
    |> Enum.flat_map(&get_in(&1, [:review, :challenges]) || [])
    |> Enum.frequencies()
    |> Enum.filter(fn {_challenge, count} -> count >= 2 end)
    |> Enum.map(fn {challenge, _count} -> challenge end)
  end
  
  defp assess_risk_profile(context) do
    risks = Map.get(context, :risks, [])
    
    %{
      identified_risks: length(risks),
      highest_severity: highest_risk_severity(risks),
      mitigation_available: Enum.all?(risks, &Map.has_key?(&1, :mitigation)),
      overall_risk: calculate_overall_risk(risks)
    }
  end
  
  defp highest_risk_severity(risks) do
    if Enum.empty?(risks) do
      :low
    else
      risks
      |> Enum.map(&Map.get(&1, :severity, :medium))
      |> Enum.max_by(&risk_severity_value/1)
    end
  end
  
  defp risk_severity_value(severity) do
    case severity do
      :critical -> 4
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 0
    end
  end
  
  defp calculate_overall_risk(risks) do
    if Enum.empty?(risks) do
      :low
    else
      avg_severity = risks
      |> Enum.map(&Map.get(&1, :severity, :medium))
      |> Enum.map(&risk_severity_value/1)
      |> Enum.sum()
      |> Kernel./(length(risks))
      
      cond do
        avg_severity >= 3.5 -> :critical
        avg_severity >= 2.5 -> :high
        avg_severity >= 1.5 -> :medium
        true -> :low
      end
    end
  end
  
  defp generate_decision_options(context, analysis) do
    base_options = []
    
    # Status quo option
    base_options = [%{
      name: "Maintain Status Quo",
      description: "Continue with current approach",
      type: :conservative,
      risk: :low,
      cost: 0,
      timeline: :immediate
    } | base_options]
    
    # Incremental change option
    if analysis.complexity in [:low, :medium] do
      base_options = [%{
        name: "Incremental Adjustment",
        description: "Make small, measured changes",
        type: :moderate,
        risk: :low_medium,
        cost: :moderate,
        timeline: :short_term
      } | base_options]
    end
    
    # Transformational option
    if analysis.importance in [:high, :critical] do
      base_options = [%{
        name: "Strategic Transformation",
        description: "Fundamental change to approach",
        type: :aggressive,
        risk: :high,
        cost: :high,
        timeline: :long_term
      } | base_options]
    end
    
    # Defer option
    if analysis.urgency in [:low, :medium] do
      base_options = [%{
        name: "Defer Decision",
        description: "Gather more information before deciding",
        type: :conservative,
        risk: :opportunity_cost,
        cost: :minimal,
        timeline: :deferred
      } | base_options]
    end
    
    base_options
  end
  
  defp evaluate_all_options(options, analysis, state) do
    options
    |> Enum.map(fn option ->
      evaluation = evaluate_single_option(option, analysis, state.decision_framework)
      Map.put(option, :evaluation, evaluation)
    end)
  end
  
  defp evaluate_single_option(option, analysis, framework) do
    criteria_scores = framework.criteria
    |> Enum.map(fn {criterion, config} ->
      score = evaluate_criterion(option, criterion, config, analysis)
      {criterion, %{score: score, weight: config.weight}}
    end)
    |> Enum.into(%{})
    
    # Calculate weighted score
    total_score = criteria_scores
    |> Enum.map(fn {_criterion, result} -> result.score * result.weight end)
    |> Enum.sum()
    
    %{
      criteria_scores: criteria_scores,
      total_score: total_score,
      meets_threshold: total_score >= framework.thresholds.minimum_score,
      confidence: calculate_evaluation_confidence(criteria_scores),
      strengths: identify_strengths(criteria_scores),
      weaknesses: identify_weaknesses(criteria_scores)
    }
  end
  
  defp evaluate_criterion(option, criterion, config, analysis) do
    case config.evaluation_method do
      :score_based ->
        evaluate_score_based(option, criterion, analysis)
      :binary_check ->
        evaluate_binary_check(option, criterion, analysis)
      :risk_matrix ->
        evaluate_risk_matrix(option, criterion, analysis)
      :ratio_analysis ->
        evaluate_ratio_analysis(option, criterion)
      :impact_assessment ->
        evaluate_impact_assessment(option, criterion, analysis)
      :projection_based ->
        evaluate_projection_based(option, criterion)
      _ ->
        0.5  # Default neutral score
    end
  end
  
  defp evaluate_score_based(option, :strategic_alignment, analysis) do
    # Check alignment with strategic factors
    alignment_factors = [
      option.type == :conservative && analysis.importance == :low,
      option.type == :moderate && analysis.importance == :medium,
      option.type == :aggressive && analysis.importance in [:high, :critical],
      !Enum.empty?(analysis.identity_factors)
    ]
    
    Enum.count(alignment_factors, & &1) / length(alignment_factors)
  end
  
  defp evaluate_binary_check(option, :value_consistency, analysis) do
    # Check if option is consistent with values
    values_check = Map.get(analysis, :values_factors, %{})
    
    if map_size(values_check) > 0 do
      # Check for conflicts
      if option.type == :aggressive && Map.get(values_check, :risk_tolerance, :medium) == :low do
        0.3
      else
        0.9
      end
    else
      0.7  # Neutral if no values input
    end
  end
  
  defp evaluate_risk_matrix(option, :risk_assessment, analysis) do
    option_risk = Map.get(option, :risk, :medium)
    risk_profile = analysis.risk_profile
    
    # Lower score for higher risk
    base_score = case option_risk do
      :low -> 0.9
      :low_medium -> 0.75
      :medium -> 0.6
      :high -> 0.4
      :critical -> 0.2
      _ -> 0.5
    end
    
    # Adjust based on mitigation
    if risk_profile.mitigation_available do
      min(1.0, base_score + 0.2)
    else
      base_score
    end
  end
  
  defp evaluate_ratio_analysis(option, :resource_efficiency, _analysis) do
    # Evaluate cost-benefit ratio
    cost = case Map.get(option, :cost, :moderate) do
      0 -> 0
      :minimal -> 0.1
      :low -> 0.3
      :moderate -> 0.5
      :high -> 0.8
      :very_high -> 1.0
      n when is_number(n) -> min(1.0, n / 1_000_000)  # Normalize large numbers
      _ -> 0.5
    end
    
    # Inverse relationship - lower cost = higher efficiency score
    1.0 - cost * 0.8
  end
  
  defp evaluate_impact_assessment(option, :stakeholder_impact, analysis) do
    # Assess impact on stakeholders
    stakeholder_count = length(Map.get(analysis, :constraints, []))
    
    impact_score = case option.type do
      :conservative -> 0.7  # Minimal disruption
      :moderate -> 0.6      # Some positive change
      :aggressive -> 0.5    # Major change, mixed impact
      _ -> 0.5
    end
    
    # Adjust for stakeholder complexity
    if stakeholder_count > 5 do
      impact_score * 0.8
    else
      impact_score
    end
  end
  
  defp evaluate_projection_based(option, :long_term_viability, _analysis) do
    timeline = Map.get(option, :timeline, :medium_term)
    
    case timeline do
      :long_term -> 0.9
      :medium_term -> 0.7
      :short_term -> 0.5
      :immediate -> 0.4
      :deferred -> 0.3
      _ -> 0.5
    end
  end
  
  defp evaluate_score_based(_option, _criterion, _analysis), do: 0.5
  defp evaluate_binary_check(_option, _criterion, _analysis), do: 0.7
  defp evaluate_risk_matrix(_option, _criterion, _analysis), do: 0.6
  defp evaluate_ratio_analysis(_option, _criterion), do: 0.6
  defp evaluate_impact_assessment(_option, _criterion, _analysis), do: 0.6
  defp evaluate_projection_based(_option, _criterion), do: 0.6
  
  defp calculate_evaluation_confidence(criteria_scores) do
    # Confidence based on score consistency
    scores = criteria_scores
    |> Map.values()
    |> Enum.map(& &1.score)
    
    if length(scores) == 0 do
      0.5
    else
      mean = Enum.sum(scores) / length(scores)
      variance = scores
      |> Enum.map(fn score -> :math.pow(score - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(scores))
      
      std_dev = :math.sqrt(variance)
      
      # Lower variance = higher confidence
      max(0.3, min(1.0, 1.0 - std_dev))
    end
  end
  
  defp identify_strengths(criteria_scores) do
    criteria_scores
    |> Enum.filter(fn {_criterion, result} -> result.score >= 0.8 end)
    |> Enum.map(fn {criterion, _result} -> criterion end)
  end
  
  defp identify_weaknesses(criteria_scores) do
    criteria_scores
    |> Enum.filter(fn {_criterion, result} -> result.score < 0.5 end)
    |> Enum.map(fn {criterion, _result} -> criterion end)
  end
  
  defp evaluate_option(option, criteria, framework) do
    # Simplified evaluation for external options
    scores = criteria
    |> Enum.map(fn {criterion, weight} ->
      score = calculate_criterion_score(option, criterion)
      {criterion, score * weight}
    end)
    
    total = scores |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    
    %{
      total: total,
      breakdown: Enum.into(scores, %{}),
      meets_threshold: total >= framework.thresholds.minimum_score
    }
  end
  
  defp calculate_criterion_score(option, criterion) do
    # Simplified scoring
    case criterion do
      :cost -> 1.0 - min(1.0, Map.get(option, :cost, 0) / 1_000_000)
      :time -> 1.0 - min(1.0, Map.get(option, :time_required, 0) / 365)
      :risk -> 1.0 - Map.get(option, :risk_level, 0.5)
      :benefit -> Map.get(option, :expected_benefit, 0.5)
      _ -> 0.5
    end
  end
  
  defp select_best_option(evaluated_options, context) do
    # Filter viable options
    viable_options = evaluated_options
    |> Enum.filter(& &1.evaluation.meets_threshold)
    
    if Enum.empty?(viable_options) do
      # If no options meet threshold, pick least bad
      evaluated_options
      |> Enum.max_by(& &1.evaluation.total_score)
    else
      # Select based on context
      selection_strategy = determine_selection_strategy(context)
      
      case selection_strategy do
        :maximize_score ->
          Enum.max_by(viable_options, & &1.evaluation.total_score)
        :minimize_risk ->
          Enum.min_by(viable_options, &Map.get(&1, :risk, :medium) |> risk_severity_value())
        :quick_win ->
          viable_options
          |> Enum.filter(&(Map.get(&1, :timeline) in [:immediate, :short_term]))
          |> Enum.max_by(& &1.evaluation.total_score, fn -> List.first(viable_options) end)
        _ ->
          Enum.max_by(viable_options, & &1.evaluation.total_score)
      end
    end
  end
  
  defp determine_selection_strategy(context) do
    cond do
      Map.get(context, :crisis_mode, false) -> :quick_win
      Map.get(context, :risk_averse, false) -> :minimize_risk
      true -> :maximize_score
    end
  end
  
  defp formulate_decision(id, context, selected_option, analysis, all_options) do
    %{
      id: id,
      timestamp: DateTime.utc_now(),
      context: context,
      analysis: analysis,
      options_considered: length(all_options),
      selected_option: selected_option,
      rationale: generate_rationale(selected_option, analysis, all_options),
      confidence: selected_option.evaluation.confidence,
      action_required: determine_action_type(selected_option),
      commands: generate_commands(selected_option, context),
      requires_monitoring: requires_monitoring?(selected_option, analysis),
      review_date: calculate_review_date(selected_option),
      success_criteria: define_success_criteria(selected_option, context)
    }
  end
  
  defp generate_rationale(selected_option, analysis, all_options) do
    reasons = []
    
    # Best score reason
    if selected_option == Enum.max_by(all_options, & &1.evaluation.total_score) do
      reasons = ["Highest overall evaluation score" | reasons]
    end
    
    # Strengths reason
    if length(selected_option.evaluation.strengths) > 0 do
      reasons = ["Strong in: #{Enum.join(selected_option.evaluation.strengths, ", ")}" | reasons]
    end
    
    # Risk reason
    if Map.get(selected_option, :risk, :medium) in [:low, :low_medium] do
      reasons = ["Acceptable risk level" | reasons]
    end
    
    # Context reasons
    reasons = case analysis.urgency do
      :critical -> ["Addresses critical urgency" | reasons]
      :high -> ["Meets urgent timeline requirements" | reasons]
      _ -> reasons
    end
    
    %{
      primary_reasons: Enum.take(reasons, 3),
      evaluation_summary: %{
        score: selected_option.evaluation.total_score,
        confidence: selected_option.evaluation.confidence,
        key_strengths: selected_option.evaluation.strengths
      },
      alternatives_considered: summarize_alternatives(all_options, selected_option)
    }
  end
  
  defp summarize_alternatives(all_options, selected_option) do
    all_options
    |> Enum.reject(&(&1 == selected_option))
    |> Enum.map(fn option ->
      %{
        name: option.name,
        score: option.evaluation.total_score,
        main_weakness: List.first(option.evaluation.weaknesses)
      }
    end)
    |> Enum.take(3)
  end
  
  defp determine_action_type(selected_option) do
    case Map.get(selected_option, :timeline, :immediate) do
      :immediate -> :immediate
      :short_term -> :scheduled
      :deferred -> :none
      _ -> :scheduled
    end
  end
  
  defp generate_commands(selected_option, context) do
    case selected_option.name do
      "Maintain Status Quo" ->
        []
        
      "Incremental Adjustment" ->
        [%{
          type: :adjust_parameters,
          target: Map.get(context, :target_system, :system3),
          parameters: Map.get(selected_option, :adjustments, %{})
        }]
        
      "Strategic Transformation" ->
        [%{
          type: :strategic_change,
          scope: :organization_wide,
          phases: generate_transformation_phases(context)
        }]
        
      "Defer Decision" ->
        [%{
          type: :gather_information,
          areas: Map.get(context, :information_gaps, [:general]),
          deadline: DateTime.add(DateTime.utc_now(), 7, :day)
        }]
        
      _ ->
        []
    end
  end
  
  defp generate_transformation_phases(_context) do
    [
      %{phase: 1, name: "Assessment", duration: :weeks_2},
      %{phase: 2, name: "Planning", duration: :weeks_4},
      %{phase: 3, name: "Implementation", duration: :months_3},
      %{phase: 4, name: "Stabilization", duration: :months_2}
    ]
  end
  
  defp requires_monitoring?(selected_option, analysis) do
    Map.get(selected_option, :risk, :medium) in [:high, :critical] ||
    analysis.complexity in [:high, :very_high] ||
    Map.get(selected_option, :timeline, :immediate) in [:long_term, :medium_term]
  end
  
  defp calculate_review_date(selected_option) do
    days_until_review = case Map.get(selected_option, :timeline, :immediate) do
      :immediate -> 7
      :short_term -> 30
      :medium_term -> 90
      :long_term -> 180
      _ -> 30
    end
    
    DateTime.add(DateTime.utc_now(), days_until_review, :day)
  end
  
  defp define_success_criteria(selected_option, context) do
    base_criteria = []
    
    # Add option-specific criteria
    base_criteria = case selected_option.name do
      "Maintain Status Quo" ->
        ["No degradation in key metrics" | base_criteria]
      "Incremental Adjustment" ->
        ["Measurable improvement in target metrics" | base_criteria]
      "Strategic Transformation" ->
        ["Successful completion of all transformation phases" | base_criteria]
      _ ->
        base_criteria
    end
    
    # Add context-specific criteria
    if Map.has_key?(context, :success_metrics) do
      base_criteria ++ context.success_metrics
    else
      base_criteria ++ ["Stakeholder satisfaction >= 70%"]
    end
  end
  
  defp record_decision(state, decision) do
    # Add to history
    history = [decision | state.decision_history]
    |> Enum.take(state.config.max_history_size)
    
    # Update patterns if learning enabled
    state = if state.config.enable_learning do
      update_decision_patterns(state, decision)
    else
      state
    end
    
    %{state | decision_history: history}
  end
  
  defp update_decision_patterns(state, decision) do
    pattern_key = {decision.context.subject, decision.selected_option.type}
    
    patterns = Map.update(
      state.decision_patterns,
      pattern_key,
      1,
      &(&1 + 1)
    )
    
    %{state | decision_patterns: patterns}
  end
  
  defp track_active_decision(state, decision) do
    # Set up monitoring
    if decision.requires_monitoring do
      Process.send_after(
        self(),
        {:decision_timeout, decision.id},
        state.config.decision_timeout
      )
    end
    
    active = Map.put(state.active_decisions, decision.id, %{
      decision: decision,
      status: :active,
      started_at: DateTime.utc_now()
    })
    
    %{state | active_decisions: active}
  end
  
  defp apply_history_filters(history, filters) do
    history
    |> filter_by_date_range(Map.get(filters, :date_range))
    |> filter_by_subject(Map.get(filters, :subject))
    |> filter_by_outcome(Map.get(filters, :outcome))
    |> filter_by_importance(Map.get(filters, :importance))
  end
  
  defp filter_by_date_range(history, nil), do: history
  defp filter_by_date_range(history, {start_date, end_date}) do
    Enum.filter(history, fn decision ->
      DateTime.compare(decision.timestamp, start_date) != :lt &&
      DateTime.compare(decision.timestamp, end_date) != :gt
    end)
  end
  
  defp filter_by_subject(history, nil), do: history
  defp filter_by_subject(history, subject) do
    Enum.filter(history, fn decision ->
      String.contains?(
        String.downcase(decision.context.subject),
        String.downcase(subject)
      )
    end)
  end
  
  defp filter_by_outcome(history, nil), do: history
  defp filter_by_outcome(history, outcome) do
    Enum.filter(history, fn decision ->
      get_in(decision, [:review, :outcome]) == outcome
    end)
  end
  
  defp filter_by_importance(history, nil), do: history
  defp filter_by_importance(history, importance) do
    Enum.filter(history, fn decision ->
      decision.analysis.importance == importance
    end)
  end
  
  defp find_decision(history, decision_id) do
    Enum.find(history, &(&1.id == decision_id))
  end
  
  defp analyze_decision_outcome(decision, outcome_data) do
    %{
      outcome: determine_outcome(outcome_data),
      success_rate: calculate_success_rate(decision, outcome_data),
      lessons_learned: extract_lessons(outcome_data),
      unexpected_results: identify_unexpected_results(decision, outcome_data),
      follow_up_required: determine_follow_up_needs(outcome_data),
      challenges: Map.get(outcome_data, :challenges, [])
    }
  end
  
  defp determine_outcome(outcome_data) do
    success_indicators = Map.get(outcome_data, :success_indicators, 0)
    total_indicators = Map.get(outcome_data, :total_indicators, 1)
    
    success_rate = success_indicators / max(total_indicators, 1)
    
    cond do
      success_rate >= 0.9 -> :highly_successful
      success_rate >= 0.7 -> :successful
      success_rate >= 0.5 -> :partially_successful
      success_rate >= 0.3 -> :limited_success
      true -> :unsuccessful
    end
  end
  
  defp calculate_success_rate(decision, outcome_data) do
    met_criteria = outcome_data
    |> Map.get(:criteria_results, %{})
    |> Enum.count(fn {_criterion, met} -> met end)
    
    total_criteria = length(decision.success_criteria)
    
    if total_criteria > 0 do
      met_criteria / total_criteria
    else
      0.5
    end
  end
  
  defp extract_lessons(outcome_data) do
    Map.get(outcome_data, :lessons_learned, [])
    |> Enum.take(5)
  end
  
  defp identify_unexpected_results(decision, outcome_data) do
    expected = Map.get(decision.selected_option, :expected_outcomes, [])
    actual = Map.get(outcome_data, :actual_outcomes, [])
    
    unexpected = actual -- expected
    missing = expected -- actual
    
    %{
      unexpected_positive: Enum.filter(unexpected, &positive_outcome?/1),
      unexpected_negative: Enum.filter(unexpected, &negative_outcome?/1),
      missing_expected: missing
    }
  end
  
  defp positive_outcome?(outcome) when is_binary(outcome) do
    positive_keywords = ["success", "improve", "increase", "better", "achieve"]
    Enum.any?(positive_keywords, &String.contains?(String.downcase(outcome), &1))
  end
  defp positive_outcome?(_), do: false
  
  defp negative_outcome?(outcome) when is_binary(outcome) do
    negative_keywords = ["fail", "problem", "issue", "delay", "loss"]
    Enum.any?(negative_keywords, &String.contains?(String.downcase(outcome), &1))
  end
  defp negative_outcome?(_), do: false
  
  defp determine_follow_up_needs(outcome_data) do
    Map.get(outcome_data, :requires_follow_up, false) ||
    Map.get(outcome_data, :open_issues, []) != []
  end
  
  defp update_decision_in_history(state, updated_decision) do
    updated_history = state.decision_history
    |> Enum.map(fn decision ->
      if decision.id == updated_decision.id do
        updated_decision
      else
        decision
      end
    end)
    
    %{state | decision_history: updated_history}
  end
  
  defp learn_from_decision(state, decision, review) do
    # Extract learning points
    learning_entry = %{
      decision_type: decision.selected_option.type,
      context_factors: summarize_context_factors(decision.analysis),
      outcome: review.outcome,
      success_rate: review.success_rate,
      effective_strategies: identify_effective_strategies(decision, review),
      timestamp: DateTime.utc_now()
    }
    
    # Update learning data
    learning_data = Map.update(
      state.learning_data,
      decision.context.subject,
      [learning_entry],
      &[learning_entry | &1]
    )
    
    %{state | learning_data: learning_data}
  end
  
  defp summarize_context_factors(analysis) do
    %{
      urgency: analysis.urgency,
      importance: analysis.importance,
      complexity: analysis.complexity,
      risk_level: analysis.risk_profile.overall_risk
    }
  end
  
  defp identify_effective_strategies(decision, review) do
    strategies = []
    
    if review.success_rate > 0.8 do
      strategies = [decision.selected_option.type | strategies]
    end
    
    if Enum.empty?(review.unexpected_results.unexpected_negative) do
      strategies = [:risk_mitigation_worked | strategies]
    end
    
    strategies
  end
  
  defp summarize_criteria(criteria) do
    criteria
    |> Enum.map(fn {name, config} ->
      %{
        name: name,
        weight: config.weight,
        description: config.description
      }
    end)
  end
  
  defp update_framework_criteria(framework, updates) do
    updated_criteria = Enum.reduce(updates, framework.criteria, fn {criterion, changes}, acc ->
      if Map.has_key?(acc, criterion) do
        Map.update!(acc, criterion, fn current ->
          Map.merge(current, changes)
        end)
      else
        acc
      end
    end)
    
    # Normalize weights
    total_weight = updated_criteria
    |> Map.values()
    |> Enum.map(& &1.weight)
    |> Enum.sum()
    
    normalized_criteria = if total_weight > 0 do
      updated_criteria
      |> Enum.map(fn {name, config} ->
        {name, %{config | weight: config.weight / total_weight}}
      end)
      |> Enum.into(%{})
    else
      updated_criteria
    end
    
    %{framework | criteria: normalized_criteria}
  end
  
  defp review_active_decisions(state) do
    now = DateTime.utc_now()
    
    {completed, active} = state.active_decisions
    |> Enum.split_with(fn {_id, tracking} ->
      DateTime.compare(tracking.decision.review_date, now) == :lt
    end)
    
    # Process completed decisions
    Enum.each(completed, fn {id, _tracking} ->
      Logger.info("Decision #{id} ready for review")
    end)
    
    %{state | active_decisions: Enum.into(active, %{})}
  end
  
  defp analyze_decision_patterns(history) do
    recent_decisions = Enum.take(history, 100)
    
    %{
      by_type: group_decisions_by_type(recent_decisions),
      by_outcome: group_decisions_by_outcome(recent_decisions),
      success_factors: identify_success_factors(recent_decisions),
      failure_patterns: identify_failure_patterns(recent_decisions)
    }
  end
  
  defp group_decisions_by_type(decisions) do
    decisions
    |> Enum.group_by(&get_in(&1, [:selected_option, :type]))
    |> Enum.map(fn {type, type_decisions} ->
      {type, %{
        count: length(type_decisions),
        avg_success: calculate_group_success_rate(type_decisions)
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp group_decisions_by_outcome(decisions) do
    decisions
    |> Enum.group_by(&get_in(&1, [:review, :outcome]) || :pending)
    |> Enum.map(fn {outcome, outcome_decisions} ->
      {outcome, length(outcome_decisions)}
    end)
    |> Enum.into(%{})
  end
  
  defp calculate_group_success_rate(decisions) do
    reviewed = Enum.filter(decisions, &Map.has_key?(&1, :review))
    
    if length(reviewed) > 0 do
      total_success = reviewed
      |> Enum.map(&get_in(&1, [:review, :success_rate]) || 0)
      |> Enum.sum()
      
      total_success / length(reviewed)
    else
      nil
    end
  end
  
  defp identify_success_factors(decisions) do
    successful_decisions = decisions
    |> Enum.filter(&(get_in(&1, [:review, :outcome]) in [:successful, :highly_successful]))
    
    if length(successful_decisions) >= 5 do
      %{
        common_types: most_common_decision_types(successful_decisions),
        avg_confidence: average_confidence(successful_decisions),
        typical_timeline: most_common_timeline(successful_decisions)
      }
    else
      %{}
    end
  end
  
  defp identify_failure_patterns(decisions) do
    failed_decisions = decisions
    |> Enum.filter(&(get_in(&1, [:review, :outcome]) in [:unsuccessful, :limited_success]))
    
    if length(failed_decisions) >= 3 do
      %{
        common_weaknesses: common_weaknesses(failed_decisions),
        risk_factors: common_risk_factors(failed_decisions),
        complexity_correlation: complexity_failure_correlation(failed_decisions)
      }
    else
      %{}
    end
  end
  
  defp most_common_decision_types(decisions) do
    decisions
    |> Enum.map(&get_in(&1, [:selected_option, :type]))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 0))
  end
  
  defp average_confidence(decisions) do
    confidences = decisions
    |> Enum.map(&(&1.confidence || 0))
    |> Enum.filter(&(&1 > 0))
    
    if length(confidences) > 0 do
      Enum.sum(confidences) / length(confidences)
    else
      0
    end
  end
  
  defp most_common_timeline(decisions) do
    decisions
    |> Enum.map(&get_in(&1, [:selected_option, :timeline]))
    |> Enum.frequencies()
    |> Enum.max_by(fn {_timeline, count} -> count end, fn -> {:unknown, 0} end)
    |> elem(0)
  end
  
  defp common_weaknesses(decisions) do
    decisions
    |> Enum.flat_map(&get_in(&1, [:selected_option, :evaluation, :weaknesses]) || [])
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_weakness, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 0))
  end
  
  defp common_risk_factors(decisions) do
    decisions
    |> Enum.map(&get_in(&1, [:analysis, :risk_profile, :overall_risk]))
    |> Enum.frequencies()
  end
  
  defp complexity_failure_correlation(decisions) do
    complexity_groups = Enum.group_by(decisions, &get_in(&1, [:analysis, :complexity]))
    
    complexity_groups
    |> Enum.map(fn {complexity, group_decisions} ->
      {complexity, length(group_decisions)}
    end)
    |> Enum.into(%{})
  end
  
  defp update_learning_data(state) do
    # Consolidate learning insights
    insights = state.learning_data
    |> Enum.map(fn {subject, entries} ->
      {subject, consolidate_learning_entries(entries)}
    end)
    |> Enum.into(%{})
    
    # Keep only recent and relevant learning data
    pruned_data = insights
    |> Enum.map(fn {subject, consolidated} ->
      {subject, Enum.take(consolidated, 50)}
    end)
    |> Enum.into(%{})
    
    %{state | learning_data: pruned_data}
  end
  
  defp consolidate_learning_entries(entries) do
    # Group similar entries and extract patterns
    entries
    |> Enum.group_by(&{&1.decision_type, &1.outcome})
    |> Enum.map(fn {{type, outcome}, group} ->
      %{
        decision_type: type,
        outcome: outcome,
        occurrences: length(group),
        avg_success_rate: average_success_rate(group),
        common_factors: extract_common_factors(group)
      }
    end)
  end
  
  defp average_success_rate(entries) do
    rates = Enum.map(entries, & &1.success_rate)
    if length(rates) > 0 do
      Enum.sum(rates) / length(rates)
    else
      0
    end
  end
  
  defp extract_common_factors(entries) do
    entries
    |> Enum.flat_map(&Map.get(&1, :effective_strategies, []))
    |> Enum.frequencies()
    |> Enum.filter(fn {_strategy, count} -> count >= 2 end)
    |> Enum.map(&elem(&1, 0))
  end
  
  defp handle_decision_timeout(state, decision_id) do
    case Map.get(state.active_decisions, decision_id) do
      nil ->
        state
        
      tracking ->
        # Mark as requiring review
        Logger.warn("Decision #{decision_id} exceeded timeout, marking for review")
        
        updated_tracking = Map.put(tracking, :status, :timeout)
        updated_active = Map.put(state.active_decisions, decision_id, updated_tracking)
        
        %{state | active_decisions: updated_active}
    end
  end
  
  defp schedule_decision_review(interval) do
    Process.send_after(self(), :review_decisions, interval)
  end
end