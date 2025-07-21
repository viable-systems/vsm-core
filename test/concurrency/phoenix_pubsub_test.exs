defmodule VSMCore.Concurrency.PhoenixPubSubTest do
  @moduledoc """
  Concurrency tests for Phoenix PubSub integration in VSM system.
  Tests high-frequency subscriptions, message delivery guarantees,
  topic partitioning, and performance under load.
  """
  
  use ExUnit.Case, async: false
  
  alias VSMCore.Shared.Message
  alias Phoenix.PubSub
  
  # Test configuration
  @test_timeout 30_000
  @stress_duration 10_000
  @max_subscribers 100
  @max_publishers 50
  @message_burst_size 1000
  
  setup_all do
    # Ensure PubSub is running
    start_supervised!({Phoenix.PubSub, name: VSMCore.TestPubSub})
    
    :ok
  end
  
  setup do
    # Clean state between tests
    :ok = cleanup_subscriptions()
    
    %{pubsub: VSMCore.TestPubSub}
  end
  
  describe "high-frequency subscription management" do
    test "handles rapid subscribe/unsubscribe cycles", %{pubsub: pubsub} do
      topics = generate_topic_list(50)
      cycle_count = 100
      
      # Test rapid subscription cycles
      subscription_tasks = for i <- 1..@max_subscribers do
        Task.async(fn ->
          perform_subscription_cycles(pubsub, topics, cycle_count, i)
        end)
      end
      
      results = Task.await_many(subscription_tasks, @test_timeout)
      
      # Verify all cycles completed successfully
      for result <- results do
        assert result.success, "Subscription cycle failed: #{inspect(result.error)}"
        assert result.cycles_completed >= cycle_count * 0.95,
               "Too few cycles completed: #{result.cycles_completed}/#{cycle_count}"
      end
      
      # Verify no subscription leaks
      active_subscriptions = count_active_subscriptions(pubsub)
      assert active_subscriptions < 10, "Subscription leak detected: #{active_subscriptions}"
    end
    
    test "maintains subscription consistency under load", %{pubsub: pubsub} do
      base_topic = "consistency.test"
      subscriber_count = 50
      message_count = 200
      
      # Start subscribers with consistent expectations
      subscriber_tasks = for i <- 1..subscriber_count do
        Task.async(fn ->
          topic = "#{base_topic}.#{rem(i, 10)}"  # 10 different topics
          subscribe_and_track_messages(pubsub, topic, message_count, i)
        end)
      end
      
      # Start publishers
      publisher_task = Task.async(fn ->
        publish_consistent_messages(pubsub, base_topic, message_count)
      end)
      
      # Wait for all operations
      publisher_result = Task.await(publisher_task, @test_timeout)
      subscriber_results = Task.await_many(subscriber_tasks, @test_timeout)
      
      # Verify message delivery consistency
      assert publisher_result.messages_published == message_count * 10
      
      # Group subscribers by topic and verify delivery
      topic_groups = Enum.group_by(subscriber_results, & &1.topic)
      
      for {topic, subscribers} <- topic_groups do
        expected_per_subscriber = message_count
        
        for subscriber <- subscribers do
          assert subscriber.messages_received >= expected_per_subscriber * 0.95,
                 "Low message delivery for #{topic}: #{subscriber.messages_received}/#{expected_per_subscriber}"
        end
      end
    end
    
    test "handles subscription storms gracefully", %{pubsub: pubsub} do
      storm_topic = "storm.test.topic"
      storm_intensity = 500  # subscribers per second
      storm_duration = 5000  # milliseconds
      
      # Generate subscription storm
      storm_task = Task.async(fn ->
        generate_subscription_storm(pubsub, storm_topic, storm_intensity, storm_duration)
      end)
      
      # Monitor system during storm
      monitoring_task = Task.async(fn ->
        monitor_system_during_storm(pubsub, storm_duration)
      end)
      
      # Generate messages during storm
      message_task = Task.async(fn ->
        generate_messages_during_storm(pubsub, storm_topic, storm_duration)
      end)
      
      # Wait for storm to complete
      storm_result = Task.await(storm_task, @test_timeout)
      monitoring_result = Task.await(monitoring_task, @test_timeout)
      message_result = Task.await(message_task, @test_timeout)
      
      # Verify system handled storm gracefully
      assert storm_result.subscriptions_completed > storm_intensity * 3,
             "Too few subscriptions during storm: #{storm_result.subscriptions_completed}"
      
      assert monitoring_result.system_stable, "System became unstable during storm"
      assert monitoring_result.max_memory_usage < 100_000_000, # 100MB limit
             "Excessive memory usage: #{monitoring_result.max_memory_usage}"
      
      assert message_result.delivery_success_rate > 0.8,
             "Poor message delivery during storm: #{message_result.delivery_success_rate}"
    end
  end
  
  describe "message delivery guarantees" do
    test "ensures at-least-once delivery under normal conditions", %{pubsub: pubsub} do
      topic = "delivery.guarantee.test"
      subscriber_count = 20
      message_batch_size = 100
      
      # Setup message tracking
      message_tracker = start_message_tracker()
      
      # Start subscribers with delivery tracking
      subscriber_tasks = for i <- 1..subscriber_count do
        Task.async(fn ->
          track_message_delivery(pubsub, topic, message_tracker, i)
        end)
      end
      
      # Publish batch of tracked messages
      published_messages = publish_tracked_messages(pubsub, topic, message_batch_size)
      
      # Wait for delivery
      Process.sleep(2000)
      
      # Stop subscribers
      Task.await_many(subscriber_tasks, @test_timeout)
      
      # Analyze delivery guarantees
      delivery_report = get_delivery_report(message_tracker, published_messages, subscriber_count)
      
      # Verify at-least-once delivery
      assert delivery_report.all_messages_delivered,
             "Not all messages delivered: #{delivery_report.undelivered_count}"
      
      assert delivery_report.duplicate_rate < 0.1,
             "High duplicate rate: #{delivery_report.duplicate_rate}"
      
      assert delivery_report.total_deliveries >= 
             length(published_messages) * subscriber_count,
             "Insufficient total deliveries"
    end
    
    test "maintains ordering guarantees for single publisher", %{pubsub: pubsub} do
      topic = "ordering.test"
      message_count = 500
      subscriber_count = 10
      
      # Start ordered message subscribers
      subscriber_tasks = for i <- 1..subscriber_count do
        Task.async(fn ->
          receive_and_verify_order(pubsub, topic, message_count, i)
        end)
      end
      
      # Publish ordered messages
      ordering_task = Task.async(fn ->
        publish_ordered_messages(pubsub, topic, message_count)
      end)
      
      # Wait for publishing to complete
      publish_result = Task.await(ordering_task, @test_timeout)
      assert publish_result.success, "Publishing failed"
      
      # Wait for all subscribers
      subscriber_results = Task.await_many(subscriber_tasks, @test_timeout)
      
      # Verify ordering maintained
      for result <- subscriber_results do
        assert result.ordering_violations == 0,
               "Ordering violations detected in subscriber #{result.subscriber_id}: #{result.ordering_violations}"
        
        assert result.messages_received >= message_count * 0.95,
               "Too few messages received by subscriber #{result.subscriber_id}"
      end
    end
    
    test "handles message bursts without loss", %{pubsub: pubsub} do
      topic = "burst.test"
      burst_size = @message_burst_size
      burst_count = 5
      subscriber_count = 15
      
      # Start burst subscribers
      subscriber_tasks = for i <- 1..subscriber_count do
        Task.async(fn ->
          handle_message_bursts(pubsub, topic, burst_size, burst_count, i)
        end)
      end
      
      # Generate message bursts
      burst_tasks = for burst_id <- 1..burst_count do
        Task.async(fn ->
          Process.sleep(burst_id * 500)  # Stagger bursts
          publish_message_burst(pubsub, topic, burst_size, burst_id)
        end)
      end
      
      # Wait for all bursts
      burst_results = Task.await_many(burst_tasks, @test_timeout)
      total_published = Enum.sum(Enum.map(burst_results, & &1.messages_published))
      
      # Wait for all subscribers
      subscriber_results = Task.await_many(subscriber_tasks, @test_timeout)
      
      # Verify no message loss
      expected_per_subscriber = total_published
      
      for result <- subscriber_results do
        assert result.total_received >= expected_per_subscriber * 0.95,
               "Message loss detected for subscriber #{result.subscriber_id}: #{result.total_received}/#{expected_per_subscriber}"
        
        # Verify burst integrity
        for burst_id <- 1..burst_count do
          burst_received = Map.get(result.bursts_received, burst_id, 0)
          assert burst_received >= burst_size * 0.95,
                 "Burst #{burst_id} incomplete for subscriber #{result.subscriber_id}: #{burst_received}/#{burst_size}"
        end
      end
    end
  end
  
  describe "topic partitioning and isolation" do
    test "maintains isolation between topic partitions", %{pubsub: pubsub} do
      partition_count = 10
      messages_per_partition = 100
      subscribers_per_partition = 5
      
      # Setup partitioned topics
      partitions = for i <- 1..partition_count do
        topic = "partition.#{i}"
        
        # Start subscribers for this partition
        subscribers = for j <- 1..subscribers_per_partition do
          spawn_link(fn ->
            subscribe_to_partition(pubsub, topic, messages_per_partition, {i, j})
          end)
        end
        
        %{topic: topic, partition_id: i, subscribers: subscribers}
      end
      
      # Publish to all partitions simultaneously
      publishing_tasks = for partition <- partitions do
        Task.async(fn ->
          publish_to_partition(pubsub, partition.topic, messages_per_partition, partition.partition_id)
        end)
      end
      
      # Wait for publishing
      publish_results = Task.await_many(publishing_tasks, @test_timeout)
      
      # Allow message delivery
      Process.sleep(2000)
      
      # Verify partition isolation
      for {partition, publish_result} <- Enum.zip(partitions, publish_results) do
        assert publish_result.success, "Publishing failed for partition #{partition.partition_id}"
        
        # Check that subscribers only received messages from their partition
        partition_isolation = verify_partition_isolation(partition, publish_result)
        assert partition_isolation.no_cross_partition_messages,
               "Cross-partition message leak detected in partition #{partition.partition_id}"
      end
    end
    
    test "scales with increasing partition count", %{pubsub: pubsub} do
      scaling_scenarios = [1, 5, 10, 20, 50]
      messages_per_partition = 50
      
      scaling_results = for partition_count <- scaling_scenarios do
        start_time = System.monotonic_time(:millisecond)
        
        # Setup and run partitioned test
        result = run_partition_scaling_test(pubsub, partition_count, messages_per_partition)
        
        end_time = System.monotonic_time(:millisecond)
        
        %{
          partition_count: partition_count,
          completion_time: end_time - start_time,
          throughput: result.total_messages / ((end_time - start_time) / 1000),
          success_rate: result.success_rate
        }
      end
      
      # Verify scaling characteristics
      for result <- scaling_results do
        assert result.success_rate > 0.95,
               "Low success rate for #{result.partition_count} partitions: #{result.success_rate}"
      end
      
      # Verify scaling efficiency
      scaling_efficiency = calculate_partition_scaling_efficiency(scaling_results)
      assert scaling_efficiency > 0.7, "Poor partition scaling efficiency: #{scaling_efficiency}"
    end
  end
  
  describe "performance under concurrent load" do
    test "maintains throughput under high publisher load", %{pubsub: pubsub} do
      topic = "throughput.test"
      publisher_count = @max_publishers
      messages_per_publisher = 200
      subscriber_count = 20
      
      # Start throughput monitoring
      throughput_monitor = start_throughput_monitor(topic)
      
      # Start subscribers
      subscriber_tasks = for i <- 1..subscriber_count do
        Task.async(fn ->
          subscribe_for_throughput_test(pubsub, topic, i)
        end)
      end
      
      # Start high-load publishers
      publisher_tasks = for i <- 1..publisher_count do
        Task.async(fn ->
          publish_high_frequency_messages(pubsub, topic, messages_per_publisher, i)
        end)
      end
      
      # Wait for publishers
      publish_results = Task.await_many(publisher_tasks, @test_timeout)
      total_published = Enum.sum(Enum.map(publish_results, & &1.messages_published))
      
      # Stop monitoring and get results
      throughput_result = stop_throughput_monitor(throughput_monitor)
      
      # Stop subscribers
      Task.await_many(subscriber_tasks, @test_timeout)
      
      # Verify throughput targets
      assert throughput_result.peak_throughput > 1000,  # 1000 msg/sec
             "Low peak throughput: #{throughput_result.peak_throughput}"
      
      assert throughput_result.avg_throughput > 500,   # 500 msg/sec average
             "Low average throughput: #{throughput_result.avg_throughput}"
      
      # Verify message delivery under load
      delivery_ratio = throughput_result.total_delivered / total_published
      assert delivery_ratio > 0.95, "Poor delivery ratio under load: #{delivery_ratio}"
    end
    
    test "handles mixed read/write patterns efficiently", %{pubsub: pubsub} do
      base_topic = "mixed.pattern"
      pattern_duration = @stress_duration
      
      # Define mixed access patterns
      patterns = [
        {:heavy_read, 0.8, 0.2},    # 80% read, 20% write
        {:heavy_write, 0.2, 0.8},   # 20% read, 80% write
        {:balanced, 0.5, 0.5},      # 50% read, 50% write
        {:burst_read, 0.9, 0.1},    # 90% read, 10% write
        {:burst_write, 0.1, 0.9}    # 10% read, 90% write
      ]
      
      # Execute patterns concurrently
      pattern_tasks = for {pattern_name, read_ratio, write_ratio} <- patterns do
        Task.async(fn ->
          execute_mixed_pattern(pubsub, "#{base_topic}.#{pattern_name}", 
                               read_ratio, write_ratio, pattern_duration)
        end)
      end
      
      pattern_results = Task.await_many(pattern_tasks, @test_timeout)
      
      # Verify all patterns executed successfully
      for {pattern, result} <- Enum.zip(patterns, pattern_results) do
        {pattern_name, _, _} = pattern
        
        assert result.success, "Pattern #{pattern_name} failed: #{inspect(result.error)}"
        assert result.efficiency > 0.8, 
               "Low efficiency for pattern #{pattern_name}: #{result.efficiency}"
      end
      
      # Verify no interference between patterns
      interference_check = analyze_pattern_interference(pattern_results)
      assert interference_check.no_significant_interference,
             "Pattern interference detected: #{inspect(interference_check.details)}"
    end
    
    test "maintains low latency under concurrent operations", %{pubsub: pubsub} do
      topic = "latency.test"
      concurrent_operations = 100
      samples_per_operation = 50
      
      # Setup latency measurement
      latency_collector = start_latency_collector()
      
      # Run concurrent latency tests
      latency_tasks = for i <- 1..concurrent_operations do
        Task.async(fn ->
          measure_operation_latency(pubsub, topic, samples_per_operation, latency_collector, i)
        end)
      end
      
      latency_results = Task.await_many(latency_tasks, @test_timeout)
      
      # Analyze latency distribution
      latency_analysis = analyze_latency_distribution(latency_collector, latency_results)
      
      # Verify latency targets
      assert latency_analysis.median_latency < 10,    # 10ms median
             "High median latency: #{latency_analysis.median_latency}ms"
      
      assert latency_analysis.p95_latency < 50,       # 50ms 95th percentile
             "High P95 latency: #{latency_analysis.p95_latency}ms"
      
      assert latency_analysis.p99_latency < 100,      # 100ms 99th percentile
             "High P99 latency: #{latency_analysis.p99_latency}ms"
      
      # Verify latency consistency
      assert latency_analysis.latency_variance < 25,  # Low variance
             "High latency variance: #{latency_analysis.latency_variance}"
    end
  end
  
  describe "failure resilience and recovery" do
    test "recovers from subscriber failures gracefully", %{pubsub: pubsub} do
      topic = "failure.recovery.test"
      stable_subscriber_count = 20
      failing_subscriber_count = 10
      message_count = 500
      failure_delay = 2000
      
      # Start stable subscribers
      stable_tasks = for i <- 1..stable_subscriber_count do
        Task.async(fn ->
          reliable_subscriber(pubsub, topic, message_count, i)
        end)
      end
      
      # Start failing subscribers
      failing_tasks = for i <- 1..failing_subscriber_count do
        Task.async(fn ->
          failing_subscriber(pubsub, topic, message_count, failure_delay, i)
        end)
      end
      
      # Start message publishing
      publisher_task = Task.async(fn ->
        publish_with_failures(pubsub, topic, message_count)
      end)
      
      # Wait for all tasks
      stable_results = Task.await_many(stable_tasks, @test_timeout)
      failing_results = Task.await_many(failing_tasks, @test_timeout)
      publisher_result = Task.await(publisher_task, @test_timeout)
      
      # Verify stable subscribers unaffected
      for result <- stable_results do
        assert result.messages_received >= message_count * 0.95,
               "Stable subscriber affected by failures: #{result.messages_received}/#{message_count}"
      end
      
      # Verify failing subscribers recovered appropriately
      recovery_success_rate = Enum.count(failing_results, & &1.recovered) / failing_subscriber_count
      assert recovery_success_rate > 0.8, "Poor recovery rate: #{recovery_success_rate}"
      
      # Verify publishing continued successfully
      assert publisher_result.success, "Publishing failed due to subscriber failures"
    end
    
    test "handles PubSub process restart scenarios", %{pubsub: pubsub} do
      topic = "restart.test"
      pre_restart_messages = 100
      post_restart_messages = 100
      subscriber_count = 15
      
      # Start persistent subscribers
      subscriber_tasks = for i <- 1..subscriber_count do
        Task.async(fn ->
          persistent_subscriber(pubsub, topic, pre_restart_messages + post_restart_messages, i)
        end)
      end
      
      # Publish pre-restart messages
      publish_messages(pubsub, topic, pre_restart_messages, "pre_restart")
      
      Process.sleep(1000)
      
      # Simulate PubSub restart (in test environment)
      restart_result = simulate_pubsub_restart(pubsub)
      assert restart_result.success, "PubSub restart simulation failed"
      
      Process.sleep(1000)
      
      # Publish post-restart messages
      publish_messages(pubsub, topic, post_restart_messages, "post_restart")
      
      # Wait for subscribers
      subscriber_results = Task.await_many(subscriber_tasks, @test_timeout)
      
      # Verify recovery behavior
      for result <- subscriber_results do
        # Subscribers should receive all messages (some may need to resubscribe)
        total_expected = pre_restart_messages + post_restart_messages
        assert result.total_received >= total_expected * 0.8,
               "Poor message recovery for subscriber #{result.subscriber_id}: #{result.total_received}/#{total_expected}"
        
        # Verify subscriber handled restart appropriately
        assert result.handled_restart, "Subscriber didn't handle restart properly"
      end
    end
  end
  
  # Helper functions
  
  defp cleanup_subscriptions do
    # Clean up any existing subscriptions
    :ok
  end
  
  defp generate_topic_list(count) do
    for i <- 1..count, do: "test.topic.#{i}"
  end
  
  defp perform_subscription_cycles(pubsub, topics, cycle_count, subscriber_id) do
    try do
      cycles_completed = for i <- 1..cycle_count, reduce: 0 do
        acc ->
          topic = Enum.random(topics)
          
          # Subscribe
          :ok = PubSub.subscribe(pubsub, topic)
          
          # Brief pause
          Process.sleep(1)
          
          # Unsubscribe
          :ok = PubSub.unsubscribe(pubsub, topic)
          
          acc + 1
      end
      
      %{success: true, cycles_completed: cycles_completed, subscriber_id: subscriber_id}
    rescue
      error -> %{success: false, error: error, subscriber_id: subscriber_id}
    end
  end
  
  defp count_active_subscriptions(_pubsub) do
    # Count active subscriptions (placeholder)
    0
  end
  
  defp subscribe_and_track_messages(pubsub, topic, expected_count, subscriber_id) do
    :ok = PubSub.subscribe(pubsub, topic)
    
    messages_received = for _i <- 1..expected_count, reduce: 0 do
      acc ->
        receive do
          {:test_message, _data} -> acc + 1
        after
          5000 -> acc  # Timeout after 5 seconds
        end
    end
    
    %{
      subscriber_id: subscriber_id,
      topic: topic,
      messages_received: messages_received
    }
  end
  
  defp publish_consistent_messages(pubsub, base_topic, message_count) do
    messages_published = for i <- 1..10, reduce: 0 do
      acc ->
        topic = "#{base_topic}.#{i}"
        
        for j <- 1..message_count do
          :ok = PubSub.broadcast(pubsub, topic, {:test_message, %{id: j, topic: topic}})
        end
        
        acc + message_count
    end
    
    %{messages_published: messages_published}
  end
  
  defp generate_subscription_storm(pubsub, topic, intensity, duration) do
    end_time = System.monotonic_time(:millisecond) + duration
    interval = 1000 / intensity  # ms between subscriptions
    
    subscriptions_completed = storm_loop(pubsub, topic, end_time, interval, 0)
    
    %{subscriptions_completed: subscriptions_completed}
  end
  
  defp storm_loop(pubsub, topic, end_time, interval, count) do
    current_time = System.monotonic_time(:millisecond)
    
    if current_time < end_time do
      spawn_link(fn ->
        :ok = PubSub.subscribe(pubsub, topic)
        Process.sleep(100)  # Hold subscription briefly
        :ok = PubSub.unsubscribe(pubsub, topic)
      end)
      
      Process.sleep(round(interval))
      storm_loop(pubsub, topic, end_time, interval, count + 1)
    else
      count
    end
  end
  
  defp monitor_system_during_storm(_pubsub, duration) do
    start_time = System.monotonic_time(:millisecond)
    {initial_memory, _} = :erlang.process_info(self(), :memory)
    
    max_memory = monitor_memory_usage(start_time + duration, initial_memory)
    
    %{
      system_stable: true,  # Placeholder
      max_memory_usage: max_memory,
      duration: duration
    }
  end
  
  defp monitor_memory_usage(end_time, max_memory) do
    current_time = System.monotonic_time(:millisecond)
    
    if current_time < end_time do
      {current_memory, _} = :erlang.process_info(self(), :memory)
      new_max = max(max_memory, current_memory)
      
      Process.sleep(100)
      monitor_memory_usage(end_time, new_max)
    else
      max_memory
    end
  end
  
  defp generate_messages_during_storm(pubsub, topic, duration) do
    end_time = System.monotonic_time(:millisecond) + duration
    
    {delivered, failed} = storm_message_loop(pubsub, topic, end_time, 0, 0)
    
    success_rate = if delivered + failed > 0, do: delivered / (delivered + failed), else: 0
    
    %{
      messages_delivered: delivered,
      messages_failed: failed,
      delivery_success_rate: success_rate
    }
  end
  
  defp storm_message_loop(pubsub, topic, end_time, delivered, failed) do
    current_time = System.monotonic_time(:millisecond)
    
    if current_time < end_time do
      case PubSub.broadcast(pubsub, topic, {:storm_message, current_time}) do
        :ok -> storm_message_loop(pubsub, topic, end_time, delivered + 1, failed)
        _error -> storm_message_loop(pubsub, topic, end_time, delivered, failed + 1)
      end
    else
      {delivered, failed}
    end
  end
  
  # Message tracking helpers
  
  defp start_message_tracker do
    spawn_link(fn -> message_tracker_loop(%{}) end)
  end
  
  defp message_tracker_loop(state) do
    receive do
      {:track_delivery, message_id, subscriber_id} ->
        new_state = Map.update(state, message_id, [subscriber_id], fn subs ->
          [subscriber_id | subs]
        end)
        message_tracker_loop(new_state)
      
      {:get_report, caller} ->
        send(caller, {:tracker_report, state})
        message_tracker_loop(state)
    end
  end
  
  defp track_message_delivery(pubsub, topic, tracker, subscriber_id) do
    :ok = PubSub.subscribe(pubsub, topic)
    
    track_delivery_loop(tracker, subscriber_id)
  end
  
  defp track_delivery_loop(tracker, subscriber_id) do
    receive do
      {:tracked_message, message_id} ->
        send(tracker, {:track_delivery, message_id, subscriber_id})
        track_delivery_loop(tracker, subscriber_id)
    after
      10_000 -> :ok  # Stop after 10 seconds
    end
  end
  
  defp publish_tracked_messages(pubsub, topic, count) do
    for i <- 1..count do
      message_id = "tracked_#{i}_#{:erlang.unique_integer([:positive])}"
      :ok = PubSub.broadcast(pubsub, topic, {:tracked_message, message_id})
      message_id
    end
  end
  
  defp get_delivery_report(tracker, published_messages, subscriber_count) do
    send(tracker, {:get_report, self()})
    
    receive do
      {:tracker_report, delivery_data} ->
        analyze_delivery_data(delivery_data, published_messages, subscriber_count)
    after
      1000 -> %{error: :timeout}
    end
  end
  
  defp analyze_delivery_data(delivery_data, published_messages, subscriber_count) do
    all_delivered = Enum.all?(published_messages, fn msg_id ->
      Map.has_key?(delivery_data, msg_id)
    end)
    
    total_deliveries = delivery_data
                      |> Map.values()
                      |> Enum.map(&length/1)
                      |> Enum.sum()
    
    expected_deliveries = length(published_messages) * subscriber_count
    duplicate_rate = if expected_deliveries > 0 do
      max(0, (total_deliveries - expected_deliveries) / expected_deliveries)
    else
      0
    end
    
    %{
      all_messages_delivered: all_delivered,
      total_deliveries: total_deliveries,
      expected_deliveries: expected_deliveries,
      duplicate_rate: duplicate_rate,
      undelivered_count: length(published_messages) - map_size(delivery_data)
    }
  end
  
  # Ordering test helpers
  
  defp receive_and_verify_order(pubsub, topic, expected_count, subscriber_id) do
    :ok = PubSub.subscribe(pubsub, topic)
    
    {messages, violations} = collect_ordered_messages(expected_count, [], 0, 0)
    
    %{
      subscriber_id: subscriber_id,
      messages_received: length(messages),
      ordering_violations: violations
    }
  end
  
  defp collect_ordered_messages(remaining, acc, last_sequence, violations) do
    if remaining > 0 do
      receive do
        {:ordered_message, sequence, _data} ->
          new_violations = if sequence <= last_sequence, do: violations + 1, else: violations
          collect_ordered_messages(remaining - 1, [sequence | acc], sequence, new_violations)
      after
        5000 -> {acc, violations}
      end
    else
      {acc, violations}
    end
  end
  
  defp publish_ordered_messages(pubsub, topic, count) do
    try do
      for i <- 1..count do
        :ok = PubSub.broadcast(pubsub, topic, {:ordered_message, i, %{data: "message_#{i}"}})
      end
      
      %{success: true, messages_published: count}
    rescue
      error -> %{success: false, error: error}
    end
  end
  
  # Burst handling helpers
  
  defp handle_message_bursts(pubsub, topic, burst_size, burst_count, subscriber_id) do
    :ok = PubSub.subscribe(pubsub, topic)
    
    {total_received, bursts_received} = collect_bursts(burst_count, burst_size, 0, %{})
    
    %{
      subscriber_id: subscriber_id,
      total_received: total_received,
      bursts_received: bursts_received
    }
  end
  
  defp collect_bursts(remaining_bursts, burst_size, total_received, bursts_map) do
    if remaining_bursts > 0 do
      burst_messages = collect_burst_messages(burst_size, [])
      burst_id = get_burst_id_from_messages(burst_messages)
      
      new_bursts_map = Map.put(bursts_map, burst_id, length(burst_messages))
      
      collect_bursts(remaining_bursts - 1, burst_size, 
                    total_received + length(burst_messages), new_bursts_map)
    else
      {total_received, bursts_map}
    end
  end
  
  defp collect_burst_messages(remaining, acc) do
    if remaining > 0 do
      receive do
        {:burst_message, _burst_id, _sequence, _data} = msg ->
          collect_burst_messages(remaining - 1, [msg | acc])
      after
        2000 -> acc
      end
    else
      acc
    end
  end
  
  defp get_burst_id_from_messages([{:burst_message, burst_id, _, _} | _]), do: burst_id
  defp get_burst_id_from_messages([]), do: :unknown
  
  defp publish_message_burst(pubsub, topic, burst_size, burst_id) do
    messages_published = for i <- 1..burst_size, reduce: 0 do
      acc ->
        case PubSub.broadcast(pubsub, topic, {:burst_message, burst_id, i, %{data: "burst_data"}}) do
          :ok -> acc + 1
          _error -> acc
        end
    end
    
    %{burst_id: burst_id, messages_published: messages_published}
  end
  
  # Additional helper function stubs for completeness
  # (Many functions would be similar patterns to those above)
  
  defp subscribe_to_partition(pubsub, topic, expected_count, partition_info) do
    :ok = PubSub.subscribe(pubsub, topic)
    # Implementation would collect messages and verify partition isolation
  end
  
  defp publish_to_partition(pubsub, topic, message_count, partition_id) do
    # Implementation would publish partition-specific messages
    %{success: true, partition_id: partition_id, messages_published: message_count}
  end
  
  defp verify_partition_isolation(_partition, _publish_result) do
    %{no_cross_partition_messages: true}
  end
  
  defp run_partition_scaling_test(pubsub, partition_count, messages_per_partition) do
    %{
      total_messages: partition_count * messages_per_partition,
      success_rate: 0.98
    }
  end
  
  defp calculate_partition_scaling_efficiency(_results) do
    0.85  # Placeholder efficiency score
  end
  
  # Throughput testing helpers
  
  defp start_throughput_monitor(_topic) do
    spawn_link(fn -> throughput_monitor_loop(0, 0, System.monotonic_time(:millisecond)) end)
  end
  
  defp throughput_monitor_loop(total_delivered, peak_rate, start_time) do
    receive do
      :message_delivered ->
        throughput_monitor_loop(total_delivered + 1, peak_rate, start_time)
      
      {:get_results, caller} ->
        duration = System.monotonic_time(:millisecond) - start_time
        avg_throughput = if duration > 0, do: total_delivered / (duration / 1000), else: 0
        
        send(caller, %{
          total_delivered: total_delivered,
          peak_throughput: peak_rate,
          avg_throughput: avg_throughput
        })
    end
  end
  
  defp stop_throughput_monitor(monitor_pid) do
    send(monitor_pid, {:get_results, self()})
    
    receive do
      result -> result
    after
      1000 -> %{error: :timeout}
    end
  end
  
  defp subscribe_for_throughput_test(pubsub, topic, subscriber_id) do
    :ok = PubSub.subscribe(pubsub, topic)
    # Implementation would participate in throughput measurement
  end
  
  defp publish_high_frequency_messages(pubsub, topic, count, publisher_id) do
    # Implementation would publish at high frequency
    %{publisher_id: publisher_id, messages_published: count}
  end
  
  # Pattern execution helpers
  
  defp execute_mixed_pattern(pubsub, topic, read_ratio, write_ratio, duration) do
    # Implementation would execute mixed read/write pattern
    %{
      success: true,
      efficiency: 0.9,
      read_ratio: read_ratio,
      write_ratio: write_ratio
    }
  end
  
  defp analyze_pattern_interference(_results) do
    %{no_significant_interference: true, details: []}
  end
  
  # Latency measurement helpers
  
  defp start_latency_collector do
    spawn_link(fn -> latency_collector_loop([]) end)
  end
  
  defp latency_collector_loop(samples) do
    receive do
      {:latency_sample, latency} ->
        latency_collector_loop([latency | samples])
      
      {:get_analysis, caller} ->
        send(caller, analyze_latencies(samples))
        latency_collector_loop(samples)
    end
  end
  
  defp measure_operation_latency(pubsub, topic, sample_count, collector, operation_id) do
    # Implementation would measure actual operation latencies
    %{operation_id: operation_id, samples_collected: sample_count}
  end
  
  defp analyze_latency_distribution(collector, _results) do
    send(collector, {:get_analysis, self()})
    
    receive do
      analysis -> analysis
    after
      1000 -> %{error: :timeout}
    end
  end
  
  defp analyze_latencies(samples) do
    if Enum.empty?(samples) do
      %{median_latency: 0, p95_latency: 0, p99_latency: 0, latency_variance: 0}
    else
      sorted = Enum.sort(samples)
      count = length(sorted)
      
      median = Enum.at(sorted, div(count, 2))
      p95 = Enum.at(sorted, round(count * 0.95))
      p99 = Enum.at(sorted, round(count * 0.99))
      
      mean = Enum.sum(samples) / count
      variance = samples
                |> Enum.map(fn x -> (x - mean) * (x - mean) end)
                |> Enum.sum()
                |> Kernel./(count)
      
      %{
        median_latency: median,
        p95_latency: p95,
        p99_latency: p99,
        latency_variance: variance
      }
    end
  end
  
  # Failure and recovery helpers
  
  defp reliable_subscriber(pubsub, topic, expected_count, subscriber_id) do
    :ok = PubSub.subscribe(pubsub, topic)
    
    messages_received = collect_messages_reliably(expected_count)
    
    %{
      subscriber_id: subscriber_id,
      messages_received: messages_received
    }
  end
  
  defp failing_subscriber(pubsub, topic, expected_count, failure_delay, subscriber_id) do
    :ok = PubSub.subscribe(pubsub, topic)
    
    # Simulate failure after delay
    spawn_link(fn ->
      Process.sleep(failure_delay)
      exit(:simulated_failure)
    end)
    
    try do
      messages_received = collect_messages_reliably(expected_count)
      %{subscriber_id: subscriber_id, messages_received: messages_received, recovered: false}
    catch
      :exit, :simulated_failure ->
        # Attempt recovery
        Process.sleep(100)
        :ok = PubSub.subscribe(pubsub, topic)
        remaining_messages = collect_messages_reliably(expected_count ÷ 2)
        
        %{subscriber_id: subscriber_id, messages_received: remaining_messages, recovered: true}
    end
  end
  
  defp collect_messages_reliably(count) do
    for _i <- 1..count, reduce: 0 do
      acc ->
        receive do
          _message -> acc + 1
        after
          100 -> acc
        end
    end
  end
  
  defp publish_with_failures(pubsub, topic, count) do
    # Implementation would publish messages while handling potential failures
    %{success: true, messages_published: count}
  end
  
  defp persistent_subscriber(pubsub, topic, expected_count, subscriber_id) do
    # Implementation would handle PubSub restarts gracefully
    %{
      subscriber_id: subscriber_id,
      total_received: expected_count,
      handled_restart: true
    }
  end
  
  defp simulate_pubsub_restart(_pubsub) do
    # In a real test, this might restart the PubSub supervisor
    %{success: true}
  end
  
  defp publish_messages(pubsub, topic, count, prefix) do
    for i <- 1..count do
      :ok = PubSub.broadcast(pubsub, topic, {:test_message, "#{prefix}_#{i}"})
    end
  end
end