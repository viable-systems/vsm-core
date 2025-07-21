defmodule VSMCore.System1.TransactionTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.System1.Transaction
  
  describe "new/3" do
    test "creates a transaction with required fields" do
      transaction = Transaction.new(:compute, %{data: "test"})
      
      assert transaction.type == :compute
      assert transaction.payload == %{data: "test"}
      assert transaction.priority == :normal
      assert transaction.required_capabilities == []
      assert is_binary(transaction.id)
      assert %DateTime{} = transaction.created_at
    end
    
    test "accepts optional parameters" do
      opts = [
        id: "custom_id",
        priority: :high,
        required_capabilities: [:compute, :gpu],
        source: :system2,
        deadline: DateTime.add(DateTime.utc_now(), 3600, :second),
        metadata: %{tag: "important"}
      ]
      
      transaction = Transaction.new(:compute, %{op: "test"}, opts)
      
      assert transaction.id == "custom_id"
      assert transaction.priority == :high
      assert transaction.required_capabilities == [:compute, :gpu]
      assert transaction.source == :system2
      assert transaction.deadline != nil
      assert transaction.metadata.tag == "important"
    end
  end
  
  describe "specialized constructors" do
    test "compute/3 creates compute transaction" do
      transaction = Transaction.compute(:factorial, %{n: 5}, priority: :high)
      
      assert transaction.type == :compute
      assert transaction.payload.operation == :factorial
      assert transaction.payload.params == %{n: 5}
      assert transaction.priority == :high
      assert :compute in transaction.required_capabilities
    end
    
    test "data/3 creates data transaction" do
      transaction = Transaction.data(:store, %{key: "value"})
      
      assert transaction.type == :data
      assert transaction.payload.operation == :store
      assert transaction.payload.data == %{key: "value"}
      assert :data in transaction.required_capabilities
    end
    
    test "io/4 creates I/O transaction" do
      transaction = Transaction.io(:write, "/tmp/file", "content")
      
      assert transaction.type == :io
      assert transaction.payload.operation == :write
      assert transaction.payload.target == "/tmp/file"
      assert transaction.payload.data == "content"
      assert :io in transaction.required_capabilities
    end
  end
  
  describe "valid?/1" do
    test "returns true for valid transaction" do
      transaction = Transaction.new(:compute, %{data: "test"})
      assert Transaction.valid?(transaction)
    end
    
    test "returns false for invalid type" do
      transaction = %Transaction{
        id: "test",
        type: "not_an_atom",
        payload: %{},
        created_at: DateTime.utc_now()
      }
      
      refute Transaction.valid?(transaction)
    end
    
    test "returns false for nil payload" do
      transaction = %Transaction{
        id: "test",
        type: :compute,
        payload: nil,
        created_at: DateTime.utc_now()
      }
      
      refute Transaction.valid?(transaction)
    end
    
    test "returns false for deadline before creation" do
      now = DateTime.utc_now()
      transaction = Transaction.new(:compute, %{}, 
        deadline: DateTime.add(now, -3600, :second)
      )
      
      refute Transaction.valid?(transaction)
    end
  end
  
  describe "calculate_input_variety/1" do
    test "calculates variety for compute transactions" do
      transaction = Transaction.compute(:factorial, %{n: 10})
      variety = Transaction.calculate_input_variety(transaction)
      
      assert is_float(variety)
      assert variety > 0
    end
    
    test "calculates variety for data transactions" do
      data = %{
        users: ["alice", "bob", "charlie"],
        scores: [100, 200, 300],
        metadata: %{version: 1}
      }
      
      transaction = Transaction.data(:transform, data)
      variety = Transaction.calculate_input_variety(transaction)
      
      assert is_float(variety)
      assert variety > 0
    end
    
    test "accounts for priority in variety calculation" do
      normal_txn = Transaction.new(:compute, %{n: 5}, priority: :normal)
      critical_txn = Transaction.new(:compute, %{n: 5}, priority: :critical)
      
      normal_variety = Transaction.calculate_input_variety(normal_txn)
      critical_variety = Transaction.calculate_input_variety(critical_txn)
      
      assert critical_variety > normal_variety
    end
    
    test "accounts for capabilities in variety calculation" do
      simple_txn = Transaction.new(:compute, %{}, required_capabilities: [:compute])
      complex_txn = Transaction.new(:compute, %{}, 
        required_capabilities: [:compute, :gpu, :memory, :network]
      )
      
      simple_variety = Transaction.calculate_input_variety(simple_txn)
      complex_variety = Transaction.calculate_input_variety(complex_txn)
      
      assert complex_variety > simple_variety
    end
  end
  
  describe "calculate_output_variety/1" do
    test "calculates variety for successful results" do
      result = {:ok, %{data: [1, 2, 3, 4, 5], metadata: %{processed: true}}}
      variety = Transaction.calculate_output_variety(result)
      
      assert is_float(variety)
      assert variety > 0
    end
    
    test "returns low variety for errors" do
      result = {:error, :processing_failed}
      variety = Transaction.calculate_output_variety(result)
      
      assert variety == 0.1
    end
    
    test "handles different output types" do
      map_result = {:ok, %{a: 1, b: 2, c: 3}}
      list_result = {:ok, [1, 2, 3, 4, 5]}
      binary_result = {:ok, "a long string of data" |> String.duplicate(10)}
      
      map_variety = Transaction.calculate_output_variety(map_result)
      list_variety = Transaction.calculate_output_variety(list_result)
      binary_variety = Transaction.calculate_output_variety(binary_result)
      
      assert map_variety > 0
      assert list_variety > 0
      assert binary_variety > 0
    end
  end
  
  describe "expired?/1 and time_remaining/1" do
    test "returns false for transaction without deadline" do
      transaction = Transaction.new(:compute, %{})
      
      refute Transaction.expired?(transaction)
      assert Transaction.time_remaining(transaction) == :infinity
    end
    
    test "correctly identifies expired transaction" do
      past_deadline = DateTime.add(DateTime.utc_now(), -3600, :second)
      transaction = Transaction.new(:compute, %{}, deadline: past_deadline)
      
      assert Transaction.expired?(transaction)
      assert Transaction.time_remaining(transaction) == 0
    end
    
    test "correctly identifies valid transaction" do
      future_deadline = DateTime.add(DateTime.utc_now(), 3600, :second)
      transaction = Transaction.new(:compute, %{}, deadline: future_deadline)
      
      refute Transaction.expired?(transaction)
      
      remaining = Transaction.time_remaining(transaction)
      assert remaining > 0
      assert remaining <= 3_600_000
    end
  end
  
  describe "serialize/1 and deserialize/1" do
    test "round-trip serialization preserves data" do
      original = Transaction.new(:compute, %{data: "test"}, 
        priority: :high,
        required_capabilities: [:compute, :gpu],
        source: :system3,
        metadata: %{version: 1}
      )
      
      serialized = Transaction.serialize(original)
      deserialized = Transaction.deserialize(serialized)
      
      assert deserialized.id == original.id
      assert deserialized.type == original.type
      assert deserialized.payload == original.payload
      assert deserialized.priority == original.priority
      assert deserialized.required_capabilities == original.required_capabilities
      assert deserialized.source == original.source
      assert deserialized.metadata == original.metadata
    end
    
    test "handles deadline serialization" do
      deadline = DateTime.add(DateTime.utc_now(), 3600, :second)
      transaction = Transaction.new(:compute, %{}, deadline: deadline)
      
      serialized = Transaction.serialize(transaction)
      deserialized = Transaction.deserialize(serialized)
      
      assert DateTime.compare(deserialized.deadline, deadline) == :eq
    end
  end
  
  describe "variety calculations for specific operations" do
    test "factorial variety scales linearly" do
      txn_5 = Transaction.compute(:factorial, %{n: 5})
      txn_10 = Transaction.compute(:factorial, %{n: 10})
      
      variety_5 = Transaction.calculate_input_variety(txn_5)
      variety_10 = Transaction.calculate_input_variety(txn_10)
      
      assert variety_10 / variety_5 == 2.0
    end
    
    test "fibonacci variety scales exponentially" do
      txn_5 = Transaction.compute(:fibonacci, %{n: 5})
      txn_10 = Transaction.compute(:fibonacci, %{n: 10})
      
      variety_5 = Transaction.calculate_input_variety(txn_5)
      variety_10 = Transaction.calculate_input_variety(txn_10)
      
      # Golden ratio approximation
      assert variety_10 / variety_5 > 10
    end
    
    test "data complexity affects variety" do
      simple_data = %{a: 1}
      complex_data = %{
        users: Enum.map(1..100, &"user_#{&1}"),
        nested: %{
          deep: %{
            structure: %{
              with: "data"
            }
          }
        }
      }
      
      simple_txn = Transaction.data(:store, simple_data)
      complex_txn = Transaction.data(:store, complex_data)
      
      simple_variety = Transaction.calculate_input_variety(simple_txn)
      complex_variety = Transaction.calculate_input_variety(complex_txn)
      
      assert complex_variety > simple_variety * 10
    end
  end
end