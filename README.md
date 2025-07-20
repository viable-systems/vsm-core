# VSM Core

The core implementation of the Viable System Model (VSM) in Elixir. This package provides the fundamental building blocks and coordination mechanisms for implementing Stafford Beer's cybernetic management framework.

## Overview

VSM Core is the foundational package in the Viable Systems ecosystem, providing:

- **S1-S5 Subsystem Implementations**: Core behaviors and structures for all five VSM subsystems
- **Channel Management**: Inter-subsystem communication protocols
- **Coordination Mechanisms**: Shared state management and event propagation
- **Telemetry Integration**: Built-in observability and monitoring
- **Extensible Architecture**: Plugin-based system for custom implementations

## Architecture

```
vsm-core/
├── lib/
│   ├── vsm_core.ex              # Main entry point
│   ├── vsm_core/
│   │   ├── application.ex       # OTP Application
│   │   ├── system1/            # Operations
│   │   ├── system2/            # Coordination
│   │   ├── system3/            # Control
│   │   ├── system4/            # Intelligence
│   │   ├── system5/            # Policy
│   │   ├── channels/           # Communication
│   │   └── shared/             # Common modules
│   └── mix/tasks/              # Mix tasks
└── test/                       # Test suite
```

## Installation

Add `vsm_core` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vsm_core, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Start the VSM supervisor
{:ok, _pid} = VSMCore.start_link()

# Access subsystems
operations = VSMCore.system(1)
coordination = VSMCore.system(2)
control = VSMCore.system(3)
intelligence = VSMCore.system(4)
policy = VSMCore.system(5)

# Subscribe to events
VSMCore.subscribe(:operations_update)

# Send messages between subsystems
VSMCore.send_message(:system1, :system3, {:alert, "Resource constraint detected"})
```

## Subsystems

### System 1: Operations
Handles the primary activities of the organization. Each operational unit is autonomous but coordinated.

### System 2: Coordination
Manages anti-oscillatory behavior and ensures smooth interaction between operational units.

### System 3: Control
Provides operational control and resource allocation across System 1 units.

### System 4: Intelligence
Monitors the environment and plans for the future, balancing external demands with internal capabilities.

### System 5: Policy
Sets overall direction and resolves conflicts between Systems 3 and 4.

## Integration with Other VSM Packages

- **vsm_starter**: Provides templates and scaffolding
- **vsm_telemetry**: Advanced monitoring and visualization
- **vsm_rate_limiter**: Algedonic signal management
- **vsm_goldrush**: Event processing and pattern matching

## Configuration

```elixir
config :vsm_core,
  telemetry_enabled: true,
  persistence: :ets,
  channel_buffer_size: 1000,
  subsystem_restart_strategy: :permanent
```

## Contributing

See [CONTRIBUTING.md](../vsm-docs/CONTRIBUTING.md) for guidelines.

## License

MIT License - see LICENSE file for details.