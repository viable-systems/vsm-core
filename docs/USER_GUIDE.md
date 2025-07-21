# VSM Core User Guide

Complete guide to using VSM Core for implementing the Viable System Model in your applications.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Core Concepts](#core-concepts)
3. [Configuration Guide](#configuration-guide)
4. [Subsystem Usage](#subsystem-usage)
5. [Channel Management](#channel-management)
6. [Monitoring and Observability](#monitoring-and-observability)
7. [Advanced Usage Patterns](#advanced-usage-patterns)
8. [Integration Examples](#integration-examples)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)
11. [Performance Tuning](#performance-tuning)

## Getting Started

### Installation and Setup

1. **Add VSM Core to your project:**

```elixir
# In mix.exs
def deps do
  [
    {:vsm_core, "~> 0.1.0"},
    # Recommended additions
    {:telemetry, "~> 1.0"},
    {:telemetry_metrics, "~> 0.6"},
    {:jason, "~> 1.4"}  # For JSON serialization
  ]
end
```

2. **Configure your application:**

```elixir
# In config/config.exs
config :vsm_core,
  name: :my_vsm_system,
  telemetry_enabled: true,
  s1_units: 3,
  algedonic_enabled: true,
  temporal_variety_enabled: true
```

3. **Start VSM Core in your supervision tree:**

```elixir
# In lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Start the VSM system
      {VSMCore, name: :my_vsm},
      
      # Your other supervisors
      MyApp.Repo,
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### First Steps

```elixir
# Start an IEx session and try these commands:

# Check system status
VSMCore.status()

# Get information about subsystems
VSMCore.info(:system1)
VSMCore.info(:system3)

# Subscribe to events
VSMCore.subscribe(:operations_events)
VSMCore.subscribe(:algedonic_alerts)

# Send a test message
VSMCore.send_message(:system1, :system3, {:status_report, %{load: 0.75}})
```

## Core Concepts

### The Five Subsystems

#### System 1: Operations
- **Purpose**: Primary work activities
- **Characteristics**: Autonomous units, direct value creation
- **Key Functions**: Process transactions, manage resources, report status

#### System 2: Coordination
- **Purpose**: Anti-oscillatory mechanisms
- **Characteristics**: Prevents conflicts between S1 units
- **Key Functions**: Load balancing, resource arbitration, dampening oscillations

#### System 3: Control
- **Purpose**: Operational management
- **Characteristics**: Resource allocation, performance optimization
- **Key Functions**: Monitor S1 performance, allocate resources, conduct audits

#### System 4: Intelligence
- **Purpose**: Environmental adaptation
- **Characteristics**: Future-focused, scanning external environment
- **Key Functions**: Environmental scanning, forecasting, planning

#### System 5: Policy
- **Purpose**: Identity and ultimate authority
- **Characteristics**: Value-based decisions, conflict resolution
- **Key Functions**: Strategic decisions, identity maintenance, S3-S4 balance

### Communication Channels

#### Temporal Variety Channel
Manages information flow over different time scales:

```elixir
# Configure temporal patterns
VSMCore.Channels.TemporalVariety.configure(%{
  timescales: [:second, :minute, :hour, :day],
  aggregation_window: 60_000,  # 1 minute
  retention_period: :days_7
})

# Query temporal patterns
patterns = VSMCore.Channels.TemporalVariety.get_patterns(
  metric: :throughput,
  timescale: :hour,
  last: 24
)
```

#### Algedonic Channel
Emergency alert system for critical issues:

```elixir
# Send an algedonic alert
VSMCore.Channels.Algedonic.alert(%{
  severity: :critical,
  source: :system1_unit_2,
  message: "Database connection pool exhausted",
  data: %{pool_size: 10, active_connections: 10}
})

# Configure alert thresholds
VSMCore.Channels.Algedonic.configure(%{
  thresholds: %{
    critical: 0.95,
    severe: 0.80,
    warning: 0.65
  },
  cooldown_period: 300_000  # 5 minutes
})
```

## Configuration Guide

### Basic Configuration

```elixir
config :vsm_core,
  # System identification
  name: :production_vsm,
  
  # System 1 Operations
  s1_units: 5,
  s1_unit_capacity: 100,
  s1_transaction_timeout: 5_000,
  s1_restart_strategy: :permanent,
  
  # System 2 Coordination
  s2_balancing_enabled: true,
  s2_balancing_interval: 1_000,
  s2_anti_oscillation: true,
  s2_dampening_factor: 0.7,
  
  # System 3 Control
  s3_audit_enabled: true,
  s3_audit_interval: 60_000,
  s3_resource_allocation: :dynamic,
  s3_optimization_strategy: :balanced,
  
  # System 4 Intelligence
  s4_scanning_enabled: true,
  s4_scan_interval: 30_000,
  s4_forecasting_enabled: true,
  s4_forecast_horizon: :hours_24,
  
  # System 5 Policy
  s5_consensus_required: true,
  s5_decision_timeout: 10_000,
  s5_value_checking: true,
  
  # Channel Configuration
  temporal_variety_enabled: true,
  temporal_variety_timescales: [:minute, :hour, :day],
  algedonic_enabled: true,
  algedonic_threshold: 0.8,
  
  # Telemetry
  telemetry_enabled: true,
  telemetry_level: :detailed,
  
  # Performance
  pool_size: System.schedulers_online() * 2,
  max_overflow: 10
```

### Environment-Specific Configuration

#### Development
```elixir
# config/dev.exs
config :vsm_core,
  telemetry_level: :debug,
  s1_units: 2,
  s4_scan_interval: 10_000,  # More frequent scanning
  algedonic_threshold: 0.6   # Lower threshold for testing
```

#### Test
```elixir
# config/test.exs
config :vsm_core,
  telemetry_enabled: false,
  s1_units: 1,
  s4_scanning_enabled: false,
  algedonic_enabled: false
```

#### Production
```elixir
# config/prod.exs
config :vsm_core,
  telemetry_level: :info,
  s1_units: System.schedulers_online(),
  s3_audit_interval: 300_000,  # 5 minutes
  algedonic_threshold: 0.85,
  pool_size: System.schedulers_online() * 4
```

## Subsystem Usage

### System 1: Operations

#### Creating Operational Units

```elixir
# Define a custom operational unit
defmodule MyApp.OrderProcessor do
  use VSMCore.System1.Unit
  
  def handle_transaction({:process_order, order}, state) do
    # Your business logic here
    case process_order(order) do
      {:ok, result} ->
        # Report metrics
        VSMCore.System1.report_metric(:orders_processed, 1)
        {:ok, result, state}
        
      {:error, reason} ->
        # Trigger alert if needed
        if critical_error?(reason) do
          VSMCore.Channels.Algedonic.alert(%{
            severity: :severe,
            source: :order_processor,
            message: "Order processing failed: #{reason}"
          })
        end
        {:error, reason, state}
    end
  end
  
  defp process_order(order) do
    # Implementation details
  end
  
  defp critical_error?(:database_unavailable), do: true
  defp critical_error?(_), do: false
end

# Register the unit
VSMCore.System1.register_unit(MyApp.OrderProcessor, %{
  name: "OrderProcessor",
  capacity: 50,
  resources: [:database, :payment_gateway]
})
```

#### Executing Transactions

```elixir
# Execute a transaction
{:ok, result} = VSMCore.System1.execute_transaction(
  :order_processor,
  {:process_order, %{id: "12345", items: [...]}}
)

# Batch transactions
transactions = [
  {:process_order, order1},
  {:process_order, order2},
  {:process_order, order3}
]

results = VSMCore.System1.execute_batch(:order_processor, transactions)
```

#### Monitoring Unit Performance

```elixir
# Get unit metrics
metrics = VSMCore.System1.get_metrics(:order_processor)
# => %{
#   throughput: 45.2,
#   latency_avg: 123.4,
#   latency_p95: 234.5,
#   error_rate: 0.002,
#   capacity_utilization: 0.85
# }

# Get all units status
all_units = VSMCore.System1.list_units()
```

### System 2: Coordination

#### Anti-Oscillation Control

```elixir
# Configure coordination rules
VSMCore.System2.add_coordination_rule(%{
  name: "DatabaseAccess",
  type: :mutex,
  resource: :primary_database,
  units: [:order_processor, :inventory_manager],
  max_concurrent: 5
})

# Detect oscillations
oscillations = VSMCore.System2.detect_oscillations()

# Apply dampening
VSMCore.System2.apply_dampening(
  type: :exponential,
  factor: 0.8,
  duration: 30_000
)
```

#### Load Balancing

```elixir
# Configure load balancing
VSMCore.System2.configure_balancing(%{
  strategy: :least_connections,
  health_check_interval: 5_000,
  fallback_strategy: :round_robin
})

# Manual rebalancing
VSMCore.System2.rebalance_load()
```

### System 3: Control

#### Resource Management

```elixir
# Allocate resources
allocation = %{
  order_processor: %{cpu: 0.4, memory: 0.3, connections: 20},
  inventory_manager: %{cpu: 0.3, memory: 0.2, connections: 10},
  notification_service: %{cpu: 0.2, memory: 0.1, connections: 5}
}

VSMCore.System3.allocate_resources(allocation)

# Monitor resource usage
usage = VSMCore.System3.get_resource_usage()

# Set resource limits
VSMCore.System3.set_limits(%{
  cpu_limit: 0.8,
  memory_limit: 0.9,
  connection_limit: 100
})
```

#### Performance Optimization

```elixir
# Run optimization
optimization_result = VSMCore.System3.optimize(%{
  strategy: :balanced,
  objectives: [:throughput, :latency, :resource_efficiency],
  constraints: [:memory_limit, :cpu_limit]
})

# Schedule periodic optimization
VSMCore.System3.schedule_optimization(%{
  interval: 300_000,  # 5 minutes
  strategy: :adaptive
})
```

#### System 3* (Audit)

```elixir
# Configure audit
VSMCore.System3.configure_audit(%{
  enabled: true,
  interval: 60_000,
  deep_audit_interval: 300_000,
  audit_scope: [:performance, :compliance, :security]
})

# Manual audit
audit_report = VSMCore.System3.audit()

# Get audit history
history = VSMCore.System3.get_audit_history(last: :hours_24)
```

### System 4: Intelligence

#### Environmental Scanning

```elixir
# Configure scanners
VSMCore.System4.configure_scanning(%{
  scanners: [
    %{
      name: :market_trends,
      source: :external_api,
      interval: 3600_000,  # 1 hour
      endpoint: "https://api.market-data.com/trends"
    },
    %{
      name: :competitor_analysis,
      source: :web_scraper,
      interval: 86_400_000,  # 24 hours
      targets: ["competitor1.com", "competitor2.com"]
    },
    %{
      name: :internal_metrics,
      source: :telemetry,
      interval: 60_000  # 1 minute
    }
  ]
})

# Get scan results
trends = VSMCore.System4.get_scan_results(:market_trends)
```

#### Forecasting

```elixir
# Generate forecasts
forecast = VSMCore.System4.forecast(%{
  metric: :order_volume,
  horizon: :days_7,
  models: [:arima, :linear_regression, :neural_network],
  confidence_level: 0.95
})

# Historical forecast accuracy
accuracy = VSMCore.System4.get_forecast_accuracy(
  metric: :order_volume,
  period: :last_month
)
```

#### Adaptation Proposals

```elixir
# Generate adaptation proposals
proposals = VSMCore.System4.propose_adaptations(%{
  context: :market_downturn,
  constraints: [:budget_limit, :staff_retention],
  objectives: [:cost_reduction, :efficiency_improvement]
})

# Evaluate proposals
evaluation = VSMCore.System4.evaluate_proposals(proposals, %{
  criteria: [:feasibility, :impact, :risk],
  weights: %{feasibility: 0.3, impact: 0.5, risk: 0.2}
})
```

### System 5: Policy

#### Value Management

```elixir
# Set organizational values
VSMCore.System5.set_values(%{
  core_values: [
    %{name: :customer_focus, weight: 0.4, description: "Customer satisfaction is paramount"},
    %{name: :innovation, weight: 0.3, description: "Continuous improvement and innovation"},
    %{name: :sustainability, weight: 0.3, description: "Long-term environmental responsibility"}
  ],
  mission: "Deliver exceptional value to customers while maintaining sustainability",
  vision: "Global leader in sustainable technology solutions"
})

# Check value alignment
alignment = VSMCore.System5.check_alignment(
  decision: :new_product_launch,
  options: [:option_a, :option_b, :option_c]
)
```

#### Strategic Decision Making

```elixir
# Strategic decision process
decision_context = %{
  issue: :market_expansion,
  options: [
    %{name: :asia_expansion, cost: 5_000_000, timeline: :months_18, risk: :medium},
    %{name: :europe_expansion, cost: 3_000_000, timeline: :months_12, risk: :low},
    %{name: :digital_first, cost: 1_000_000, timeline: :months_6, risk: :high}
  ],
  constraints: [:budget_limit, :timeline_pressure, :risk_tolerance],
  stakeholders: [:board, :investors, :employees, :customers]
}

decision = VSMCore.System5.make_decision(decision_context)
```

#### Conflict Resolution

```elixir
# S3-S4 conflict resolution
conflict = %{
  s3_position: %{
    focus: :operational_efficiency,
    proposal: :cost_reduction,
    rationale: "Improve short-term profitability"
  },
  s4_position: %{
    focus: :future_adaptation,
    proposal: :innovation_investment,
    rationale: "Prepare for market changes"
  }
}

resolution = VSMCore.System5.resolve_conflict(conflict)
```

## Channel Management

### Temporal Variety Channel

The Temporal Variety Channel manages information flow across different time scales, ensuring appropriate aggregation and filtering of data.

#### Configuration

```elixir
# Configure temporal analysis
VSMCore.Channels.TemporalVariety.configure(%{
  # Time scales to analyze
  timescales: [:second, :minute, :hour, :day, :week],
  
  # Aggregation methods
  aggregation_methods: [:mean, :median, :max, :min, :std_dev, :percentile_95],
  
  # Pattern detection
  pattern_detection: true,
  pattern_types: [:trend, :cycle, :seasonal, :anomaly],
  
  # Data retention
  retention_policy: %{
    raw_data: :hours_24,
    minute_aggregates: :days_7,
    hour_aggregates: :weeks_4,
    day_aggregates: :months_12
  },
  
  # Variety calculations
  variety_calculation: %{
    method: :shannon_entropy,
    window_size: 100,
    update_interval: 60_000
  }
})
```

#### Usage Examples

```elixir
# Add temporal data
VSMCore.Channels.TemporalVariety.add_data(
  metric: :order_volume,
  value: 125,
  timestamp: DateTime.utc_now(),
  metadata: %{source: :system1, unit: :order_processor_1}
)

# Query aggregated data
aggregates = VSMCore.Channels.TemporalVariety.get_aggregates(
  metric: :order_volume,
  timescale: :hour,
  from: DateTime.add(DateTime.utc_now(), -24, :hour),
  to: DateTime.utc_now()
)

# Detect patterns
patterns = VSMCore.Channels.TemporalVariety.detect_patterns(
  metric: :order_volume,
  pattern_types: [:trend, :seasonal],
  lookback: :days_30
)

# Calculate variety
variety = VSMCore.Channels.TemporalVariety.calculate_variety(
  metric: :order_volume,
  window: :last_hour
)

# Visualize data
chart_data = VSMCore.Channels.TemporalVariety.prepare_visualization(
  metric: :order_volume,
  timescale: :hour,
  period: :last_24_hours,
  chart_type: :line
)
```

### Algedonic Channel

The Algedonic Channel provides an emergency communication path that bypasses normal hierarchical channels for critical alerts.

#### Alert Types

```elixir
# Critical system failure
VSMCore.Channels.Algedonic.alert(%{
  severity: :critical,
  type: :system_failure,
  source: :system1_unit_3,
  message: "Unit completely unresponsive",
  data: %{
    last_heartbeat: DateTime.add(DateTime.utc_now(), -300, :second),
    error_count: 150,
    recovery_attempts: 3
  },
  requires_immediate_action: true
})

# Resource exhaustion warning
VSMCore.Channels.Algedonic.alert(%{
  severity: :severe,
  type: :resource_exhaustion,
  source: :system3,
  message: "Memory usage approaching limit",
  data: %{
    current_usage: 0.89,
    threshold: 0.90,
    trend: :increasing
  }
})

# Security incident
VSMCore.Channels.Algedonic.alert(%{
  severity: :critical,
  type: :security_incident,
  source: :system4_scanner,
  message: "Unusual access pattern detected",
  data: %{
    suspicious_ips: ["192.168.1.100", "10.0.0.50"],
    access_attempts: 500,
    timeframe: :last_5_minutes
  },
  escalation_required: true
})
```

#### Alert Routing and Response

```elixir
# Configure alert routing
VSMCore.Channels.Algedonic.configure_routing(%{
  critical: %{
    targets: [:system5, :ops_team, :management],
    immediate: true,
    acknowledge_required: true,
    escalation_timeout: 300_000  # 5 minutes
  },
  severe: %{
    targets: [:system3, :system5, :ops_team],
    immediate: false,
    acknowledge_required: true,
    escalation_timeout: 900_000  # 15 minutes
  },
  warning: %{
    targets: [:system3],
    immediate: false,
    acknowledge_required: false
  }
})

# Handle alert acknowledgment
VSMCore.Channels.Algedonic.acknowledge_alert(alert_id, %{
  acknowledged_by: "ops_team_lead",
  action_taken: "Initiated emergency procedure",
  estimated_resolution: :minutes_30
})

# Query alert history
alerts = VSMCore.Channels.Algedonic.get_alerts(%{
  severity: [:critical, :severe],
  from: DateTime.add(DateTime.utc_now(), -24, :hour),
  status: :all
})
```

## Monitoring and Observability

### Telemetry Integration

VSM Core provides comprehensive telemetry integration for monitoring system behavior.

#### Built-in Events

```elixir
# System 1 events
[:vsm_core, :system1, :unit, :start]
[:vsm_core, :system1, :transaction, :start]
[:vsm_core, :system1, :transaction, :stop]
[:vsm_core, :system1, :transaction, :exception]

# System 2 events
[:vsm_core, :system2, :coordination, :start]
[:vsm_core, :system2, :oscillation, :detected]
[:vsm_core, :system2, :dampening, :applied]

# System 3 events
[:vsm_core, :system3, :resource_allocation]
[:vsm_core, :system3, :optimization, :start]
[:vsm_core, :system3, :audit, :completed]

# System 4 events
[:vsm_core, :system4, :scan, :completed]
[:vsm_core, :system4, :forecast, :generated]
[:vsm_core, :system4, :adaptation, :proposed]

# System 5 events
[:vsm_core, :system5, :decision, :made]
[:vsm_core, :system5, :conflict, :resolved]

# Channel events
[:vsm_core, :temporal_variety, :pattern, :detected]
[:vsm_core, :algedonic, :alert, :triggered]
```

#### Custom Telemetry Handlers

```elixir
defmodule MyApp.TelemetryHandler do
  require Logger
  
  def handle_event([:vsm_core, :system1, :transaction, :stop], measurements, metadata, _config) do
    Logger.info("Transaction completed", 
      duration: measurements.duration,
      unit: metadata.unit,
      transaction_type: metadata.transaction_type
    )
    
    # Send to external monitoring
    MyApp.Metrics.increment("vsm.transactions.completed", %{
      unit: metadata.unit,
      type: metadata.transaction_type
    })
    
    MyApp.Metrics.histogram("vsm.transaction.duration", measurements.duration, %{
      unit: metadata.unit
    })
  end
  
  def handle_event([:vsm_core, :algedonic, :alert, :triggered], _measurements, metadata, _config) do
    Logger.error("Algedonic alert triggered",
      severity: metadata.severity,
      source: metadata.source,
      message: metadata.message
    )
    
    # Trigger external alerting
    MyApp.AlertManager.send_alert(%{
      title: "VSM Algedonic Alert",
      message: metadata.message,
      severity: metadata.severity,
      source: metadata.source,
      timestamp: DateTime.utc_now()
    })
  end
  
  def handle_event([:vsm_core, :system4, :adaptation, :proposed], _measurements, metadata, _config) do
    Logger.info("System 4 proposed adaptation",
      proposal: metadata.proposal,
      confidence: metadata.confidence,
      estimated_impact: metadata.estimated_impact
    )
    
    # Store for decision making
    MyApp.DecisionSupport.store_proposal(metadata.proposal)
  end
end

# Attach handlers
:telemetry.attach_many(
  "vsm-core-handler",
  [
    [:vsm_core, :system1, :transaction, :stop],
    [:vsm_core, :algedonic, :alert, :triggered],
    [:vsm_core, :system4, :adaptation, :proposed]
  ],
  &MyApp.TelemetryHandler.handle_event/4,
  nil
)
```

### Metrics Export

#### Prometheus Integration

```elixir
# Configure Prometheus metrics
defmodule MyApp.PrometheusMetrics do
  use Prometheus.Metric
  
  # Counter metrics
  @counter [
    name: :vsm_transactions_total,
    help: "Total number of VSM transactions",
    labels: [:system, :unit, :type, :status]
  ]
  
  @counter [
    name: :vsm_alerts_total,
    help: "Total number of algedonic alerts",
    labels: [:severity, :source]
  ]
  
  # Histogram metrics
  @histogram [
    name: :vsm_transaction_duration_seconds,
    help: "Transaction duration in seconds",
    labels: [:system, :unit, :type],
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0]
  ]
  
  # Gauge metrics
  @gauge [
    name: :vsm_system_variety,
    help: "Current system variety measure",
    labels: [:system, :metric]
  ]
  
  def setup do
    Counter.declare(@counter)
    Histogram.declare(@histogram)
    Gauge.declare(@gauge)
  end
end

# Set up Prometheus endpoint
defmodule MyAppWeb.MetricsPlug do
  use Plug.Router
  
  plug :match
  plug :dispatch
  
  get "/metrics" do
    metrics = Prometheus.Format.Text.format()
    
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end
  
  match _ do
    send_resp(conn, 404, "Not found")
  end
end
```

#### Grafana Dashboard

Example Grafana dashboard configuration:

```json
{
  "dashboard": {
    "title": "VSM Core Monitoring",
    "panels": [
      {
        "title": "Transaction Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(vsm_transactions_total[5m])",
            "legendFormat": "{{system}} - {{unit}}"
          }
        ]
      },
      {
        "title": "System Variety",
        "type": "graph",
        "targets": [
          {
            "expr": "vsm_system_variety",
            "legendFormat": "{{system}} - {{metric}}"
          }
        ]
      },
      {
        "title": "Algedonic Alerts",
        "type": "table",
        "targets": [
          {
            "expr": "increase(vsm_alerts_total[1h])",
            "format": "table"
          }
        ]
      }
    ]
  }
}
```

## Advanced Usage Patterns

### Custom Subsystem Implementations

You can extend VSM Core with custom subsystem implementations:

```elixir
defmodule MyApp.CustomSystem1Unit do
  use VSMCore.System1.Unit
  
  # Custom initialization
  def init(opts) do
    state = %{
      custom_config: opts[:custom_config],
      metrics: %{},
      cache: :ets.new(:unit_cache, [:set, :private])
    }
    {:ok, state}
  end
  
  # Handle custom transaction types
  def handle_transaction({:custom_operation, params}, state) do
    # Custom business logic
    result = perform_custom_operation(params, state)
    
    # Update metrics
    new_state = update_metrics(state, :custom_operation, result)
    
    {:ok, result, new_state}
  end
  
  # Implement required callbacks
  def handle_status_request(state) do
    status = %{
      health: :healthy,
      load: calculate_load(state),
      custom_metrics: state.metrics
    }
    {:ok, status, state}
  end
  
  def handle_resource_allocation(allocation, state) do
    # Apply resource allocation
    {:ok, state}
  end
  
  # Custom functions
  defp perform_custom_operation(params, state) do
    # Implementation
  end
  
  defp update_metrics(state, operation, result) do
    # Update internal metrics
    %{state | metrics: updated_metrics}
  end
  
  defp calculate_load(state) do
    # Calculate current load
    0.75
  end
end
```

### Event-Driven Architecture

Integrate VSM Core with event-driven patterns:

```elixir
defmodule MyApp.EventHandler do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Subscribe to VSM events
    VSMCore.subscribe(:all_events)
    {:ok, %{}}
  end
  
  def handle_info({:vsm_event, event_type, data}, state) do
    handle_vsm_event(event_type, data)
    {:noreply, state}
  end
  
  defp handle_vsm_event(:algedonic_alert, %{severity: :critical} = alert) do
    # Trigger emergency procedures
    MyApp.EmergencyManager.activate_procedures(alert)
    
    # Notify stakeholders
    MyApp.NotificationService.send_emergency_alert(alert)
  end
  
  defp handle_vsm_event(:s4_adaptation_proposal, proposal) do
    # Store for decision review
    MyApp.DecisionQueue.add_proposal(proposal)
    
    # If high confidence, auto-approve certain types
    if proposal.confidence > 0.95 and auto_approvable?(proposal) do
      VSMCore.System5.approve_proposal(proposal.id)
    end
  end
  
  defp handle_vsm_event(:resource_shortage, data) do
    # Trigger auto-scaling
    MyApp.AutoScaler.scale_up(data.resource_type, data.shortage_amount)
  end
  
  defp auto_approvable?(%{type: :routine_optimization}), do: true
  defp auto_approvable?(_), do: false
end
```

### Multi-VSM Coordination

Coordinate multiple VSM instances:

```elixir
defmodule MyApp.VSMCluster do
  use GenServer
  
  @vsm_instances [
    :vsm_region_us,
    :vsm_region_eu,
    :vsm_region_asia
  ]
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Start coordination between VSM instances
    state = %{
      instances: start_vsm_instances(),
      coordination_state: %{}
    }
    
    schedule_coordination_check()
    {:ok, state}
  end
  
  def handle_info(:coordination_check, state) do
    # Check coordination between instances
    coordination_result = check_coordination(state.instances)
    
    # Apply coordination adjustments if needed
    new_state = apply_coordination_adjustments(state, coordination_result)
    
    schedule_coordination_check()
    {:noreply, new_state}
  end
  
  defp start_vsm_instances do
    Enum.map(@vsm_instances, fn instance_name ->
      {:ok, pid} = VSMCore.start_link(name: instance_name)
      {instance_name, pid}
    end)
    |> Map.new()
  end
  
  defp check_coordination(instances) do
    # Analyze coordination state across instances
    # Check for conflicting decisions, resource competition, etc.
  end
  
  defp apply_coordination_adjustments(state, coordination_result) do
    # Apply necessary adjustments to maintain coordination
    state
  end
  
  defp schedule_coordination_check do
    Process.send_after(self(), :coordination_check, 30_000)  # 30 seconds
  end
end
```

## Integration Examples

### Phoenix Web Application

Integrate VSM Core with a Phoenix application:

```elixir
# In your Phoenix endpoint
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app
  
  # VSM monitoring endpoint
  plug MyAppWeb.VSMMonitoringPlug
  
  # Other plugs...
end

# Monitoring plug
defmodule MyAppWeb.VSMMonitoringPlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(%{request_path: "/vsm/status"} = conn, _opts) do
    status = VSMCore.status()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(status))
    |> halt()
  end
  
  def call(%{request_path: "/vsm/metrics"} = conn, _opts) do
    metrics = VSMCore.get_all_metrics()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(metrics))
    |> halt()
  end
  
  def call(conn, _opts), do: conn
end

# LiveView for real-time monitoring
defmodule MyAppWeb.VSMDashboardLive do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    if connected?(socket) do
      VSMCore.subscribe(:all_events)
      :timer.send_interval(1000, self(), :update_metrics)
    end
    
    {:ok, assign(socket, :metrics, VSMCore.get_all_metrics())}
  end
  
  def handle_info(:update_metrics, socket) do
    {:noreply, assign(socket, :metrics, VSMCore.get_all_metrics())}
  end
  
  def handle_info({:vsm_event, :algedonic_alert, alert}, socket) do
    # Show alert in UI
    {:noreply, put_flash(socket, :error, "Algedonic Alert: #{alert.message}")}
  end
  
  def render(assigns) do
    ~H"""
    <div class="vsm-dashboard">
      <h1>VSM System Dashboard</h1>
      
      <div class="metrics-grid">
        <%= for {system, metrics} <- @metrics do %>
          <div class="system-card">
            <h3>System <%= system %></h3>
            <div class="metrics">
              <%= for {metric, value} <- metrics do %>
                <div class="metric">
                  <span class="metric-name"><%= metric %></span>
                  <span class="metric-value"><%= value %></span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
```

### Database Integration

Integrate with database operations:

```elixir
defmodule MyApp.DatabaseOperationalUnit do
  use VSMCore.System1.Unit
  
  alias MyApp.Repo
  
  def handle_transaction({:create_record, schema, params}, state) do
    case Repo.insert(struct(schema, params)) do
      {:ok, record} ->
        # Report success metrics
        VSMCore.System1.report_metric(:db_inserts_success, 1)
        {:ok, record, state}
        
      {:error, changeset} ->
        # Report error metrics
        VSMCore.System1.report_metric(:db_inserts_error, 1)
        
        # Check if this indicates a system problem
        if system_error?(changeset) do
          VSMCore.Channels.Algedonic.alert(%{
            severity: :severe,
            source: :database_unit,
            message: "Database operation failure pattern detected",
            data: %{error: changeset, pattern: :connection_issues}
          })
        end
        
        {:error, changeset, state}
    end
  end
  
  def handle_transaction({:query, query_module, params}, state) do
    start_time = System.monotonic_time()
    
    result = query_module.execute(params)
    
    duration = System.monotonic_time() - start_time
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)
    
    # Report performance metrics
    VSMCore.System1.report_metric(:db_query_duration, duration_ms)
    
    # Check for performance degradation
    if duration_ms > 5000 do  # 5 seconds
      VSMCore.Channels.Algedonic.alert(%{
        severity: :warning,
        source: :database_unit,
        message: "Slow query detected",
        data: %{query: query_module, duration: duration_ms, params: params}
      })
    end
    
    {:ok, result, state}
  end
  
  defp system_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {message, _opts}} ->
      String.contains?(message, ["connection", "timeout", "unavailable"])
    end)
  end
end
```

### External API Integration

Integrate with external services:

```elixir
defmodule MyApp.ExternalAPIUnit do
  use VSMCore.System1.Unit
  
  def handle_transaction({:api_call, service, endpoint, params}, state) do
    start_time = System.monotonic_time()
    
    case make_api_call(service, endpoint, params) do
      {:ok, response} ->
        duration = calculate_duration(start_time)
        
        # Update service health metrics
        update_service_health(service, :success, duration)
        
        {:ok, response, state}
        
      {:error, :timeout} ->
        duration = calculate_duration(start_time)
        
        # Report timeout
        update_service_health(service, :timeout, duration)
        
        # Check if this indicates service degradation
        if service_degraded?(service) do
          VSMCore.Channels.Algedonic.alert(%{
            severity: :severe,
            source: :external_api_unit,
            message: "External service degradation detected",
            data: %{service: service, issue: :timeout_pattern}
          })
        end
        
        {:error, :timeout, state}
        
      {:error, reason} ->
        duration = calculate_duration(start_time)
        update_service_health(service, :error, duration)
        
        {:error, reason, state}
    end
  end
  
  defp make_api_call(service, endpoint, params) do
    # Implementation of API call with retries, circuit breaker, etc.
  end
  
  defp calculate_duration(start_time) do
    duration = System.monotonic_time() - start_time
    System.convert_time_unit(duration, :native, :millisecond)
  end
  
  defp update_service_health(service, status, duration) do
    VSMCore.System1.report_metric("#{service}_api_#{status}", 1)
    VSMCore.System1.report_metric("#{service}_api_duration", duration)
  end
  
  defp service_degraded?(service) do
    # Check recent metrics to determine if service is degraded
    recent_timeouts = VSMCore.System1.get_metric("#{service}_api_timeout", :last_5_minutes)
    total_calls = VSMCore.System1.get_metric("#{service}_api_total", :last_5_minutes)
    
    timeout_rate = recent_timeouts / max(total_calls, 1)
    timeout_rate > 0.1  # 10% timeout rate
  end
end
```

## Best Practices

### 1. Subsystem Design

#### Operations (System 1)
- **Keep units focused**: Each operational unit should have a single, well-defined responsibility
- **Design for autonomy**: Units should be able to operate independently when possible
- **Implement proper error handling**: Include circuit breakers and graceful degradation
- **Monitor performance**: Track throughput, latency, and error rates

```elixir
# Good: Focused unit
defmodule OrderProcessingUnit do
  use VSMCore.System1.Unit
  # Handles only order processing
end

# Bad: Overly broad unit
defmodule EverythingUnit do
  use VSMCore.System1.Unit
  # Handles orders, inventory, shipping, billing...
end
```

#### Coordination (System 2)
- **Identify oscillation sources**: Look for resource contention, feedback loops
- **Implement dampening gradually**: Start with light dampening and adjust
- **Monitor coordination effectiveness**: Track oscillation frequency and amplitude

#### Control (System 3)
- **Set clear resource limits**: Define and enforce resource boundaries
- **Implement regular auditing**: Use System 3* to verify operational integrity
- **Optimize based on metrics**: Use data-driven resource allocation

#### Intelligence (System 4)
- **Scan relevant environments**: Focus on factors that actually impact your system
- **Validate forecasts**: Track forecast accuracy and adjust models
- **Propose actionable adaptations**: Ensure proposals are realistic and implementable

#### Policy (System 5)
- **Define clear values**: Make organizational values explicit and measurable
- **Establish decision criteria**: Create clear frameworks for strategic decisions
- **Resolve conflicts systematically**: Have processes for S3-S4 conflicts

### 2. Channel Configuration

#### Temporal Variety
- **Choose appropriate timescales**: Match timescales to your business needs
- **Configure retention policies**: Balance storage costs with analytical needs
- **Monitor variety levels**: Track requisite variety and adjust as needed

#### Algedonic
- **Set meaningful thresholds**: Thresholds should reflect real business impact
- **Implement proper routing**: Ensure alerts reach the right people
- **Avoid alert fatigue**: Use cooldown periods and aggregation

### 3. Performance Optimization

#### Resource Management
```elixir
# Configure appropriate pool sizes
config :vsm_core,
  pool_size: System.schedulers_online() * 2,
  max_overflow: 5,
  
  # Set reasonable timeouts
  s1_transaction_timeout: 5_000,
  s3_optimization_timeout: 30_000,
  s5_decision_timeout: 60_000
```

#### Telemetry
```elixir
# Selective telemetry to avoid overhead
config :vsm_core,
  telemetry_level: :info,  # Not :debug in production
  telemetry_sampling_rate: 0.1  # Sample 10% of events
```

#### Memory Management
```elixir
# Configure appropriate retention
config :vsm_core,
  temporal_variety_retention: :days_7,  # Not indefinite
  algedonic_history_retention: :hours_24,
  metrics_retention: :hours_6
```

### 4. Error Handling

#### Graceful Degradation
```elixir
defmodule MyUnit do
  use VSMCore.System1.Unit
  
  def handle_transaction(request, state) do
    case primary_processor(request) do
      {:ok, result} -> {:ok, result, state}
      {:error, _reason} ->
        # Fall back to secondary processor
        case secondary_processor(request) do
          {:ok, result} -> {:ok, result, state}
          {:error, reason} -> {:error, reason, state}
        end
    end
  end
end
```

#### Circuit Breaker Pattern
```elixir
defmodule MyAPIUnit do
  use VSMCore.System1.Unit
  
  def handle_transaction({:api_call, params}, state) do
    if circuit_breaker_open?(state) do
      {:error, :service_unavailable, state}
    else
      case make_api_call(params) do
        {:ok, result} -> 
          {:ok, result, reset_circuit_breaker(state)}
        {:error, reason} -> 
          {:error, reason, increment_failure_count(state)}
      end
    end
  end
end
```

### 5. Testing

#### Unit Testing
```elixir
defmodule MyUnitTest do
  use ExUnit.Case
  
  test "handles successful transaction" do
    {:ok, pid} = MyUnit.start_link([])
    
    assert {:ok, result, _state} = 
      MyUnit.handle_transaction({:process, %{data: "test"}}, %{})
    
    assert result.status == :success
  end
  
  test "handles error conditions gracefully" do
    {:ok, pid} = MyUnit.start_link([])
    
    assert {:error, :invalid_data, _state} = 
      MyUnit.handle_transaction({:process, %{invalid: true}}, %{})
  end
end
```

#### Integration Testing
```elixir
defmodule VSMIntegrationTest do
  use ExUnit.Case
  
  setup do
    {:ok, vsm_pid} = VSMCore.start_link(name: :test_vsm)
    
    on_exit(fn ->
      if Process.alive?(vsm_pid) do
        GenServer.stop(vsm_pid)
      end
    end)
    
    %{vsm: vsm_pid}
  end
  
  test "end-to-end transaction processing", %{vsm: vsm} do
    # Send transaction to System 1
    result = VSMCore.System1.execute_transaction(
      :test_unit, 
      {:process_order, %{id: "123"}}
    )
    
    assert {:ok, _} = result
    
    # Verify metrics were updated
    metrics = VSMCore.System1.get_metrics(:test_unit)
    assert metrics.transactions_processed > 0
  end
end
```

## Troubleshooting

### Common Issues

#### 1. High Memory Usage

**Symptoms:**
- Memory usage continuously increasing
- Algedonic alerts about memory pressure
- System slowdown

**Diagnosis:**
```elixir
# Check temporal variety retention
retention_stats = VSMCore.Channels.TemporalVariety.get_retention_stats()

# Check algedonic alert history size
alert_count = VSMCore.Channels.Algedonic.get_alert_count(:all_time)

# Check metrics storage
metrics_size = VSMCore.System1.get_metrics_storage_size()
```

**Solutions:**
- Reduce retention periods
- Implement data aggregation
- Enable periodic cleanup

```elixir
# Configure shorter retention
config :vsm_core,
  temporal_variety_retention: :hours_6,
  algedonic_history_retention: :hours_6,
  metrics_retention: :hours_2

# Enable automatic cleanup
VSMCore.schedule_cleanup(%{
  interval: :timer.hours(1),
  aggressive: true
})
```

#### 2. Algedonic Alert Storms

**Symptoms:**
- Too many algedonic alerts
- Alert fatigue
- Important alerts being missed

**Diagnosis:**
```elixir
# Check alert frequency
frequency = VSMCore.Channels.Algedonic.get_alert_frequency(:last_hour)

# Check alert patterns
patterns = VSMCore.Channels.Algedonic.analyze_alert_patterns()
```

**Solutions:**
```elixir
# Configure rate limiting
VSMCore.Channels.Algedonic.configure(%{
  rate_limit: %{
    max_alerts_per_minute: 5,
    cooldown_period: 300_000  # 5 minutes
  },
  aggregation: %{
    enabled: true,
    window: 60_000,  # 1 minute
    max_aggregated: 10
  }
})
```

#### 3. System 3-4 Conflicts

**Symptoms:**
- Frequent conflicts between operational control and intelligence
- Decision paralysis
- Oscillating resource allocation

**Diagnosis:**
```elixir
# Check conflict history
conflicts = VSMCore.System5.get_conflict_history(:last_week)

# Analyze decision patterns
patterns = VSMCore.System5.analyze_decision_patterns()
```

**Solutions:**
```elixir
# Clarify value hierarchy
VSMCore.System5.set_values(%{
  core_values: [
    %{name: :stability, weight: 0.6},
    %{name: :innovation, weight: 0.4}
  ],
  conflict_resolution_strategy: :weighted_consensus
})

# Set decision timeouts
VSMCore.System5.configure(%{
  decision_timeout: 30_000,  # 30 seconds
  fallback_to_s3: true  # Default to operational control
})
```

#### 4. Performance Degradation

**Symptoms:**
- Increasing transaction latency
- Decreasing throughput
- Resource utilization issues

**Diagnosis:**
```elixir
# Check system performance trends
trends = VSMCore.get_performance_trends(:last_24_hours)

# Analyze resource utilization
utilization = VSMCore.System3.get_resource_utilization_history()

# Check for bottlenecks
bottlenecks = VSMCore.analyze_bottlenecks()
```

**Solutions:**
```elixir
# Enable auto-optimization
VSMCore.System3.enable_auto_optimization(%{
  strategy: :adaptive,
  optimization_interval: 300_000,  # 5 minutes
  aggressive_optimization: false
})

# Scale resources
VSMCore.System3.scale_resources(%{
  cpu: 1.2,  # 20% increase
  memory: 1.1,  # 10% increase
  connections: 1.5  # 50% increase
})
```

### Debug Mode

Enable debug mode for detailed troubleshooting:

```elixir
# In config/dev.exs or runtime
config :vsm_core,
  debug_mode: true,
  telemetry_level: :debug,
  log_all_transactions: true,
  log_coordination_decisions: true,
  trace_variety_calculations: true
```

### Health Checks

Implement comprehensive health checks:

```elixir
defmodule MyApp.VSMHealthCheck do
  def check_system_health do
    %{
      overall_status: overall_status(),
      subsystems: check_all_subsystems(),
      channels: check_channels(),
      resources: check_resources(),
      alerts: check_recent_alerts()
    }
  end
  
  defp overall_status do
    case VSMCore.status() do
      %{status: :healthy} -> :healthy
      %{status: :degraded} -> :degraded
      %{status: :critical} -> :critical
      _ -> :unknown
    end
  end
  
  defp check_all_subsystems do
    for system <- 1..5, into: %{} do
      status = VSMCore.system_status(system)
      {"system#{system}", status}
    end
  end
  
  defp check_channels do
    %{
      temporal_variety: VSMCore.Channels.TemporalVariety.status(),
      algedonic: VSMCore.Channels.Algedonic.status()
    }
  end
  
  defp check_resources do
    VSMCore.System3.get_resource_status()
  end
  
  defp check_recent_alerts do
    VSMCore.Channels.Algedonic.get_alerts(%{
      last: :minutes_5,
      severity: [:critical, :severe]
    })
  end
end
```

## Performance Tuning

### Resource Optimization

#### Pool Sizing
```elixir
# Calculate optimal pool size based on your workload
optimal_pool_size = case System.schedulers_online() do
  cpu_count when cpu_count <= 4 -> cpu_count * 2
  cpu_count when cpu_count <= 8 -> cpu_count * 1.5
  cpu_count -> cpu_count + 4
end

config :vsm_core,
  pool_size: optimal_pool_size,
  max_overflow: div(optimal_pool_size, 2)
```

#### Memory Management
```elixir
# Configure memory-efficient settings
config :vsm_core,
  # Reduce retention for high-frequency data
  temporal_variety_retention: %{
    raw_data: :minutes_30,
    aggregates: %{
      minute: :hours_2,
      hour: :days_1,
      day: :weeks_2
    }
  },
  
  # Limit metrics storage
  metrics_max_entries: 10_000,
  metrics_cleanup_interval: :timer.minutes(15),
  
  # Configure efficient data structures
  use_compressed_storage: true,
  ets_compressed: true
```

#### Network Optimization
```elixir
# Optimize for distributed setups
config :vsm_core,
  # Batch updates to reduce network overhead
  batch_updates: true,
  batch_size: 100,
  batch_timeout: 1_000,
  
  # Compress inter-node communication
  compress_messages: true,
  compression_level: 6
```

### Monitoring Performance

#### Key Metrics to Track

1. **Transaction Metrics**
   - Throughput (transactions per second)
   - Latency (average, P95, P99)
   - Error rate

2. **Resource Metrics**
   - CPU utilization
   - Memory usage
   - Connection pool usage

3. **System Metrics**
   - Variety levels
   - Oscillation frequency
   - Alert frequency

4. **Channel Metrics**
   - Message queue sizes
   - Processing delays
   - Pattern detection accuracy

#### Performance Benchmarking

```elixir
defmodule VSMCore.Benchmark do
  def run_performance_test(duration \\ :timer.minutes(5)) do
    start_time = System.monotonic_time()
    end_time = start_time + System.convert_time_unit(duration, :millisecond, :native)
    
    # Start load generation
    load_generators = start_load_generators()
    
    # Collect metrics during test
    metrics = collect_metrics_during_test(end_time)
    
    # Stop load generation
    stop_load_generators(load_generators)
    
    # Analyze results
    analyze_performance_results(metrics)
  end
  
  defp start_load_generators do
    for i <- 1..System.schedulers_online() do
      spawn_link(fn -> generate_load() end)
    end
  end
  
  defp generate_load do
    # Generate realistic transaction load
    transaction = generate_test_transaction()
    VSMCore.System1.execute_transaction(:test_unit, transaction)
    
    # Random delay to simulate realistic load
    :timer.sleep(:rand.uniform(100))
    
    generate_load()
  end
  
  defp collect_metrics_during_test(end_time) do
    if System.monotonic_time() < end_time do
      metrics = VSMCore.get_all_metrics()
      :timer.sleep(1000)  # Collect every second
      [metrics | collect_metrics_during_test(end_time)]
    else
      []
    end
  end
  
  defp analyze_performance_results(metrics_history) do
    # Calculate performance statistics
    %{
      average_throughput: calculate_average_throughput(metrics_history),
      latency_percentiles: calculate_latency_percentiles(metrics_history),
      resource_utilization: calculate_resource_utilization(metrics_history),
      bottlenecks: identify_bottlenecks(metrics_history)
    }
  end
end
```

This comprehensive user guide should help you effectively use VSM Core in your applications. Remember to start with basic configurations and gradually add complexity as you understand how the system behaves with your specific workload.