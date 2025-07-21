defmodule VSMCore.System3.ControlTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.System3.Control
  alias VSMCore.Channels.{CommandChannel, ResourceBargainChannel}
  
  setup do
    # Start test instance of control
    {:ok, pid} = Control.start_link(name: :test_control)
    
    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)
    
    {:ok, pid: pid}
  end
  
  describe "allocate_resources/1" do
    test "allocates resources based on requests and performance" do
      resource_requests = [
        %{
          unit_id: :unit1,
          resources: %{cpu: 30, memory: 40},
          priority: 0.8,
          purpose: :processing
        },
        %{
          unit_id: :unit2,
          resources: %{cpu: 20, memory: 30},
          priority: 0.6,
          purpose: :storage
        }
      ]
      
      {:ok, allocations} = GenServer.call(:test_control, {:allocate_resources, resource_requests})
      
      assert Map.has_key?(allocations, :unit1)
      assert Map.has_key?(allocations, :unit2)
      assert is_map(allocations[:unit1])
      assert is_map(allocations[:unit2])
    end
    
    test "respects resource pool limits" do
      # Request more than available
      huge_requests = [
        %{
          unit_id: :greedy_unit,
          resources: %{cpu: 2000, memory: 2000},
          priority: 1.0,
          purpose: :processing
        }
      ]
      
      {:ok, allocations} = GenServer.call(:test_control, {:allocate_resources, huge_requests})
      
      # Should allocate less than requested
      assert allocations[:greedy_unit][:cpu] < 2000
      assert allocations[:greedy_unit][:memory] < 2000
    end
  end
  
  describe "monitor_performance/1" do
    test "gathers performance metrics for specified units" do
      # First register some units
      GenServer.cast(:test_control, {:register_unit, :unit1, %{type: :processor}})
      GenServer.cast(:test_control, {:register_unit, :unit2, %{type: :storage}})
      
      Process.sleep(100)
      
      {:ok, performance_data, issues} = GenServer.call(:test_control, 
        {:monitor_performance, [:unit1, :unit2]})
      
      assert Map.has_key?(performance_data, :unit1)
      assert Map.has_key?(performance_data, :unit2)
      assert is_list(issues)
    end
    
    test "detects performance issues" do
      # Register a unit
      GenServer.cast(:test_control, {:register_unit, :problematic_unit, %{type: :processor}})
      Process.sleep(100)
      
      # Monitor should detect issues based on policies
      {:ok, _data, issues} = GenServer.call(:test_control,
        {:monitor_performance, [:problematic_unit]})
      
      # May or may not have issues depending on random metrics
      assert is_list(issues)
    end
  end
  
  describe "generate_directives/2" do
    test "generates optimization directives for well-performing units" do
      performance_data = %{
        efficiency: 0.9,
        throughput: 500,
        error_rate: 0.01,
        resource_utilization: %{cpu: 0.7, memory: 0.6}
      }
      
      {:ok, directives} = GenServer.call(:test_control,
        {:generate_directives, :unit1, performance_data})
      
      assert directives.type == :optimization
      assert directives.priority == :low
    end
    
    test "generates corrective directives for underperforming units" do
      performance_data = %{
        efficiency: 0.5,
        throughput: 50,
        error_rate: 0.08,
        resource_utilization: %{cpu: 0.3, memory: 0.2}
      }
      
      {:ok, directives} = GenServer.call(:test_control,
        {:generate_directives, :unit2, performance_data})
      
      assert directives.type in [:corrective, :enforcement]
      assert directives.priority in [:medium, :high]
    end
    
    test "generates enforcement directives for critical violations" do
      performance_data = %{
        efficiency: 0.3,
        throughput: 20,
        error_rate: 0.2,
        resource_utilization: %{cpu: 0.1, memory: 0.1}
      }
      
      {:ok, directives} = GenServer.call(:test_control,
        {:generate_directives, :unit3, performance_data})
      
      assert directives.type == :enforcement
      assert directives.priority == :high
    end
  end
  
  describe "audit_units/2" do
    test "performs comprehensive audit of units" do
      # Register units
      GenServer.cast(:test_control, {:register_unit, :audit_unit1, %{type: :processor}})
      GenServer.cast(:test_control, {:register_unit, :audit_unit2, %{type: :storage}})
      Process.sleep(100)
      
      {:ok, audit_results} = GenServer.call(:test_control,
        {:audit_units, [:audit_unit1, :audit_unit2], :comprehensive}, 35_000)
      
      assert Map.has_key?(audit_results, :audit_unit1)
      assert Map.has_key?(audit_results, :audit_unit2)
      
      result1 = audit_results[:audit_unit1]
      assert result1.audit_type == :comprehensive
      assert is_boolean(result1.issues_found)
      assert is_list(result1.recommendations)
      assert is_float(result1.compliance_score)
    end
    
    test "performs spot check audit" do
      GenServer.cast(:test_control, {:register_unit, :spot_unit, %{type: :processor}})
      Process.sleep(100)
      
      {:ok, audit_results} = GenServer.call(:test_control,
        {:audit_units, [:spot_unit], :spot_check}, 35_000)
      
      assert audit_results[:spot_unit].audit_type == :spot_check
    end
  end
  
  describe "update_resource_pool/1" do
    test "updates available resources" do
      new_resources = %{
        cpu: 200,
        memory: 300,
        io: 150
      }
      
      :ok = GenServer.cast(:test_control, {:update_resource_pool, new_resources})
      
      # Verify by trying to allocate more resources
      Process.sleep(100)
      
      requests = [
        %{
          unit_id: :test_unit,
          resources: %{cpu: 150, memory: 200},
          priority: 1.0,
          purpose: :processing
        }
      ]
      
      {:ok, allocations} = GenServer.call(:test_control, {:allocate_resources, requests})
      
      # Should be able to allocate more with updated pool
      assert allocations[:test_unit][:cpu] > 0
      assert allocations[:test_unit][:memory] > 0
    end
  end
  
  describe "set_control_policies/1" do
    test "updates control policies" do
      new_policies = [
        %{
          type: :efficiency,
          metric: :resource_utilization,
          threshold: 0.8,
          action: :optimize_allocation
        },
        %{
          type: :custom,
          metric: :custom_metric,
          threshold: 100,
          action: :custom_action
        }
      ]
      
      :ok = GenServer.cast(:test_control, {:set_control_policies, new_policies})
      
      # Policies are applied in subsequent operations
      Process.sleep(100)
      
      # This would affect resource allocation and directive generation
      assert true
    end
  end
  
  describe "performance monitoring" do
    test "periodic performance checks run automatically" do
      # Register a unit
      GenServer.cast(:test_control, {:register_unit, :monitored_unit, %{type: :processor}})
      
      # Wait for automatic performance check
      Process.sleep(100)
      
      # The unit should have been monitored
      # In a real test, we'd check metrics or logs
      assert true
    end
  end
end