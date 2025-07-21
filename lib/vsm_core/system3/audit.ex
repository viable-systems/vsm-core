defmodule VSMCore.System3.Audit do
  @moduledoc """
  Audit module for System 3* (S3*).
  
  Implements the sporadic audit channel that provides independent
  verification of S1 unit operations, ensuring compliance and
  identifying issues that regular monitoring might miss.
  """
  
  require Logger
  
  alias VSMCore.Channels.AuditChannel
  alias VSMCore.Shared.Message
  
  @type audit_type :: :comprehensive | :focused | :spot_check | :compliance
  @type audit_result :: %{
    unit_id: atom(),
    audit_type: audit_type(),
    timestamp: DateTime.t(),
    findings: list(),
    issues_found: boolean(),
    issue_categories: list(),
    recommendations: list(),
    compliance_score: float()
  }
  
  @doc """
  Performs an audit of specified S1 units.
  """
  @spec perform_audit([atom()], audit_type(), map()) :: %{atom() => audit_result()}
  def perform_audit(unit_ids, audit_type, system_state) do
    Logger.info("Starting #{audit_type} audit for #{length(unit_ids)} units")
    
    # Perform audits in parallel for efficiency
    tasks = Enum.map(unit_ids, fn unit_id ->
      Task.async(fn ->
        {unit_id, audit_single_unit(unit_id, audit_type, system_state)}
      end)
    end)
    
    # Collect results
    results = tasks
    |> Enum.map(&Task.await(&1, 30_000))
    |> Map.new()
    
    # Send audit complete notifications
    Enum.each(results, fn {unit_id, result} ->
      notify_audit_complete(unit_id, result)
    end)
    
    results
  end
  
  @doc """
  Schedules periodic audits based on risk assessment.
  """
  @spec schedule_audits(map(), map()) :: map()
  def schedule_audits(units, risk_scores) do
    Enum.reduce(units, %{}, fn {unit_id, _unit_info}, schedule ->
      risk_score = Map.get(risk_scores, unit_id, 0.5)
      
      audit_frequency = calculate_audit_frequency(risk_score)
      next_audit = calculate_next_audit_time(audit_frequency)
      
      Map.put(schedule, unit_id, %{
        next_audit: next_audit,
        frequency: audit_frequency,
        audit_type: determine_audit_type(risk_score)
      })
    end)
  end
  
  @doc """
  Analyzes audit findings to identify patterns and systemic issues.
  """
  @spec analyze_audit_patterns([audit_result()]) :: map()
  def analyze_audit_patterns(audit_results) do
    # Group findings by category
    findings_by_category = group_findings_by_category(audit_results)
    
    # Identify recurring issues
    recurring_issues = find_recurring_issues(audit_results)
    
    # Calculate overall compliance trends
    compliance_trends = calculate_compliance_trends(audit_results)
    
    %{
      findings_by_category: findings_by_category,
      recurring_issues: recurring_issues,
      compliance_trends: compliance_trends,
      recommendations: generate_systemic_recommendations(findings_by_category, recurring_issues)
    }
  end
  
  @doc """
  Generates an audit report for management review.
  """
  @spec generate_audit_report([audit_result()]) :: map()
  def generate_audit_report(audit_results) do
    %{
      summary: generate_summary(audit_results),
      detailed_findings: format_detailed_findings(audit_results),
      risk_assessment: assess_overall_risk(audit_results),
      action_items: generate_action_items(audit_results),
      timestamp: DateTime.utc_now()
    }
  end
  
  # Private Functions
  
  defp audit_single_unit(unit_id, audit_type, system_state) do
    start_time = DateTime.utc_now()
    
    # Send audit initiation message
    send_audit_initiation(unit_id, audit_type)
    
    # Perform audit checks based on type
    findings = case audit_type do
      :comprehensive ->
        perform_comprehensive_audit(unit_id, system_state)
        
      :focused ->
        perform_focused_audit(unit_id, system_state)
        
      :spot_check ->
        perform_spot_check(unit_id, system_state)
        
      :compliance ->
        perform_compliance_audit(unit_id, system_state)
    end
    
    # Analyze findings
    issues = identify_issues(findings)
    issue_categories = categorize_issues(issues)
    recommendations = generate_recommendations(issues)
    compliance_score = calculate_compliance_score(findings)
    
    %{
      unit_id: unit_id,
      audit_type: audit_type,
      timestamp: start_time,
      findings: findings,
      issues_found: not Enum.empty?(issues),
      issue_categories: issue_categories,
      recommendations: recommendations,
      compliance_score: compliance_score
    }
  end
  
  defp perform_comprehensive_audit(unit_id, system_state) do
    [
      audit_resource_usage(unit_id, system_state),
      audit_performance_metrics(unit_id, system_state),
      audit_operational_compliance(unit_id, system_state),
      audit_communication_patterns(unit_id, system_state),
      audit_error_handling(unit_id, system_state),
      audit_data_integrity(unit_id, system_state)
    ]
    |> List.flatten()
  end
  
  defp perform_focused_audit(unit_id, system_state) do
    # Focus on areas with known issues
    problem_areas = get_problem_areas(unit_id, system_state)
    
    Enum.flat_map(problem_areas, fn area ->
      case area do
        :resource_usage -> audit_resource_usage(unit_id, system_state)
        :performance -> audit_performance_metrics(unit_id, system_state)
        :compliance -> audit_operational_compliance(unit_id, system_state)
        _ -> []
      end
    end)
  end
  
  defp perform_spot_check(unit_id, system_state) do
    # Random sampling of operations
    sample_size = 10
    operations = get_recent_operations(unit_id, system_state, sample_size)
    
    Enum.map(operations, fn operation ->
      audit_single_operation(operation)
    end)
  end
  
  defp perform_compliance_audit(unit_id, system_state) do
    # Check compliance with all active policies
    policies = get_active_policies(system_state)
    
    Enum.map(policies, fn policy ->
      check_policy_compliance(unit_id, policy, system_state)
    end)
  end
  
  defp audit_resource_usage(unit_id, system_state) do
    allocated = get_in(system_state, [:allocations, unit_id]) || %{}
    actual_usage = simulate_actual_usage(allocated)
    
    findings = []
    
    # Check for over-utilization
    over_utilized = Enum.filter(actual_usage, fn {resource, usage} ->
      allocated_amount = Map.get(allocated, resource, 0)
      allocated_amount > 0 && usage > allocated_amount * 1.1 # 10% tolerance
    end)
    
    findings = if not Enum.empty?(over_utilized) do
      [%{
        type: :resource_over_utilization,
        severity: :high,
        details: %{
          unit_id: unit_id,
          over_utilized: Map.new(over_utilized)
        }
      } | findings]
    else
      findings
    end
    
    # Check for under-utilization
    under_utilized = Enum.filter(actual_usage, fn {resource, usage} ->
      allocated_amount = Map.get(allocated, resource, 0)
      allocated_amount > 0 && usage < allocated_amount * 0.5 # 50% threshold
    end)
    
    if not Enum.empty?(under_utilized) do
      [%{
        type: :resource_under_utilization,
        severity: :medium,
        details: %{
          unit_id: unit_id,
          under_utilized: Map.new(under_utilized)
        }
      } | findings]
    else
      findings
    end
  end
  
  defp audit_performance_metrics(unit_id, system_state) do
    metrics = get_in(system_state, [:performance_metrics, unit_id]) || %{}
    
    findings = []
    
    # Check efficiency
    if metrics[:efficiency] && metrics.efficiency < 0.6 do
      findings = [%{
        type: :low_efficiency,
        severity: :high,
        details: %{
          unit_id: unit_id,
          efficiency: metrics.efficiency,
          threshold: 0.6
        }
      } | findings]
    end
    
    # Check error rate
    if metrics[:error_rate] && metrics.error_rate > 0.05 do
      findings = [%{
        type: :high_error_rate,
        severity: :high,
        details: %{
          unit_id: unit_id,
          error_rate: metrics.error_rate,
          threshold: 0.05
        }
      } | findings]
    end
    
    # Check throughput consistency
    if metrics[:throughput] do
      throughput_variance = calculate_throughput_variance(unit_id, system_state)
      if throughput_variance > 0.3 do
        findings = [%{
          type: :inconsistent_throughput,
          severity: :medium,
          details: %{
            unit_id: unit_id,
            variance: throughput_variance,
            threshold: 0.3
          }
        } | findings]
      end
    end
    
    findings
  end
  
  defp audit_operational_compliance(unit_id, system_state) do
    # Check compliance with operational procedures
    findings = []
    
    # Check if unit is following prescribed schedules
    schedule_compliance = check_schedule_compliance(unit_id, system_state)
    if schedule_compliance < 0.9 do
      findings = [%{
        type: :schedule_non_compliance,
        severity: :medium,
        details: %{
          unit_id: unit_id,
          compliance_rate: schedule_compliance,
          threshold: 0.9
        }
      } | findings]
    end
    
    # Check if unit is responding to directives
    directive_compliance = check_directive_compliance(unit_id, system_state)
    if directive_compliance < 0.95 do
      findings = [%{
        type: :directive_non_compliance,
        severity: :high,
        details: %{
          unit_id: unit_id,
          compliance_rate: directive_compliance,
          threshold: 0.95
        }
      } | findings]
    end
    
    findings
  end
  
  defp audit_communication_patterns(unit_id, system_state) do
    # Audit communication behavior
    findings = []
    
    # Check message response times
    avg_response_time = calculate_avg_response_time(unit_id, system_state)
    if avg_response_time > 1000 do # 1 second
      findings = [%{
        type: :slow_response_time,
        severity: :medium,
        details: %{
          unit_id: unit_id,
          avg_response_time: avg_response_time,
          threshold: 1000
        }
      } | findings]
    end
    
    # Check for communication failures
    failure_rate = calculate_comm_failure_rate(unit_id, system_state)
    if failure_rate > 0.02 do # 2%
      findings = [%{
        type: :communication_failures,
        severity: :high,
        details: %{
          unit_id: unit_id,
          failure_rate: failure_rate,
          threshold: 0.02
        }
      } | findings]
    end
    
    findings
  end
  
  defp audit_error_handling(unit_id, system_state) do
    # Check error handling practices
    findings = []
    
    # Check for unhandled errors
    unhandled_errors = count_unhandled_errors(unit_id, system_state)
    if unhandled_errors > 0 do
      findings = [%{
        type: :unhandled_errors,
        severity: :critical,
        details: %{
          unit_id: unit_id,
          count: unhandled_errors
        }
      } | findings]
    end
    
    # Check error recovery time
    avg_recovery_time = calculate_avg_recovery_time(unit_id, system_state)
    if avg_recovery_time > 5000 do # 5 seconds
      findings = [%{
        type: :slow_error_recovery,
        severity: :medium,
        details: %{
          unit_id: unit_id,
          avg_recovery_time: avg_recovery_time,
          threshold: 5000
        }
      } | findings]
    end
    
    findings
  end
  
  defp audit_data_integrity(unit_id, system_state) do
    # Check data handling and integrity
    findings = []
    
    # Check for data inconsistencies
    inconsistencies = find_data_inconsistencies(unit_id, system_state)
    if not Enum.empty?(inconsistencies) do
      findings = [%{
        type: :data_inconsistency,
        severity: :high,
        details: %{
          unit_id: unit_id,
          inconsistencies: inconsistencies
        }
      } | findings]
    end
    
    # Check for data loss
    data_loss_incidents = check_data_loss(unit_id, system_state)
    if data_loss_incidents > 0 do
      findings = [%{
        type: :data_loss,
        severity: :critical,
        details: %{
          unit_id: unit_id,
          incidents: data_loss_incidents
        }
      } | findings]
    end
    
    findings
  end
  
  defp identify_issues(findings) do
    Enum.filter(findings, fn finding ->
      finding[:severity] in [:high, :critical]
    end)
  end
  
  defp categorize_issues(issues) do
    issues
    |> Enum.map(& &1.type)
    |> Enum.uniq()
    |> Enum.group_by(fn type ->
      cond do
        type in [:resource_over_utilization, :resource_under_utilization] -> :resource_management
        type in [:low_efficiency, :high_error_rate, :inconsistent_throughput] -> :performance
        type in [:schedule_non_compliance, :directive_non_compliance] -> :compliance
        type in [:slow_response_time, :communication_failures] -> :communication
        type in [:unhandled_errors, :slow_error_recovery] -> :error_handling
        type in [:data_inconsistency, :data_loss] -> :data_integrity
        true -> :other
      end
    end)
    |> Map.keys()
  end
  
  defp generate_recommendations(issues) do
    Enum.flat_map(issues, fn issue ->
      case issue.type do
        :resource_over_utilization ->
          ["Increase resource allocation", "Optimize resource usage patterns"]
          
        :resource_under_utilization ->
          ["Reduce resource allocation", "Investigate low utilization causes"]
          
        :low_efficiency ->
          ["Review and optimize operational procedures", "Provide additional training"]
          
        :high_error_rate ->
          ["Implement enhanced error prevention", "Review error handling procedures"]
          
        :directive_non_compliance ->
          ["Enforce directive compliance", "Review directive clarity and feasibility"]
          
        :data_loss ->
          ["Implement data backup procedures", "Add data integrity checks"]
          
        _ ->
          ["Investigate and address #{issue.type}"]
      end
    end)
    |> Enum.uniq()
  end
  
  defp calculate_compliance_score(findings) do
    if Enum.empty?(findings) do
      1.0
    else
      total_weight = Enum.reduce(findings, 0, fn finding, acc ->
        acc + severity_weight(finding.severity)
      end)
      
      # Score decreases with severity-weighted findings
      max(0, 1.0 - (total_weight / 100.0))
    end
  end
  
  defp severity_weight(severity) do
    case severity do
      :critical -> 25
      :high -> 15
      :medium -> 8
      :low -> 3
    end
  end
  
  defp send_audit_initiation(unit_id, audit_type) do
    message = Message.new(
      from: :system3_audit,
      to: unit_id,
      channel: :audit,
      type: :audit_initiation,
      payload: %{
        audit_type: audit_type,
        timestamp: DateTime.utc_now()
      }
    )
    
    AuditChannel.send_message(message)
  end
  
  defp notify_audit_complete(unit_id, result) do
    message = Message.new(
      from: :system3_audit,
      to: unit_id,
      channel: :audit,
      type: :audit_complete,
      payload: %{
        issues_found: result.issues_found,
        compliance_score: result.compliance_score,
        recommendations: result.recommendations
      }
    )
    
    AuditChannel.send_message(message)
  end
  
  defp calculate_audit_frequency(risk_score) do
    cond do
      risk_score > 0.8 -> :daily
      risk_score > 0.6 -> :weekly
      risk_score > 0.4 -> :biweekly
      true -> :monthly
    end
  end
  
  defp calculate_next_audit_time(frequency) do
    seconds = case frequency do
      :daily -> 86_400
      :weekly -> 604_800
      :biweekly -> 1_209_600
      :monthly -> 2_592_000
    end
    
    DateTime.add(DateTime.utc_now(), seconds, :second)
  end
  
  defp determine_audit_type(risk_score) do
    cond do
      risk_score > 0.8 -> :comprehensive
      risk_score > 0.5 -> :focused
      true -> :spot_check
    end
  end
  
  defp group_findings_by_category(audit_results) do
    audit_results
    |> Enum.flat_map(& &1.findings)
    |> Enum.group_by(& &1.type)
  end
  
  defp find_recurring_issues(audit_results) do
    all_issues = audit_results
    |> Enum.flat_map(& &1.findings)
    |> Enum.filter(& &1[:severity] in [:high, :critical])
    
    # Group by type and unit
    grouped = Enum.group_by(all_issues, fn issue ->
      {issue.type, get_in(issue, [:details, :unit_id])}
    end)
    
    # Find issues that appear multiple times
    Enum.filter(grouped, fn {_key, issues} ->
      length(issues) > 1
    end)
    |> Map.new()
  end
  
  defp calculate_compliance_trends(audit_results) do
    # Group by timestamp (daily buckets)
    by_day = Enum.group_by(audit_results, fn result ->
      DateTime.to_date(result.timestamp)
    end)
    
    # Calculate average compliance per day
    Map.new(by_day, fn {date, results} ->
      avg_compliance = Enum.sum(Enum.map(results, & &1.compliance_score)) / length(results)
      {date, avg_compliance}
    end)
  end
  
  defp generate_systemic_recommendations(findings_by_category, recurring_issues) do
    recommendations = []
    
    # Resource management recommendations
    if Map.has_key?(findings_by_category, :resource_over_utilization) do
      recommendations = ["Review and adjust resource allocation policies" | recommendations]
    end
    
    # Performance recommendations
    if Map.has_key?(findings_by_category, :low_efficiency) do
      recommendations = ["Implement performance optimization program" | recommendations]
    end
    
    # Recurring issue recommendations
    if map_size(recurring_issues) > 3 do
      recommendations = ["Conduct root cause analysis of recurring issues" | recommendations]
    end
    
    recommendations
  end
  
  defp generate_summary(audit_results) do
    total_units = length(audit_results)
    units_with_issues = Enum.count(audit_results, & &1.issues_found)
    avg_compliance = Enum.sum(Enum.map(audit_results, & &1.compliance_score)) / total_units
    
    %{
      total_units_audited: total_units,
      units_with_issues: units_with_issues,
      issue_rate: units_with_issues / total_units,
      average_compliance_score: avg_compliance,
      status: determine_overall_status(avg_compliance, units_with_issues / total_units)
    }
  end
  
  defp determine_overall_status(avg_compliance, issue_rate) do
    cond do
      avg_compliance < 0.7 || issue_rate > 0.5 -> :critical
      avg_compliance < 0.85 || issue_rate > 0.3 -> :warning
      true -> :healthy
    end
  end
  
  defp format_detailed_findings(audit_results) do
    Enum.map(audit_results, fn result ->
      %{
        unit_id: result.unit_id,
        audit_type: result.audit_type,
        compliance_score: result.compliance_score,
        findings: Enum.map(result.findings, &format_finding/1),
        recommendations: result.recommendations
      }
    end)
  end
  
  defp format_finding(finding) do
    %{
      type: finding.type,
      severity: finding.severity,
      description: describe_finding(finding),
      details: finding.details
    }
  end
  
  defp describe_finding(finding) do
    case finding.type do
      :resource_over_utilization ->
        "Unit is using more resources than allocated"
        
      :low_efficiency ->
        "Unit efficiency is below acceptable threshold"
        
      :high_error_rate ->
        "Unit error rate exceeds acceptable limits"
        
      :directive_non_compliance ->
        "Unit is not following control directives"
        
      :data_loss ->
        "Data loss incidents detected"
        
      _ ->
        "#{finding.type} detected"
    end
  end
  
  defp assess_overall_risk(audit_results) do
    risk_factors = calculate_risk_factors(audit_results)
    risk_score = calculate_risk_score(risk_factors)
    
    %{
      risk_score: risk_score,
      risk_level: determine_risk_level(risk_score),
      risk_factors: risk_factors,
      mitigation_priority: determine_mitigation_priority(risk_factors)
    }
  end
  
  defp calculate_risk_factors(audit_results) do
    %{
      compliance_risk: calculate_compliance_risk(audit_results),
      operational_risk: calculate_operational_risk(audit_results),
      data_risk: calculate_data_risk(audit_results),
      systemic_risk: calculate_systemic_risk(audit_results)
    }
  end
  
  defp calculate_compliance_risk(audit_results) do
    compliance_issues = Enum.count(audit_results, fn result ->
      Enum.any?(result.findings, & &1.type in [:directive_non_compliance, :schedule_non_compliance])
    end)
    
    compliance_issues / length(audit_results)
  end
  
  defp calculate_operational_risk(audit_results) do
    operational_issues = Enum.count(audit_results, fn result ->
      Enum.any?(result.findings, & &1.type in [:low_efficiency, :high_error_rate])
    end)
    
    operational_issues / length(audit_results)
  end
  
  defp calculate_data_risk(audit_results) do
    data_issues = Enum.count(audit_results, fn result ->
      Enum.any?(result.findings, & &1.type in [:data_loss, :data_inconsistency])
    end)
    
    # Data issues are weighted more heavily
    (data_issues / length(audit_results)) * 2.0
  end
  
  defp calculate_systemic_risk(audit_results) do
    # Risk increases if many units have similar issues
    common_issues = audit_results
    |> Enum.flat_map(& &1.findings)
    |> Enum.map(& &1.type)
    |> Enum.frequencies()
    |> Enum.filter(fn {_type, count} -> count > length(audit_results) * 0.3 end)
    
    length(common_issues) * 0.2
  end
  
  defp calculate_risk_score(risk_factors) do
    risk_factors
    |> Map.values()
    |> Enum.sum()
    |> min(1.0)
  end
  
  defp determine_risk_level(risk_score) do
    cond do
      risk_score > 0.7 -> :high
      risk_score > 0.4 -> :medium
      true -> :low
    end
  end
  
  defp determine_mitigation_priority(risk_factors) do
    risk_factors
    |> Enum.sort_by(fn {_type, score} -> -score end)
    |> Enum.take(2)
    |> Enum.map(fn {type, _} -> type end)
  end
  
  defp generate_action_items(audit_results) do
    critical_findings = audit_results
    |> Enum.flat_map(& &1.findings)
    |> Enum.filter(& &1.severity == :critical)
    
    high_findings = audit_results
    |> Enum.flat_map(& &1.findings)
    |> Enum.filter(& &1.severity == :high)
    
    action_items = []
    
    # Critical items need immediate attention
    action_items = action_items ++ Enum.map(critical_findings, fn finding ->
      %{
        priority: :immediate,
        type: finding.type,
        unit_id: get_in(finding, [:details, :unit_id]),
        action: "Address critical #{finding.type} immediately",
        deadline: DateTime.add(DateTime.utc_now(), 3600, :second)
      }
    end)
    
    # High priority items need attention within 24 hours
    action_items = action_items ++ Enum.take(high_findings, 5) |> Enum.map(fn finding ->
      %{
        priority: :high,
        type: finding.type,
        unit_id: get_in(finding, [:details, :unit_id]),
        action: "Resolve #{finding.type} issue",
        deadline: DateTime.add(DateTime.utc_now(), 86_400, :second)
      }
    end)
    
    action_items
  end
  
  # Simulation helper functions (would be replaced with real data in production)
  
  defp simulate_actual_usage(allocated) do
    Map.new(allocated, fn {resource, amount} ->
      # Simulate usage between 50% and 120% of allocated
      usage = amount * (0.5 + :rand.uniform() * 0.7)
      {resource, usage}
    end)
  end
  
  defp get_problem_areas(_unit_id, _system_state) do
    # Simulate problem areas
    [:resource_usage, :performance] |> Enum.take(:rand.uniform(2))
  end
  
  defp get_recent_operations(_unit_id, _system_state, count) do
    # Simulate recent operations
    Enum.map(1..count, fn i ->
      %{
        id: "op_#{i}",
        type: Enum.random([:process, :compute, :store]),
        status: Enum.random([:success, :success, :success, :failed]),
        duration: :rand.uniform(1000)
      }
    end)
  end
  
  defp audit_single_operation(operation) do
    if operation.status == :failed do
      %{
        type: :operation_failure,
        severity: :medium,
        details: %{operation_id: operation.id}
      }
    else
      %{
        type: :operation_success,
        severity: :info,
        details: %{operation_id: operation.id}
      }
    end
  end
  
  defp get_active_policies(system_state) do
    Map.get(system_state, :control_policies, [])
  end
  
  defp check_policy_compliance(_unit_id, policy, _system_state) do
    # Simulate policy compliance check
    compliance = :rand.uniform()
    
    if compliance < 0.9 do
      %{
        type: :policy_violation,
        severity: :high,
        details: %{
          policy: policy.type,
          compliance_level: compliance
        }
      }
    else
      %{
        type: :policy_compliant,
        severity: :info,
        details: %{policy: policy.type}
      }
    end
  end
  
  defp calculate_throughput_variance(_unit_id, _system_state) do
    # Simulate throughput variance
    :rand.uniform() * 0.5
  end
  
  defp check_schedule_compliance(_unit_id, _system_state) do
    # Simulate schedule compliance
    0.85 + :rand.uniform() * 0.15
  end
  
  defp check_directive_compliance(_unit_id, _system_state) do
    # Simulate directive compliance
    0.9 + :rand.uniform() * 0.1
  end
  
  defp calculate_avg_response_time(_unit_id, _system_state) do
    # Simulate response time in milliseconds
    500 + :rand.uniform(1000)
  end
  
  defp calculate_comm_failure_rate(_unit_id, _system_state) do
    # Simulate communication failure rate
    :rand.uniform() * 0.05
  end
  
  defp count_unhandled_errors(_unit_id, _system_state) do
    # Simulate unhandled error count
    if :rand.uniform() > 0.9, do: :rand.uniform(3), else: 0
  end
  
  defp calculate_avg_recovery_time(_unit_id, _system_state) do
    # Simulate recovery time in milliseconds
    2000 + :rand.uniform(5000)
  end
  
  defp find_data_inconsistencies(_unit_id, _system_state) do
    # Simulate data inconsistencies
    if :rand.uniform() > 0.8 do
      ["timestamp_mismatch", "missing_fields"]
    else
      []
    end
  end
  
  defp check_data_loss(_unit_id, _system_state) do
    # Simulate data loss incidents
    if :rand.uniform() > 0.95, do: 1, else: 0
  end
end