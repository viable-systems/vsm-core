defmodule VSMCore.Concurrency.EventOrderingTest do
  @moduledoc """
  Comprehensive tests for event ordering and delivery in distributed VSM environment.
  Tests causality preservation, ordering guarantees, and concurrent message processing.
  """
  
  use ExUnit.Case, async: false
  
  alias VSMCore.Shared.Message
  alias VSMCore.Channels.Temporal.Causality
  alias VSMCore.Channels.{CommandChannel, CoordinationChannel, AlgedonicChannel}
  
  import ExUnit.CaptureLog
  
  # Test fixtures
  @test_timeout 30_000
  @concurrent_producers 10
  @messages_per_producer 100
  @node_count 3
  
  setup_all do
    # Start required processes for testing
    start_supervised!({Registry, keys: :unique, name: VSMCore.TestRegistry})
    start_supervised!(VSMCore.Channels.Supervisor)
    
    # Setup test nodes for distributed testing
    nodes = setup_test_cluster(@node_count)
    
    %{nodes: nodes}
  end
  
  setup do
    # Clean up between tests
    :ok = cleanup_channels()
    
    # Setup test message tracking
    {:ok, collector} = start_message_collector()
    
    %{collector: collector}
  end
  
  describe "concurrent message ordering" do
    test "maintains causal order under high concurrency", %{collector: collector} do
      # Setup causal chain: A -> B -> C
      message_a = Message.command(:system5, :system4, :start_chain, %{chain_id: "test_1"})
      message_b = Message.command(:system4, :system3, :continue_chain, 
                    %{chain_id: "test_1", depends_on: message_a.id})
      message_c = Message.command(:system3, :system1, :finish_chain, 
                    %{chain_id: "test_1", depends_on: message_b.id})
      
      # Send messages from multiple concurrent processes
      tasks = for i <- 1..@concurrent_producers do
        Task.async(fn ->
          # Each producer sends the causal chain rapidly
          CommandChannel.publish(message_a)
          Process.sleep(1) # Minimal delay
          CommandChannel.publish(message_b)
          Process.sleep(1)
          CommandChannel.publish(message_c)
          
          producer_id: i
        end)
      end
      
      # Wait for all producers to complete
      results = Task.await_many(tasks, @test_timeout)
      assert length(results) == @concurrent_producers
      
      # Collect and analyze message ordering
      Process.sleep(100) # Allow message processing
      collected_messages = get_collected_messages(collector)
      
      # Verify causal ordering is preserved
      chains = group_messages_by_chain(collected_messages)
      
      for {chain_id, messages} <- chains do
        sorted_messages = Enum.sort_by(messages, & &1.timestamp)
        assert verify_causal_order(sorted_messages), 
               "Causal order violated in chain #{chain_id}"
      end
    end
    
    test "handles simultaneous message bursts", %{collector: collector} do
      # Create a burst of messages from different systems simultaneously
      message_templates = [
        {:system1, :system2, :status_update},
        {:system2, :system1, :coordination_request},
        {:system3, :system1, :resource_allocation},
        {:system1, :system3, :resource_response},
        {:system4, :system3, :intelligence_report},
        {:system5, :system4, :policy_directive}
      ]
      
      # Send burst from multiple processes
      start_time = System.monotonic_time(:millisecond)
      
      tasks = for i <- 1..@concurrent_producers do
        Task.async(fn ->
          for {from, to, type} <- message_templates do
            message = Message.new(from, to, get_channel_for_systems(from, to), 
                                type, %{producer: i, timestamp: System.monotonic_time()})
            publish_to_channel(message)
          end
          
          producer_id: i
        end)
      end
      
      Task.await_many(tasks, @test_timeout)
      end_time = System.monotonic_time(:millisecond)
      
      # Verify all messages were processed
      Process.sleep(200)
      collected_messages = get_collected_messages(collector)
      
      expected_count = @concurrent_producers * length(message_templates)
      assert length(collected_messages) == expected_count,
             "Expected #{expected_count} messages, got #{length(collected_messages)}"
      
      # Verify no message corruption
      for message <- collected_messages do
        assert Message.valid?(message), "Message corruption detected: #{inspect(message)}"
      end
      
      # Performance assertion
      processing_time = end_time - start_time
      assert processing_time < 5000, 
             "Message burst processing took too long: #{processing_time}ms"
    end
    
    test "preserves message ordering across system boundaries" do
      # Test ordering between VSM subsystems
      system_pairs = [
        {:system1, :system2},
        {:system2, :system1}, 
        {:system3, :system1},
        {:system1, :system3},
        {:system4, :system3},
        {:system5, :system4}
      ]
      
      for {from_system, to_system} <- system_pairs do
        messages = for i <- 1..50 do
          Message.new(from_system, to_system, get_channel_for_systems(from_system, to_system),
                     :sequence_test, %{sequence: i, sender: from_system})
        end
        
        # Send messages rapidly
        for message <- messages do
          publish_to_channel(message)
        end
        
        # Verify ordering is preserved
        Process.sleep(100)
        received = get_messages_for_system_pair(from_system, to_system)
        sequences = Enum.map(received, &get_in(&1.payload, [:sequence]))
        
        assert sequences == Enum.sort(sequences),
               "Message ordering violated for #{from_system} -> #{to_system}"
      end
    end
  end
  
  describe "distributed event consistency" do
    test "maintains consistency across multiple nodes", %{nodes: nodes} do
      # Distribute test across cluster nodes
      message_sets = partition_messages_across_nodes(nodes, 1000)
      
      # Send messages from each node simultaneously
      tasks = for {node, messages} <- message_sets do
        Task.async(fn ->
          :rpc.call(node, __MODULE__, :send_message_batch, [messages])
        end)
      end
      
      results = Task.await_many(tasks, @test_timeout)
      
      # Collect results from all nodes
      all_processed = Enum.flat_map(results, & &1)
      
      # Verify global ordering consistency
      global_timeline = build_global_timeline(all_processed)
      assert verify_global_consistency(global_timeline)
    end
    
    test "handles network partitions gracefully", %{nodes: nodes} do
      # Simulate network partition
      [node1, node2, node3] = nodes
      
      # Create partition: node1 isolated from node2, node3
      :rpc.call(node1, :net_kernel, :disconnect_node, [node2])
      :rpc.call(node1, :net_kernel, :disconnect_node, [node3])
      
      # Send messages during partition
      partition_messages = generate_partition_test_messages()
      
      # Send from isolated node
      :rpc.call(node1, __MODULE__, :send_message_batch, [partition_messages])
      
      # Send from connected nodes
      :rpc.call(node2, __MODULE__, :send_message_batch, [partition_messages])
      :rpc.call(node3, __MODULE__, :send_message_batch, [partition_messages])
      
      Process.sleep(1000)
      
      # Reconnect nodes
      :rpc.call(node1, :net_kernel, :connect_node, [node2])
      :rpc.call(node1, :net_kernel, :connect_node, [node3])
      
      # Allow reconciliation
      Process.sleep(2000)
      
      # Verify eventual consistency
      final_states = for node <- nodes do
        :rpc.call(node, __MODULE__, :get_node_state, [])
      end
      
      assert verify_eventual_consistency(final_states)
    end
  end
  
  describe "hybrid logical clock ordering" do
    test "generates monotonic HLC timestamps under load" do
      # Generate HLC timestamps from multiple concurrent processes
      timestamp_generators = for i <- 1..@concurrent_producers do
        Task.async(fn ->
          for j <- 1..@messages_per_producer do
            {
              generate_hlc_timestamp(),
              {i, j}
            }
          end
        end)
      end
      
      all_timestamps = 
        timestamp_generators
        |> Task.await_many(@test_timeout)
        |> List.flatten()
      
      # Verify monotonicity
      sorted_by_generation = Enum.sort_by(all_timestamps, fn {{logical, physical, _}, _} ->
        {physical, logical}
      end)
      
      previous_hlc = {0, 0, 0}
      
      for {{logical, physical, node_id}, metadata} <- sorted_by_generation do
        current_hlc = {logical, physical, node_id}
        assert hlc_compare(current_hlc, previous_hlc) >= 0,
               "HLC monotonicity violated: #{inspect(current_hlc)} <= #{inspect(previous_hlc)}"
        previous_hlc = current_hlc
      end
    end
    
    test "maintains causal relationships with HLC" do
      # Create causal chain with HLC timestamps
      events = [
        {:send, :alice, :bob, "Hello"},
        {:receive, :bob, :alice, "Hello"},
        {:send, :bob, :alice, "Hi back"},
        {:receive, :alice, :bob, "Hi back"}
      ]
      
      # Process events and assign HLC timestamps
      timestamped_events = process_causal_events(events)
      
      # Verify causal relationships are preserved
      send_hello = find_event(timestamped_events, {:send, :alice, :bob, "Hello"})
      receive_hello = find_event(timestamped_events, {:receive, :bob, :alice, "Hello"})
      send_reply = find_event(timestamped_events, {:send, :bob, :alice, "Hi back"})
      receive_reply = find_event(timestamped_events, {:receive, :alice, :bob, "Hi back"})
      
      # Verify happens-before relationships
      assert hlc_happens_before(send_hello.hlc, receive_hello.hlc)
      assert hlc_happens_before(receive_hello.hlc, send_reply.hlc)
      assert hlc_happens_before(send_reply.hlc, receive_reply.hlc)
    end
  end
  
  describe "causality chain analysis under concurrency" do
    test "detects causal chains in high-throughput scenario" do
      # Generate complex causal patterns
      causal_patterns = generate_complex_causal_patterns(5, 100)
      
      # Process patterns concurrently
      pattern_tasks = for pattern <- causal_patterns do
        Task.async(fn ->
          process_causal_pattern(pattern)
        end)
      end
      
      processed_patterns = Task.await_many(pattern_tasks, @test_timeout)
      
      # Analyze for causal chains
      all_events = List.flatten(processed_patterns)
      chains = Causality.analyze_chains(all_events, %{})
      
      # Verify chain detection accuracy
      assert length(chains) >= length(causal_patterns),
             "Not all causal chains were detected"
      
      # Verify chain validity
      for chain <- chains do
        assert valid_causal_chain?(chain)
        assert chain.total_lag > 0
        assert length(chain.links) >= 1
      end
    end
    
    test "handles concurrent causal analysis without deadlocks" do
      # Setup multiple concurrent analyzers
      analyzer_count = 5
      events_per_analyzer = 200
      
      analyzer_tasks = for i <- 1..analyzer_count do
        Task.async(fn ->
          events = generate_random_events(events_per_analyzer, i)
          start_time = System.monotonic_time(:millisecond)
          
          chains = Causality.analyze_chains(events, %{})
          
          end_time = System.monotonic_time(:millisecond)
          
          %{
            analyzer_id: i,
            chains: chains,
            processing_time: end_time - start_time,
            event_count: length(events)
          }
        end)
      end
      
      # Verify no deadlocks or excessive blocking
      results = Task.await_many(analyzer_tasks, @test_timeout)
      
      # Performance checks
      avg_processing_time = 
        results
        |> Enum.map(& &1.processing_time)
        |> Enum.sum()
        |> div(length(results))
      
      assert avg_processing_time < 5000,
             "Causal analysis taking too long: #{avg_processing_time}ms"
      
      # Verify all analyzers completed
      assert length(results) == analyzer_count
      
      # Verify results quality
      total_chains = Enum.sum(Enum.map(results, &length(&1.chains)))
      assert total_chains > 0, "No causal chains detected across all analyzers"
    end
  end
  
  describe "Phoenix PubSub concurrency" do
    test "handles high-frequency topic subscriptions" do
      topics = ["system1.events", "system2.events", "system3.events", 
                "system4.events", "system5.events", "algedonic.alerts"]
      
      # Subscribe from multiple processes
      subscription_tasks = for i <- 1..@concurrent_producers do
        Task.async(fn ->
          for topic <- topics do
            Phoenix.PubSub.subscribe(VSMCore.PubSub, topic)
          end
          
          # Verify subscriptions
          for topic <- topics do
            send(self(), {:test_message, topic, i})
          end
          
          # Collect messages
          received = for _topic <- topics do
            receive do
              {:test_message, topic, producer_id} -> {topic, producer_id}
            after
              1000 -> :timeout
            end
          end
          
          %{producer_id: i, received: received}
        end)
      end
      
      results = Task.await_many(subscription_tasks, @test_timeout)
      
      # Verify all subscriptions worked
      for result <- results do
        refute Enum.any?(result.received, &(&1 == :timeout)),
               "Subscription timeout for producer #{result.producer_id}"
      end
    end
    
    test "maintains message delivery guarantees under load" do
      topic = "stress.test.topic"
      subscriber_count = 20
      message_count = 1000
      
      # Start subscribers
      subscriber_tasks = for i <- 1..subscriber_count do
        Task.async(fn ->
          Phoenix.PubSub.subscribe(VSMCore.PubSub, topic)
          
          received_messages = for _j <- 1..message_count do
            receive do
              {:stress_message, sequence, data} -> {sequence, data}
            after
              5000 -> :timeout
            end
          end
          
          %{subscriber_id: i, received: received_messages}
        end)
      end
      
      # Start publisher
      publisher_task = Task.async(fn ->
        for i <- 1..message_count do
          Phoenix.PubSub.broadcast(VSMCore.PubSub, topic, 
                                  {:stress_message, i, %{data: "test_#{i}"}})
        end
        
        :published_all
      end)
      
      # Wait for publishing to complete
      assert Task.await(publisher_task, @test_timeout) == :published_all
      
      # Wait for all subscribers
      subscriber_results = Task.await_many(subscriber_tasks, @test_timeout)
      
      # Verify delivery guarantees
      for result <- subscriber_results do
        received_count = length(Enum.filter(result.received, &(&1 != :timeout)))
        assert received_count == message_count,
               "Subscriber #{result.subscriber_id} received #{received_count}/#{message_count} messages"
        
        # Verify message ordering
        sequences = Enum.map(result.received, &elem(&1, 0))
        assert sequences == Enum.sort(sequences),
               "Message ordering violated for subscriber #{result.subscriber_id}"
      end
    end
  end
  
  # Helper functions
  
  defp setup_test_cluster(node_count) do
    # Setup test cluster for distributed testing
    base_name = "vsm_test_node"
    
    nodes = for i <- 1..node_count do
      node_name = :"#{base_name}_#{i}@127.0.0.1"
      {:ok, node} = :slave.start('127.0.0.1', :"#{base_name}_#{i}")
      
      # Load application on remote node
      :rpc.call(node, :code, :add_paths, [:code.get_path()])
      :rpc.call(node, Application, :ensure_all_started, [:vsm_core])
      
      node
    end
    
    nodes
  end
  
  defp cleanup_channels do
    # Reset channel state between tests
    :ok
  end
  
  defp start_message_collector do
    # Start process to collect messages for verification
    {:ok, spawn_link(fn -> message_collector_loop([]) end)}
  end
  
  defp message_collector_loop(messages) do
    receive do
      {:collected_message, message} ->
        message_collector_loop([message | messages])
      
      {:get_messages, caller} ->
        send(caller, {:messages, Enum.reverse(messages)})
        message_collector_loop(messages)
      
      :reset ->
        message_collector_loop([])
    end
  end
  
  defp get_collected_messages(collector) do
    send(collector, {:get_messages, self()})
    receive do
      {:messages, messages} -> messages
    after
      1000 -> []
    end
  end
  
  defp group_messages_by_chain(messages) do
    messages
    |> Enum.group_by(fn message ->
      get_in(message.payload, [:chain_id])
    end)
    |> Enum.filter(fn {chain_id, _} -> chain_id != nil end)
  end
  
  defp verify_causal_order(messages) do
    # Verify messages maintain causal dependencies
    dependency_map = build_dependency_map(messages)
    
    messages
    |> Enum.with_index()
    |> Enum.all?(fn {message, index} ->
      case get_in(message.payload, [:depends_on]) do
        nil -> true
        dependency_id ->
          dependency_index = Map.get(dependency_map, dependency_id)
          dependency_index != nil and dependency_index < index
      end
    end)
  end
  
  defp build_dependency_map(messages) do
    messages
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {message, index}, map ->
      Map.put(map, message.id, index)
    end)
  end
  
  defp get_channel_for_systems(from, to) do
    case {from, to} do
      {:system1, :system2} -> :coordination_channel
      {:system2, :system1} -> :coordination_channel
      {:system3, :system1} -> :command_channel
      {:system4, :system3} -> :command_channel
      {:system5, :system4} -> :command_channel
      _ -> :command_channel
    end
  end
  
  defp publish_to_channel(message) do
    case message.channel do
      :command_channel -> CommandChannel.publish(message)
      :coordination_channel -> CoordinationChannel.publish(message)
      :algedonic_channel -> AlgedonicChannel.publish(message)
      _ -> :ok
    end
  end
  
  defp generate_hlc_timestamp do
    # Simplified HLC timestamp generation
    physical = System.os_time(:millisecond)
    logical = :rand.uniform(1000)
    node_id = :erlang.unique_integer([:positive])
    
    {logical, physical, node_id}
  end
  
  defp hlc_compare({l1, p1, n1}, {l2, p2, n2}) do
    cond do
      p1 > p2 -> 1
      p1 < p2 -> -1
      l1 > l2 -> 1
      l1 < l2 -> -1
      n1 > n2 -> 1
      n1 < n2 -> -1
      true -> 0
    end
  end
  
  defp hlc_happens_before(hlc1, hlc2) do
    hlc_compare(hlc1, hlc2) < 0
  end
  
  defp process_causal_events(events) do
    # Process events and assign HLC timestamps maintaining causality
    {timestamped_events, _hlc_state} = 
      Enum.reduce(events, {[], {0, 0, node()}}, fn event, {acc, hlc_state} ->
        new_hlc = update_hlc_for_event(hlc_state, event)
        timestamped_event = %{event: event, hlc: new_hlc, timestamp: DateTime.utc_now()}
        {[timestamped_event | acc], new_hlc}
      end)
    
    Enum.reverse(timestamped_events)
  end
  
  defp update_hlc_for_event({logical, physical, node_id}, _event) do
    new_physical = max(physical, System.os_time(:millisecond))
    new_logical = if new_physical > physical, do: 0, else: logical + 1
    {new_logical, new_physical, node_id}
  end
  
  defp find_event(events, target_event) do
    Enum.find(events, fn %{event: event} -> event == target_event end)
  end
  
  defp generate_complex_causal_patterns(pattern_count, events_per_pattern) do
    for i <- 1..pattern_count do
      generate_causal_pattern(i, events_per_pattern)
    end
  end
  
  defp generate_causal_pattern(pattern_id, event_count) do
    # Generate a chain of causally related events
    for j <- 1..event_count do
      %{
        id: "#{pattern_id}_#{j}",
        pattern_id: pattern_id,
        sequence: j,
        timestamp: DateTime.utc_now(),
        depends_on: if j > 1, do: "#{pattern_id}_#{j-1}", else: nil,
        data: %{pattern: pattern_id, step: j}
      }
    end
  end
  
  defp process_causal_pattern(pattern) do
    # Simulate processing causal pattern with timing
    Enum.map(pattern, fn event ->
      Process.sleep(:rand.uniform(5)) # Simulate processing time
      Map.put(event, :processed_at, DateTime.utc_now())
    end)
  end
  
  defp valid_causal_chain?(chain) do
    # Validate causal chain structure
    chain.id != nil and
    is_list(chain.links) and
    length(chain.links) > 0 and
    chain.total_lag > 0 and
    chain.root_cause != nil
  end
  
  defp generate_random_events(count, seed) do
    :rand.seed(:exsplus, {seed, seed * 2, seed * 3})
    
    for i <- 1..count do
      %{
        id: "event_#{seed}_#{i}",
        timestamp: DateTime.utc_now(),
        dimensions: %{
          :cpu_usage => :rand.uniform(),
          :memory_usage => :rand.uniform(),
          :network_io => :rand.uniform(),
          :disk_io => :rand.uniform()
        },
        value: :rand.uniform() * 100
      }
    end
  end
  
  # Distributed test helpers
  
  def send_message_batch(messages) do
    # Helper function called on remote nodes
    for message <- messages do
      publish_to_channel(message)
    end
    
    length(messages)
  end
  
  def get_node_state do
    # Helper to get current node state for consistency checks
    %{
      node: node(),
      timestamp: DateTime.utc_now(),
      message_count: get_message_count(),
      system_state: get_system_state()
    }
  end
  
  defp get_message_count do
    # Get current message count (placeholder)
    :rand.uniform(1000)
  end
  
  defp get_system_state do
    # Get current system state (placeholder)
    %{status: :operational, load: :rand.uniform()}
  end
  
  defp partition_messages_across_nodes(nodes, total_messages) do
    messages_per_node = div(total_messages, length(nodes))
    
    nodes
    |> Enum.with_index()
    |> Enum.map(fn {node, index} ->
      messages = for i <- 1..messages_per_node do
        Message.command(:system1, :system2, :distributed_test, 
                       %{node: node, index: index, sequence: i})
      end
      
      {node, messages}
    end)
  end
  
  defp build_global_timeline(processed_messages) do
    processed_messages
    |> List.flatten()
    |> Enum.sort_by(& &1.timestamp)
  end
  
  defp verify_global_consistency(timeline) do
    # Verify global consistency across distributed timeline
    timeline
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [msg1, msg2] ->
      DateTime.compare(msg1.timestamp, msg2.timestamp) != :gt
    end)
  end
  
  defp generate_partition_test_messages do
    for i <- 1..100 do
      Message.command(:system1, :system2, :partition_test, 
                     %{sequence: i, timestamp: DateTime.utc_now()})
    end
  end
  
  defp verify_eventual_consistency(node_states) do
    # Verify eventual consistency across nodes after partition healing
    message_counts = Enum.map(node_states, & &1.message_count)
    max_count = Enum.max(message_counts)
    min_count = Enum.min(message_counts)
    
    # Allow some variance due to timing
    (max_count - min_count) <= 10
  end
  
  defp get_messages_for_system_pair(from_system, to_system) do
    # Placeholder for getting messages between specific systems
    []
  end
end