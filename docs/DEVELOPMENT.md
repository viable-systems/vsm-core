# VSM Core Development Guide

Complete guide for developers contributing to VSM Core, including development setup, testing guidelines, and architecture decisions.

## Table of Contents

1. [Development Setup](#development-setup)
2. [Project Structure](#project-structure)
3. [Development Workflow](#development-workflow)
4. [Testing Guidelines](#testing-guidelines)
5. [Code Style and Standards](#code-style-and-standards)
6. [Architecture Guidelines](#architecture-guidelines)
7. [Performance Considerations](#performance-considerations)
8. [Contributing Guidelines](#contributing-guidelines)
9. [Release Process](#release-process)
10. [Troubleshooting Development Issues](#troubleshooting-development-issues)

## Development Setup

### Prerequisites

Ensure you have the following installed:

- **Elixir 1.14+** (recommended: 1.15.x)
- **Erlang/OTP 25+** (recommended: 26.x)
- **Git 2.x+**
- **Make** (for build automation)
- **Docker** (optional, for integration testing)

### Environment Setup

1. **Clone the repository:**
```bash
git clone https://github.com/viable-systems/vsm-core.git
cd vsm-core
```

2. **Install dependencies:**
```bash
mix deps.get
mix deps.compile
```

3. **Setup development configuration:**
```bash
cp config/dev.exs.example config/dev.exs
# Edit config/dev.exs with your local settings
```

4. **Verify installation:**
```bash
mix test
mix credo
mix dialyzer --build_plt  # First time only
```

### Development Tools

#### Recommended Editor Extensions

**VS Code:**
- ElixirLS Language Server
- Elixir Syntax Highlighting
- Elixir Formatter

**Vim/Neovim:**
- vim-elixir
- ale (with ElixirLS)

**Emacs:**
- elixir-mode
- alchemist.el

#### Development Dependencies

The development environment includes these tools:

```elixir
# In mix.exs - :dev dependencies
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:dialyxir, "~> 1.4", only: [:dev], runtime: false},
{:ex_doc, "~> 0.30", only: :dev, runtime: false},
{:excoveralls, "~> 0.17", only: :test},
{:benchee, "~> 1.1", only: :dev},
{:doctor, "~> 0.21", only: :dev}
```

### Development Configuration

#### config/dev.exs
```elixir
import Config

config :vsm_core,
  # Enable debug logging
  log_level: :debug,
  
  # Enable telemetry for development
  telemetry_enabled: true,
  telemetry_level: :debug,
  
  # Smaller resource pools for development
  s1_units: 2,
  pool_size: 4,
  
  # Faster intervals for testing
  s2_balancing_interval: 1_000,
  s3_audit_interval: 30_000,
  s4_scan_interval: 10_000,
  
  # Lower thresholds for testing alerts
  algedonic_threshold: 0.6,
  
  # Enable development features
  debug_mode: true,
  trace_messages: true,
  log_all_transactions: true

# Logger configuration
config :logger,
  level: :debug,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]

# Development-specific telemetry
config :telemetry,
  metrics_reporters: [:console]
```

#### Development Scripts

Create useful development scripts in `scripts/dev/`:

```bash
#!/bin/bash
# scripts/dev/setup.sh
echo "Setting up VSM Core development environment..."

# Install dependencies
mix deps.get
mix deps.compile

# Setup PLT for Dialyzer
mix dialyzer --build_plt

# Run initial tests
mix test

# Check code quality
mix credo

echo "Development environment ready!"
```

```bash
#!/bin/bash
# scripts/dev/test_watch.sh
# Watches for file changes and runs tests
fswatch -o lib/ test/ | xargs -n1 -I{} mix test
```

## Project Structure

### Directory Layout

```
vsm-core/
├── config/                 # Configuration files
│   ├── config.exs          # Base configuration
│   ├── dev.exs             # Development configuration
│   ├── test.exs            # Test configuration
│   └── prod.exs            # Production configuration
├── docs/                   # Documentation
│   ├── ARCHITECTURE_DESIGN.md
│   ├── API_REFERENCE.md
│   ├── USER_GUIDE.md
│   └── DEVELOPMENT.md
├── lib/                    # Source code
│   ├── vsm_core.ex         # Main entry point
│   └── vsm_core/           # Core modules
│       ├── application.ex  # OTP Application
│       ├── system1/        # Operations subsystem
│       ├── system2/        # Coordination subsystem
│       ├── system3/        # Control subsystem
│       ├── system4/        # Intelligence subsystem
│       ├── system5/        # Policy subsystem
│       ├── channels/       # Communication channels
│       └── shared/         # Shared utilities
├── test/                   # Test files
│   ├── test_helper.exs     # Test configuration
│   ├── support/            # Test support modules
│   ├── integration/        # Integration tests
│   └── unit/               # Unit tests (mirrors lib/)
├── scripts/                # Development scripts
│   ├── dev/                # Development utilities
│   ├── ci/                 # CI/CD scripts
│   └── benchmarks/         # Performance benchmarks
├── priv/                   # Private resources
│   └── static/             # Static files
├── mix.exs                 # Project configuration
├── README.md               # Project overview
├── LICENSE                 # License file
├── .gitignore              # Git ignore rules
├── .credo.exs              # Credo configuration
└── .dialyzer_ignore.exs    # Dialyzer ignore rules
```

### Module Organization

#### Subsystem Structure

Each subsystem follows a consistent structure:

```
system<N>/
├── <system_name>.ex        # Main module (e.g., operations.ex)
├── supervisor.ex           # Subsystem supervisor
├── <feature1>.ex           # Feature modules
├── <feature2>.ex
└── README.md               # Subsystem documentation
```

#### Channel Structure

```
channels/
├── <channel_name>.ex       # Main channel module
├── <channel_name>/         # Channel implementation details
│   ├── <component1>.ex
│   ├── <component2>.ex
│   └── ...
└── ...
```

#### Shared Module Structure

```
shared/
├── channel.ex              # Channel behavior and utilities
├── message.ex              # Message handling
├── recursion.ex            # Recursive structure utilities
├── variety/                # Variety engineering
│   ├── calculator.ex
│   ├── amplifier.ex
│   └── attenuator.ex
└── variety_engineering.ex  # Main variety engineering module
```

### Naming Conventions

#### Modules
- Use PascalCase: `VSMCore.System1.Operations`
- Subsystem modules: `VSMCore.System<N>.<Name>`
- Channel modules: `VSMCore.Channels.<Name>`
- Shared modules: `VSMCore.Shared.<Name>` or `VSMCore.<Name>`

#### Functions
- Use snake_case: `execute_transaction/2`
- Predicate functions end with `?`: `healthy?/1`
- Bang functions end with `!`: `execute_transaction!/2`

#### Variables
- Use snake_case: `transaction_result`
- Private variables start with `_`: `_unused_param`

#### Atoms
- Use snake_case: `:transaction_success`
- Subsystem atoms: `:system1`, `:system2`, etc.
- Status atoms: `:healthy`, `:degraded`, `:critical`

## Development Workflow

### Feature Development

1. **Create feature branch:**
```bash
git checkout -b feature/your-feature-name
```

2. **Write tests first (TDD):**
```bash
# Create test file
touch test/vsm_core/system1/your_feature_test.exs
# Write failing tests
mix test test/vsm_core/system1/your_feature_test.exs
```

3. **Implement feature:**
```bash
# Create implementation file
touch lib/vsm_core/system1/your_feature.ex
# Implement until tests pass
mix test
```

4. **Run quality checks:**
```bash
mix credo
mix dialyzer
mix docs
```

5. **Update documentation:**
```bash
# Update relevant docs
# Add @doc annotations
# Update CHANGELOG.md
```

6. **Submit pull request**

### Bug Fix Workflow

1. **Create bug fix branch:**
```bash
git checkout -b bugfix/issue-description
```

2. **Write regression test:**
```bash
# Add test that reproduces the bug
mix test  # Should fail
```

3. **Fix the bug:**
```bash
# Implement fix
mix test  # Should pass
```

4. **Verify fix doesn't break anything:**
```bash
mix test --cover
mix credo
mix dialyzer
```

### Development Commands

#### Essential Commands
```bash
# Run tests
mix test                    # All tests
mix test --stale           # Only changed tests
mix test --cover           # With coverage
mix test --trace           # With detailed output

# Code quality
mix credo                  # Linting
mix credo --strict         # Strict linting
mix dialyzer              # Type checking
mix format                # Code formatting
mix format --check-formatted  # Check if formatted

# Documentation
mix docs                  # Generate documentation
mix docs --open          # Generate and open docs

# Dependencies
mix deps.get             # Get dependencies
mix deps.update --all    # Update all dependencies
mix deps.clean --all     # Clean dependencies

# Analysis
mix xref graph           # Generate dependency graph
mix profile.eprof        # CPU profiling
mix profile.fprof        # Function profiling
```

#### Development Helpers
```bash
# Start IEx with project loaded
iex -S mix

# Run specific test file
mix test test/vsm_core/system1/operations_test.exs

# Run tests matching pattern
mix test --only tag:integration

# Continuous testing
mix test.watch

# Benchmark specific function
mix run scripts/benchmarks/system1_benchmark.exs
```

### Development Workflow with IEx

Start an interactive session for development:

```elixir
# Start IEx
iex -S mix

# Start VSM Core
{:ok, pid} = VSMCore.start_link(name: :dev_vsm, config: [s1_units: 2])

# Test functionality interactively
VSMCore.status()
VSMCore.System1.create_unit(%{name: "TestUnit", module: VSMCore.System1.Unit})

# Reload modules during development
r VSMCore.System1.Operations  # Reload single module
recompile()                   # Recompile all changed modules

# Access system state
state = :sys.get_state(VSMCore.System1.Supervisor)

# Subscribe to events for debugging
VSMCore.subscribe(:all_events)
flush()  # Check received messages
```

## Testing Guidelines

### Test Structure

VSM Core uses a comprehensive testing strategy:

1. **Unit Tests** - Test individual modules/functions
2. **Integration Tests** - Test subsystem interactions
3. **Property Tests** - Test with generated data
4. **Performance Tests** - Verify performance requirements

### Test Organization

```
test/
├── test_helper.exs          # Test configuration
├── support/                 # Test utilities
│   ├── factory.ex           # Data factories
│   ├── test_unit.ex         # Test operational unit
│   └── helpers.ex           # Test helpers
├── unit/                    # Unit tests
│   └── vsm_core/
│       ├── system1/
│       ├── system2/
│       ├── system3/
│       ├── system4/
│       ├── system5/
│       ├── channels/
│       └── shared/
├── integration/             # Integration tests
│   ├── subsystem_integration_test.exs
│   ├── channel_integration_test.exs
│   └── full_system_test.exs
└── property/                # Property-based tests
    └── variety_properties_test.exs
```

### Writing Unit Tests

#### Basic Test Structure

```elixir
defmodule VSMCore.System1.OperationsTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.System1.Operations
  
  setup do
    # Setup test data
    %{
      unit_config: %{
        name: "TestUnit",
        module: TestUnit,
        capacity: 10
      }
    }
  end
  
  describe "create_unit/1" do
    test "creates unit with valid configuration", %{unit_config: config} do
      assert {:ok, pid} = Operations.create_unit(config)
      assert Process.alive?(pid)
    end
    
    test "returns error with invalid configuration" do
      invalid_config = %{name: nil}
      assert {:error, :invalid_config} = Operations.create_unit(invalid_config)
    end
  end
  
  describe "execute_transaction/2" do
    setup %{unit_config: config} do
      {:ok, unit_pid} = Operations.create_unit(config)
      %{unit: unit_pid}
    end
    
    test "executes valid transaction", %{unit: unit} do
      transaction = {:test_operation, %{data: "test"}}
      assert {:ok, result} = Operations.execute_transaction(unit, transaction)
      assert result.status == :success
    end
    
    @tag :capture_log
    test "handles transaction errors gracefully", %{unit: unit} do
      invalid_transaction = {:invalid_operation, %{}}
      assert {:error, _reason} = Operations.execute_transaction(unit, invalid_transaction)
    end
  end
end
```

#### Test Factories

Create data factories for consistent test data:

```elixir
defmodule VSMCore.Test.Factory do
  @moduledoc "Factory functions for creating test data"
  
  def unit_config(overrides \\ %{}) do
    base_config = %{
      name: "TestUnit#{:rand.uniform(1000)}",
      module: VSMCore.Test.TestUnit,
      capacity: 10,
      resources: [:test_resource]
    }
    
    Map.merge(base_config, overrides)
  end
  
  def transaction(type \\ :test_operation, data \\ %{}) do
    {type, Map.merge(%{id: generate_id(), timestamp: DateTime.utc_now()}, data)}
  end
  
  def algedonic_alert(overrides \\ %{}) do
    base_alert = %{
      severity: :warning,
      source: :test_unit,
      message: "Test alert",
      data: %{value: 0.75}
    }
    
    Map.merge(base_alert, overrides)
  end
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
```

#### Test Helpers

```elixir
defmodule VSMCore.Test.Helpers do
  @moduledoc "Helper functions for tests"
  
  def start_vsm_system(config \\ []) do
    default_config = [
      s1_units: 1,
      telemetry_enabled: false,
      algedonic_enabled: false
    ]
    
    final_config = Keyword.merge(default_config, config)
    
    {:ok, pid} = VSMCore.start_link(name: :"test_vsm_#{:rand.uniform(10000)}", config: final_config)
    
    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)
    
    pid
  end
  
  def wait_for_event(event_pattern, timeout \\ 1000) do
    receive do
      ^event_pattern -> :ok
      other -> {:error, {:unexpected_message, other}}
    after
      timeout -> {:error, :timeout}
    end
  end
  
  def assert_eventually(assertion_fun, timeout \\ 1000, interval \\ 50) do
    end_time = System.monotonic_time(:millisecond) + timeout
    
    do_assert_eventually(assertion_fun, end_time, interval)
  end
  
  defp do_assert_eventually(assertion_fun, end_time, interval) do
    try do
      assertion_fun.()
    rescue
      ExUnit.AssertionError ->
        if System.monotonic_time(:millisecond) < end_time do
          Process.sleep(interval)
          do_assert_eventually(assertion_fun, end_time, interval)
        else
          assertion_fun.()  # Let the assertion error propagate
        end
    end
  end
end
```

### Integration Tests

Test subsystem interactions:

```elixir
defmodule VSMCore.Integration.SubsystemIntegrationTest do
  use ExUnit.Case
  
  import VSMCore.Test.Helpers
  alias VSMCore.Test.Factory
  
  setup do
    vsm_pid = start_vsm_system([
      s1_units: 2,
      s2_balancing_enabled: true,
      s3_audit_enabled: true
    ])
    
    %{vsm: vsm_pid}
  end
  
  test "S1 -> S3 resource allocation flow", %{vsm: _vsm} do
    # Create operational unit
    unit_config = Factory.unit_config()
    {:ok, _unit} = VSMCore.System1.create_unit(unit_config)
    
    # Trigger resource pressure
    high_load_transactions = for i <- 1..20 do
      Factory.transaction(:high_load_operation, %{load: 0.9, id: i})
    end
    
    # Execute transactions
    Enum.each(high_load_transactions, fn transaction ->
      VSMCore.System1.execute_transaction(:test_unit, transaction)
    end)
    
    # Wait for S3 to respond with resource allocation
    assert_eventually(fn ->
      usage = VSMCore.System3.get_resource_usage()
      assert usage.total.cpu > 0.5
    end)
    
    # Verify S3 optimization was triggered
    assert_eventually(fn ->
      metrics = VSMCore.System3.get_metrics()
      assert metrics.optimizations_performed > 0
    end)
  end
  
  test "S4 adaptation proposal -> S5 decision flow", %{vsm: _vsm} do
    # Subscribe to decision events
    VSMCore.subscribe([:policy_events])
    
    # Simulate environmental change detected by S4
    VSMCore.System4.configure_scanning(%{
      scanners: [%{
        name: :test_scanner,
        source: :test,
        data: %{market_volatility: 0.9}  # High volatility
      }]
    })
    
    # Wait for S4 to propose adaptation
    assert_eventually(fn ->
      proposals = VSMCore.System4.get_adaptation_proposals()
      assert length(proposals) > 0
    end)
    
    # Verify S5 makes decision
    assert_receive {:vsm_event, :decision_made, decision_data}, 5000
    assert decision_data.decision_type == :adaptation_response
  end
end
```

### Property-Based Tests

Use StreamData for property-based testing:

```elixir
defmodule VSMCore.Property.VarietyTest do
  use ExUnit.Case
  use ExUnitProperties
  
  alias VSMCore.VarietyEngineering
  
  property "requisite variety is always >= input variety" do
    check all disturbances <- positive_integer(),
              environmental_states <- positive_integer() do
      
      {:ok, result} = VarietyEngineering.calculate_requisite_variety(%{
        disturbances: disturbances,
        environmental_states: environmental_states
      })
      
      assert result.requisite_variety >= max(disturbances, environmental_states)
    end
  end
  
  property "attenuator reduces variety" do
    check all input_variety <- integer(100..10_000),
              target_variety <- integer(10..99) do
      
      {:ok, attenuators} = VarietyEngineering.design_attenuators(%{
        input_variety: input_variety,
        target_variety: target_variety,
        methods: [:filtering, :categorization]
      })
      
      # Test that applying attenuators reduces variety
      Enum.each(attenuators, fn attenuator ->
        assert attenuator.output_variety <= input_variety
        assert attenuator.reduction_ratio > 0
      end)
    end
  end
end
```

### Performance Tests

Test performance requirements:

```elixir
defmodule VSMCore.Performance.System1Test do
  use ExUnit.Case
  
  import VSMCore.Test.Helpers
  alias VSMCore.Test.Factory
  
  @transaction_count 1000
  @max_avg_latency 10  # milliseconds
  
  setup do
    vsm_pid = start_vsm_system([s1_units: 4])
    
    # Create operational units
    for i <- 1..4 do
      unit_config = Factory.unit_config(%{name: "PerfUnit#{i}"})
      {:ok, _unit} = VSMCore.System1.create_unit(unit_config)
    end
    
    %{vsm: vsm_pid}
  end
  
  @tag :performance
  test "handles high transaction throughput", %{vsm: _vsm} do
    transactions = for i <- 1..@transaction_count do
      Factory.transaction(:fast_operation, %{id: i, size: :small})
    end
    
    start_time = System.monotonic_time(:millisecond)
    
    # Execute transactions in parallel
    tasks = Enum.map(transactions, fn transaction ->
      Task.async(fn ->
        unit = :"PerfUnit#{:rand.uniform(4)}"
        VSMCore.System1.execute_transaction(unit, transaction)
      end)
    end)
    
    # Wait for all transactions to complete
    results = Task.await_many(tasks, 30_000)
    
    end_time = System.monotonic_time(:millisecond)
    total_time = end_time - start_time
    
    # Verify performance requirements
    avg_latency = total_time / @transaction_count
    throughput = @transaction_count / (total_time / 1000)
    
    assert avg_latency <= @max_avg_latency,
           "Average latency #{avg_latency}ms exceeds limit #{@max_avg_latency}ms"
    
    assert throughput >= 100,
           "Throughput #{throughput} TPS below minimum 100 TPS"
    
    # Verify all transactions succeeded
    success_count = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    success_rate = success_count / @transaction_count
    assert success_rate >= 0.99, "Success rate #{success_rate} below 99%"
  end
end
```

### Test Configuration

#### test_helper.exs
```elixir
# Start ExUnit
ExUnit.start()

# Configure test environment
Application.put_env(:vsm_core, :telemetry_enabled, false)
Application.put_env(:vsm_core, :log_level, :warn)

# Load test support modules
Code.require_file("support/factory.ex", __DIR__)
Code.require_file("support/helpers.ex", __DIR__)
Code.require_file("support/test_unit.ex", __DIR__)

# Configure test tags
ExUnit.configure(
  exclude: [
    :performance,    # Skip performance tests by default
    :integration,    # Skip integration tests by default
    :slow           # Skip slow tests by default
  ]
)
```

#### Running Specific Test Types
```bash
# Run only unit tests
mix test --exclude integration --exclude performance

# Run integration tests
mix test --only integration

# Run performance tests
mix test --only performance

# Run all tests including slow ones
mix test --include slow

# Run tests with coverage
mix coveralls
mix coveralls.html  # Generate HTML coverage report
```

## Code Style and Standards

### Elixir Style Guide

Follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide) with these additions:

#### Module Documentation

```elixir
defmodule VSMCore.System1.Operations do
  @moduledoc """
  Operations management for System 1 (Operations subsystem).
  
  This module provides functionality for creating and managing operational units,
  executing transactions, and monitoring performance metrics.
  
  ## Examples
  
      # Create an operational unit
      {:ok, unit} = VSMCore.System1.Operations.create_unit(%{
        name: "OrderProcessor",
        module: MyApp.OrderProcessingUnit,
        capacity: 100
      })
      
      # Execute a transaction
      {:ok, result} = VSMCore.System1.Operations.execute_transaction(
        unit,
        {:process_order, %{id: "123", items: [...]}}
      )
  
  ## Configuration
  
  Operations can be configured with the following options:
  
  - `:max_units` - Maximum number of operational units (default: 10)
  - `:default_capacity` - Default unit capacity (default: 100)
  - `:transaction_timeout` - Transaction timeout in milliseconds (default: 5000)
  
  """
  
  # Module implementation...
end
```

#### Function Documentation

```elixir
@doc """
Executes a transaction on the specified operational unit.

The transaction is processed asynchronously and the result is returned
when processing completes or times out.

## Parameters

- `unit` - The operational unit (PID or registered name)
- `transaction` - Transaction data in the format `{type, payload}`

## Returns

- `{:ok, result}` - Transaction executed successfully
- `{:error, reason}` - Transaction failed

## Examples

    {:ok, result} = execute_transaction(:order_unit, {:process_order, order_data})
    
    # With timeout
    {:ok, result} = execute_transaction(:order_unit, transaction, timeout: 10_000)

## Errors

- `:unit_not_found` - The specified unit doesn't exist
- `:timeout` - Transaction didn't complete within the timeout period
- `:unit_at_capacity` - Unit is at maximum capacity

"""
@spec execute_transaction(GenServer.server(), term(), keyword()) ::
        {:ok, term()} | {:error, atom()}
def execute_transaction(unit, transaction, opts \\ []) do
  # Implementation...
end
```

#### Error Handling

```elixir
# Good: Use tagged tuples for expected errors
def create_unit(config) do
  case validate_config(config) do
    :ok ->
      case start_unit(config) do
        {:ok, pid} -> {:ok, pid}
        {:error, reason} -> {:error, {:start_failed, reason}}
      end
    {:error, reason} ->
      {:error, {:invalid_config, reason}}
  end
end

# Good: Use ! functions for cases where errors are unexpected
def create_unit!(config) do
  case create_unit(config) do
    {:ok, unit} -> unit
    {:error, reason} -> raise ArgumentError, "Failed to create unit: #{inspect(reason)}"
  end
end

# Good: Handle errors at the appropriate level
def execute_batch_transactions(unit, transactions) do
  results = Enum.map(transactions, fn transaction ->
    case execute_transaction(unit, transaction) do
      {:ok, result} -> result
      {:error, reason} ->
        Logger.warning("Transaction failed: #{inspect(reason)}")
        {:error, reason}
    end
  end)
  
  {successes, errors} = Enum.split_with(results, fn
    {:error, _} -> false
    _ -> true
  end)
  
  %{
    successful: successes,
    failed: errors,
    success_rate: length(successes) / length(transactions)
  }
end
```

#### Logging

```elixir
# Use structured logging
Logger.info("Unit created",
  unit_name: unit.name,
  unit_pid: inspect(unit.pid),
  capacity: unit.capacity
)

# Use appropriate log levels
Logger.debug("Processing transaction", transaction_id: id)
Logger.info("Unit capacity updated", unit: unit, old_capacity: old, new_capacity: new)
Logger.warning("Unit approaching capacity", unit: unit, utilization: 0.85)
Logger.error("Unit failed to start", unit: unit, reason: reason)

# Avoid logging sensitive data
Logger.info("User authenticated", user_id: user.id)  # Good
Logger.info("User authenticated", user: user)        # Bad - might contain passwords
```

### Credo Configuration

#### .credo.exs
```elixir
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "test/",
          "scripts/"
        ],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/priv/"
        ]
      },
      strict: true,
      color: true,
      checks: [
        # Enabled checks
        {Credo.Check.Consistency.ExceptionNames, []},
        {Credo.Check.Consistency.LineEndings, []},
        {Credo.Check.Consistency.ParameterPatternMatching, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.SpaceInParentheses, []},
        {Credo.Check.Consistency.TabsOrSpaces, []},
        
        # Design checks
        {Credo.Check.Design.AliasUsage, [if_nested_deeper_than: 2, if_called_more_often_than: 2]},
        {Credo.Check.Design.TagTODO, [exit_status: 0]},  # Don't fail on TODOs
        {Credo.Check.Design.TagFIXME, []},
        
        # Readability checks
        {Credo.Check.Readability.AliasOrder, []},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Readability.LargeNumbers, []},
        {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
        {Credo.Check.Readability.ModuleAttributeNames, []},
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Readability.ModuleNames, []},
        {Credo.Check.Readability.ParenthesesInCondition, []},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
        {Credo.Check.Readability.PredicateFunctionNames, []},
        {Credo.Check.Readability.PreferImplicitTry, []},
        {Credo.Check.Readability.RedundantBlankLines, []},
        {Credo.Check.Readability.Semicolons, []},
        {Credo.Check.Readability.SpaceAfterCommas, []},
        {Credo.Check.Readability.StringSigils, []},
        {Credo.Check.Readability.TrailingBlankLine, []},
        {Credo.Check.Readability.TrailingWhiteSpace, []},
        {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
        {Credo.Check.Readability.VariableNames, []},
        
        # Refactoring opportunities
        {Credo.Check.Refactor.CondStatements, []},
        {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 12]},
        {Credo.Check.Refactor.FunctionArity, [max_arity: 8]},
        {Credo.Check.Refactor.LongQuoteBlocks, []},
        {Credo.Check.Refactor.MatchInCondition, []},
        {Credo.Check.Refactor.NegatedConditionsInUnless, []},
        {Credo.Check.Refactor.NegatedConditionsWithElse, []},
        {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
        {Credo.Check.Refactor.UnlessWithElse, []},
        {Credo.Check.Refactor.WithClauses, []},
        
        # Warnings
        {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
        {Credo.Check.Warning.BoolOperationOnSameValues, []},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
        {Credo.Check.Warning.IExPry, []},
        {Credo.Check.Warning.IoInspect, []},
        {Credo.Check.Warning.LazyLogging, []},
        {Credo.Check.Warning.OperationOnSameValues, []},
        {Credo.Check.Warning.OperationWithConstantResult, []},
        {Credo.Check.Warning.RaiseInsideRescue, []},
        {Credo.Check.Warning.UnusedEnumOperation, []},
        {Credo.Check.Warning.UnusedFileOperation, []},
        {Credo.Check.Warning.UnusedKeywordOperation, []},
        {Credo.Check.Warning.UnusedListOperation, []},
        {Credo.Check.Warning.UnusedPathOperation, []},
        {Credo.Check.Warning.UnusedRegexOperation, []},
        {Credo.Check.Warning.UnusedStringOperation, []},
        {Credo.Check.Warning.UnusedTupleOperation, []},
      ]
    }
  ]
}
```

## Architecture Guidelines

### OTP Design Principles

#### Supervision Trees

VSM Core follows OTP supervision principles:

```elixir
defmodule VSMCore.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Start telemetry first
      {VSMCore.Telemetry, []},
      
      # Start shared services
      {VSMCore.Shared.ChannelRegistry, []},
      {VSMCore.Shared.MessageBus, []},
      
      # Start subsystems in dependency order
      {VSMCore.System5.Supervisor, []},  # Policy first
      {VSMCore.System4.Supervisor, []},  # Intelligence
      {VSMCore.System3.Supervisor, []},  # Control
      {VSMCore.System2.Supervisor, []},  # Coordination
      {VSMCore.System1.Supervisor, []},  # Operations last
      
      # Start channels
      {VSMCore.Channels.TemporalVariety, []},
      {VSMCore.Channels.Algedonic, []}
    ]
    
    opts = [strategy: :one_for_one, name: VSMCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# Subsystem supervisors follow similar patterns
defmodule VSMCore.System1.Supervisor do
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    children = [
      # Core subsystem process
      {VSMCore.System1.Operations, opts},
      
      # Unit supervisor (dynamic)
      {DynamicSupervisor, name: VSMCore.System1.UnitSupervisor, strategy: :one_for_one},
      
      # Metrics collector
      {VSMCore.System1.Metrics, opts},
      
      # Transaction processor pool
      {VSMCore.System1.TransactionPool, pool_size: opts[:pool_size] || 5}
    ]
    
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
```

#### GenServer Design

```elixir
defmodule VSMCore.System1.Operations do
  use GenServer
  
  require Logger
  
  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def create_unit(config) do
    GenServer.call(__MODULE__, {:create_unit, config})
  end
  
  def execute_transaction(unit, transaction, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    GenServer.call(__MODULE__, {:execute_transaction, unit, transaction}, timeout)
  end
  
  # Server Callbacks
  def init(opts) do
    state = %{
      units: %{},
      metrics: %{},
      config: opts
    }
    
    # Schedule periodic tasks
    schedule_metrics_collection()
    
    {:ok, state}
  end
  
  def handle_call({:create_unit, config}, _from, state) do
    case validate_unit_config(config) do
      :ok ->
        case start_unit(config) do
          {:ok, unit_pid} ->
            new_state = put_in(state.units[config.name], %{
              pid: unit_pid,
              config: config,
              status: :healthy,
              created_at: DateTime.utc_now()
            })
            
            Logger.info("Unit created", unit: config.name, pid: inspect(unit_pid))
            emit_telemetry(:unit_created, %{name: config.name}, %{pid: unit_pid})
            
            {:reply, {:ok, unit_pid}, new_state}
            
          {:error, reason} ->
            Logger.error("Failed to create unit", unit: config.name, reason: reason)
            {:reply, {:error, reason}, state}
        end
        
      {:error, reason} ->
        {:reply, {:error, {:invalid_config, reason}}, state}
    end
  end
  
  def handle_info(:collect_metrics, state) do
    metrics = collect_system_metrics(state)
    new_state = %{state | metrics: metrics}
    
    schedule_metrics_collection()
    {:noreply, new_state}
  end
  
  # Private functions
  defp schedule_metrics_collection do
    Process.send_after(self(), :collect_metrics, 1_000)
  end
  
  defp emit_telemetry(event, measurements, metadata) do
    :telemetry.execute([:vsm_core, :system1, event], measurements, metadata)
  end
end
```

### Message Passing

Use structured messages between subsystems:

```elixir
defmodule VSMCore.Message do
  @moduledoc "Standard message format for VSM Core communication"
  
  @type t :: %__MODULE__{
    id: binary(),
    type: atom(),
    from: atom(),
    to: atom(),
    payload: term(),
    timestamp: DateTime.t(),
    priority: :low | :medium | :high | :critical,
    correlation_id: binary() | nil,
    metadata: map()
  }
  
  defstruct [
    :id,
    :type,
    :from,
    :to,
    :payload,
    :timestamp,
    :priority,
    :correlation_id,
    :metadata
  ]
  
  def new(type, from, to, payload, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      type: type,
      from: from,
      to: to,
      payload: payload,
      timestamp: DateTime.utc_now(),
      priority: Keyword.get(opts, :priority, :medium),
      correlation_id: Keyword.get(opts, :correlation_id),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
  
  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end

# Usage in subsystems
def send_resource_allocation(allocation) do
  message = VSMCore.Message.new(
    :resource_allocation,
    :system3,
    :system1,
    allocation,
    priority: :high
  )
  
  VSMCore.MessageBus.send(message)
end
```

### Error Handling Strategy

```elixir
# Use Result pattern for operations that can fail
defmodule VSMCore.Result do
  @type t(success, error) :: {:ok, success} | {:error, error}
  
  def map({:ok, value}, fun), do: {:ok, fun.(value)}
  def map({:error, _} = error, _fun), do: error
  
  def flat_map({:ok, value}, fun), do: fun.(value)
  def flat_map({:error, _} = error, _fun), do: error
  
  def with_default({:ok, value}, _default), do: value
  def with_default({:error, _}, default), do: default
end

# Chain operations safely
def process_order(order_data) do
  order_data
  |> validate_order()
  |> Result.flat_map(&check_inventory/1)
  |> Result.flat_map(&process_payment/1)
  |> Result.flat_map(&fulfill_order/1)
  |> case do
    {:ok, result} -> 
      Logger.info("Order processed successfully", order_id: result.id)
      {:ok, result}
    {:error, reason} ->
      Logger.warning("Order processing failed", reason: reason)
      {:error, reason}
  end
end
```

## Performance Considerations

### Profiling and Benchmarking

#### CPU Profiling

```elixir
# Use :eprof for CPU profiling
:eprof.start_profiling([self()])

# Run the code you want to profile
result = VSMCore.System1.execute_batch_transactions(unit, transactions)

:eprof.stop_profiling()
:eprof.analyze()
```

#### Memory Profiling

```elixir
# Use :fprof for detailed function profiling
:fprof.trace(:start)

# Run code
VSMCore.System1.execute_transaction(unit, transaction)

:fprof.trace(:stop)
:fprof.profile()
:fprof.analyse()
```

#### Benchmarking with Benchee

```elixir
# scripts/benchmarks/system1_benchmark.exs
defmodule System1Benchmark do
  alias VSMCore.System1
  
  def run do
    # Setup
    {:ok, _vsm} = VSMCore.start_link()
    {:ok, unit} = System1.create_unit(%{name: "BenchUnit", module: TestUnit})
    
    Benchee.run(%{
      "single_transaction" => fn ->
        System1.execute_transaction(unit, {:test_op, %{size: :small}})
      end,
      "batch_transactions" => fn ->
        transactions = for i <- 1..10, do: {:test_op, %{id: i, size: :small}}
        System1.execute_batch(unit, transactions)
      end
    },
    time: 10,
    memory_time: 2,
    formatters: [
      {Benchee.Formatters.HTML, file: "benchmarks/system1.html"},
      Benchee.Formatters.Console
    ])
  end
end

System1Benchmark.run()
```

### Memory Optimization

#### ETS for Caching

```elixir
defmodule VSMCore.Cache do
  @moduledoc "ETS-based cache for performance optimization"
  
  def start_link do
    :ets.new(__MODULE__, [:named_table, :public, read_concurrency: true])
    {:ok, self()}
  end
  
  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value, expiry}] ->
        if System.monotonic_time(:second) < expiry do
          {:ok, value}
        else
          :ets.delete(__MODULE__, key)
          :not_found
        end
      [] ->
        :not_found
    end
  end
  
  def put(key, value, ttl_seconds \\ 300) do
    expiry = System.monotonic_time(:second) + ttl_seconds
    :ets.insert(__MODULE__, {key, value, expiry})
    :ok
  end
end
```

#### Process Pool Management

```elixir
defmodule VSMCore.ProcessPool do
  @moduledoc "Generic process pool for CPU-intensive tasks"
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def execute(fun, timeout \\ 5_000) do
    GenServer.call(__MODULE__, {:execute, fun}, timeout)
  end
  
  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, System.schedulers_online())
    
    workers = for _i <- 1..pool_size do
      {:ok, pid} = Task.Supervisor.start_link()
      pid
    end
    
    state = %{
      workers: workers,
      current: 0
    }
    
    {:ok, state}
  end
  
  def handle_call({:execute, fun}, _from, state) do
    worker = Enum.at(state.workers, state.current)
    
    task = Task.Supervisor.async(worker, fun)
    result = Task.await(task)
    
    next_worker = rem(state.current + 1, length(state.workers))
    new_state = %{state | current: next_worker}
    
    {:reply, result, new_state}
  end
end
```

### Telemetry Optimization

Minimize telemetry overhead in hot paths:

```elixir
# Good: Use conditional telemetry
if telemetry_enabled?() do
  :telemetry.execute([:vsm_core, :system1, :transaction, :stop], 
                     %{duration: duration}, 
                     %{unit: unit, type: type})
end

# Better: Use telemetry spans for expensive operations
:telemetry.span([:vsm_core, :system1, :transaction], %{unit: unit}, fn ->
  result = execute_expensive_operation()
  {result, %{result_type: :success}}
end)

# Best: Sampling for high-frequency events
def emit_transaction_telemetry(duration, metadata) do
  if should_sample?() do
    :telemetry.execute([:vsm_core, :system1, :transaction, :stop], 
                       %{duration: duration}, 
                       metadata)
  end
end

defp should_sample? do
  :rand.uniform() < 0.1  # 10% sampling rate
end
```

## Contributing Guidelines

### Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Create a feature branch** from `main`
4. **Make your changes** following the development guidelines
5. **Write tests** for your changes
6. **Run the test suite** and ensure all tests pass
7. **Submit a pull request**

### Pull Request Process

1. **Update documentation** if you're changing public APIs
2. **Add tests** for new functionality
3. **Update CHANGELOG.md** with your changes
4. **Ensure CI passes** (tests, linting, type checking)
5. **Request review** from maintainers

### Commit Message Format

Use conventional commits:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(system1): add transaction batching support

- Implement execute_batch/2 function
- Add batch size validation
- Update telemetry events for batch operations

Closes #123
```

```
fix(algedonic): prevent alert storm on rapid failures

Rate limit alerts to prevent overwhelming operators when
multiple alerts are triggered in quick succession.

Fixes #456
```

### Issue Templates

#### Bug Report Template
```markdown
## Bug Description
Brief description of the bug.

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Environment
- Elixir version:
- OTP version:
- VSM Core version:
- OS:

## Additional Context
Any additional information about the bug.
```

#### Feature Request Template
```markdown
## Feature Description
Brief description of the feature.

## Motivation
Why this feature would be useful.

## Detailed Design
How you envision this feature working.

## Alternatives Considered
Other approaches you've considered.

## Additional Context
Any additional context about the feature.
```

## Release Process

### Version Numbering

VSM Core follows [Semantic Versioning](https://semver.org/):

- **MAJOR** version: Incompatible API changes
- **MINOR** version: New functionality (backward compatible)
- **PATCH** version: Bug fixes (backward compatible)

### Release Checklist

1. **Update version** in `mix.exs`
2. **Update CHANGELOG.md** with release notes
3. **Run full test suite** including integration tests
4. **Update documentation** if needed
5. **Create release tag**
6. **Publish to Hex.pm**
7. **Create GitHub release** with release notes

### Release Script

```bash
#!/bin/bash
# scripts/release.sh

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

echo "Preparing release $VERSION..."

# Update version in mix.exs
sed -i "s/version: \".*\"/version: \"$VERSION\"/" mix.exs

# Run tests
echo "Running tests..."
mix test --cover
mix credo --strict
mix dialyzer

# Generate documentation
echo "Generating documentation..."
mix docs

# Update changelog
echo "Update CHANGELOG.md with release notes"
read -p "Press enter when ready to continue..."

# Commit changes
git add .
git commit -m "chore: bump version to $VERSION"

# Create tag
git tag -a "v$VERSION" -m "Release $VERSION"

# Push
git push origin main
git push origin "v$VERSION"

echo "Release $VERSION prepared!"
echo "Review the changes and run 'mix hex.publish' to publish to Hex.pm"
```

## Troubleshooting Development Issues

### Common Development Problems

#### 1. Dependency Conflicts

```bash
# Clean and reinstall dependencies
mix deps.clean --all
mix deps.get
mix deps.compile
```

#### 2. Dialyzer PLT Issues

```bash
# Rebuild PLT
mix dialyzer --clean_plt
mix dialyzer --build_plt
```

#### 3. Test Database Issues

```bash
# Reset test database
MIX_ENV=test mix ecto.drop
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
```

#### 4. Memory Leaks in Tests

```elixir
# Add proper cleanup in test setup
setup do
  on_exit(fn ->
    # Clean up processes
    GenServer.stop(MyProcess, :normal, 1000)
    
    # Clear ETS tables
    :ets.delete_all_objects(MyTable)
    
    # Reset application state
    Application.put_env(:my_app, :test_state, nil)
  end)
end
```

#### 5. Flaky Tests

```elixir
# Use proper synchronization
test "async operation completes" do
  start_async_operation()
  
  # Don't use sleep - use proper waiting
  assert_eventually(fn ->
    assert operation_completed?()
  end, 5000)
end

# Avoid race conditions
test "concurrent access" do
  barrier = :ets.new(:test_barrier, [:public])
  
  tasks = for i <- 1..10 do
    Task.async(fn ->
      # Wait for all tasks to be ready
      :ets.insert(barrier, {i, :ready})
      wait_for_count(barrier, 10)
      
      # Now run the actual test
      perform_operation()
    end)
  end
  
  Task.await_many(tasks)
end
```

### Debug Techniques

#### IEx Debugging

```elixir
# Add breakpoints in code
require IEx; IEx.pry()

# Debug in tests
test "complex operation" do
  result = complex_operation()
  
  require IEx; IEx.pry()  # Inspect result here
  
  assert result.status == :success
end
```

#### Tracing

```elixir
# Trace function calls
:dbg.tracer()
:dbg.p(all, c)
:dbg.tpl(MyModule, :my_function, [])

# Or use simpler tracing
:sys.trace(pid, true)
```

#### Process Monitoring

```elixir
# Monitor process state
:observer.start()

# Or programmatically
Process.monitor(pid)
```

This development guide should help contributors work effectively on VSM Core while maintaining code quality and following best practices.