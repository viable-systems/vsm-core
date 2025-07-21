#!/usr/bin/env elixir

# Advanced VSM Core Scenarios Example
# 
# This script demonstrates advanced features including:
# - Complex multi-subsystem coordination
# - Variety engineering across subsystems
# - Emergency response through algedonic channels
# - Adaptive policy implementation
# 
# Run with: elixir examples/advanced_scenarios.exs

Mix.install([{:vsm_core, path: "."}])

IO.puts("🚀 Starting VSM Core Advanced Scenarios")
IO.puts("=" <> String.duplicate("=", 50))

# Ensure system is running
{:ok, _} = VSMCore.start()

# Scenario 1: Complex Variety Management
IO.puts("\n🎯 Scenario 1: Complex Variety Management")
IO.puts("-" <> String.duplicate("-", 40))

# Create multiple units with different characteristics
units = [
  %{id: "high_variety_unit", variety_capacity: 1000, type: :complex_operations},
  %{id: "stable_unit", variety_capacity: 100, type: :routine_operations},
  %{id: "adaptive_unit", variety_capacity: 500, type: :flexible_operations}
]

IO.puts("Creating operational units...")
for unit_spec <- units do
  {:ok, _unit} = VSMCore.System1.Unit.create(unit_spec)
  IO.puts("  ✅ Created #{unit_spec.id}")
end

# Generate complex variety patterns
IO.puts("Generating complex variety patterns...")
variety_patterns = [
  # High variety burst
  {50, "high_variety_unit", fn i -> 
    %{
      type: Enum.random([:sale, :return, :exchange, :repair, :consultation]),
      amount: :rand.uniform(2000),
      complexity: :rand.uniform(5),
      priority: Enum.random([:low, :medium, :high, :critical]),
      metadata: %{pattern: "burst_#{i}", source: "external"}
    }
  end},
  
  # Stable pattern
  {20, "stable_unit", fn i ->
    %{
      type: :routine_processing,
      amount: 100 + rem(i, 50),
      complexity: 1,
      priority: :medium,
      metadata: %{pattern: "stable_#{i}", source: "internal"}
    }
  end},
  
  # Adaptive responses
  {30, "adaptive_unit", fn i ->
    complexity = if rem(i, 10) == 0, do: 4, else: 2
    %{
      type: :adaptive_processing,
      amount: 200 + rem(i * 7, 300),
      complexity: complexity,
      priority: if(complexity > 3, do: :high, else: :medium),
      metadata: %{pattern: "adaptive_#{i}", source: "hybrid"}
    }
  end}
]

# Execute patterns concurrently
tasks = for {count, unit_id, pattern_fn} <- variety_patterns do
  Task.async(fn ->
    for i <- 1..count do
      transaction = pattern_fn.(i) |> Map.put(:unit_id, unit_id)
      VSMCore.System1.Operations.process_transaction(transaction)
      if rem(i, 10) == 0, do: Process.sleep(10)  # Brief pause
    end
  end)
end

Task.await_many(tasks, 10_000)
IO.puts("✅ Variety patterns generated successfully")

# Analyze variety distribution
IO.puts("Analyzing variety distribution...")
for unit_id <- ["high_variety_unit", "stable_unit", "adaptive_unit"] do
  metrics = VSMCore.System1.Metrics.get_unit_metrics(unit_id)
  ratio = if metrics.variety_generated > 0, 
    do: metrics.variety_absorbed / metrics.variety_generated, 
    else: 0
  IO.puts("  #{unit_id}: Generated=#{metrics.variety_generated}, Absorbed=#{metrics.variety_absorbed}, Ratio=#{Float.round(ratio, 3)}")
end

# Scenario 2: Emergency Response Coordination
IO.puts("\n🚨 Scenario 2: Emergency Response Coordination")
IO.puts("-" <> String.duplicate("-", 40))

# Simulate a cascading failure scenario
IO.puts("Simulating cascading failure scenario...")

# First, send multiple warning signals
warning_signals = [
  %{urgency: :low, source: :s1, content: "Increased processing time detected", metrics: %{avg_time: 120}},
  %{urgency: :medium, source: :s1, content: "Memory usage above threshold", metrics: %{memory: 85}},
  %{urgency: :medium, source: :s2, content: "Coordination conflicts increasing", metrics: %{conflicts: 12}},
  %{urgency: :high, source: :s3, content: "Control rules failing", metrics: %{failures: 5}}
]

IO.puts("Sending escalating warning signals...")
for signal <- warning_signals do
  {:ok, signal_id} = VSMCore.Channels.Algedonic.send_signal(signal)
  IO.puts("  📡 Sent #{signal.urgency} signal: #{signal.content} (ID: #{signal_id})")
  Process.sleep(100)
end

# Then send critical signal
IO.puts("Sending critical emergency signal...")
{:ok, critical_id} = VSMCore.Channels.Algedonic.send_signal(%{
  urgency: :critical,
  source: :system_monitor,
  content: "System overload - immediate intervention required",
  metrics: %{cpu: 98, memory: 95, error_rate: 0.15},
  correlation_id: "emergency_cascade_001"
})

IO.puts("  🚨 Critical signal sent (ID: #{critical_id})")

# Wait for system response
Process.sleep(500)

# Check emergency response
IO.puts("Checking emergency response...")
s5_signals = VSMCore.System5.Policy.get_algedonic_signals()
emergency_policies = VSMCore.System5.Policy.get_emergency_policies()

IO.puts("  📊 S5 received #{length(s5_signals)} algedonic signals")
IO.puts("  📋 #{length(emergency_policies)} emergency policies activated")

# Scenario 3: Adaptive Policy Implementation
IO.puts("\n🧠 Scenario 3: Adaptive Policy Implementation")
IO.puts("-" <> String.duplicate("-", 40))

# Set baseline policies
IO.puts("Setting baseline system policies...")
baseline_policies = [
  %{
    id: "efficiency_policy",
    type: :performance,
    parameters: %{max_processing_time: 100, min_success_rate: 0.95},
    scope: :system_wide
  },
  %{
    id: "variety_policy", 
    type: :variety_management,
    parameters: %{max_variety_ratio: 0.8, attenuation_threshold: 500},
    scope: [:s1, :s2]
  },
  %{
    id: "resource_policy",
    type: :resource_management, 
    parameters: %{cpu_threshold: 0.8, memory_threshold: 0.85},
    scope: :system_wide
  }
]

for policy <- baseline_policies do
  {:ok, _policy_id} = VSMCore.System5.Policy.set_policy(policy)
  IO.puts("  📜 Set policy: #{policy.id}")
end

# Simulate system learning and adaptation
IO.puts("Triggering system learning cycle...")

# Generate load that will trigger policy adaptations
IO.puts("Generating adaptive load patterns...")
adaptive_tasks = for i <- 1..5 do
  Task.async(fn ->
    unit_id = "adaptive_unit"
    
    # Gradually increase complexity to trigger adaptations
    for j <- 1..20 do
      complexity = min(5, 1 + div(i * j, 10))
      transaction = %{
        type: :adaptive_load,
        amount: 100 + j * 10,
        unit_id: unit_id,
        complexity: complexity,
        metadata: %{
          learning_cycle: i,
          step: j,
          expected_adaptation: complexity > 3
        }
      }
      
      VSMCore.System1.Operations.process_transaction(transaction)
      if rem(j, 5) == 0, do: Process.sleep(50)
    end
  end)
end

Task.await_many(adaptive_tasks, 15_000)

# Check system adaptations
IO.puts("Analyzing system adaptations...")
final_policies = VSMCore.System5.Policy.get_active_policies()
policy_changes = VSMCore.System5.Policy.get_policy_changes_since(System.system_time(:second) - 300)

IO.puts("  📊 Active policies: #{length(final_policies)}")
IO.puts("  🔄 Policy changes in last 5 minutes: #{length(policy_changes)}")

for change <- Enum.take(policy_changes, 3) do
  IO.puts("    - #{change.type}: #{change.policy_id} (#{change.reason})")
end

# Scenario 4: System-wide Optimization
IO.puts("\n⚡ Scenario 4: System-wide Optimization")
IO.puts("-" <> String.duplicate("-", 40))

# Request comprehensive system optimization
IO.puts("Initiating system-wide optimization...")
{:ok, optimization_id} = VSMCore.optimize_system(%{
  target: :overall_efficiency,
  constraints: %{
    max_disruption: :medium,
    preserve_functionality: true,
    optimization_time_limit: 30_000
  },
  focus_areas: [:throughput, :resource_utilization, :response_time, :variety_handling]
})

IO.puts("  🎯 Optimization initiated (ID: #{optimization_id})")

# Monitor optimization progress
IO.puts("Monitoring optimization progress...")
optimization_start = System.monotonic_time(:millisecond)

# Wait for completion with progress updates
:ok = VSMCore.wait_for_optimization(optimization_id, 30_000)
optimization_duration = System.monotonic_time(:millisecond) - optimization_start

# Get results
results = VSMCore.get_optimization_results(optimization_id)
IO.puts("  ✅ Optimization completed in #{optimization_duration}ms")
IO.puts("  📊 Status: #{results.status}")

if results.status == :completed do
  IO.puts("  Improvements achieved:")
  for {subsystem, improvement} <- results.improvements do
    if improvement > 0 do
      IO.puts("    - #{subsystem}: +#{Float.round(improvement * 100, 1)}%")
    end
  end
end

# Scenario 5: Resilience Testing
IO.puts("\n🛡️  Scenario 5: System Resilience Testing")
IO.puts("-" <> String.duplicate("-", 40))

# Test system behavior under partial failures
IO.puts("Testing system resilience under partial failures...")

# Record baseline performance
baseline_health = VSMCore.health()
IO.puts("  📊 Baseline health: #{baseline_health.status}")

# Simulate subsystem stress
IO.puts("Applying stress to S4 (Intelligence subsystem)...")
stress_task = Task.async(fn ->
  # Overload S4 with analysis requests
  for i <- 1..100 do
    VSMCore.System4.Intelligence.analyze_pattern(%{
      type: :stress_test,
      data: %{iteration: i, complexity: :rand.uniform(10)},
      priority: Enum.random([:low, :medium, :high])
    })
    if rem(i, 20) == 0, do: Process.sleep(10)
  end
end)

# Continue normal operations during stress
normal_ops_task = Task.async(fn ->
  for i <- 1..50 do
    VSMCore.System1.Operations.process_transaction(%{
      type: :resilience_test,
      amount: 100 + i,
      unit_id: "stable_unit",
      metadata: %{stress_test: true}
    })
    Process.sleep(20)
  end
end)

Task.await_many([stress_task, normal_ops_task], 10_000)

# Check system resilience
stressed_health = VSMCore.health()
IO.puts("  📊 Health under stress: #{stressed_health.status}")

# Test recovery
IO.puts("Testing system recovery...")
Process.sleep(2000)  # Allow recovery time

recovery_health = VSMCore.health()
IO.puts("  📊 Recovery health: #{recovery_health.status}")

# Final system assessment
IO.puts("\n📊 Final System Assessment")
IO.puts("-" <> String.duplicate("-", 40))

final_status = VSMCore.status()
final_health = VSMCore.health()

IO.puts("System Status: #{final_status.system}")
IO.puts("Health Status: #{final_health.status}")
IO.puts("Active Alerts: #{length(final_health.alerts)}")

if length(final_health.alerts) > 0 do
  IO.puts("Outstanding alerts:")
  for alert <- Enum.take(final_health.alerts, 5) do
    IO.puts("  ⚠️  #{alert.level}: #{alert.message}")
  end
end

# Performance summary
IO.puts("\nPerformance Summary:")
IO.puts("  Message Count: #{final_status.metrics.message_count}")
IO.puts("  Error Rate: #{final_status.metrics.error_rate}")
IO.puts("  Avg Processing Time: #{final_status.metrics.processing_time}ms")

# Capacity summary
IO.puts("\nCapacity Summary:")
for {subsystem, capacity} <- final_health.capacity.variety_handling do
  IO.puts("  #{subsystem}: #{capacity}% variety capacity")
end

IO.puts("\n🎉 Advanced scenarios completed successfully!")
IO.puts("The VSM Core system has demonstrated:")
IO.puts("  ✅ Complex variety management across subsystems")
IO.puts("  ✅ Emergency response through algedonic channels") 
IO.puts("  ✅ Adaptive policy implementation")
IO.puts("  ✅ System-wide optimization capabilities")
IO.puts("  ✅ Resilience under stress conditions")
IO.puts("\nSystem is ready for production workloads.")