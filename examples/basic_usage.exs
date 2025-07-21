#!/usr/bin/env elixir

# Basic VSM Core Usage Example
# 
# This script demonstrates how to start, monitor, and interact with the VSM Core system.
# Run with: elixir examples/basic_usage.exs

# Ensure VSM Core is available
Mix.install([{:vsm_core, path: "."}])

IO.puts("🚀 Starting VSM Core Basic Usage Example")
IO.puts("=" <> String.duplicate("=", 50))

# Start the VSM Core system
IO.puts("\n📍 Step 1: Starting VSM Core...")
case VSMCore.start() do
  {:ok, _pid} ->
    IO.puts("✅ VSM Core started successfully!")
  {:error, {:already_started, _}} ->
    IO.puts("ℹ️  VSM Core already running")
  {:error, reason} ->
    IO.puts("❌ Failed to start VSM Core: #{inspect(reason)}")
    System.halt(1)
end

# Check system status
IO.puts("\n📍 Step 2: Checking system status...")
status = VSMCore.status()
IO.puts("System Status: #{status.system}")
IO.puts("Subsystems:")
for {subsystem, subsystem_status} <- status.subsystems do
  status_emoji = if subsystem_status == :running, do: "✅", else: "❌"
  IO.puts("  #{status_emoji} #{subsystem}: #{subsystem_status}")
end

IO.puts("Channels:")
for {channel, channel_status} <- status.channels do
  status_emoji = if channel_status == :running, do: "✅", else: "❌"
  IO.puts("  #{status_emoji} #{channel}: #{channel_status}")
end

# Check system health
IO.puts("\n📍 Step 3: Checking system health...")
health = VSMCore.health()
IO.puts("Overall Health: #{health.status}")
IO.puts("System Uptime: #{health.uptime} seconds")
IO.puts("Active Alerts: #{length(health.alerts)}")

if length(health.alerts) > 0 do
  IO.puts("Alert Details:")
  for alert <- health.alerts do
    IO.puts("  ⚠️  #{alert.level}: #{alert.message}")
  end
end

# Create some test units in S1
IO.puts("\n📍 Step 4: Creating test operational units...")
units = [
  %{id: "sales_unit_1", variety_capacity: 100, type: :sales},
  %{id: "support_unit_1", variety_capacity: 50, type: :support},
  %{id: "production_unit_1", variety_capacity: 200, type: :production}
]

created_units = for unit_spec <- units do
  case VSMCore.System1.Unit.create(unit_spec) do
    {:ok, unit} ->
      IO.puts("  ✅ Created unit: #{unit.id}")
      unit
    {:error, reason} ->
      IO.puts("  ❌ Failed to create unit #{unit_spec.id}: #{inspect(reason)}")
      nil
  end
end |> Enum.filter(& &1)

# Process some transactions
IO.puts("\n📍 Step 5: Processing sample transactions...")
transactions = [
  %{type: :sale, amount: 150, unit_id: "sales_unit_1"},
  %{type: :support_request, complexity: 3, unit_id: "support_unit_1"},
  %{type: :production_order, quantity: 50, unit_id: "production_unit_1"},
  %{type: :sale, amount: 300, unit_id: "sales_unit_1"},
  %{type: :maintenance, duration: 30, unit_id: "production_unit_1"}
]

successful_transactions = for transaction <- transactions do
  case VSMCore.System1.Operations.process_transaction(transaction) do
    {:ok, result} ->
      IO.puts("  ✅ Processed #{transaction.type} for #{transaction.unit_id}")
      result
    {:error, reason} ->
      IO.puts("  ❌ Failed to process #{transaction.type}: #{inspect(reason)}")
      nil
  end
end |> Enum.filter(& &1)

IO.puts("Successfully processed #{length(successful_transactions)} transactions")

# Test system signal propagation
IO.puts("\n📍 Step 6: Testing system signal propagation...")
case VSMCore.test_signal() do
  {:ok, result} ->
    IO.puts("✅ Test signal successful!")
    IO.puts("  Signal path: #{inspect(result.path)}")
    IO.puts("  Latency: #{result.latency_ms}ms")
  {:error, reason} ->
    IO.puts("❌ Test signal failed: #{inspect(reason)}")
end

# Demonstrate variety engineering
IO.puts("\n📍 Step 7: Demonstrating variety engineering...")
if length(created_units) > 0 do
  unit = hd(created_units)
  
  # Generate variety in the unit
  IO.puts("Generating variety in #{unit.id}...")
  for i <- 1..10 do
    VSMCore.System1.Operations.process_transaction(%{
      type: Enum.random([:sale, :return, :exchange]),
      amount: :rand.uniform(500),
      unit_id: unit.id,
      complexity: rem(i, 3) + 1
    })
  end
  
  # Check variety metrics
  metrics = VSMCore.System1.Metrics.get_unit_metrics(unit.id)
  IO.puts("  Variety generated: #{metrics.variety_generated}")
  IO.puts("  Variety absorbed: #{metrics.variety_absorbed}")
  IO.puts("  Variety ratio: #{Float.round(metrics.variety_absorbed / max(metrics.variety_generated, 1), 3)}")
else
  IO.puts("⚠️  No units available for variety demonstration")
end

# Send a test algedonic signal
IO.puts("\n📍 Step 8: Testing algedonic (emergency) channel...")
case VSMCore.Channels.Algedonic.send_signal(%{
  urgency: :medium,
  source: :example_script,
  content: "Test alert from basic usage example",
  metrics: %{example_metric: 75}
}) do
  {:ok, signal_id} ->
    IO.puts("✅ Algedonic signal sent successfully (ID: #{signal_id})")
    
    # Check if it was processed
    Process.sleep(100)
    signals = VSMCore.System5.Policy.get_algedonic_signals()
    if length(signals) > 0 do
      IO.puts("  Signal processed by S5 Policy subsystem")
    end
  {:error, reason} ->
    IO.puts("❌ Failed to send algedonic signal: #{inspect(reason)}")
end

# Final system status
IO.puts("\n📍 Step 9: Final system status...")
final_status = VSMCore.status()
final_health = VSMCore.health()

IO.puts("Final System Status: #{final_status.system}")
IO.puts("Final Health Status: #{final_health.status}")
IO.puts("Total System Messages: #{final_status.metrics.message_count}")

# Demonstrate graceful shutdown (optional - uncomment to test)
# IO.puts("\n📍 Step 10: Stopping VSM Core...")
# case VSMCore.stop() do
#   :ok ->
#     IO.puts("✅ VSM Core stopped successfully")
#   {:error, reason} ->
#     IO.puts("❌ Error stopping VSM Core: #{inspect(reason)}")
# end

IO.puts("\n🎉 Basic usage example completed!")
IO.puts("The VSM Core system is now running and processing transactions.")
IO.puts("You can interact with it through the VSMCore module or by running")
IO.puts("other example scripts.")