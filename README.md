# vsm-core

Elixir implementation of Stafford Beer's Viable System Model (VSM). Provides the 5 subsystems (S1-S5), communication channels, and variety engineering as OTP processes with supervision trees.

## What the VSM is

The Viable System Model is a cybernetic framework for organizational structure. Any viable system has 5 subsystems:

| System | Name | Role |
|--------|------|------|
| S1 | Operations | Does the actual work. Multiple operational units |
| S2 | Coordination | Prevents oscillation between S1 units |
| S3 | Control | Manages S1 resources, runs audits (S3*) |
| S4 | Intelligence | Scans environment, forecasts, proposes adaptations |
| S5 | Policy | Identity, values, resolves S3-S4 conflicts |

Communication between systems flows through typed channels (command, coordination, algedonic, audit).

## Codebase

| Category | Count |
|----------|-------|
| Source modules (`lib/`) | 51 `.ex` files |
| Test files (`test/`) | 32 `.exs` files |
| S1 modules | 5 (operations, unit, transaction, metrics, supervisor) |
| S2 modules | 4 (coordination, balancer, scheduler, supervisor) |
| S3 modules | 4 (control, resources, audit, supervisor) |
| S4 modules | 5 (intelligence, analytics, forecasting, scanner, supervisor) |
| S5 modules | 5 (policy, identity, values, decisions, supervisor) |
| Channel modules | 13 (temporal variety, algedonic + sub-modules, command, coordination, audit, supervisor) |
| Shared modules | 7 (channel, message, recursion, variety engineering, amplifier, attenuator, calculator) |

## Architecture

```
S5 (Policy)
  |
S4 (Intelligence) <--> Environment
  |
S3 (Control) ---> S3* (Audit)
  |
S2 (Coordination)
  |
S1 (Operations)
  [Unit A] [Unit B] [Unit C]
```

Algedonic signals bypass the hierarchy: any S1 unit can alert S5 directly when thresholds are crossed.

## Stack

| Component | Choice |
|-----------|--------|
| Language | Elixir 1.17+ |
| OTP | 25+ |
| Process framework | GenServer, GenStage |
| Telemetry | telemetry + telemetry_metrics + telemetry_poller |
| Code quality | Credo, Dialyxir |
| Test coverage | ExCoveralls |
| Version | 0.1.0 (pre-release) |

## Dependencies

Runtime: `gen_stage`, `telemetry`, `telemetry_metrics`, `telemetry_poller`

Dev/test: `ex_doc`, `credo`, `dialyxir`, `excoveralls`

No external database or network dependencies. State is held in OTP processes.

## Setup

```elixir
# mix.exs
def deps do
  [{:vsm_core, "~> 0.1.0"}]
end
```

```bash
mix deps.get
mix deps.compile
```

Requires Elixir 1.17+ and Erlang/OTP 25+.

## Usage

```elixir
# Start the VSM supervisor
{:ok, pid} = VSMCore.start_link(
  name: :my_vsm,
  config: [
    s1_units: 3,
    telemetry_enabled: true,
    algedonic_threshold: 0.8
  ]
)

# Access subsystems
operations = VSMCore.system(1)
control = VSMCore.system(3)

# Send messages between subsystems
VSMCore.send_message(:system1, :system3, {:alert, "Resource constraint detected"})

# Query state
state = VSMCore.get_state(:system3)
metrics = VSMCore.get_metrics(:system1)
```

## Module layout

```
lib/
  vsm_core.ex                          # Main API
  vsm_core/
    application.ex                      # OTP Application
    system1/
      operations.ex                     # Core operations logic
      unit.ex                           # Operational units (GenServer)
      transaction.ex                    # Transaction management
      metrics.ex                        # Performance metrics
      supervisor.ex                     # S1 supervision tree
    system2/
      coordination.ex                   # Anti-oscillation
      balancer.ex                       # Load balancing
      scheduler.ex                      # Task scheduling
      supervisor.ex
    system3/
      control.ex                        # Resource allocation
      resources.ex                      # Resource tracking
      audit.ex                          # S3* audit operations
      supervisor.ex
    system4/
      intelligence.ex                   # Environmental scanning
      analytics.ex                      # Data analysis
      forecasting.ex                    # Predictions
      scanner.ex                        # External monitoring
      supervisor.ex
    system5/
      policy.ex                         # Policy engine
      identity.ex                       # System identity
      values.ex                         # Core values
      decisions.ex                      # Strategic decisions
      supervisor.ex
    channels/
      temporal_variety.ex               # Time-based variety management
      algedonic.ex                      # Pain/pleasure bypass signals
      algedonic/                        # Alerting, correlation, filtering, routing, signals
      temporal/                         # Aggregation, causality, forecasting, patterns, timescales, visualization
      command_channel.ex
      coordination_channel.ex
      audit_channel.ex
      supervisor.ex
    shared/
      variety_engineering.ex            # Ashby's Law calculations
      variety/                          # Amplifier, attenuator, calculator
      channel.ex                        # Channel behaviour
      message.ex                        # Message types
      recursion.ex                      # Recursive VSM structures
    telemetry_reporter.ex               # Telemetry event emission
```

## Design decisions

| Decision | Rationale |
|----------|-----------|
| Each subsystem is a supervision tree | OTP supervision gives fault isolation. If S4 crashes, S1 operations continue |
| GenStage for channels | Backpressure between subsystems prevents message flooding |
| Variety engineering as math | Ashby's Law of Requisite Variety is implemented as calculable functions, not just a concept |
| Algedonic bypass | Mirrors Beer's design: emergency signals skip the hierarchy and go directly to S5 |
| No external persistence | State lives in OTP processes. Persistence is the caller's responsibility. Keeps the core simple |

## Documentation

| Document | Contents |
|----------|----------|
| [User Guide](docs/USER_GUIDE.md) | Usage patterns and examples |
| [API Reference](docs/API_REFERENCE.md) | Module-level API docs |
| [Architecture](docs/ARCHITECTURE_DESIGN.md) | Design rationale |
| [Development](docs/DEVELOPMENT.md) | Contributing, running tests |

## Status

Version 0.1.0. The S1-S5 subsystems and channel infrastructure are implemented. The API surface is not yet stable. Several features in the README examples (Prometheus export, config-file-based setup) are aspirational -- check the actual module docs for what is implemented today.

Related packages (vsm_telemetry, vsm_rate_limiter, vsm_goldrush) are referenced in the codebase but are not yet published.

## License

MIT
