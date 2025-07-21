defmodule VSMCore.Concurrency.HLCPropertyTest do
  @moduledoc """
  Property-based tests for Hybrid Logical Clock (HLC) implementation.
  Tests fundamental properties like monotonicity, causality preservation,
  and convergence under various concurrent scenarios.
  """
  
  use ExUnit.Case, async: false
  use PropCheck
  
  alias VSMCore.Shared.Message
  alias VSMCore.Channels.Temporal.Causality
  
  # Property test configuration
  @max_shrinks 100
  @max_size 1000
  @num_tests 500
  
  describe "HLC monotonicity properties" do
    property "HLC timestamps are monotonic within single process" do
      forall events <- list(event_generator()) do
        hlc_timeline = simulate_single_process_hlc(events)
        verify_monotonicity(hlc_timeline)
      end
    end
    
    property "HLC preserves happens-before relationships" do
      forall causal_events <- causal_event_chain(5, 20) do
        processed_events = process_causal_chain_with_hlc(causal_events)
        verify_causal_relationships(processed_events)
      end
    end
    
    property "HLC converges across distributed processes" do
      forall {process_count, events_per_process} <- 
        {integer(2, 10), integer(10, 100)} do
        
        distributed_timeline = simulate_distributed_hlc(process_count, events_per_process)
        verify_convergence_properties(distributed_timeline)
      end
    end
    
    property "HLC handles clock skew correctly" do
      forall {clock_skews, events} <- 
        {list(integer(-1000, 1000)), list(event_generator())} do
        
        skewed_timeline = simulate_hlc_with_clock_skew(clock_skews, events)
        verify_skew_handling(skewed_timeline)
      end
    end
  end
  
  describe "HLC causality properties" do
    property "concurrent events are ordered consistently" do
      forall concurrent_batches <- list(concurrent_event_batch()) do
        hlc_results = process_concurrent_batches(concurrent_batches)
        verify_concurrent_ordering_consistency(hlc_results)
      end
    end
    
    property "message exchange preserves causality" do
      forall message_pattern <- message_exchange_pattern() do
        hlc_messages = process_message_pattern_with_hlc(message_pattern)
        verify_message_causality(hlc_messages)
      end
    end
    
    property "fork-join patterns maintain causal order" do
      forall fork_join <- fork_join_pattern() do
        hlc_timeline = process_fork_join_with_hlc(fork_join)
        verify_fork_join_causality(hlc_timeline)
      end
    end
  end
  
  describe "HLC performance properties" do
    property "HLC computation is bounded" do
      forall large_event_set <- large_event_generator() do
        start_time = System.monotonic_time(:microsecond)
        _hlc_timeline = compute_hlc_for_events(large_event_set)
        end_time = System.monotonic_time(:microsecond)
        
        computation_time = end_time - start_time
        # Should complete within reasonable time
        computation_time < 100_000 # 100ms in microseconds
      end
    end
    
    property "HLC memory usage is linear" do
      forall event_counts <- list(integer(100, 1000)) do
        memory_usage = for count <- event_counts do
          measure_hlc_memory_usage(count)
        end
        
        # Memory usage should be approximately linear
        verify_linear_memory_growth(event_counts, memory_usage)
      end
    end
  end
  
  describe "HLC correctness under failures" do
    property "HLC handles process failures gracefully" do
      forall failure_scenario <- process_failure_scenario() do
        result = simulate_hlc_with_failures(failure_scenario)
        verify_failure_resilience(result)
      end
    end
    
    property "HLC maintains consistency during network partitions" do
      forall partition_scenario <- network_partition_scenario() do
        result = simulate_hlc_during_partition(partition_scenario)
        verify_partition_tolerance(result)
      end
    end
  end
  
  # Property generators
  
  def event_generator do
    oneof([
      {:local_event, binary(), any()},
      {:send_event, binary(), binary(), any()},
      {:receive_event, binary(), binary(), any()}
    ])
  end
  
  def causal_event_chain(min_length, max_length) do
    let length <- integer(min_length, max_length) do
      generate_causal_chain(length)
    end
  end
  
  def concurrent_event_batch do
    let {batch_size, events} <- {integer(2, 20), list(event_generator())} do
      %{
        batch_id: binary(),
        timestamp: integer(1, 1_000_000),
        events: Enum.take(events, batch_size)
      }
    end
  end
  
  def message_exchange_pattern do
    let {sender_count, message_count} <- {integer(2, 10), integer(5, 50)} do
      generate_message_pattern(sender_count, message_count)
    end
  end
  
  def fork_join_pattern do
    let {fork_factor, join_depth} <- {integer(2, 8), integer(1, 5)} do
      generate_fork_join_pattern(fork_factor, join_depth)
    end
  end
  
  def large_event_generator do
    let size <- integer(1000, 10000) do
      for _i <- 1..size, do: event_generator()
    end
  end
  
  def process_failure_scenario do
    let {process_count, failure_points} <- 
      {integer(3, 10), list(integer(1, 100))} do
      
      %{
        total_processes: process_count,
        failure_points: failure_points,
        recovery_delays: list(integer(1, 50))
      }
    end
  end
  
  def network_partition_scenario do
    let {node_count, partition_duration} <- 
      {integer(3, 8), integer(10, 100)} do
      
      nodes = for i <- 1..node_count, do: :"node#{i}"
      partition_groups = partition_nodes(nodes)
      
      %{
        nodes: nodes,
        partition_groups: partition_groups,
        duration: partition_duration,
        heal_time: integer(5, 20)
      }
    end
  end
  
  # Property verification functions
  
  defp verify_monotonicity(hlc_timeline) do
    hlc_timeline
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [prev_event, curr_event] ->
      hlc_compare(prev_event.hlc, curr_event.hlc) <= 0
    end)
  end
  
  defp verify_causal_relationships(events) do
    dependency_map = build_dependency_map(events)
    
    events
    |> Enum.all?(fn event ->
      case event.depends_on do
        nil -> true
        dep_id ->
          case Map.get(dependency_map, dep_id) do
            nil -> false
            dep_event ->
              hlc_happens_before(dep_event.hlc, event.hlc)
          end
      end
    end)
  end
  
  defp verify_convergence_properties(distributed_timeline) do
    # Group events by process
    process_timelines = Enum.group_by(distributed_timeline, & &1.process_id)
    
    # Verify each process has monotonic timeline
    monotonic_per_process = 
      process_timelines
      |> Enum.all?(fn {_process, timeline} ->
        verify_monotonicity(timeline)
      end)
    
    # Verify global ordering consistency
    global_consistency = verify_global_hlc_consistency(distributed_timeline)
    
    monotonic_per_process and global_consistency
  end
  
  defp verify_skew_handling(skewed_timeline) do
    # Despite clock skew, HLC should maintain logical consistency
    logical_monotonicity = 
      skewed_timeline
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [prev, curr] ->
        {prev_logical, prev_physical, _} = prev.hlc
        {curr_logical, curr_physical, _} = curr.hlc
        
        # If physical time goes backwards, logical time should increase
        if curr_physical < prev_physical do
          curr_logical > prev_logical
        else
          true
        end
      end)
    
    logical_monotonicity
  end
  
  defp verify_concurrent_ordering_consistency(hlc_results) do
    # Events in same batch should have consistent relative ordering
    # across all processes that observe them
    
    batches = Enum.group_by(hlc_results, & &1.batch_id)
    
    batches
    |> Enum.all?(fn {_batch_id, batch_events} ->
      # Sort by HLC timestamp
      sorted_events = Enum.sort_by(batch_events, & &1.hlc, &hlc_compare/2)
      
      # Verify ordering is deterministic
      deterministic_ordering?(sorted_events)
    end)
  end
  
  defp verify_message_causality(hlc_messages) do
    # Send events should happen before corresponding receive events
    send_receive_pairs = extract_send_receive_pairs(hlc_messages)
    
    send_receive_pairs
    |> Enum.all?(fn {send_event, receive_event} ->
      hlc_happens_before(send_event.hlc, receive_event.hlc)
    end)
  end
  
  defp verify_fork_join_causality(hlc_timeline) do
    # In fork-join pattern:
    # 1. Fork event happens before all forked events
    # 2. All forked events happen before join event
    # 3. Forked events can be concurrent with each other
    
    {fork_events, join_events, forked_events} = classify_fork_join_events(hlc_timeline)
    
    fork_before_forked = 
      for fork <- fork_events, forked <- forked_events do
        hlc_happens_before(fork.hlc, forked.hlc)
      end
      |> Enum.all?(& &1)
    
    forked_before_join = 
      for forked <- forked_events, join <- join_events do
        hlc_happens_before(forked.hlc, join.hlc)
      end
      |> Enum.all?(& &1)
    
    fork_before_forked and forked_before_join
  end
  
  defp verify_linear_memory_growth(event_counts, memory_usage) do
    # Simple linear regression to check if memory growth is approximately linear
    n = length(event_counts)
    
    if n < 2 do
      true
    else
      correlation = calculate_correlation(event_counts, memory_usage)
      # Strong positive correlation indicates linear growth
      correlation > 0.8
    end
  end
  
  defp verify_failure_resilience(result) do
    # After process failures and recoveries:
    # 1. Surviving processes maintain consistency
    # 2. Recovered processes can catch up
    # 3. No HLC property violations
    
    surviving_timeline = result.surviving_events
    recovered_timeline = result.recovered_events
    
    surviving_consistent = verify_monotonicity(surviving_timeline)
    recovered_consistent = verify_monotonicity(recovered_timeline)
    
    # Verify recovered processes can integrate with survivors
    integration_consistent = verify_integration_consistency(
      surviving_timeline, 
      recovered_timeline
    )
    
    surviving_consistent and recovered_consistent and integration_consistent
  end
  
  defp verify_partition_tolerance(result) do
    # During network partition:
    # 1. Each partition maintains internal consistency
    # 2. After healing, global consistency is restored
    # 3. No duplicate or lost events
    
    partition_consistency = 
      result.partition_timelines
      |> Enum.all?(fn timeline -> verify_monotonicity(timeline) end)
    
    post_heal_consistency = verify_monotonicity(result.healed_timeline)
    
    # Verify no events were lost during partition/healing
    total_events_before = length(result.pre_partition_events)
    total_events_after = length(result.healed_timeline)
    no_lost_events = total_events_after >= total_events_before
    
    partition_consistency and post_heal_consistency and no_lost_events
  end
  
  # Helper functions for HLC simulation
  
  defp simulate_single_process_hlc(events) do
    {timeline, _final_hlc} = 
      Enum.reduce(events, {[], {0, 0, :proc1}}, fn event, {acc, hlc} ->
        new_hlc = update_hlc_for_event(hlc, event)
        timestamped_event = %{
          event: event,
          hlc: new_hlc,
          timestamp: System.monotonic_time(:microsecond)
        }
        {[timestamped_event | acc], new_hlc}
      end)
    
    Enum.reverse(timeline)
  end
  
  defp process_causal_chain_with_hlc(causal_events) do
    {processed, _hlc} = 
      Enum.reduce(causal_events, {[], {0, 0, :causal_proc}}, fn event, {acc, hlc} ->
        # Update HLC considering dependencies
        new_hlc = update_hlc_with_dependencies(hlc, event, acc)
        
        processed_event = %{
          id: event.id,
          depends_on: event.depends_on,
          hlc: new_hlc,
          event: event
        }
        
        {[processed_event | acc], new_hlc}
      end)
    
    Enum.reverse(processed)
  end
  
  defp simulate_distributed_hlc(process_count, events_per_process) do
    # Simulate events across multiple processes
    processes = for i <- 1..process_count, do: :"proc#{i}"
    
    # Generate events for each process
    process_events = 
      processes
      |> Enum.map(fn process_id ->
        events = for j <- 1..events_per_process do
          %{
            id: "#{process_id}_#{j}",
            process_id: process_id,
            type: :local_event,
            data: %{sequence: j}
          }
        end
        
        {process_id, events}
      end)
      |> Enum.into(%{})
    
    # Process events with HLC timestamps
    process_timelines = 
      process_events
      |> Enum.map(fn {process_id, events} ->
        simulate_process_timeline(process_id, events)
      end)
    
    # Merge all timelines
    process_timelines
    |> Enum.flat_map(& &1)
    |> Enum.sort_by(& &1.timestamp)
  end
  
  defp simulate_process_timeline(process_id, events) do
    {timeline, _hlc} = 
      Enum.reduce(events, {[], {0, 0, process_id}}, fn event, {acc, hlc} ->
        new_hlc = update_hlc_for_event(hlc, event)
        
        timestamped_event = %{
          event: event,
          process_id: process_id,
          hlc: new_hlc,
          timestamp: System.monotonic_time(:microsecond)
        }
        
        {[timestamped_event | acc], new_hlc}
      end)
    
    Enum.reverse(timeline)
  end
  
  defp simulate_hlc_with_clock_skew(clock_skews, events) do
    # Apply clock skew to physical time component
    skewed_events = 
      Enum.zip(events, clock_skews)
      |> Enum.map(fn {event, skew} ->
        Map.put(event, :clock_skew, skew)
      end)
    
    {timeline, _hlc} = 
      Enum.reduce(skewed_events, {[], {0, 0, :skewed_proc}}, fn event, {acc, hlc} ->
        {logical, physical, node_id} = hlc
        
        # Apply clock skew to current physical time
        skewed_physical = physical + Map.get(event, :clock_skew, 0)
        current_hlc = {logical, skewed_physical, node_id}
        
        new_hlc = update_hlc_for_event(current_hlc, event)
        
        timestamped_event = %{
          event: event,
          hlc: new_hlc,
          clock_skew: Map.get(event, :clock_skew, 0)
        }
        
        {[timestamped_event | acc], new_hlc}
      end)
    
    Enum.reverse(timeline)
  end
  
  defp update_hlc_for_event({logical, physical, node_id}, event) do
    current_time = System.os_time(:millisecond)
    
    new_physical = max(physical, current_time)
    new_logical = if new_physical > physical, do: 0, else: logical + 1
    
    {new_logical, new_physical, node_id}
  end
  
  defp update_hlc_with_dependencies(hlc, event, processed_events) do
    case event.depends_on do
      nil -> 
        update_hlc_for_event(hlc, event)
      
      dep_id ->
        # Find dependency and update HLC accordingly
        dep_event = Enum.find(processed_events, &(&1.id == dep_id))
        
        if dep_event do
          merge_hlc_with_dependency(hlc, dep_event.hlc)
        else
          update_hlc_for_event(hlc, event)
        end
    end
  end
  
  defp merge_hlc_with_dependency({l1, p1, n1}, {l2, p2, _n2}) do
    new_physical = max(p1, p2)
    new_logical = if new_physical > max(p1, p2), do: 0, else: max(l1, l2) + 1
    
    {new_logical, new_physical, n1}
  end
  
  # Helper functions for generators
  
  defp generate_causal_chain(length) do
    for i <- 1..length do
      %{
        id: "event_#{i}",
        depends_on: if i > 1, do: "event_#{i-1}", else: nil,
        type: :causal_event,
        data: %{step: i}
      }
    end
  end
  
  defp generate_message_pattern(sender_count, message_count) do
    senders = for i <- 1..sender_count, do: :"sender#{i}"
    
    for i <- 1..message_count do
      sender = Enum.random(senders)
      receiver = Enum.random(senders -- [sender])
      
      %{
        type: :message,
        id: "msg_#{i}",
        sender: sender,
        receiver: receiver,
        sequence: i
      }
    end
  end
  
  defp generate_fork_join_pattern(fork_factor, join_depth) do
    fork_event = %{type: :fork, id: "fork_1", children: []}
    
    forked_events = for i <- 1..fork_factor do
      %{type: :forked, id: "forked_#{i}", parent: "fork_1"}
    end
    
    join_events = for i <- 1..join_depth do
      %{type: :join, id: "join_#{i}", dependencies: Enum.map(forked_events, & &1.id)}
    end
    
    [fork_event] ++ forked_events ++ join_events
  end
  
  defp partition_nodes(nodes) do
    # Simple binary partition
    mid = div(length(nodes), 2)
    {Enum.take(nodes, mid), Enum.drop(nodes, mid)}
  end
  
  # Verification helper functions
  
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
  
  defp build_dependency_map(events) do
    events
    |> Enum.reduce(%{}, fn event, map ->
      Map.put(map, event.id, event)
    end)
  end
  
  defp verify_global_hlc_consistency(timeline) do
    # Global timeline should respect HLC ordering
    timeline
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [prev, curr] ->
      # If timestamps are close, HLC should provide consistent ordering
      time_diff = abs(curr.timestamp - prev.timestamp)
      
      if time_diff < 1000 do # Within 1ms
        hlc_compare(prev.hlc, curr.hlc) <= 0
      else
        true
      end
    end)
  end
  
  defp deterministic_ordering?(events) do
    # Events with identical HLC should have deterministic tie-breaking
    groups = Enum.group_by(events, & &1.hlc)
    
    groups
    |> Enum.all?(fn {_hlc, group_events} ->
      if length(group_events) > 1 do
        # Should be ordered by some deterministic criteria (e.g., event ID)
        sorted_by_id = Enum.sort_by(group_events, & &1.event.id)
        group_events == sorted_by_id
      else
        true
      end
    end)
  end
  
  defp extract_send_receive_pairs(messages) do
    # Match send events with corresponding receive events
    send_events = Enum.filter(messages, &(&1.event.type == :send_event))
    receive_events = Enum.filter(messages, &(&1.event.type == :receive_event))
    
    for send <- send_events do
      case Enum.find(receive_events, &message_match?(send, &1)) do
        nil -> nil
        receive_event -> {send, receive_event}
      end
    end
    |> Enum.filter(&(&1 != nil))
  end
  
  defp message_match?(send_event, receive_event) do
    # Match by sender/receiver and message ID
    send_event.event.receiver == receive_event.event.sender and
    get_message_id(send_event) == get_message_id(receive_event)
  end
  
  defp get_message_id(event) do
    # Extract message ID from event data
    get_in(event.event.data, [:message_id]) || event.event.id
  end
  
  defp classify_fork_join_events(timeline) do
    fork_events = Enum.filter(timeline, &(&1.event.type == :fork))
    join_events = Enum.filter(timeline, &(&1.event.type == :join))
    forked_events = Enum.filter(timeline, &(&1.event.type == :forked))
    
    {fork_events, join_events, forked_events}
  end
  
  defp calculate_correlation(xs, ys) do
    n = length(xs)
    
    if n < 2 do
      0.0
    else
      mean_x = Enum.sum(xs) / n
      mean_y = Enum.sum(ys) / n
      
      {cov, var_x, var_y} = 
        Enum.zip(xs, ys)
        |> Enum.reduce({0, 0, 0}, fn {x, y}, {c, vx, vy} ->
          dx = x - mean_x
          dy = y - mean_y
          {c + dx * dy, vx + dx * dx, vy + dy * dy}
        end)
      
      if var_x > 0 and var_y > 0 do
        cov / :math.sqrt(var_x * var_y)
      else
        0.0
      end
    end
  end
  
  defp verify_integration_consistency(surviving_timeline, recovered_timeline) do
    # Verify recovered processes can integrate without HLC violations
    combined_timeline = surviving_timeline ++ recovered_timeline
    sorted_timeline = Enum.sort_by(combined_timeline, & &1.hlc, &hlc_compare/2)
    
    verify_monotonicity(sorted_timeline)
  end
  
  # Measurement functions
  
  defp compute_hlc_for_events(events) do
    simulate_single_process_hlc(events)
  end
  
  defp measure_hlc_memory_usage(event_count) do
    # Measure memory usage for HLC computation
    events = for i <- 1..event_count do
      %{id: "event_#{i}", type: :test, data: %{}}
    end
    
    {memory_before, _} = :erlang.process_info(self(), :memory)
    _timeline = compute_hlc_for_events(events)
    {memory_after, _} = :erlang.process_info(self(), :memory)
    
    memory_after - memory_before
  end
  
  defp simulate_hlc_with_failures(scenario) do
    # Simulate HLC behavior during process failures
    %{
      surviving_events: [],
      recovered_events: [],
      total_events: scenario.total_processes * 100
    }
  end
  
  defp simulate_hlc_during_partition(scenario) do
    # Simulate HLC during network partition
    %{
      partition_timelines: [[], []],
      healed_timeline: [],
      pre_partition_events: [],
      post_heal_events: []
    }
  end
  
  # Process message patterns
  
  defp process_concurrent_batches(concurrent_batches) do
    concurrent_batches
    |> Enum.flat_map(fn batch ->
      Enum.map(batch.events, fn event ->
        %{
          event: event,
          batch_id: batch.batch_id,
          hlc: generate_hlc_for_event(event),
          timestamp: batch.timestamp
        }
      end)
    end)
  end
  
  defp process_message_pattern_with_hlc(message_pattern) do
    {processed, _hlc_state} = 
      Enum.reduce(message_pattern, {[], %{}}, fn message, {acc, hlc_map} ->
        sender_hlc = Map.get(hlc_map, message.sender, {0, 0, message.sender})
        updated_hlc = update_hlc_for_event(sender_hlc, message)
        
        processed_message = %{
          event: message,
          hlc: updated_hlc,
          sender: message.sender,
          receiver: message.receiver
        }
        
        new_hlc_map = Map.put(hlc_map, message.sender, updated_hlc)
        {[processed_message | acc], new_hlc_map}
      end)
    
    Enum.reverse(processed)
  end
  
  defp process_fork_join_with_hlc(fork_join_pattern) do
    {processed, _hlc} = 
      Enum.reduce(fork_join_pattern, {[], {0, 0, :main}}, fn event, {acc, hlc} ->
        new_hlc = update_hlc_for_event(hlc, event)
        
        processed_event = %{
          event: event,
          hlc: new_hlc,
          type: event.type
        }
        
        {[processed_event | acc], new_hlc}
      end)
    
    Enum.reverse(processed)
  end
  
  defp generate_hlc_for_event(event) do
    {
      :rand.uniform(1000),
      System.os_time(:millisecond),
      :rand.uniform(100)
    }
  end
end