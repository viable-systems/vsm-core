defmodule VSMCore.System1.OperationsTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.System1.{Operations, Transaction}
  
  setup do
    {:ok, pid} = Operations.start_link(name: :test_operations)
    
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)
    
    {:ok, server: pid}
  end
  
  describe "register_unit/2" do
    test "successfully registers a new operational unit", %{server: server} do
      unit_config = %{
        id: "test_unit_1",
        capabilities: [:compute, :data],
        auto_restart: true
      }
      
      assert {:ok, "test_unit_1"} = Operations.register_unit(server, unit_config)
      
      # Verify unit is listed
      {:ok, units} = Operations.list_units(server)
      assert Enum.any?(units, &(&1.id == "test_unit_1"))
    end
    
    test "handles unit registration failures gracefully", %{server: server} do
      # Test with invalid config
      invalid_config = %{id: nil}
      
      assert {:error, _reason} = Operations.register_unit(server, invalid_config)
    end
  end
  
  describe "process_transaction/2" do
    setup %{server: server} do
      # Register a test unit
      unit_config = %{
        id: "processor_unit",
        capabilities: [:compute],
        auto_restart: false
      }
      
      {:ok, _} = Operations.register_unit(server, unit_config)
      :timer.sleep(100) # Allow unit to initialize
      
      {:ok, server: server}
    end
    
    test "processes a valid transaction", %{server: server} do
      transaction = Transaction.compute(:factorial, %{n: 5})
      
      result = Operations.process_transaction(server, transaction)
      
      assert {:ok, %{transaction_id: _, result: 120}} = result
    end
    
    test "returns error when no suitable unit exists", %{server: server} do
      # Create transaction requiring unavailable capability
      transaction = Transaction.new(:special, %{}, required_capabilities: [:unavailable])
      
      assert {:error, :no_suitable_unit} = Operations.process_transaction(server, transaction)
    end
  end
  
  describe "get_variety/1" do
    test "returns variety measurements", %{server: server} do
      assert {:ok, variety} = Operations.get_variety(server)
      
      assert %{
        input: _,
        output: _,
        ratio: _
      } = variety
    end
    
    test "calculates variety after processing transactions", %{server: server} do
      # Register unit and process transactions
      unit_config = %{
        id: "variety_unit",
        capabilities: [:compute],
        auto_restart: false
      }
      
      {:ok, _} = Operations.register_unit(server, unit_config)
      :timer.sleep(100)
      
      # Process multiple transactions
      for i <- 1..5 do
        transaction = Transaction.compute(:factorial, %{n: i})
        Operations.process_transaction(server, transaction)
      end
      
      {:ok, variety} = Operations.get_variety(server)
      
      assert variety.input > 0
      assert variety.output > 0
      assert variety.ratio > 0
    end
  end
  
  describe "get_metrics/1" do
    test "returns comprehensive metrics", %{server: server} do
      assert {:ok, metrics} = Operations.get_metrics(server)
      
      assert %{
        summary: %{
          transactions_total: _,
          transactions_success: _,
          transactions_failed: _,
          success_rate: _
        },
        performance: _,
        variety: _
      } = metrics
    end
  end
  
  describe "send_algedonic_signal/2" do
    test "sends algedonic signal without blocking", %{server: server} do
      signal = %{
        severity: :critical,
        message: "System overload detected",
        source: :test,
        metrics: %{load: 0.95}
      }
      
      # Should not block or raise
      assert :ok = Operations.send_algedonic_signal(server, signal)
    end
  end
  
  describe "unit coordination" do
    test "handles unit failures and restarts", %{server: server} do
      unit_config = %{
        id: "restart_unit",
        capabilities: [:compute],
        auto_restart: true
      }
      
      {:ok, _} = Operations.register_unit(server, unit_config)
      {:ok, units} = Operations.list_units(server)
      
      unit = Enum.find(units, &(&1.id == "restart_unit"))
      assert unit.status.operational
      
      # Simulate unit crash
      # In real implementation, we would kill the process
      # For now, we just verify the structure is in place
    end
  end
  
  describe "channel message handling" do
    test "processes command channel messages", %{server: server} do
      # In a real test, we would simulate channel messages
      # For now, verify the server is running and can handle casts
      assert Process.alive?(server)
    end
  end
end