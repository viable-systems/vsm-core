# VSM Core Concurrency Test Suite Configuration
# Configuration for comprehensive concurrency and distributed systems testing

import Config

# Test Environment Configuration
config :vsm_core, :test_environment,
  # Cluster configuration for distributed testing
  cluster: %{
    node_count: 5,
    node_prefix: "vsm_test",
    startup_delay: 2000,
    coordination_timeout: 30_000
  },
  
  # Load testing parameters
  load_testing: %{
    max_concurrent_processes: 200,
    max_message_rate: 2000,
    stress_duration: 30_000,
    scenarios: [:light, :medium, :heavy, :extreme]
  },
  
  # Performance benchmarks and targets
  performance_targets: %{
    message_throughput: %{
      min_messages_per_sec: 1000,
      target_messages_per_sec: 5000,
      max_latency_ms: 100
    },
    
    causality_analysis: %{
      min_events_per_sec: 500,
      max_analysis_time_ms: 1000,
      accuracy_threshold: 0.95
    },
    
    distributed_coordination: %{
      max_coordination_latency_ms: 50,
      max_consensus_time_ms: 200,
      sync_overhead_threshold: 0.1
    },
    
    memory_efficiency: %{
      min_efficiency_score: 0.8,
      max_memory_growth_rate: 0.05,
      gc_effectiveness_threshold: 0.9
    },
    
    hlc_timestamps: %{
      monotonicity_violations: 0,
      causality_violations: 0,
      max_clock_skew_ms: 1000
    }
  },
  
  # Failure simulation parameters
  failure_scenarios: %{
    node_crash: %{
      max_recovery_time_ms: 30_000,
      data_loss_tolerance: 0.0,
      availability_threshold: 0.99
    },
    
    network_partition: %{
      max_partition_duration_ms: 60_000,
      consistency_model: :eventual,
      reconciliation_timeout_ms: 30_000
    },
    
    resource_exhaustion: %{
      memory_limit_mb: 500,
      cpu_saturation_threshold: 0.95,
      recovery_strategy: :graceful_degradation
    }
  }

# PubSub Testing Configuration
config :vsm_core, :pubsub_testing,
  # High-frequency subscription testing
  subscription_storm: %{
    max_subscribers: 1000,
    subscription_rate: 500,  # per second
    topic_count: 100,
    burst_duration_ms: 10_000
  },
  
  # Message delivery guarantees
  delivery_testing: %{
    message_burst_size: 10_000,
    subscriber_count: 50,
    delivery_timeout_ms: 5_000,
    ordering_verification: true,
    duplicate_detection: true
  },
  
  # Topic partitioning and isolation
  partition_testing: %{
    max_partitions: 100,
    messages_per_partition: 500,
    isolation_verification: true,
    cross_partition_leak_tolerance: 0.0
  }

# Distributed Testing Configuration
config :vsm_core, :distributed_testing,
  # Multi-node coordination
  coordination: %{
    consensus_algorithms: [:raft, :pbft],
    byzantine_fault_tolerance: true,
    network_delay_simulation: true,
    packet_loss_simulation: 0.01
  },
  
  # Data consistency testing
  consistency: %{
    models: [:strong, :eventual, :causal],
    conflict_resolution: [:last_write_wins, :vector_clocks],
    convergence_timeout_ms: 30_000
  },
  
  # Scaling characteristics
  scaling: %{
    node_configurations: [1, 3, 5, 8, 12, 20],
    scaling_efficiency_threshold: 0.7,
    latency_increase_threshold: 2.0,
    throughput_scaling_target: 0.8
  }

# Property-Based Testing Configuration
config :vsm_core, :property_testing,
  # Test generation parameters
  generation: %{
    max_shrinks: 1000,
    max_size: 10_000,
    num_tests: 1000,
    timeout_ms: 120_000
  },
  
  # HLC property testing
  hlc_properties: %{
    event_chain_length: 1000,
    concurrent_processes: 100,
    clock_skew_range: 10_000,  # ms
    timestamp_precision: :microsecond
  },
  
  # Causality property testing
  causality_properties: %{
    max_dependency_depth: 100,
    circular_dependency_detection: true,
    temporal_violation_detection: true,
    causal_graph_complexity: :high
  }

# Stress Testing Configuration
config :vsm_core, :stress_testing,
  # Extreme load scenarios
  extreme_load: %{
    event_count: 100_000,
    concurrent_analyzers: 100,
    complex_chain_depth: 500,
    timeout_ms: 300_000
  },
  
  # Adversarial scenarios
  adversarial: %{
    circular_dependency_bombs: true,
    dependency_explosions: true,
    timestamp_manipulation: true,
    memory_exhaustion_attacks: true,
    cpu_spike_patterns: true
  },
  
  # Resource constraints
  resource_limits: %{
    memory_limit_mb: 100,
    cpu_limit_percent: 50,
    time_limit_ms: 10_000,
    concurrent_process_limit: 10
  }

# Integration Testing Configuration
config :vsm_core, :integration_testing,
  # VSM subsystem integration
  subsystems: %{
    system1: %{operations: true, metrics: true, transactions: true},
    system2: %{coordination: true, balancing: true, scheduling: true},
    system3: %{audit: true, control: true, resources: true},
    system4: %{analytics: true, forecasting: true, intelligence: true, scanning: true},
    system5: %{decisions: true, identity: true, policy: true, values: true}
  },
  
  # Cross-system coordination
  coordination: %{
    command_flows: [:s5_to_s4, :s4_to_s3, :s3_to_s1],
    coordination_channels: [:s1_s2_bidirectional],
    audit_channels: [:s3_star_s1_bidirectional],
    algedonic_channels: [:s1_to_s5_emergency],
    resource_bargaining: [:s1_s3_bidirectional]
  },
  
  # Ecosystem integration
  ecosystem: %{
    vsm_telemetry: %{metrics: true, monitoring: true, alerting: true},
    vsm_rate_limiter: %{token_bucket: true, sliding_window: true, adaptive: true},
    vsm_goldrush: %{event_processing: true, pattern_matching: true, temporal_analysis: true},
    vsm_starter: %{initialization: true, configuration: true, supervision: true}
  }

# Reporting and Analysis Configuration
config :vsm_core, :test_reporting,
  # Report generation
  reports: %{
    output_directory: "test/concurrency/results",
    formats: [:json, :html, :csv],
    real_time_updates: true,
    historical_comparison: true
  },
  
  # Performance analysis
  analysis: %{
    trend_analysis: true,
    regression_detection: true,
    anomaly_detection: true,
    performance_profiling: true
  },
  
  # Metrics collection
  metrics: %{
    system_metrics: true,
    application_metrics: true,
    custom_metrics: true,
    telemetry_integration: true
  }

# Test Execution Configuration
config :vsm_core, :test_execution,
  # Parallel execution
  parallelism: %{
    max_concurrent_tests: 10,
    test_isolation: true,
    resource_sharing: :minimal,
    cleanup_between_tests: true
  },
  
  # Test ordering and dependencies
  scheduling: %{
    dependency_resolution: true,
    priority_scheduling: true,
    resource_based_scheduling: true,
    failure_isolation: true
  },
  
  # Retry and recovery
  resilience: %{
    max_retries: 3,
    retry_delay_ms: 1000,
    exponential_backoff: true,
    failure_analysis: true
  }

# Development and Debugging Configuration
config :vsm_core, :test_debugging,
  # Logging configuration
  logging: %{
    level: :info,
    detailed_failures: true,
    performance_logging: true,
    memory_usage_tracking: true
  },
  
  # Debug modes
  debug: %{
    verbose_output: false,
    step_by_step_execution: false,
    memory_profiling: false,
    cpu_profiling: false
  },
  
  # Development aids
  development: %{
    hot_reloading: true,
    test_discovery: true,
    auto_retry_on_change: false,
    interactive_mode: false
  }

# Security and Safety Configuration
config :vsm_core, :test_security,
  # Safe execution
  safety: %{
    resource_limits_enforced: true,
    timeout_enforcement: true,
    memory_limit_enforcement: true,
    process_isolation: true
  },
  
  # Security testing
  security: %{
    input_validation_testing: true,
    injection_attack_simulation: false,
    privilege_escalation_testing: false,
    data_sanitization_verification: true
  }

# Environment-Specific Overrides
import_config "#{Mix.env()}.exs"