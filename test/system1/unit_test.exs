defmodule VSMCore.System1.UnitTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.System1.{Unit, Transaction}
  
  setup do
    config = %{
      id: "test_unit",
      capabilities: [:compute, :data],
      health_check_interval: 60_000
    }
    
    {:ok, unit} = Unit.start_link(config)
    
    on_exit(fn ->
      if Process.alive?(unit), do: GenServer.stop(unit)
    end)
    
    {:ok, unit: unit, config: config}
  end
  
  describe "can_handle?/2" do
    test "returns true for matching capabilities", %{unit: unit} do
      transaction = Transaction.compute(:factorial, %{n: 5})
      assert Unit.can_handle?(unit, transaction)
    end
    
    test "returns false for missing capabilities", %{unit: unit} do
      transaction = Transaction.new(:special, %{}, required_capabilities: [:io, :network])
      refute Unit.can_handle?(unit, transaction)
    end
    
    test "handles transactions without required capabilities", %{unit: unit} do
      transaction = Transaction.new(:generic, %{data: "test"})
      assert Unit.can_handle?(unit, transaction)
    end
  end
  
  describe "process/2" do
    test "successfully processes compute transaction", %{unit: unit} do
      transaction = Transaction.compute(:factorial, %{n: 5})
      
      assert {:ok, result} = Unit.process(unit, transaction)
      assert result.result == 120
      assert result.transaction_id == transaction.id
    end
    
    test "successfully processes data transaction", %{unit: unit} do
      data = %{key: "value", nested: %{data: "test"}}
      transaction = Transaction.data(:transform, data)
      
      assert {:ok, result} = Unit.process(unit, transaction)
      assert {:ok, transformed} = result.result
      assert is_map(transformed)
    end
    
    test "returns error when overloaded", %{unit: unit} do
      # Simulate high load
      for _ <- 1..20 do
        Unit.migrate_work(unit, :in, 0.1)
      end
      
      transaction = Transaction.compute(:factorial, %{n: 10})
      assert {:error, :overloaded} = Unit.process(unit, transaction)
    end
    
    test "handles processing errors gracefully", %{unit: unit} do
      # Transaction that will cause an error
      transaction = Transaction.new(:compute, %{operation: :unknown})
      
      result = Unit.process(unit, transaction)
      assert elem(result, 0) == :ok or elem(result, 0) == :error
    end
  end
  
  describe "get_load/1" do
    test "returns current load", %{unit: unit} do
      load = Unit.get_load(unit)
      assert is_float(load) or is_integer(load)
      assert load >= 0 and load <= 1
    end
    
    test "load increases with work migration", %{unit: unit} do
      initial_load = Unit.get_load(unit)
      
      Unit.migrate_work(unit, :in, 0.3)
      :timer.sleep(10)
      
      new_load = Unit.get_load(unit)
      assert new_load > initial_load
    end
  end
  
  describe "get_status/1" do
    test "returns comprehensive status", %{unit: unit, config: config} do
      status = Unit.get_status(unit)
      
      assert %{
        id: "test_unit",
        operational: true,
        load: _,
        health: _,
        uptime: _,
        transactions_processed: _,
        error_rate: _
      } = status
      
      assert status.id == config.id
      assert status.health >= 0 and status.health <= 1
      assert status.uptime >= 0
    end
  end
  
  describe "state management" do
    test "get and update state", %{unit: unit} do
      # Get initial state
      initial_state = Unit.get_state(unit)
      assert initial_state == %{}
      
      # Update state
      new_state = %{counter: 1, data: "test"}
      assert :ok = Unit.update_state(unit, new_state)
      
      # Verify update
      updated_state = Unit.get_state(unit)
      assert updated_state.counter == 1
      assert updated_state.data == "test"
    end
    
    test "state updates are merged", %{unit: unit} do
      # Set initial state
      Unit.update_state(unit, %{a: 1, b: 2})
      
      # Update with partial state
      Unit.update_state(unit, %{b: 3, c: 4})
      
      # Verify merge
      state = Unit.get_state(unit)
      assert state.a == 1
      assert state.b == 3
      assert state.c == 4
    end
  end
  
  describe "execute_command/2" do
    test "executes reset_metrics command", %{unit: unit} do
      # Process some transactions first
      for i <- 1..5 do
        transaction = Transaction.compute(:factorial, %{n: i})
        Unit.process(unit, transaction)
      end
      
      # Execute reset command
      command = %{action: :reset_metrics}
      Unit.execute_command(unit, command)
      
      :timer.sleep(50)
      
      # Verify metrics were reset
      status = Unit.get_status(unit)
      assert status.transactions_processed == 0
      assert status.error_rate == 0.0
    end
    
    test "executes update_capabilities command", %{unit: unit} do
      new_capabilities = [:compute, :data, :io, :network]
      command = %{action: :update_capabilities, capabilities: new_capabilities}
      
      Unit.execute_command(unit, command)
      :timer.sleep(50)
      
      # Verify capabilities were updated
      transaction = Transaction.new(:test, %{}, required_capabilities: [:io, :network])
      assert Unit.can_handle?(unit, transaction)
    end
    
    test "handles unknown commands gracefully", %{unit: unit} do
      command = %{action: :unknown_action}
      
      # Should not crash
      Unit.execute_command(unit, command)
      :timer.sleep(50)
      
      # Unit should still be operational
      assert Process.alive?(unit)
    end
  end
  
  describe "performance characteristics" do
    test "processing time affects load", %{unit: unit} do
      initial_load = Unit.get_load(unit)
      
      # Process multiple transactions
      for i <- 1..10 do
        transaction = Transaction.compute(:fibonacci, %{n: i})
        Unit.process(unit, transaction)
      end
      
      # Load should change based on processing
      final_load = Unit.get_load(unit)
      assert final_load != initial_load
    end
    
    test "health degrades with high error rate", %{unit: unit} do
      initial_status = Unit.get_status(unit)
      initial_health = initial_status.health
      
      # Generate errors
      for _ <- 1..10 do
        bad_transaction = Transaction.new(:compute, %{operation: :invalid})
        Unit.process(unit, bad_transaction)
      end
      
      # Health should be lower
      final_status = Unit.get_status(unit)
      assert final_status.health <= initial_health
    end
  end
end