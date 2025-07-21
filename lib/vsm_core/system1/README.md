# System 1 (Operations)

System 1 is the implementation subsystem in the Viable System Model. It handles the core operational transformations and primary activities of the organization.

## Components

### Operations (`operations.ex`)
The main GenServer that manages all operational units, handles transaction routing, and measures variety according to Ashby's Law of Requisite Variety.

Key features:
- Dynamic unit registration and management
- Transaction routing based on capabilities
- Real-time variety measurement
- Algedonic channel for emergency signals
- Integration with all VSM channels

### Unit (`unit.ex`)
Individual operational units that perform specific transformations. Each unit is an autonomous agent with:
- Capability-based transaction handling
- Load balancing and work migration
- Health monitoring and self-reporting
- State synchronization with other units

### Transaction (`transaction.ex`)
Represents work to be processed by the system:
- Multiple transaction types (compute, data, I/O)
- Variety calculation for inputs and outputs
- Priority and deadline support
- Serialization for persistence

### Metrics (`metrics.ex`)
Comprehensive performance tracking:
- Transaction success/failure rates
- Processing time percentiles
- Variety measurements and trends
- Unit-specific performance metrics
- Telemetry integration

### Supervisor (`supervisor.ex`)
Manages the S1 subsystem lifecycle with proper supervision tree.

## Usage

```elixir
# Start the S1 subsystem
{:ok, _} = VSMCore.System1.Supervisor.start_link()

# Register operational units
VSMCore.System1.Operations.register_unit(%{
  id: "compute_unit_1",
  capabilities: [:compute, :gpu],
  auto_restart: true
})

# Process transactions
transaction = VSMCore.System1.Transaction.compute(:factorial, %{n: 10})
{:ok, result} = VSMCore.System1.Operations.process_transaction(transaction)

# Monitor variety
{:ok, variety} = VSMCore.System1.Operations.get_variety()
# => %{input: 15.3, output: 14.8, ratio: 0.97, trend: :stable}

# Get performance metrics
{:ok, metrics} = VSMCore.System1.Operations.get_metrics()
```

## Variety Engineering

System 1 implements Ashby's Law of Requisite Variety by:
1. Measuring input variety of incoming transactions
2. Ensuring operational units have sufficient variety to handle inputs
3. Monitoring the variety ratio to detect control mismatches
4. Sending algedonic signals when variety imbalance is critical

## Communication Channels

- **Command Channel**: Receives operational commands from S3
- **Coordination Channel**: Coordinates with S2 for inter-unit synchronization
- **Audit Channel**: Responds to S3* audit requests
- **Resource Bargain**: Negotiates resources with S3
- **Algedonic Channel**: Sends emergency signals directly to S5

## Testing

Run the comprehensive test suite:

```bash
mix test test/system1/
```

Tests cover:
- Unit registration and lifecycle
- Transaction processing and routing
- Variety calculations
- Performance metrics
- Channel communication
- Error handling and recovery