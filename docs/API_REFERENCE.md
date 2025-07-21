# VSM Core API Reference

Complete API documentation for all VSM Core modules and functions.

## Table of Contents

1. [Core API](#core-api)
2. [System 1 - Operations API](#system-1---operations-api)
3. [System 2 - Coordination API](#system-2---coordination-api)
4. [System 3 - Control API](#system-3---control-api)
5. [System 4 - Intelligence API](#system-4---intelligence-api)
6. [System 5 - Policy API](#system-5---policy-api)
7. [Channels API](#channels-api)
8. [Shared Modules API](#shared-modules-api)
9. [Message Formats](#message-formats)
10. [Event Types](#event-types)
11. [Error Codes](#error-codes)

## Core API

### VSMCore

Main entry point for the VSM Core system.

#### Functions

##### `start_link/1`

Starts the VSM Core supervisor.

```elixir
@spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
```

**Parameters:**
- `opts` - Configuration options (keyword list)

**Options:**
- `:name` - Name for the VSM system (atom, default: `:vsm_core`)
- `:config` - System configuration (keyword list)

**Returns:**
- `{:ok, pid}` - Success with supervisor PID
- `{:error, reason}` - Error with reason

**Example:**
```elixir
{:ok, pid} = VSMCore.start_link(
  name: :my_vsm,
  config: [
    s1_units: 3,
    telemetry_enabled: true
  ]
)
```

##### `status/0` and `status/1`

Gets the current system status.

```elixir
@spec status() :: map()
@spec status(atom()) :: map()
```

**Parameters:**
- `system_name` - Name of the VSM system (optional, default: `:vsm_core`)

**Returns:**
- Map with system status information

**Example:**
```elixir
status = VSMCore.status()
# => %{
#   status: :healthy,
#   uptime: 3600000,
#   subsystems: %{
#     system1: :healthy,
#     system2: :healthy,
#     system3: :healthy,
#     system4: :healthy,
#     system5: :healthy
#   },
#   channels: %{
#     temporal_variety: :active,
#     algedonic: :active
#   }
# }
```

##### `system/1` and `system/2`

Gets a reference to a specific subsystem.

```elixir
@spec system(1..5) :: pid() | atom()
@spec system(1..5, atom()) :: pid() | atom()
```

**Parameters:**
- `system_number` - Subsystem number (1-5)
- `vsm_name` - VSM system name (optional)

**Returns:**
- PID or registered name of the subsystem

**Example:**
```elixir
s1 = VSMCore.system(1)
s3 = VSMCore.system(3, :my_vsm)
```

##### `subscribe/1` and `subscribe/2`

Subscribes to VSM events.

```elixir
@spec subscribe(atom() | [atom()]) :: :ok | {:error, term()}
@spec subscribe(atom() | [atom()], atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `event_types` - Event type or list of event types to subscribe to
- `vsm_name` - VSM system name (optional)

**Available Event Types:**
- `:all_events` - All VSM events
- `:operations_events` - System 1 events
- `:coordination_events` - System 2 events
- `:control_events` - System 3 events
- `:intelligence_events` - System 4 events
- `:policy_events` - System 5 events
- `:algedonic_alerts` - Algedonic channel alerts
- `:temporal_variety_updates` - Temporal variety channel updates

**Returns:**
- `:ok` - Successfully subscribed
- `{:error, reason}` - Subscription failed

**Example:**
```elixir
:ok = VSMCore.subscribe([:operations_events, :algedonic_alerts])
```

##### `send_message/3` and `send_message/4`

Sends a message between subsystems.

```elixir
@spec send_message(atom(), atom(), term()) :: :ok | {:error, term()}
@spec send_message(atom(), atom(), term(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `from` - Source subsystem (`:system1` to `:system5`)
- `to` - Destination subsystem (`:system1` to `:system5`)
- `message` - Message content
- `vsm_name` - VSM system name (optional)

**Returns:**
- `:ok` - Message sent successfully
- `{:error, reason}` - Message sending failed

**Example:**
```elixir
:ok = VSMCore.send_message(:system1, :system3, {:alert, "High load detected"})
```

##### `get_state/1` and `get_state/2`

Gets the current state of a subsystem.

```elixir
@spec get_state(atom()) :: term()
@spec get_state(atom(), atom()) :: term()
```

**Parameters:**
- `subsystem` - Subsystem name (`:system1` to `:system5`)
- `vsm_name` - VSM system name (optional)

**Returns:**
- Current state of the subsystem

**Example:**
```elixir
state = VSMCore.get_state(:system3)
```

##### `get_metrics/1` and `get_metrics/2`

Gets metrics for a subsystem or the entire system.

```elixir
@spec get_metrics(atom()) :: map()
@spec get_metrics(atom(), atom()) :: map()
```

**Parameters:**
- `subsystem` - Subsystem name or `:all` for all subsystems
- `vsm_name` - VSM system name (optional)

**Returns:**
- Map containing metrics data

**Example:**
```elixir
metrics = VSMCore.get_metrics(:system1)
all_metrics = VSMCore.get_metrics(:all)
```

## System 1 - Operations API

### VSMCore.System1

Main module for System 1 (Operations) functionality.

#### Functions

##### `create_unit/1` and `create_unit/2`

Creates a new operational unit.

```elixir
@spec create_unit(map()) :: {:ok, pid()} | {:error, term()}
@spec create_unit(map(), atom()) :: {:ok, pid()} | {:error, term()}
```

**Parameters:**
- `unit_config` - Unit configuration map
- `vsm_name` - VSM system name (optional)

**Unit Configuration:**
- `:name` - Unit name (string, required)
- `:module` - Unit implementation module (atom, required)
- `:capacity` - Maximum capacity (integer, default: 100)
- `:resources` - Required resources (list of atoms)
- `:config` - Unit-specific configuration (map)

**Returns:**
- `{:ok, pid}` - Unit created successfully
- `{:error, reason}` - Unit creation failed

**Example:**
```elixir
{:ok, unit_pid} = VSMCore.System1.create_unit(%{
  name: "OrderProcessor",
  module: MyApp.OrderProcessingUnit,
  capacity: 50,
  resources: [:database, :payment_gateway],
  config: %{timeout: 5000}
})
```

##### `execute_transaction/2` and `execute_transaction/3`

Executes a transaction on a specific unit.

```elixir
@spec execute_transaction(atom() | pid(), term()) :: {:ok, term()} | {:error, term()}
@spec execute_transaction(atom() | pid(), term(), atom()) :: {:ok, term()} | {:error, term()}
```

**Parameters:**
- `unit` - Unit name or PID
- `transaction` - Transaction data
- `vsm_name` - VSM system name (optional)

**Returns:**
- `{:ok, result}` - Transaction executed successfully
- `{:error, reason}` - Transaction failed

**Example:**
```elixir
{:ok, result} = VSMCore.System1.execute_transaction(
  :order_processor,
  {:process_order, %{id: "123", items: [...]}}
)
```

##### `execute_batch/2` and `execute_batch/3`

Executes multiple transactions in batch.

```elixir
@spec execute_batch(atom() | pid(), [term()]) :: [term()]
@spec execute_batch(atom() | pid(), [term()], atom()) :: [term()]
```

**Parameters:**
- `unit` - Unit name or PID
- `transactions` - List of transactions
- `vsm_name` - VSM system name (optional)

**Returns:**
- List of results corresponding to each transaction

**Example:**
```elixir
results = VSMCore.System1.execute_batch(:order_processor, [
  {:process_order, order1},
  {:process_order, order2},
  {:process_order, order3}
])
```

##### `get_metrics/1` and `get_metrics/2`

Gets metrics for a specific unit or all units.

```elixir
@spec get_metrics(atom() | :all) :: map()
@spec get_metrics(atom() | :all, atom()) :: map()
```

**Parameters:**
- `unit` - Unit name or `:all` for all units
- `vsm_name` - VSM system name (optional)

**Returns:**
- Map containing unit metrics

**Example:**
```elixir
metrics = VSMCore.System1.get_metrics(:order_processor)
# => %{
#   throughput: 45.2,
#   latency_avg: 123.4,
#   latency_p95: 234.5,
#   latency_p99: 456.7,
#   error_rate: 0.002,
#   capacity_utilization: 0.85,
#   active_transactions: 12
# }
```

##### `list_units/0` and `list_units/1`

Lists all operational units.

```elixir
@spec list_units() :: [map()]
@spec list_units(atom()) :: [map()]
```

**Parameters:**
- `vsm_name` - VSM system name (optional)

**Returns:**
- List of unit information maps

**Example:**
```elixir
units = VSMCore.System1.list_units()
# => [
#   %{name: "OrderProcessor", pid: #PID<0.123.0>, status: :healthy},
#   %{name: "InventoryManager", pid: #PID<0.124.0>, status: :healthy}
# ]
```

##### `report_metric/2` and `report_metric/3`

Reports a metric value.

```elixir
@spec report_metric(atom(), number()) :: :ok
@spec report_metric(atom(), number(), atom()) :: :ok
```

**Parameters:**
- `metric_name` - Name of the metric
- `value` - Metric value
- `vsm_name` - VSM system name (optional)

**Returns:**
- `:ok`

**Example:**
```elixir
VSMCore.System1.report_metric(:orders_processed, 1)
VSMCore.System1.report_metric(:processing_time, 123.4)
```

### VSMCore.System1.Unit

Behavior for implementing operational units.

#### Callbacks

##### `init/1`

Initializes the unit.

```elixir
@callback init(opts :: keyword()) :: {:ok, state :: term()} | {:error, reason :: term()}
```

##### `handle_transaction/2`

Handles a transaction.

```elixir
@callback handle_transaction(transaction :: term(), state :: term()) ::
  {:ok, result :: term(), new_state :: term()} |
  {:error, reason :: term(), new_state :: term()}
```

##### `handle_status_request/1`

Handles status requests.

```elixir
@callback handle_status_request(state :: term()) ::
  {:ok, status :: map(), new_state :: term()}
```

##### `handle_resource_allocation/2`

Handles resource allocation updates.

```elixir
@callback handle_resource_allocation(allocation :: map(), state :: term()) ::
  {:ok, new_state :: term()} | {:error, reason :: term(), new_state :: term()}
```

## System 2 - Coordination API

### VSMCore.System2

Main module for System 2 (Coordination) functionality.

#### Functions

##### `add_coordination_rule/1` and `add_coordination_rule/2`

Adds a coordination rule to prevent oscillations.

```elixir
@spec add_coordination_rule(map()) :: :ok | {:error, term()}
@spec add_coordination_rule(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `rule` - Coordination rule configuration
- `vsm_name` - VSM system name (optional)

**Rule Configuration:**
- `:name` - Rule name (string, required)
- `:type` - Rule type (`:mutex`, `:throttle`, `:queue`, `:priority`)
- `:resource` - Resource being coordinated (atom)
- `:units` - List of units affected (list of atoms)
- `:parameters` - Rule-specific parameters (map)

**Returns:**
- `:ok` - Rule added successfully
- `{:error, reason}` - Rule addition failed

**Example:**
```elixir
:ok = VSMCore.System2.add_coordination_rule(%{
  name: "DatabaseAccess",
  type: :mutex,
  resource: :primary_database,
  units: [:order_processor, :inventory_manager],
  parameters: %{max_concurrent: 5, timeout: 10_000}
})
```

##### `detect_oscillations/0` and `detect_oscillations/1`

Detects oscillations in the system.

```elixir
@spec detect_oscillations() :: [map()]
@spec detect_oscillations(atom()) :: [map()]
```

**Parameters:**
- `vsm_name` - VSM system name (optional)

**Returns:**
- List of detected oscillations

**Example:**
```elixir
oscillations = VSMCore.System2.detect_oscillations()
# => [
#   %{
#     type: :resource_competition,
#     units: [:unit_a, :unit_b],
#     resource: :shared_database,
#     frequency: 2.5,
#     amplitude: 0.3
#   }
# ]
```

##### `apply_dampening/1` and `apply_dampening/2`

Applies dampening to reduce oscillations.

```elixir
@spec apply_dampening(map()) :: :ok | {:error, term()}
@spec apply_dampening(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `dampening_config` - Dampening configuration
- `vsm_name` - VSM system name (optional)

**Dampening Configuration:**
- `:type` - Dampening type (`:linear`, `:exponential`, `:adaptive`)
- `:factor` - Dampening factor (float, 0.0-1.0)
- `:duration` - Dampening duration in milliseconds
- `:target` - Specific oscillation to dampen (optional)

**Returns:**
- `:ok` - Dampening applied successfully
- `{:error, reason}` - Dampening application failed

**Example:**
```elixir
:ok = VSMCore.System2.apply_dampening(%{
  type: :exponential,
  factor: 0.8,
  duration: 30_000
})
```

##### `configure_balancing/1` and `configure_balancing/2`

Configures load balancing parameters.

```elixir
@spec configure_balancing(map()) :: :ok | {:error, term()}
@spec configure_balancing(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `config` - Balancing configuration
- `vsm_name` - VSM system name (optional)

**Balancing Configuration:**
- `:strategy` - Balancing strategy (`:round_robin`, `:least_connections`, `:weighted`, `:adaptive`)
- `:health_check_interval` - Health check interval in milliseconds
- `:fallback_strategy` - Fallback strategy when primary fails
- `:weights` - Unit weights for weighted strategy (map)

**Returns:**
- `:ok` - Configuration applied successfully
- `{:error, reason}` - Configuration failed

**Example:**
```elixir
:ok = VSMCore.System2.configure_balancing(%{
  strategy: :least_connections,
  health_check_interval: 5_000,
  fallback_strategy: :round_robin
})
```

##### `rebalance_load/0` and `rebalance_load/1`

Triggers manual load rebalancing.

```elixir
@spec rebalance_load() :: :ok | {:error, term()}
@spec rebalance_load(atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `vsm_name` - VSM system name (optional)

**Returns:**
- `:ok` - Rebalancing triggered successfully
- `{:error, reason}` - Rebalancing failed

**Example:**
```elixir
:ok = VSMCore.System2.rebalance_load()
```

## System 3 - Control API

### VSMCore.System3

Main module for System 3 (Control) functionality.

#### Functions

##### `allocate_resources/1` and `allocate_resources/2`

Allocates resources to operational units.

```elixir
@spec allocate_resources(map()) :: :ok | {:error, term()}
@spec allocate_resources(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `allocation` - Resource allocation map
- `vsm_name` - VSM system name (optional)

**Allocation Format:**
```elixir
%{
  unit_name => %{
    cpu: float(),      # CPU allocation (0.0-1.0)
    memory: float(),   # Memory allocation (0.0-1.0)
    connections: integer(),  # Connection pool size
    bandwidth: integer(),    # Bandwidth in bytes/sec
    custom_resource: term()  # Custom resource allocations
  }
}
```

**Returns:**
- `:ok` - Allocation successful
- `{:error, reason}` - Allocation failed

**Example:**
```elixir
:ok = VSMCore.System3.allocate_resources(%{
  order_processor: %{cpu: 0.4, memory: 0.3, connections: 20},
  inventory_manager: %{cpu: 0.3, memory: 0.2, connections: 10}
})
```

##### `get_resource_usage/0` and `get_resource_usage/1`

Gets current resource usage statistics.

```elixir
@spec get_resource_usage() :: map()
@spec get_resource_usage(atom()) :: map()
```

**Parameters:**
- `vsm_name` - VSM system name (optional)

**Returns:**
- Map containing resource usage information

**Example:**
```elixir
usage = VSMCore.System3.get_resource_usage()
# => %{
#   total: %{cpu: 0.75, memory: 0.60, connections: 45},
#   by_unit: %{
#     order_processor: %{cpu: 0.40, memory: 0.30, connections: 25},
#     inventory_manager: %{cpu: 0.35, memory: 0.30, connections: 20}
#   },
#   limits: %{cpu: 0.90, memory: 0.85, connections: 100}
# }
```

##### `set_limits/1` and `set_limits/2`

Sets resource limits for the system.

```elixir
@spec set_limits(map()) :: :ok | {:error, term()}
@spec set_limits(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `limits` - Resource limits map
- `vsm_name` - VSM system name (optional)

**Limits Format:**
```elixir
%{
  cpu_limit: float(),        # Maximum CPU usage (0.0-1.0)
  memory_limit: float(),     # Maximum memory usage (0.0-1.0)
  connection_limit: integer(), # Maximum connections
  custom_limits: map()       # Custom resource limits
}
```

**Returns:**
- `:ok` - Limits set successfully
- `{:error, reason}` - Setting limits failed

**Example:**
```elixir
:ok = VSMCore.System3.set_limits(%{
  cpu_limit: 0.8,
  memory_limit: 0.9,
  connection_limit: 100
})
```

##### `optimize/1` and `optimize/2`

Performs resource optimization.

```elixir
@spec optimize(map()) :: {:ok, map()} | {:error, term()}
@spec optimize(map(), atom()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `optimization_config` - Optimization configuration
- `vsm_name` - VSM system name (optional)

**Optimization Configuration:**
- `:strategy` - Optimization strategy (`:balanced`, `:performance`, `:efficiency`, `:custom`)
- `:objectives` - List of objectives (`:throughput`, `:latency`, `:resource_efficiency`)
- `:constraints` - List of constraints (`:memory_limit`, `:cpu_limit`, `:latency_target`)
- `:custom_function` - Custom optimization function (for `:custom` strategy)

**Returns:**
- `{:ok, optimization_result}` - Optimization successful
- `{:error, reason}` - Optimization failed

**Example:**
```elixir
{:ok, result} = VSMCore.System3.optimize(%{
  strategy: :balanced,
  objectives: [:throughput, :latency],
  constraints: [:memory_limit, :cpu_limit]
})
```

##### `audit/0` and `audit/1`

Performs System 3* audit operations.

```elixir
@spec audit() :: {:ok, map()} | {:error, term()}
@spec audit(atom()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `vsm_name` - VSM system name (optional)

**Returns:**
- `{:ok, audit_report}` - Audit completed successfully
- `{:error, reason}` - Audit failed

**Example:**
```elixir
{:ok, report} = VSMCore.System3.audit()
# => %{
#   timestamp: ~U[2024-01-01 12:00:00Z],
#   overall_health: :healthy,
#   units_audited: 5,
#   issues_found: [],
#   recommendations: [
#     %{type: :performance, description: "Consider increasing memory allocation"}
#   ],
#   compliance_status: :compliant
# }
```

##### `configure_audit/1` and `configure_audit/2`

Configures audit parameters.

```elixir
@spec configure_audit(map()) :: :ok | {:error, term()}
@spec configure_audit(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `audit_config` - Audit configuration
- `vsm_name` - VSM system name (optional)

**Audit Configuration:**
- `:enabled` - Enable/disable auditing (boolean)
- `:interval` - Audit interval in milliseconds
- `:deep_audit_interval` - Deep audit interval in milliseconds
- `:audit_scope` - List of audit areas (`:performance`, `:compliance`, `:security`)

**Returns:**
- `:ok` - Configuration applied successfully
- `{:error, reason}` - Configuration failed

**Example:**
```elixir
:ok = VSMCore.System3.configure_audit(%{
  enabled: true,
  interval: 60_000,
  deep_audit_interval: 300_000,
  audit_scope: [:performance, :compliance]
})
```

## System 4 - Intelligence API

### VSMCore.System4

Main module for System 4 (Intelligence) functionality.

#### Functions

##### `configure_scanning/1` and `configure_scanning/2`

Configures environmental scanning.

```elixir
@spec configure_scanning(map()) :: :ok | {:error, term()}
@spec configure_scanning(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `scan_config` - Scanning configuration
- `vsm_name` - VSM system name (optional)

**Scanning Configuration:**
- `:enabled` - Enable/disable scanning (boolean)
- `:scanners` - List of scanner configurations
- `:default_interval` - Default scan interval in milliseconds
- `:aggregation_strategy` - How to aggregate scan results

**Scanner Configuration:**
- `:name` - Scanner name (atom)
- `:source` - Data source type (`:external_api`, `:web_scraper`, `:database`, `:telemetry`)
- `:interval` - Scan interval in milliseconds
- `:config` - Scanner-specific configuration

**Returns:**
- `:ok` - Configuration applied successfully
- `{:error, reason}` - Configuration failed

**Example:**
```elixir
:ok = VSMCore.System4.configure_scanning(%{
  enabled: true,
  default_interval: 30_000,
  scanners: [
    %{
      name: :market_trends,
      source: :external_api,
      interval: 3600_000,
      config: %{
        endpoint: "https://api.market-data.com/trends",
        api_key: System.get_env("MARKET_API_KEY")
      }
    }
  ]
})
```

##### `get_scan_results/1` and `get_scan_results/2`

Gets results from environmental scanning.

```elixir
@spec get_scan_results(atom()) :: {:ok, map()} | {:error, term()}
@spec get_scan_results(atom(), atom()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `scanner_name` - Name of the scanner
- `vsm_name` - VSM system name (optional)

**Returns:**
- `{:ok, scan_results}` - Scan results retrieved successfully
- `{:error, reason}` - Failed to retrieve results

**Example:**
```elixir
{:ok, trends} = VSMCore.System4.get_scan_results(:market_trends)
# => %{
#   timestamp: ~U[2024-01-01 12:00:00Z],
#   data: %{
#     market_volatility: 0.25,
#     growth_indicators: [:tech_sector_up, :energy_stable],
#     risk_factors: [:inflation_concerns]
#   },
#   confidence: 0.85
# }
```

##### `forecast/1` and `forecast/2`

Generates forecasts based on collected data.

```elixir
@spec forecast(map()) :: {:ok, map()} | {:error, term()}
@spec forecast(map(), atom()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `forecast_config` - Forecasting configuration
- `vsm_name` - VSM system name (optional)

**Forecast Configuration:**
- `:metric` - Metric to forecast (atom)
- `:horizon` - Forecast horizon (`:hours_1`, `:days_7`, `:weeks_4`, etc.)
- `:models` - List of models to use (`:arima`, `:linear_regression`, `:neural_network`)
- `:confidence_level` - Confidence level (float, 0.0-1.0)
- `:include_uncertainty` - Include uncertainty bounds (boolean)

**Returns:**
- `{:ok, forecast_result}` - Forecast generated successfully
- `{:error, reason}` - Forecast generation failed

**Example:**
```elixir
{:ok, forecast} = VSMCore.System4.forecast(%{
  metric: :order_volume,
  horizon: :days_7,
  models: [:arima, :neural_network],
  confidence_level: 0.95,
  include_uncertainty: true
})

# => %{
#   metric: :order_volume,
#   horizon: :days_7,
#   predictions: [
#     %{time: ~U[2024-01-02 00:00:00Z], value: 1250, lower_bound: 1180, upper_bound: 1320},
#     %{time: ~U[2024-01-03 00:00:00Z], value: 1300, lower_bound: 1220, upper_bound: 1380}
#   ],
#   model_performance: %{arima: 0.85, neural_network: 0.92},
#   confidence: 0.95
# }
```

##### `propose_adaptations/1` and `propose_adaptations/2`

Proposes adaptations based on environmental changes.

```elixir
@spec propose_adaptations(map()) :: {:ok, [map()]} | {:error, term()}
@spec propose_adaptations(map(), atom()) :: {:ok, [map()]} | {:error, term()}
```

**Parameters:**
- `adaptation_config` - Adaptation configuration
- `vsm_name` - VSM system name (optional)

**Adaptation Configuration:**
- `:context` - Current context or trigger (atom)
- `:constraints` - List of constraints to consider
- `:objectives` - List of objectives to optimize for
- `:risk_tolerance` - Risk tolerance level (`:low`, `:medium`, `:high`)

**Returns:**
- `{:ok, adaptation_proposals}` - Proposals generated successfully
- `{:error, reason}` - Proposal generation failed

**Example:**
```elixir
{:ok, proposals} = VSMCore.System4.propose_adaptations(%{
  context: :market_downturn,
  constraints: [:budget_limit, :staff_retention],
  objectives: [:cost_reduction, :efficiency_improvement],
  risk_tolerance: :medium
})

# => [
#   %{
#     id: "adapt_001",
#     type: :resource_optimization,
#     description: "Reduce non-critical resource allocation by 15%",
#     impact: %{cost_savings: 50_000, efficiency_gain: 0.12},
#     risk_level: :low,
#     implementation_time: :weeks_2,
#     confidence: 0.88
#   }
# ]
```

##### `get_forecast_accuracy/1` and `get_forecast_accuracy/2`

Gets historical forecast accuracy metrics.

```elixir
@spec get_forecast_accuracy(map()) :: {:ok, map()} | {:error, term()}
@spec get_forecast_accuracy(map(), atom()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `accuracy_query` - Query for accuracy metrics
- `vsm_name` - VSM system name (optional)

**Accuracy Query:**
- `:metric` - Metric to check accuracy for
- `:period` - Time period to analyze
- `:models` - Specific models to analyze (optional)

**Returns:**
- `{:ok, accuracy_metrics}` - Accuracy metrics retrieved successfully
- `{:error, reason}` - Failed to retrieve accuracy metrics

**Example:**
```elixir
{:ok, accuracy} = VSMCore.System4.get_forecast_accuracy(%{
  metric: :order_volume,
  period: :last_month
})

# => %{
#   overall_accuracy: 0.87,
#   by_model: %{
#     arima: 0.85,
#     neural_network: 0.89
#   },
#   by_horizon: %{
#     hours_1: 0.95,
#     days_1: 0.88,
#     days_7: 0.82
#   }
# }
```

## System 5 - Policy API

### VSMCore.System5

Main module for System 5 (Policy) functionality.

#### Functions

##### `set_values/1` and `set_values/2`

Sets organizational values and identity.

```elixir
@spec set_values(map()) :: :ok | {:error, term()}
@spec set_values(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `values_config` - Values configuration
- `vsm_name` - VSM system name (optional)

**Values Configuration:**
- `:core_values` - List of core values with weights
- `:mission` - Mission statement (string)
- `:vision` - Vision statement (string)
- `:principles` - Operating principles (list)

**Core Value Format:**
```elixir
%{
  name: atom(),           # Value name
  weight: float(),        # Relative weight (0.0-1.0)
  description: string(),  # Description
  metrics: [atom()]       # Associated metrics (optional)
}
```

**Returns:**
- `:ok` - Values set successfully
- `{:error, reason}` - Setting values failed

**Example:**
```elixir
:ok = VSMCore.System5.set_values(%{
  core_values: [
    %{name: :customer_focus, weight: 0.4, description: "Customer satisfaction is paramount"},
    %{name: :innovation, weight: 0.3, description: "Continuous improvement and innovation"},
    %{name: :sustainability, weight: 0.3, description: "Long-term environmental responsibility"}
  ],
  mission: "Deliver exceptional value to customers while maintaining sustainability",
  vision: "Global leader in sustainable technology solutions",
  principles: [:transparency, :accountability, :continuous_learning]
})
```

##### `make_decision/1` and `make_decision/2`

Makes strategic decisions using the configured decision framework.

```elixir
@spec make_decision(map()) :: {:ok, map()} | {:error, term()}
@spec make_decision(map(), atom()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `decision_context` - Decision context and options
- `vsm_name` - VSM system name (optional)

**Decision Context:**
- `:issue` - Issue or decision type (atom)
- `:options` - List of available options
- `:criteria` - Decision criteria (list of atoms)
- `:constraints` - Constraints to consider (list)
- `:stakeholders` - Affected stakeholders (list)
- `:urgency` - Decision urgency (`:low`, `:medium`, `:high`, `:critical`)

**Returns:**
- `{:ok, decision_result}` - Decision made successfully
- `{:error, reason}` - Decision making failed

**Example:**
```elixir
{:ok, decision} = VSMCore.System5.make_decision(%{
  issue: :market_expansion,
  options: [
    %{name: :asia_expansion, cost: 5_000_000, timeline: :months_18, risk: :medium},
    %{name: :europe_expansion, cost: 3_000_000, timeline: :months_12, risk: :low}
  ],
  criteria: [:roi, :risk, :strategic_alignment],
  constraints: [:budget_limit, :timeline_pressure],
  stakeholders: [:board, :investors, :employees],
  urgency: :high
})

# => %{
#   decision: :europe_expansion,
#   rationale: "Best balance of ROI, risk, and timeline constraints",
#   confidence: 0.85,
#   value_alignment: 0.92,
#   stakeholder_impact: %{
#     board: :positive,
#     investors: :positive,
#     employees: :neutral
#   },
#   implementation_plan: [...]
# }
```

##### `resolve_conflict/1` and `resolve_conflict/2`

Resolves conflicts between System 3 and System 4.

```elixir
@spec resolve_conflict(map()) :: {:ok, map()} | {:error, term()}
@spec resolve_conflict(map(), atom()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `conflict` - Conflict description
- `vsm_name` - VSM system name (optional)

**Conflict Format:**
- `:s3_position` - System 3's position and rationale
- `:s4_position` - System 4's position and rationale
- `:severity` - Conflict severity (`:low`, `:medium`, `:high`)
- `:time_pressure` - Time pressure for resolution

**Returns:**
- `{:ok, resolution}` - Conflict resolved successfully
- `{:error, reason}` - Conflict resolution failed

**Example:**
```elixir
{:ok, resolution} = VSMCore.System5.resolve_conflict(%{
  s3_position: %{
    focus: :operational_efficiency,
    proposal: :cost_reduction,
    rationale: "Improve short-term profitability"
  },
  s4_position: %{
    focus: :future_adaptation,
    proposal: :innovation_investment,
    rationale: "Prepare for market changes"
  },
  severity: :medium,
  time_pressure: :high
})

# => %{
#   resolution: :balanced_approach,
#   decision: "Implement cost reduction in non-critical areas while maintaining innovation budget",
#   allocation: %{cost_reduction: 0.3, innovation_investment: 0.7},
#   rationale: "Balances immediate needs with future sustainability",
#   monitoring_metrics: [:short_term_efficiency, :innovation_pipeline]
# }
```

##### `check_alignment/1` and `check_alignment/2`

Checks alignment of decisions/actions with organizational values.

```elixir
@spec check_alignment(map()) :: {:ok, map()} | {:error, term()}
@spec check_alignment(map(), atom()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `alignment_query` - Query for alignment check
- `vsm_name` - VSM system name (optional)

**Alignment Query:**
- `:decision` - Decision or action to check
- `:options` - List of options to evaluate (optional)
- `:context` - Context information

**Returns:**
- `{:ok, alignment_result}` - Alignment check completed successfully
- `{:error, reason}` - Alignment check failed

**Example:**
```elixir
{:ok, alignment} = VSMCore.System5.check_alignment(%{
  decision: :new_product_launch,
  options: [:option_a, :option_b, :option_c],
  context: %{market_conditions: :stable, resources: :adequate}
})

# => %{
#   overall_alignment: 0.87,
#   by_value: %{
#     customer_focus: 0.92,
#     innovation: 0.85,
#     sustainability: 0.84
#   },
#   recommendations: [
#     "Consider environmental impact in option_b",
#     "Enhance customer research for option_c"
#   ],
#   approval: :recommended
# }
```

## Channels API

### VSMCore.Channels.TemporalVariety

Manages temporal variety and pattern detection across different timescales.

#### Functions

##### `configure/1` and `configure/2`

Configures temporal variety analysis.

```elixir
@spec configure(map()) :: :ok | {:error, term()}
@spec configure(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `config` - Temporal variety configuration
- `vsm_name` - VSM system name (optional)

**Configuration Options:**
- `:timescales` - List of timescales to analyze (`:second`, `:minute`, `:hour`, `:day`, `:week`)
- `:aggregation_methods` - List of aggregation methods (`:mean`, `:median`, `:max`, `:min`, `:std_dev`)
- `:pattern_detection` - Enable pattern detection (boolean)
- `:retention_policy` - Data retention policy (map)
- `:variety_calculation` - Variety calculation configuration (map)

**Returns:**
- `:ok` - Configuration applied successfully
- `{:error, reason}` - Configuration failed

**Example:**
```elixir
:ok = VSMCore.Channels.TemporalVariety.configure(%{
  timescales: [:minute, :hour, :day],
  aggregation_methods: [:mean, :max, :percentile_95],
  pattern_detection: true,
  retention_policy: %{
    raw_data: :hours_24,
    aggregates: :days_7
  }
})
```

##### `add_data/1` and `add_data/2`

Adds data point for temporal analysis.

```elixir
@spec add_data(map()) :: :ok | {:error, term()}
@spec add_data(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `data_point` - Data point to add
- `vsm_name` - VSM system name (optional)

**Data Point Format:**
- `:metric` - Metric name (atom)
- `:value` - Metric value (number)
- `:timestamp` - Timestamp (DateTime)
- `:metadata` - Additional metadata (map, optional)

**Returns:**
- `:ok` - Data added successfully
- `{:error, reason}` - Adding data failed

**Example:**
```elixir
:ok = VSMCore.Channels.TemporalVariety.add_data(%{
  metric: :order_volume,
  value: 125,
  timestamp: DateTime.utc_now(),
  metadata: %{source: :system1, unit: :order_processor}
})
```

##### `get_aggregates/1` and `get_aggregates/2`

Gets aggregated data for a specific metric and timescale.

```elixir
@spec get_aggregates(map()) :: {:ok, [map()]} | {:error, term()}
@spec get_aggregates(map(), atom()) :: {:ok, [map()]} | {:error, term()}
```

**Parameters:**
- `query` - Aggregation query
- `vsm_name` - VSM system name (optional)

**Query Format:**
- `:metric` - Metric name (atom)
- `:timescale` - Timescale (atom)
- `:from` - Start time (DateTime)
- `:to` - End time (DateTime)
- `:aggregation_method` - Aggregation method (atom, optional)

**Returns:**
- `{:ok, aggregates}` - Aggregates retrieved successfully
- `{:error, reason}` - Failed to retrieve aggregates

**Example:**
```elixir
{:ok, aggregates} = VSMCore.Channels.TemporalVariety.get_aggregates(%{
  metric: :order_volume,
  timescale: :hour,
  from: DateTime.add(DateTime.utc_now(), -24, :hour),
  to: DateTime.utc_now()
})
```

##### `detect_patterns/1` and `detect_patterns/2`

Detects patterns in temporal data.

```elixir
@spec detect_patterns(map()) :: {:ok, [map()]} | {:error, term()}
@spec detect_patterns(map(), atom()) :: {:ok, [map()]} | {:error, term()}
```

**Parameters:**
- `pattern_query` - Pattern detection query
- `vsm_name` - VSM system name (optional)

**Pattern Query:**
- `:metric` - Metric name (atom)
- `:pattern_types` - Types of patterns to detect (list)
- `:lookback` - Lookback period
- `:sensitivity` - Detection sensitivity (float, 0.0-1.0)

**Pattern Types:**
- `:trend` - Trending patterns
- `:seasonal` - Seasonal patterns
- `:cycle` - Cyclical patterns
- `:anomaly` - Anomalous patterns

**Returns:**
- `{:ok, patterns}` - Patterns detected successfully
- `{:error, reason}` - Pattern detection failed

**Example:**
```elixir
{:ok, patterns} = VSMCore.Channels.TemporalVariety.detect_patterns(%{
  metric: :order_volume,
  pattern_types: [:trend, :seasonal],
  lookback: :days_30,
  sensitivity: 0.7
})
```

### VSMCore.Channels.Algedonic

Manages critical alerts and emergency communications.

#### Functions

##### `configure/1` and `configure/2`

Configures algedonic alert system.

```elixir
@spec configure(map()) :: :ok | {:error, term()}
@spec configure(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `config` - Algedonic configuration
- `vsm_name` - VSM system name (optional)

**Configuration Options:**
- `:thresholds` - Alert thresholds by severity
- `:routing` - Alert routing configuration
- `:rate_limiting` - Rate limiting configuration
- `:escalation` - Escalation rules

**Returns:**
- `:ok` - Configuration applied successfully
- `{:error, reason}` - Configuration failed

**Example:**
```elixir
:ok = VSMCore.Channels.Algedonic.configure(%{
  thresholds: %{
    critical: 0.95,
    severe: 0.80,
    warning: 0.65
  },
  routing: %{
    critical: [:system5, :ops_team, :management],
    severe: [:system3, :system5],
    warning: [:system3]
  },
  rate_limiting: %{
    max_alerts_per_minute: 5,
    cooldown_period: 300_000
  }
})
```

##### `alert/1` and `alert/2`

Triggers an algedonic alert.

```elixir
@spec alert(map()) :: :ok | {:error, term()}
@spec alert(map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `alert_data` - Alert information
- `vsm_name` - VSM system name (optional)

**Alert Data:**
- `:severity` - Alert severity (`:critical`, `:severe`, `:warning`)
- `:source` - Alert source (atom)
- `:message` - Alert message (string)
- `:data` - Additional alert data (map, optional)
- `:requires_immediate_action` - Immediate action required (boolean, optional)

**Returns:**
- `:ok` - Alert triggered successfully
- `{:error, reason}` - Alert triggering failed

**Example:**
```elixir
:ok = VSMCore.Channels.Algedonic.alert(%{
  severity: :critical,
  source: :system1_unit_a,
  message: "Database connection pool exhausted",
  data: %{
    pool_usage: 1.0,
    waiting_requests: 150,
    last_successful_connection: DateTime.add(DateTime.utc_now(), -30, :second)
  },
  requires_immediate_action: true
})
```

##### `acknowledge_alert/2` and `acknowledge_alert/3`

Acknowledges an alert.

```elixir
@spec acknowledge_alert(binary(), map()) :: :ok | {:error, term()}
@spec acknowledge_alert(binary(), map(), atom()) :: :ok | {:error, term()}
```

**Parameters:**
- `alert_id` - Alert ID (string)
- `acknowledgment` - Acknowledgment information
- `vsm_name` - VSM system name (optional)

**Acknowledgment Information:**
- `:acknowledged_by` - Who acknowledged the alert (string)
- `:action_taken` - Action taken (string)
- `:estimated_resolution` - Estimated resolution time

**Returns:**
- `:ok` - Alert acknowledged successfully
- `{:error, reason}` - Acknowledgment failed

**Example:**
```elixir
:ok = VSMCore.Channels.Algedonic.acknowledge_alert("alert_123", %{
  acknowledged_by: "ops_team_lead",
  action_taken: "Initiated connection pool restart",
  estimated_resolution: :minutes_15
})
```

##### `get_alerts/1` and `get_alerts/2`

Retrieves alert history.

```elixir
@spec get_alerts(map()) :: {:ok, [map()]} | {:error, term()}
@spec get_alerts(map(), atom()) :: {:ok, [map()]} | {:error, term()}
```

**Parameters:**
- `query` - Alert query
- `vsm_name` - VSM system name (optional)

**Query Options:**
- `:severity` - Filter by severity (atom or list)
- `:source` - Filter by source (atom)
- `:from` - Start time (DateTime)
- `:to` - End time (DateTime)
- `:status` - Filter by status (`:active`, `:acknowledged`, `:resolved`, `:all`)
- `:limit` - Maximum number of alerts to return

**Returns:**
- `{:ok, alerts}` - Alerts retrieved successfully
- `{:error, reason}` - Failed to retrieve alerts

**Example:**
```elixir
{:ok, alerts} = VSMCore.Channels.Algedonic.get_alerts(%{
  severity: [:critical, :severe],
  from: DateTime.add(DateTime.utc_now(), -24, :hour),
  status: :all,
  limit: 100
})
```

## Shared Modules API

### VSMCore.VarietyEngineering

Provides variety engineering calculations and design tools.

#### Functions

##### `calculate_requisite_variety/1`

Calculates requisite variety using Ashby's Law.

```elixir
@spec calculate_requisite_variety(map()) :: {:ok, map()} | {:error, term()}
```

**Parameters:**
- `params` - Calculation parameters

**Parameters:**
- `:disturbances` - Number of possible disturbances
- `:environmental_states` - Number of environmental states
- `:control_actions` - Number of available control actions (optional)

**Returns:**
- `{:ok, calculation_result}` - Calculation successful
- `{:error, reason}` - Calculation failed

**Example:**
```elixir
{:ok, result} = VSMCore.VarietyEngineering.calculate_requisite_variety(%{
  disturbances: 1000,
  environmental_states: 50,
  control_actions: 100
})

# => %{
#   requisite_variety: 50000,
#   current_variety: 100,
#   variety_gap: 49900,
#   recommendations: [:add_attenuators, :increase_amplifiers]
# }
```

##### `design_attenuators/1`

Designs variety attenuators to reduce input variety.

```elixir
@spec design_attenuators(map()) :: {:ok, [map()]} | {:error, term()}
```

**Parameters:**
- `design_params` - Attenuator design parameters

**Design Parameters:**
- `:input_variety` - Input variety level
- `:target_variety` - Target variety level
- `:methods` - Preferred attenuation methods
- `:constraints` - Design constraints

**Attenuation Methods:**
- `:categorization` - Group similar inputs
- `:filtering` - Filter out irrelevant inputs
- `:aggregation` - Combine multiple inputs
- `:sampling` - Sample from input stream
- `:prioritization` - Focus on high-priority inputs

**Returns:**
- `{:ok, attenuator_designs}` - Designs generated successfully
- `{:error, reason}` - Design generation failed

**Example:**
```elixir
{:ok, attenuators} = VSMCore.VarietyEngineering.design_attenuators(%{
  input_variety: 10_000,
  target_variety: 100,
  methods: [:categorization, :filtering, :prioritization],
  constraints: [:processing_time, :accuracy_threshold]
})
```

##### `design_amplifiers/1`

Designs variety amplifiers to increase output variety.

```elixir
@spec design_amplifiers(map()) :: {:ok, [map()]} | {:error, term()}
```

**Parameters:**
- `design_params` - Amplifier design parameters

**Design Parameters:**
- `:input_variety` - Input variety level
- `:target_variety` - Target variety level
- `:methods` - Preferred amplification methods
- `:constraints` - Design constraints

**Amplification Methods:**
- `:automation` - Automate repetitive actions
- `:delegation` - Delegate to multiple units
- `:replication` - Replicate successful patterns
- `:combination` - Combine simple actions
- `:specialization` - Create specialized responses

**Returns:**
- `{:ok, amplifier_designs}` - Designs generated successfully
- `{:error, reason}` - Design generation failed

**Example:**
```elixir
{:ok, amplifiers} = VSMCore.VarietyEngineering.design_amplifiers(%{
  input_variety: 10,
  target_variety: 1_000,
  methods: [:automation, :delegation, :replication],
  constraints: [:resource_limits, :quality_standards]
})
```

## Message Formats

### Standard Message Format

All VSM Core messages follow a standard format:

```elixir
%VSMCore.Message{
  id: binary(),           # Unique message ID
  type: atom(),           # Message type
  from: atom(),           # Source subsystem
  to: atom(),             # Destination subsystem
  payload: term(),        # Message payload
  timestamp: DateTime.t(),# Message timestamp
  priority: atom(),       # Message priority (:low, :medium, :high, :critical)
  correlation_id: binary(), # For request-response correlation
  metadata: map()         # Additional metadata
}
```

### Message Types

#### System 1 Messages

- `:transaction_request` - Request to execute a transaction
- `:transaction_response` - Response from transaction execution
- `:status_report` - Unit status report
- `:capacity_update` - Capacity change notification
- `:resource_request` - Resource allocation request

#### System 2 Messages

- `:coordination_rule` - New coordination rule
- `:oscillation_alert` - Oscillation detected
- `:dampening_applied` - Dampening has been applied
- `:load_balance_update` - Load balancing update

#### System 3 Messages

- `:resource_allocation` - Resource allocation update
- `:optimization_result` - Optimization completed
- `:audit_report` - Audit results
- `:performance_alert` - Performance issue alert

#### System 4 Messages

- `:scan_result` - Environmental scan result
- `:forecast_update` - New forecast available
- `:adaptation_proposal` - Proposed adaptation
- `:intelligence_alert` - Intelligence-based alert

#### System 5 Messages

- `:policy_update` - Policy change
- `:decision_request` - Request for strategic decision
- `:decision_result` - Strategic decision made
- `:conflict_resolution` - Conflict resolved
- `:value_alignment_check` - Value alignment check

#### Channel Messages

- `:algedonic_alert` - Emergency alert
- `:temporal_pattern` - Temporal pattern detected
- `:variety_update` - Variety level update

### Payload Formats

#### Transaction Request
```elixir
%{
  unit: atom(),           # Target unit
  transaction: term(),    # Transaction data
  timeout: integer(),     # Timeout in milliseconds
  options: map()          # Additional options
}
```

#### Status Report
```elixir
%{
  unit: atom(),           # Reporting unit
  status: atom(),         # Status (:healthy, :degraded, :critical)
  metrics: map(),         # Current metrics
  capacity: integer(),    # Current capacity
  load: float(),          # Current load (0.0-1.0)
  issues: [map()]         # Current issues
}
```

#### Algedonic Alert
```elixir
%{
  severity: atom(),       # Alert severity
  source: atom(),         # Alert source
  message: binary(),      # Alert message
  data: map(),            # Alert data
  requires_immediate_action: boolean(),
  escalation_rules: map() # Escalation configuration
}
```

## Event Types

VSM Core emits telemetry events for monitoring and integration.

### System 1 Events

```elixir
# Unit lifecycle events
[:vsm_core, :system1, :unit, :start]
[:vsm_core, :system1, :unit, :stop]
[:vsm_core, :system1, :unit, :restart]

# Transaction events
[:vsm_core, :system1, :transaction, :start]
[:vsm_core, :system1, :transaction, :stop]
[:vsm_core, :system1, :transaction, :exception]

# Metrics events
[:vsm_core, :system1, :metrics, :updated]
```

**Event Metadata:**
- `unit` - Unit identifier
- `transaction_type` - Type of transaction
- `duration` - Operation duration
- `result` - Operation result

### System 2 Events

```elixir
# Coordination events
[:vsm_core, :system2, :coordination, :start]
[:vsm_core, :system2, :coordination, :rule_added]
[:vsm_core, :system2, :oscillation, :detected]
[:vsm_core, :system2, :dampening, :applied]

# Load balancing events
[:vsm_core, :system2, :load_balance, :updated]
[:vsm_core, :system2, :load_balance, :rebalanced]
```

### System 3 Events

```elixir
# Resource management events
[:vsm_core, :system3, :resource_allocation]
[:vsm_core, :system3, :resource_limit_exceeded]

# Optimization events
[:vsm_core, :system3, :optimization, :start]
[:vsm_core, :system3, :optimization, :complete]

# Audit events
[:vsm_core, :system3, :audit, :start]
[:vsm_core, :system3, :audit, :complete]
```

### System 4 Events

```elixir
# Scanning events
[:vsm_core, :system4, :scan, :start]
[:vsm_core, :system4, :scan, :complete]
[:vsm_core, :system4, :scan, :error]

# Forecasting events
[:vsm_core, :system4, :forecast, :generated]
[:vsm_core, :system4, :forecast, :accuracy_updated]

# Adaptation events
[:vsm_core, :system4, :adaptation, :proposed]
[:vsm_core, :system4, :adaptation, :evaluated]
```

### System 5 Events

```elixir
# Decision events
[:vsm_core, :system5, :decision, :requested]
[:vsm_core, :system5, :decision, :made]

# Policy events
[:vsm_core, :system5, :policy, :updated]
[:vsm_core, :system5, :values, :updated]

# Conflict resolution events
[:vsm_core, :system5, :conflict, :detected]
[:vsm_core, :system5, :conflict, :resolved]
```

### Channel Events

```elixir
# Temporal variety events
[:vsm_core, :temporal_variety, :data, :added]
[:vsm_core, :temporal_variety, :pattern, :detected]
[:vsm_core, :temporal_variety, :variety, :calculated]

# Algedonic events
[:vsm_core, :algedonic, :alert, :triggered]
[:vsm_core, :algedonic, :alert, :acknowledged]
[:vsm_core, :algedonic, :alert, :resolved]
```

## Error Codes

VSM Core uses structured error codes for consistent error handling.

### General Error Codes

- `:invalid_config` - Invalid configuration provided
- `:system_not_found` - VSM system not found
- `:subsystem_unavailable` - Subsystem not available
- `:timeout` - Operation timeout
- `:permission_denied` - Permission denied
- `:rate_limited` - Rate limit exceeded

### System 1 Error Codes

- `:unit_not_found` - Operational unit not found
- `:unit_at_capacity` - Unit at maximum capacity
- `:transaction_failed` - Transaction execution failed
- `:invalid_transaction` - Invalid transaction format
- `:resource_unavailable` - Required resource unavailable

### System 2 Error Codes

- `:coordination_rule_conflict` - Coordination rule conflicts with existing rules
- `:oscillation_uncontrollable` - Unable to control oscillation
- `:dampening_failed` - Dampening application failed
- `:load_balance_failed` - Load balancing failed

### System 3 Error Codes

- `:resource_allocation_failed` - Resource allocation failed
- `:optimization_failed` - Optimization process failed
- `:audit_failed` - Audit process failed
- `:resource_limit_exceeded` - Resource limit exceeded

### System 4 Error Codes

- `:scan_failed` - Environmental scan failed
- `:forecast_failed` - Forecast generation failed
- `:adaptation_generation_failed` - Adaptation proposal generation failed
- `:insufficient_data` - Insufficient data for analysis

### System 5 Error Codes

- `:decision_failed` - Decision making failed
- `:conflict_unresolvable` - Conflict cannot be resolved
- `:value_alignment_failed` - Value alignment check failed
- `:policy_conflict` - Policy conflicts detected

### Channel Error Codes

- `:temporal_variety_error` - Temporal variety processing error
- `:algedonic_alert_failed` - Algedonic alert failed
- `:pattern_detection_failed` - Pattern detection failed
- `:variety_calculation_failed` - Variety calculation failed

### Error Response Format

```elixir
%{
  error: atom(),          # Error code
  message: binary(),      # Human-readable error message
  details: map(),         # Additional error details
  suggestions: [binary()], # Suggested solutions
  correlation_id: binary(), # For tracing
  timestamp: DateTime.t() # Error timestamp
}
```

---

This API reference provides comprehensive documentation for all VSM Core functionality. For additional examples and usage patterns, see the [User Guide](USER_GUIDE.md).