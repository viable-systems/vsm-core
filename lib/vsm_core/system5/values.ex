defmodule VSMCore.System5.Values do
  @moduledoc """
  Values Management for System 5
  
  Responsible for:
  - Core organizational values definition
  - Value system maintenance and evolution
  - Value-based decision criteria
  - Cultural value reinforcement
  - Ethics and principles management
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def define_values(values_server, values) do
    GenServer.call(values_server, {:define_values, values})
  end
  
  def get_current_values(values_server) do
    GenServer.call(values_server, :get_current_values)
  end
  
  def evaluate_against_values(values_server, subject) do
    GenServer.call(values_server, {:evaluate_against_values, subject})
  end
  
  def check_alignment(values_server, proposal) do
    GenServer.call(values_server, {:check_alignment, proposal})
  end
  
  def validate_policy(values_server, policy_area, policy_details) do
    GenServer.call(values_server, {:validate_policy, policy_area, policy_details})
  end
  
  def add_value(values_server, value) do
    GenServer.call(values_server, {:add_value, value})
  end
  
  def update_value_priority(values_server, value_name, new_priority) do
    GenServer.call(values_server, {:update_value_priority, value_name, new_priority})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("S5 Values Manager initializing...")
    
    state = %{
      core_values: initialize_core_values(),
      value_hierarchy: initialize_value_hierarchy(),
      ethical_framework: initialize_ethical_framework(),
      value_conflicts: %{},
      value_metrics: %{},
      config: Keyword.get(opts, :config, default_config())
    }
    
    # Schedule periodic value assessment
    schedule_value_assessment(state.config.assessment_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:define_values, values}, _from, state) do
    Logger.info("Values: Defining organizational values")
    
    # Validate values structure
    case validate_values_structure(values) do
      {:ok, validated_values} ->
        # Update core values
        state = %{state | core_values: merge_values(state.core_values, validated_values)}
        
        # Rebuild value hierarchy
        state = %{state | value_hierarchy: build_value_hierarchy(state.core_values)}
        
        # Check for conflicts
        conflicts = detect_value_conflicts(state.core_values)
        state = %{state | value_conflicts: conflicts}
        
        {:reply, {:ok, state.core_values}, state}
        
      {:error, reason} = error ->
        Logger.error("Values: Invalid values structure - #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:get_current_values, _from, state) do
    values_summary = %{
      core_values: summarize_core_values(state.core_values),
      hierarchy: state.value_hierarchy,
      active_conflicts: map_size(state.value_conflicts),
      ethical_principles: summarize_ethical_framework(state.ethical_framework),
      health_score: calculate_values_health(state)
    }
    
    {:reply, values_summary, state}
  end
  
  @impl true
  def handle_call({:evaluate_against_values, subject}, _from, state) do
    Logger.debug("Values: Evaluating subject against values")
    
    evaluation = perform_values_evaluation(subject, state)
    
    {:reply, evaluation, state}
  end
  
  @impl true
  def handle_call({:check_alignment, proposal}, _from, state) do
    Logger.debug("Values: Checking proposal alignment")
    
    alignment_score = calculate_values_alignment(proposal, state)
    
    {:reply, alignment_score, state}
  end
  
  @impl true
  def handle_call({:validate_policy, policy_area, policy_details}, _from, state) do
    Logger.debug("Values: Validating policy for area: #{policy_area}")
    
    validation_result = validate_policy_values(policy_area, policy_details, state)
    
    {:reply, validation_result, state}
  end
  
  @impl true
  def handle_call({:add_value, value}, _from, state) do
    Logger.info("Values: Adding new value: #{value.name}")
    
    case validate_single_value(value) do
      {:ok, validated_value} ->
        # Check compatibility
        if value_compatible?(validated_value, state.core_values) do
          state = add_value_to_system(state, validated_value)
          {:reply, :ok, state}
        else
          {:reply, {:error, :incompatible_value}, state}
        end
        
      {:error, reason} = error ->
        Logger.error("Values: Invalid value - #{reason}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:update_value_priority, value_name, new_priority}, _from, state) do
    Logger.info("Values: Updating priority for value: #{value_name}")
    
    case update_value_priority_internal(state, value_name, new_priority) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_info(:assess_values, state) do
    Logger.debug("Values: Performing periodic value assessment")
    
    # Assess value system health
    assessment = assess_value_system(state)
    
    # Update metrics
    state = %{state | value_metrics: assessment.metrics}
    
    # Take corrective action if needed
    state = if assessment.needs_intervention do
      apply_value_interventions(state, assessment.interventions)
    else
      state
    end
    
    # Schedule next assessment
    schedule_value_assessment(state.config.assessment_interval)
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp default_config do
    %{
      assessment_interval: :timer.days(30),
      max_core_values: 10,
      min_core_values: 3,
      conflict_resolution_strategy: :prioritize,
      allow_value_evolution: true
    }
  end
  
  defp initialize_core_values do
    %{
      integrity: %{
        name: "Integrity",
        description: "Act with honesty and strong moral principles",
        priority: 1,
        type: :foundational,
        behavioral_indicators: [
          "Transparent communication",
          "Ethical decision making",
          "Accountability for actions",
          "Consistency in values application"
        ],
        metrics: %{
          adherence_score: 1.0,
          violation_count: 0,
          reinforcement_frequency: :daily
        }
      },
      excellence: %{
        name: "Excellence",
        description: "Strive for the highest quality in all endeavors",
        priority: 2,
        type: :aspirational,
        behavioral_indicators: [
          "Continuous improvement",
          "High standards",
          "Attention to detail",
          "Innovation and creativity"
        ],
        metrics: %{
          adherence_score: 0.9,
          achievement_rate: 0.85,
          improvement_trend: :positive
        }
      },
      collaboration: %{
        name: "Collaboration",
        description: "Work together effectively towards common goals",
        priority: 3,
        type: :operational,
        behavioral_indicators: [
          "Active knowledge sharing",
          "Cross-functional cooperation",
          "Collective problem solving",
          "Mutual support"
        ],
        metrics: %{
          adherence_score: 0.85,
          collaboration_index: 0.8,
          conflict_rate: 0.1
        }
      },
      sustainability: %{
        name: "Sustainability",
        description: "Ensure long-term viability and positive impact",
        priority: 4,
        type: :strategic,
        behavioral_indicators: [
          "Long-term thinking",
          "Resource conservation",
          "Stakeholder consideration",
          "Future-proofing decisions"
        ],
        metrics: %{
          adherence_score: 0.8,
          sustainability_score: 0.75,
          impact_assessment: :positive
        }
      }
    }
  end
  
  defp initialize_value_hierarchy do
    %{
      foundational: [:integrity],
      strategic: [:sustainability],
      operational: [:collaboration],
      aspirational: [:excellence]
    }
  end
  
  defp initialize_ethical_framework do
    %{
      principles: %{
        beneficence: %{
          description: "Act to benefit stakeholders",
          weight: 0.25,
          application_rules: ["Maximize positive outcomes", "Consider all affected parties"]
        },
        non_maleficence: %{
          description: "Do no harm",
          weight: 0.3,
          application_rules: ["Avoid negative consequences", "Minimize risks"]
        },
        autonomy: %{
          description: "Respect individual autonomy",
          weight: 0.25,
          application_rules: ["Enable informed decisions", "Respect choices"]
        },
        justice: %{
          description: "Ensure fairness and equity",
          weight: 0.2,
          application_rules: ["Equal treatment", "Fair distribution"]
        }
      },
      decision_framework: %{
        ethical_tests: [
          :universality_test,  # Would I want everyone to act this way?
          :publicity_test,     # Would I be comfortable if this was public?
          :reversibility_test, # Would I accept this if roles were reversed?
          :harm_test          # Does this minimize harm?
        ],
        threshold: 0.75  # Must pass 75% of tests
      }
    }
  end
  
  defp validate_values_structure(values) do
    if is_map(values) || is_list(values) do
      validated = if is_list(values) do
        values
        |> Enum.map(&normalize_value/1)
        |> Enum.into(%{}, fn v -> {String.to_atom(String.downcase(v.name)), v} end)
      else
        values
        |> Enum.map(fn {k, v} -> {k, normalize_value(v)} end)
        |> Enum.into(%{})
      end
      
      {:ok, validated}
    else
      {:error, "Values must be a map or list"}
    end
  end
  
  defp normalize_value(value) when is_map(value) do
    value
    |> Map.put_new(:priority, 5)
    |> Map.put_new(:type, :operational)
    |> Map.put_new(:behavioral_indicators, [])
    |> Map.put_new(:metrics, %{adherence_score: 0.5})
  end
  
  defp normalize_value(value) when is_binary(value) do
    %{
      name: value,
      description: "",
      priority: 5,
      type: :operational,
      behavioral_indicators: [],
      metrics: %{adherence_score: 0.5}
    }
  end
  
  defp merge_values(current_values, new_values) do
    Map.merge(current_values, new_values, fn _key, current, new ->
      Map.merge(current, new)
    end)
  end
  
  defp build_value_hierarchy(core_values) do
    core_values
    |> Enum.group_by(fn {_name, value} -> value.type end)
    |> Enum.map(fn {type, values} ->
      {type, Enum.map(values, fn {name, _v} -> name end)}
    end)
    |> Enum.into(%{})
  end
  
  defp detect_value_conflicts(core_values) do
    values_list = Map.to_list(core_values)
    
    conflicts = for {name1, value1} <- values_list,
                    {name2, value2} <- values_list,
                    name1 < name2,
                    conflict = detect_conflict(value1, value2),
                    conflict != nil do
      {{name1, name2}, conflict}
    end
    
    Enum.into(conflicts, %{})
  end
  
  defp detect_conflict(value1, value2) do
    # Check for potential conflicts
    cond do
      # Speed vs Quality conflict
      has_indicator?(value1, "speed") && has_indicator?(value2, "quality") ->
        %{type: :tension, severity: :medium, resolution: :balance}
        
      # Individual vs Collective conflict  
      has_indicator?(value1, "individual") && has_indicator?(value2, "collective") ->
        %{type: :philosophical, severity: :low, resolution: :context_dependent}
        
      # Short-term vs Long-term conflict
      has_indicator?(value1, "immediate") && has_indicator?(value2, "long-term") ->
        %{type: :temporal, severity: :medium, resolution: :prioritize}
        
      true ->
        nil
    end
  end
  
  defp has_indicator?(value, keyword) do
    Enum.any?(value.behavioral_indicators, &String.contains?(String.downcase(&1), keyword))
  end
  
  defp summarize_core_values(core_values) do
    core_values
    |> Enum.map(fn {name, value} ->
      %{
        name: value.name,
        priority: value.priority,
        type: value.type,
        adherence: get_in(value, [:metrics, :adherence_score]) || 0
      }
    end)
    |> Enum.sort_by(& &1.priority)
  end
  
  defp summarize_ethical_framework(framework) do
    %{
      principles: Map.keys(framework.principles),
      decision_threshold: framework.decision_framework.threshold,
      ethical_tests: length(framework.decision_framework.ethical_tests)
    }
  end
  
  defp calculate_values_health(state) do
    factors = %{
      completeness: calculate_completeness_score(state),
      coherence: calculate_coherence_score(state),
      adoption: calculate_adoption_score(state),
      effectiveness: calculate_effectiveness_score(state)
    }
    
    Enum.sum(Map.values(factors)) / map_size(factors)
  end
  
  defp calculate_completeness_score(state) do
    value_count = map_size(state.core_values)
    
    cond do
      value_count >= state.config.min_core_values && 
      value_count <= state.config.max_core_values -> 1.0
      value_count < state.config.min_core_values -> 0.5
      value_count > state.config.max_core_values -> 0.7
    end
  end
  
  defp calculate_coherence_score(state) do
    conflict_count = map_size(state.value_conflicts)
    value_count = map_size(state.core_values)
    
    if value_count > 0 do
      max(0, 1 - (conflict_count / value_count))
    else
      0
    end
  end
  
  defp calculate_adoption_score(state) do
    adherence_scores = state.core_values
    |> Map.values()
    |> Enum.map(&get_in(&1, [:metrics, :adherence_score]) || 0)
    
    if length(adherence_scores) > 0 do
      Enum.sum(adherence_scores) / length(adherence_scores)
    else
      0
    end
  end
  
  defp calculate_effectiveness_score(state) do
    # Simplified effectiveness based on metrics
    if map_size(state.value_metrics) > 0 do
      Map.get(state.value_metrics, :overall_effectiveness, 0.7)
    else
      0.5
    end
  end
  
  defp perform_values_evaluation(subject, state) do
    # Evaluate subject against each core value
    value_scores = state.core_values
    |> Enum.map(fn {name, value} ->
      score = evaluate_against_value(subject, value)
      {name, score}
    end)
    |> Enum.into(%{})
    
    # Apply ethical framework
    ethical_assessment = apply_ethical_framework(subject, state.ethical_framework)
    
    # Calculate overall evaluation
    overall_score = calculate_overall_evaluation(value_scores, ethical_assessment)
    
    %{
      value_scores: value_scores,
      ethical_assessment: ethical_assessment,
      overall_score: overall_score,
      recommendation: generate_values_recommendation(overall_score),
      concerns: identify_value_concerns(value_scores, ethical_assessment)
    }
  end
  
  defp evaluate_against_value(subject, value) do
    # Check how well subject aligns with value
    indicators_matched = value.behavioral_indicators
    |> Enum.count(fn indicator ->
      subject_matches_indicator?(subject, indicator)
    end)
    
    if length(value.behavioral_indicators) > 0 do
      indicators_matched / length(value.behavioral_indicators)
    else
      0.5  # Neutral if no indicators
    end
  end
  
  defp subject_matches_indicator?(subject, indicator) do
    # Simplified matching logic
    subject_text = inspect(subject) |> String.downcase()
    indicator_keywords = String.split(String.downcase(indicator), " ")
    
    Enum.any?(indicator_keywords, &String.contains?(subject_text, &1))
  end
  
  defp apply_ethical_framework(subject, framework) do
    # Run ethical tests
    test_results = framework.decision_framework.ethical_tests
    |> Enum.map(fn test ->
      {test, run_ethical_test(test, subject)}
    end)
    |> Enum.into(%{})
    
    passed_count = Enum.count(test_results, fn {_test, result} -> result end)
    pass_rate = passed_count / length(framework.decision_framework.ethical_tests)
    
    %{
      tests_passed: passed_count,
      total_tests: length(framework.decision_framework.ethical_tests),
      pass_rate: pass_rate,
      passed: pass_rate >= framework.decision_framework.threshold,
      details: test_results
    }
  end
  
  defp run_ethical_test(test, subject) do
    case test do
      :universality_test ->
        # Would this be acceptable if everyone did it?
        !Map.get(subject, :exclusive_benefit, false)
        
      :publicity_test ->
        # Would this be acceptable if made public?
        !Map.get(subject, :requires_secrecy, false)
        
      :reversibility_test ->
        # Would I accept this if roles were reversed?
        !Map.get(subject, :unfair_advantage, false)
        
      :harm_test ->
        # Does this minimize harm?
        Map.get(subject, :harm_level, :low) in [:none, :minimal, :low]
        
      _ ->
        true
    end
  end
  
  defp calculate_overall_evaluation(value_scores, ethical_assessment) do
    # Weight values by priority
    weighted_value_score = value_scores
    |> Enum.map(fn {_name, score} -> score end)
    |> Enum.sum()
    |> Kernel./(map_size(value_scores))
    
    # Combine with ethical assessment
    ethical_score = if ethical_assessment.passed, do: 1.0, else: ethical_assessment.pass_rate
    
    # Overall score
    weighted_value_score * 0.6 + ethical_score * 0.4
  end
  
  defp generate_values_recommendation(overall_score) do
    cond do
      overall_score >= 0.8 -> :strongly_aligned
      overall_score >= 0.6 -> :aligned
      overall_score >= 0.4 -> :partially_aligned
      overall_score >= 0.2 -> :poorly_aligned
      true -> :misaligned
    end
  end
  
  defp identify_value_concerns(value_scores, ethical_assessment) do
    concerns = []
    
    # Check for low value scores
    low_scores = value_scores
    |> Enum.filter(fn {_name, score} -> score < 0.5 end)
    |> Enum.map(fn {name, _score} -> {:value_violation, name} end)
    
    concerns = concerns ++ low_scores
    
    # Check for ethical failures
    if !ethical_assessment.passed do
      concerns = [{:ethical_concern, :failed_ethical_tests} | concerns]
    end
    
    concerns
  end
  
  defp calculate_values_alignment(proposal, state) do
    # Check how proposal aligns with value system
    
    # Direct value alignment
    value_alignment = state.core_values
    |> Enum.map(fn {_name, value} ->
      proposal_alignment_with_value(proposal, value)
    end)
    |> Enum.sum()
    |> Kernel./(map_size(state.core_values))
    
    # Conflict analysis
    conflict_score = analyze_proposal_conflicts(proposal, state.value_conflicts)
    
    # Ethical alignment
    ethical_score = if Map.get(proposal, :ethical_review, false) do
      1.0
    else
      0.7
    end
    
    # Combined score
    value_alignment * 0.5 + (1 - conflict_score) * 0.3 + ethical_score * 0.2
  end
  
  defp proposal_alignment_with_value(proposal, value) do
    # Check if proposal supports or contradicts value
    impacts = Map.get(proposal, :value_impacts, %{})
    impact = Map.get(impacts, String.to_atom(String.downcase(value.name)), 0)
    
    # Convert impact to alignment score
    cond do
      impact > 0 -> min(1.0, 0.5 + impact * 0.5)
      impact < 0 -> max(0.0, 0.5 + impact * 0.5)
      true -> 0.5
    end
  end
  
  defp analyze_proposal_conflicts(proposal, value_conflicts) do
    # Check if proposal exacerbates conflicts
    affected_values = Map.get(proposal, :affected_values, [])
    
    conflict_count = value_conflicts
    |> Enum.count(fn {{v1, v2}, _conflict} ->
      v1 in affected_values && v2 in affected_values
    end)
    
    if length(affected_values) > 1 do
      conflict_count / (length(affected_values) * (length(affected_values) - 1) / 2)
    else
      0
    end
  end
  
  defp validate_policy_values(policy_area, policy_details, state) do
    # Check if policy aligns with values
    
    # Identify relevant values for policy area
    relevant_values = identify_relevant_values(policy_area, state.core_values)
    
    # Check alignment
    alignment_issues = relevant_values
    |> Enum.flat_map(fn value ->
      check_policy_value_alignment(policy_details, value)
    end)
    
    # Ethical review
    ethical_review = review_policy_ethics(policy_details, state.ethical_framework)
    
    if Enum.empty?(alignment_issues) && ethical_review.passed do
      {:ok, Map.put(policy_details, :values_approved, true)}
    else
      {:error, format_validation_errors(alignment_issues, ethical_review)}
    end
  end
  
  defp identify_relevant_values(policy_area, core_values) do
    # Map policy areas to relevant values
    value_relevance = %{
      operations: [:excellence, :efficiency, :collaboration],
      strategy: [:sustainability, :innovation, :integrity],
      compliance: [:integrity, :accountability, :transparency],
      human_resources: [:collaboration, :development, :fairness],
      innovation: [:excellence, :creativity, :risk_taking]
    }
    
    relevant_names = Map.get(value_relevance, policy_area, Map.keys(core_values))
    
    core_values
    |> Enum.filter(fn {name, _value} -> name in relevant_names end)
    |> Enum.map(fn {_name, value} -> value end)
  end
  
  defp check_policy_value_alignment(policy_details, value) do
    issues = []
    
    # Check if policy contradicts value
    if policy_contradicts_value?(policy_details, value) do
      issues = ["Policy contradicts value: #{value.name}" | issues]
    end
    
    # Check if policy weakens value
    if policy_weakens_value?(policy_details, value) do
      issues = ["Policy may weaken value: #{value.name}" | issues]
    end
    
    issues
  end
  
  defp policy_contradicts_value?(policy, value) do
    # Simplified contradiction detection
    exclusions = Map.get(policy, :excludes, [])
    
    Enum.any?(value.behavioral_indicators, fn indicator ->
      Enum.any?(exclusions, fn exclusion ->
        String.contains?(String.downcase(indicator), String.downcase(exclusion))
      end)
    end)
  end
  
  defp policy_weakens_value?(policy, value) do
    # Check if policy reduces value importance
    deemphasized = Map.get(policy, :deemphasizes, [])
    
    String.downcase(value.name) in Enum.map(deemphasized, &String.downcase/1)
  end
  
  defp review_policy_ethics(policy_details, ethical_framework) do
    # Run ethical tests on policy
    apply_ethical_framework(policy_details, ethical_framework)
  end
  
  defp format_validation_errors(alignment_issues, ethical_review) do
    errors = alignment_issues
    
    if !ethical_review.passed do
      errors = ["Failed ethical review" | errors]
    end
    
    Enum.join(errors, "; ")
  end
  
  defp validate_single_value(value) do
    required_fields = [:name, :description]
    
    missing_fields = required_fields -- Map.keys(value)
    
    if Enum.empty?(missing_fields) do
      {:ok, normalize_value(value)}
    else
      {:error, "Missing required fields: #{inspect(missing_fields)}"}
    end
  end
  
  defp value_compatible?(new_value, existing_values) do
    # Check if new value conflicts with existing values
    conflicts = existing_values
    |> Map.values()
    |> Enum.map(&detect_conflict(&1, new_value))
    |> Enum.reject(&is_nil/1)
    
    Enum.empty?(conflicts) || 
    Enum.all?(conflicts, &(&1.severity in [:low, :medium]))
  end
  
  defp add_value_to_system(state, value) do
    value_key = String.to_atom(String.downcase(value.name))
    
    # Add to core values
    updated_values = Map.put(state.core_values, value_key, value)
    
    # Update hierarchy
    updated_hierarchy = Map.update(
      state.value_hierarchy, 
      value.type, 
      [value_key], 
      &([value_key | &1] |> Enum.uniq())
    )
    
    # Recalculate conflicts
    conflicts = detect_value_conflicts(updated_values)
    
    %{state | 
      core_values: updated_values,
      value_hierarchy: updated_hierarchy,
      value_conflicts: conflicts
    }
  end
  
  defp update_value_priority_internal(state, value_name, new_priority) do
    value_key = if is_atom(value_name), do: value_name, else: String.to_atom(value_name)
    
    if Map.has_key?(state.core_values, value_key) do
      updated_values = update_in(
        state.core_values, 
        [value_key, :priority], 
        fn _ -> new_priority end
      )
      
      {:ok, %{state | core_values: updated_values}}
    else
      {:error, :value_not_found}
    end
  end
  
  defp assess_value_system(state) do
    metrics = %{
      adoption_rate: calculate_system_adoption_rate(state),
      conflict_level: calculate_conflict_level(state),
      coherence: calculate_system_coherence(state),
      effectiveness: calculate_system_effectiveness(state),
      evolution_need: assess_evolution_need(state)
    }
    
    needs_intervention = Enum.any?(metrics, fn {_metric, value} -> 
      value < 0.6
    end)
    
    interventions = if needs_intervention do
      generate_interventions(metrics, state)
    else
      []
    end
    
    %{
      metrics: metrics,
      needs_intervention: needs_intervention,
      interventions: interventions,
      timestamp: DateTime.utc_now()
    }
  end
  
  defp calculate_system_adoption_rate(state) do
    # Average adoption across all values
    adoption_scores = state.core_values
    |> Map.values()
    |> Enum.map(&get_in(&1, [:metrics, :adherence_score]) || 0.5)
    
    if length(adoption_scores) > 0 do
      Enum.sum(adoption_scores) / length(adoption_scores)
    else
      0
    end
  end
  
  defp calculate_conflict_level(state) do
    # Assess overall conflict level
    conflict_count = map_size(state.value_conflicts)
    value_count = map_size(state.core_values)
    
    if value_count > 1 do
      # Maximum possible conflicts
      max_conflicts = div(value_count * (value_count - 1), 2)
      1 - (conflict_count / max_conflicts)
    else
      1.0
    end
  end
  
  defp calculate_system_coherence(state) do
    # Check if values form coherent system
    type_distribution = state.value_hierarchy
    |> Map.values()
    |> Enum.map(&length/1)
    
    # Good distribution across types
    if length(type_distribution) >= 3 && Enum.all?(type_distribution, &(&1 > 0)) do
      0.9
    else
      0.6
    end
  end
  
  defp calculate_system_effectiveness(state) do
    # Measure value system effectiveness
    if map_size(state.value_metrics) > 0 do
      Map.get(state.value_metrics, :decision_quality, 0.7)
    else
      0.5
    end
  end
  
  defp assess_evolution_need(state) do
    # Check if values need evolution
    factors = [
      state.config.allow_value_evolution,
      map_size(state.value_conflicts) > 2,
      calculate_system_adoption_rate(state) < 0.7
    ]
    
    if Enum.count(factors, & &1) >= 2 do
      0.8  # High evolution need
    else
      0.3  # Low evolution need
    end
  end
  
  defp generate_interventions(metrics, _state) do
    interventions = []
    
    interventions = if metrics.adoption_rate < 0.6 do
      [{:reinforce_values, :high_priority} | interventions]
    else
      interventions
    end
    
    interventions = if metrics.conflict_level < 0.6 do
      [{:resolve_conflicts, :medium_priority} | interventions]
    else
      interventions
    end
    
    interventions = if metrics.coherence < 0.6 do
      [{:rebalance_values, :medium_priority} | interventions]
    else
      interventions
    end
    
    interventions
  end
  
  defp apply_value_interventions(state, interventions) do
    Enum.reduce(interventions, state, fn intervention, acc_state ->
      apply_single_intervention(acc_state, intervention)
    end)
  end
  
  defp apply_single_intervention(state, {:reinforce_values, _priority}) do
    # Increase reinforcement activities
    Logger.info("Values: Initiating value reinforcement program")
    state
  end
  
  defp apply_single_intervention(state, {:resolve_conflicts, _priority}) do
    # Address value conflicts
    Logger.info("Values: Initiating conflict resolution process")
    state
  end
  
  defp apply_single_intervention(state, {:rebalance_values, _priority}) do
    # Rebalance value priorities
    Logger.info("Values: Rebalancing value priorities")
    state
  end
  
  defp apply_single_intervention(state, _other) do
    state
  end
  
  defp schedule_value_assessment(interval) do
    Process.send_after(self(), :assess_values, interval)
  end
end