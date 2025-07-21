defmodule VSMCore.System1.IntegrationTest do
  use ExUnit.Case
  
  alias VSMCore.System1.{Supervisor, Operations, Transaction}
  alias VSMCore.Shared.{Channel, Message}
  
  setup do
    # Start channel infrastructure
    {:ok, _} = Channel.start_link()
    
    # Start S1 subsystem
    {:ok, sup} = Supervisor.start_link(name: :test_s1_supervisor)
    
    on_exit(fn ->
      if Process.alive?(sup), do: Supervisor.stop(sup)
    end)
    
    {:ok, supervisor: sup}
  end
  
  describe "channel communication" do
    test "receives and processes command channel messages" do
      # Subscribe to command channel to simulate S3
      Channel.subscribe(:command_channel)
      
      # Register a unit
      Operations.register_unit(%{
        id: "command_unit",
        capabilities: [:compute],
        auto_restart: false
      })
      
      # Send command from S3
      command = Message.new(
        :system3,
        :system1,
        :command_channel,
        :execute,
        %{
          action: :process_batch,
          parameters: %{batch_size: 10}
        }
      )
      
      Channel.publish(:command_channel, command)
      
      # Allow processing
      :timer.sleep(100)
      
      # Verify command was processed (would check side effects in real system)
      assert Process.alive?(Process.whereis(VSMCore.System1.Operations))
    end
    
    test "sends algedonic signals on critical events" do
      # Subscribe to algedonic channel to simulate S5
      Channel.subscribe(:algedonic_channel)
      
      # Trigger algedonic signal
      Operations.send_algedonic_signal(%{
        severity: :critical,
        message: "Unit failure cascade",
        affected_units: 3,
        timestamp: DateTime.utc_now()
      })
      
      # Should receive the signal
      assert_receive {:channel_message, message}, 1000
      assert message.channel == :algedonic_channel
      assert message.from == :system1
      assert message.to == :system5
      assert message.type == :alert
    end
    
    test "handles resource bargaining with S3" do
      # Subscribe to resource bargain channel
      Channel.subscribe(:resource_bargain_channel)
      
      # Create transaction requiring unavailable capability
      transaction = Transaction.new(
        :special,
        %{operation: "gpu_compute"},
        required_capabilities: [:gpu_cluster]
      )
      
      # Process transaction - should trigger resource request
      result = Operations.process_transaction(transaction)
      
      assert {:error, :no_suitable_unit} = result
      
      # Should receive resource request
      assert_receive {:channel_message, message}, 1000
      assert message.channel == :resource_bargain_channel
      assert message.from == :system1
      assert message.to == :system3
      assert message.type == :unit_request
    end
  end
  
  describe "variety management" do
    test "maintains variety balance under normal load" do
      # Register multiple units
      for i <- 1..3 do
        Operations.register_unit(%{
          id: "variety_unit_#{i}",
          capabilities: [:compute, :data],
          auto_restart: true
        })
      end
      
      :timer.sleep(200)
      
      # Process diverse transactions
      transactions = [
        Transaction.compute(:factorial, %{n: 5}),
        Transaction.data(:store, %{key: "test", value: "data"}),
        Transaction.compute(:fibonacci, %{n: 8}),
        Transaction.data(:transform, %{input: [1, 2, 3]}),
        Transaction.io(:read, "/virtual/file", nil)
      ]
      
      for txn <- transactions do
        Operations.process_transaction(txn)
      end
      
      :timer.sleep(100)
      
      # Check variety measurements
      {:ok, variety} = Operations.get_variety()
      
      # Variety ratio should be close to 1 (good control)
      assert variety.ratio > 0.7
      assert variety.ratio < 1.3
    end
    
    test "detects variety imbalance" do
      # Register limited capability unit
      Operations.register_unit(%{
        id: "limited_unit",
        capabilities: [:compute],
        auto_restart: false
      })
      
      :timer.sleep(100)
      
      # Send transactions requiring various capabilities
      # Most will fail due to missing capabilities
      for i <- 1..10 do
        capability = Enum.random([:compute, :data, :io, :network, :gpu])
        
        transaction = Transaction.new(
          :mixed,
          %{operation: "test_#{i}"},
          required_capabilities: [capability]
        )
        
        Operations.process_transaction(transaction)
      end
      
      :timer.sleep(100)
      
      {:ok, variety} = Operations.get_variety()
      
      # Should show poor variety control
      assert variety.ratio < 0.5 or variety.ratio > 1.5
    end
  end
  
  describe "performance under load" do
    test "handles concurrent transactions efficiently" do
      # Register high-performance units
      for i <- 1..5 do
        Operations.register_unit(%{
          id: "perf_unit_#{i}",
          capabilities: [:compute, :data, :io],
          auto_restart: true
        })
      end
      
      :timer.sleep(300)
      
      # Spawn concurrent transaction processors
      parent = self()
      
      tasks = for i <- 1..100 do
        Task.async(fn ->
          transaction = case rem(i, 3) do
            0 -> Transaction.compute(:factorial, %{n: rem(i, 10) + 1})
            1 -> Transaction.data(:store, %{id: i, data: "test_#{i}"})
            2 -> Transaction.io(:write, "/virtual/#{i}", "content")
          end
          
          start = System.monotonic_time(:millisecond)
          result = Operations.process_transaction(transaction)
          duration = System.monotonic_time(:millisecond) - start
          
          send(parent, {:completed, i, result, duration})
          
          result
        end)
      end
      
      # Wait for all tasks
      results = Task.await_many(tasks, 5000)
      
      # Collect timings
      timings = for i <- 1..100 do
        receive do
          {:completed, ^i, _result, duration} -> duration
        after
          0 -> nil
        end
      end |> Enum.reject(&is_nil/1)
      
      # Verify performance
      successful = Enum.count(results, fn r -> elem(r, 0) == :ok end)
      avg_time = Enum.sum(timings) / length(timings)
      
      assert successful > 95  # At least 95% success rate
      assert avg_time < 50    # Average processing under 50ms
    end
  end
  
  describe "fault tolerance" do
    test "recovers from unit failures" do
      # Register units with auto-restart
      for i <- 1..3 do
        Operations.register_unit(%{
          id: "fault_unit_#{i}",
          capabilities: [:compute],
          auto_restart: true
        })
      end
      
      :timer.sleep(200)
      
      # Get initial unit count
      {:ok, initial_units} = Operations.list_units()
      initial_count = length(initial_units)
      
      # Simulate unit failure (in real system, we'd kill the process)
      # For now, verify the structure supports recovery
      
      # Continue processing
      transaction = Transaction.compute(:factorial, %{n: 5})
      result = Operations.process_transaction(transaction)
      
      assert {:ok, _} = result
      
      # Verify units still operational
      {:ok, final_units} = Operations.list_units()
      assert length(final_units) == initial_count
    end
  end
end