defmodule VSMCore.System5.PolicyTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.System5.Policy
  alias VSMCore.{Message, Registry}
  
  setup do
    # Start Registry if not already started
    Registry.start_link(keys: :unique, name: VSMCore.Registry)
    
    # Start S5 Policy
    {:ok, policy} = Policy.start_link()
    
    # Allow processes to initialize
    Process.sleep(100)
    
    %{policy: policy}
  end
  
  describe "identity management" do
    test "sets organizational identity" do
      identity_config = %{
        purpose: %{
          statement: "To innovate and lead in technology",
          why_we_exist: "Enable digital transformation"
        },
        mission: %{
          statement: "Deliver cutting-edge solutions",
          key_activities: ["Research", "Development", "Innovation"]
        },
        vision: %{
          statement: "Be the global technology leader",
          time_horizon: "5 years"
        }
      }
      
      assert {:ok, _identity} = Policy.set_identity(identity_config)
    end
    
    test "validates identity configuration" do
      # Missing required fields
      invalid_config = %{
        purpose: "Just a string, not a map"
      }
      
      assert {:error, _reason} = Policy.set_identity(invalid_config)
    end
  end
  
  describe "values definition" do
    test "defines organizational values" do
      values = [
        %{name: "Innovation", description: "Continuous improvement", priority: 1},
        %{name: "Quality", description: "Excellence in everything", priority: 2},
        %{name: "Teamwork", description: "Collaborate effectively", priority: 3}
      ]
      
      assert {:ok, _values} = Policy.define_values(values)
    end
    
    test "updates policies based on new values" do
      values = [
        %{name: "Sustainability", description: "Environmental responsibility", priority: 1}
      ]
      
      assert {:ok, _values} = Policy.define_values(values)
      
      # Verify organizational state reflects values
      {:ok, state} = Policy.get_organizational_state()
      assert Map.has_key?(state, :values)
    end
  end
  
  describe "decision making" do
    test "makes decision based on context and inputs" do
      decision_request = %{
        subject: "New product launch",
        urgency: :high,
        options: [
          %{name: "Launch immediately", risk: :high, benefit: :high},
          %{name: "Delay 3 months", risk: :low, benefit: :medium},
          %{name: "Cancel project", risk: :low, benefit: :low}
        ]
      }
      
      {:ok, decision} = Policy.make_decision(decision_request)
      
      assert Map.has_key?(decision, :selected_option)
      assert Map.has_key?(decision, :rationale)
      assert Map.has_key?(decision, :confidence)
      assert decision.action_required in [:immediate, :scheduled, :none]
    end
    
    test "considers crisis mode in decisions" do
      # First set crisis mode
      crisis_info = %{
        type: :system_failure,
        severity: :critical,
        description: "Major system outage",
        affected_area: :operations
      }
      
      {:ok, crisis_decisions} = Policy.handle_crisis(crisis_info)
      assert is_list(crisis_decisions)
      
      # Now make a decision while in crisis mode
      decision_request = %{
        subject: "Resource allocation",
        urgency: :critical
      }
      
      {:ok, decision} = Policy.make_decision(decision_request)
      assert decision.context.crisis_mode == true
    end
  end
  
  describe "policy management" do
    test "sets policy for specific area" do
      policy_details = %{
        description: "Ensure data security",
        rules: [
          %{type: :requirement, field: :encryption, value: true},
          %{type: :threshold, field: :access_level, min_value: 2}
        ],
        effective_date: DateTime.utc_now()
      }
      
      assert {:ok, validated_policy} = Policy.set_policy(:security, policy_details)
      assert validated_policy.values_approved == true
    end
    
    test "validates policy against values" do
      # Set values first
      values = [
        %{name: "Transparency", description: "Open communication", priority: 1}
      ]
      Policy.define_values(values)
      
      # Try to set conflicting policy
      conflicting_policy = %{
        description: "Restrict information",
        excludes: ["transparency", "openness"]
      }
      
      assert {:error, _reason} = Policy.set_policy(:communication, conflicting_policy)
    end
  end
  
  describe "alignment evaluation" do
    test "evaluates proposal alignment" do
      proposal = %{
        name: "New AI Initiative",
        description: "Implement AI across operations",
        affected_areas: [:operations, :innovation],
        values_impact: %{
          innovation: 0.8,
          efficiency: 0.6
        }
      }
      
      {:ok, alignment, recommendations} = Policy.evaluate_alignment(proposal)
      
      assert Map.has_key?(alignment, :overall_score)
      assert Map.has_key?(alignment, :identity_alignment)
      assert Map.has_key?(alignment, :values_alignment)
      assert is_float(alignment.overall_score)
      assert is_list(recommendations)
    end
    
    test "provides recommendations for low alignment" do
      misaligned_proposal = %{
        name: "Cost Cutting Initiative",
        description: "Reduce all expenses by 50%",
        affected_areas: [:all],
        values_impact: %{
          quality: -0.8,
          innovation: -0.6
        }
      }
      
      {:ok, alignment, recommendations} = Policy.evaluate_alignment(misaligned_proposal)
      
      assert alignment.overall_score < 0.7
      assert length(recommendations) > 0
    end
  end
  
  describe "crisis handling" do
    test "handles crisis appropriately" do
      crisis_info = %{
        type: :market_crash,
        severity: :critical,
        description: "Sudden market downturn",
        affected_area: :financial
      }
      
      {:ok, decisions} = Policy.handle_crisis(crisis_info)
      
      assert is_list(decisions)
      assert Enum.any?(decisions, &(&1.priority == :critical))
      assert Enum.any?(decisions, &(&1.type in [:survival, :resource_allocation, :communication]))
    end
    
    test "issues emergency commands during crisis" do
      crisis_info = %{
        type: :security_breach,
        severity: :critical,
        description: "Data breach detected",
        affected_area: :security
      }
      
      {:ok, decisions} = Policy.handle_crisis(crisis_info)
      
      # Verify emergency commands were generated
      assert Enum.any?(decisions, fn decision ->
        length(decision.commands) > 0
      end)
    end
  end
  
  describe "organizational health" do
    test "reports organizational state" do
      {:ok, state} = Policy.get_organizational_state()
      
      assert Map.has_key?(state, :identity)
      assert Map.has_key?(state, :values)
      assert Map.has_key?(state, :policies)
      assert Map.has_key?(state, :health)
      assert Map.has_key?(state, :crisis_mode)
      assert is_boolean(state.crisis_mode)
    end
    
    test "tracks organizational health metrics" do
      {:ok, state} = Policy.get_organizational_state()
      
      health = state.health
      assert Map.has_key?(health, :overall)
      assert Map.has_key?(health, :subsystems)
      assert Map.has_key?(health, :metrics)
      assert is_float(health.overall)
      assert health.overall >= 0 and health.overall <= 1
    end
  end
  
  describe "algedonic signal handling" do
    test "responds to critical alerts" do
      # This test would require mocking the AlgedonicChannel
      # For now, we ensure the basic functionality works
      
      {:ok, state} = Policy.get_organizational_state()
      assert Map.has_key?(state, :crisis_mode)
    end
  end
  
  describe "decision history" do
    test "maintains decision history" do
      # Make several decisions
      Enum.each(1..3, fn i ->
        decision_request = %{
          subject: "Decision #{i}",
          urgency: :medium
        }
        Policy.make_decision(decision_request)
      end)
      
      {:ok, state} = Policy.get_organizational_state()
      assert is_list(state.recent_decisions)
      assert length(state.recent_decisions) <= 5
    end
  end
end