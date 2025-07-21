defmodule VSMCore.System4.Scanner do
  @moduledoc """
  Environmental Scanner for System 4
  
  Responsible for:
  - Monitoring external environment
  - Detecting changes and patterns
  - Gathering intelligence from various sources
  - Identifying potential threats and opportunities
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def scan(scanner, patterns) do
    GenServer.call(scanner, {:scan, patterns})
  end
  
  def assess_environment(scanner, focus_areas) do
    GenServer.call(scanner, {:assess_environment, focus_areas})
  end
  
  def add_data_source(scanner, source_config) do
    GenServer.cast(scanner, {:add_data_source, source_config})
  end
  
  def get_scan_history(scanner, limit \\ 10) do
    GenServer.call(scanner, {:get_scan_history, limit})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("S4 Scanner initializing...")
    
    state = %{
      data_sources: initialize_data_sources(opts),
      scan_history: [],
      pattern_matchers: initialize_pattern_matchers(),
      cache: %{},
      config: Keyword.get(opts, :config, default_config())
    }
    
    # Schedule cache cleanup
    schedule_cache_cleanup(state.config.cache_ttl)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:scan, patterns}, _from, state) do
    Logger.debug("Scanner: Scanning for patterns: #{inspect(patterns)}")
    
    # Collect data from all sources
    raw_data = collect_from_sources(state.data_sources, patterns)
    
    # Apply pattern matching
    scan_results = apply_patterns(raw_data, patterns, state.pattern_matchers)
    
    # Cache results
    state = cache_results(state, scan_results)
    
    # Update scan history
    state = update_scan_history(state, patterns, scan_results)
    
    {:reply, scan_results, state}
  end
  
  @impl true
  def handle_call({:assess_environment, focus_areas}, _from, state) do
    Logger.debug("Scanner: Assessing environment for areas: #{inspect(focus_areas)}")
    
    assessment = focus_areas
    |> Enum.map(fn area ->
      {area, assess_area(area, state)}
    end)
    |> Enum.into(%{})
    
    {:reply, assessment, state}
  end
  
  @impl true
  def handle_call({:get_scan_history, limit}, _from, state) do
    history = Enum.take(state.scan_history, limit)
    {:reply, history, state}
  end
  
  @impl true
  def handle_cast({:add_data_source, source_config}, state) do
    Logger.info("Scanner: Adding new data source: #{source_config.name}")
    
    source = initialize_source(source_config)
    state = Map.update!(state, :data_sources, &Map.put(&1, source_config.name, source))
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:cleanup_cache, state) do
    Logger.debug("Scanner: Cleaning up cache")
    
    state = cleanup_expired_cache(state)
    schedule_cache_cleanup(state.config.cache_ttl)
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp default_config do
    %{
      cache_ttl: :timer.minutes(30),
      max_history_size: 100,
      scan_timeout: :timer.seconds(30),
      parallel_sources: true
    }
  end
  
  defp initialize_data_sources(_opts) do
    %{
      market_data: %{
        type: :market,
        active: true,
        endpoint: nil,  # Would connect to real market data API
        transform: &transform_market_data/1
      },
      competitor_monitor: %{
        type: :competitor,
        active: true,
        sources: [],  # Would monitor competitor activities
        transform: &transform_competitor_data/1
      },
      technology_trends: %{
        type: :technology,
        active: true,
        feeds: [],  # Would connect to tech news/research feeds
        transform: &transform_tech_data/1
      },
      regulatory_tracker: %{
        type: :regulatory,
        active: true,
        jurisdictions: [],  # Would track regulatory changes
        transform: &transform_regulatory_data/1
      },
      social_sentiment: %{
        type: :social,
        active: true,
        platforms: [],  # Would analyze social media sentiment
        transform: &transform_social_data/1
      }
    }
  end
  
  defp initialize_pattern_matchers do
    %{
      trend_detector: &detect_trends/2,
      anomaly_detector: &detect_anomalies/2,
      opportunity_finder: &find_opportunities/2,
      threat_identifier: &identify_threats/2,
      correlation_analyzer: &analyze_correlations/2
    }
  end
  
  defp collect_from_sources(data_sources, patterns) do
    active_sources = Enum.filter(data_sources, fn {_name, source} -> source.active end)
    
    if patterns == :all do
      collect_all_data(active_sources)
    else
      collect_targeted_data(active_sources, patterns)
    end
  end
  
  defp collect_all_data(sources) do
    sources
    |> Enum.map(fn {name, source} ->
      {name, simulate_data_collection(source)}
    end)
    |> Enum.into(%{})
  end
  
  defp collect_targeted_data(sources, patterns) do
    relevant_sources = filter_relevant_sources(sources, patterns)
    
    relevant_sources
    |> Enum.map(fn {name, source} ->
      {name, simulate_data_collection(source, patterns)}
    end)
    |> Enum.into(%{})
  end
  
  defp filter_relevant_sources(sources, patterns) do
    sources
    |> Enum.filter(fn {_name, source} ->
      Enum.any?(patterns, &pattern_matches_source?(&1, source.type))
    end)
  end
  
  defp pattern_matches_source?(pattern, source_type) do
    case {pattern, source_type} do
      {:market_conditions, :market} -> true
      {:competitor_activity, :competitor} -> true
      {:technology_trends, :technology} -> true
      {:regulatory_changes, :regulatory} -> true
      {:social_sentiment, :social} -> true
      _ -> false
    end
  end
  
  defp simulate_data_collection(source, patterns \\ nil) do
    # In a real implementation, this would connect to actual data sources
    # For now, we simulate with meaningful data structures
    
    base_data = case source.type do
      :market ->
        %{
          indices: %{sp500: 4500 + :rand.uniform(100), nasdaq: 15000 + :rand.uniform(200)},
          volatility: 15 + :rand.uniform(10),
          volume: :rand.uniform(1_000_000_000),
          trends: [:bullish, :bearish, :neutral] |> Enum.random()
        }
      
      :competitor ->
        %{
          new_products: :rand.uniform(3),
          market_share_change: -5 + :rand.uniform(10),
          strategic_moves: [:expansion, :consolidation, :pivot] |> Enum.random(),
          sentiment: [:positive, :negative, :neutral] |> Enum.random()
        }
      
      :technology ->
        %{
          emerging_tech: [:ai, :quantum, :biotech, :blockchain] |> Enum.take(:rand.uniform(2)),
          adoption_rate: :rand.uniform(100),
          disruption_potential: [:low, :medium, :high] |> Enum.random(),
          maturity: [:experimental, :early_adopter, :mainstream] |> Enum.random()
        }
      
      :regulatory ->
        %{
          new_regulations: :rand.uniform(5),
          compliance_changes: [:stricter, :relaxed, :unchanged] |> Enum.random(),
          impact_assessment: [:low, :medium, :high] |> Enum.random(),
          effective_date: Date.add(Date.utc_today(), :rand.uniform(365))
        }
      
      :social ->
        %{
          sentiment_score: :rand.uniform(100),
          trending_topics: [:sustainability, :innovation, :quality] |> Enum.take(:rand.uniform(2)),
          engagement_rate: :rand.uniform(100),
          influence_score: :rand.uniform(100)
        }
    end
    
    # Apply transformation
    source.transform.(base_data)
  end
  
  defp transform_market_data(data) do
    Map.put(data, :timestamp, DateTime.utc_now())
  end
  
  defp transform_competitor_data(data) do
    Map.put(data, :timestamp, DateTime.utc_now())
  end
  
  defp transform_tech_data(data) do
    Map.put(data, :timestamp, DateTime.utc_now())
  end
  
  defp transform_regulatory_data(data) do
    Map.put(data, :timestamp, DateTime.utc_now())
  end
  
  defp transform_social_data(data) do
    Map.put(data, :timestamp, DateTime.utc_now())
  end
  
  defp apply_patterns(raw_data, patterns, matchers) do
    patterns
    |> Enum.map(fn pattern ->
      {pattern, analyze_pattern(pattern, raw_data, matchers)}
    end)
    |> Enum.into(%{})
  end
  
  defp analyze_pattern(pattern, data, matchers) do
    # Apply relevant pattern matchers
    results = matchers
    |> Enum.map(fn {_name, matcher} ->
      matcher.(pattern, data)
    end)
    |> Enum.filter(&(&1 != nil))
    
    %{
      pattern: pattern,
      findings: results,
      confidence: calculate_confidence(results),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp detect_trends(_pattern, data) do
    # Simplified trend detection
    market_trend = get_in(data, [:market_data, :trends])
    
    if market_trend do
      %{
        type: :trend,
        direction: market_trend,
        strength: :rand.uniform(100) / 100,
        indicators: [:price_movement, :volume_analysis]
      }
    end
  end
  
  defp detect_anomalies(_pattern, data) do
    # Simplified anomaly detection
    volatility = get_in(data, [:market_data, :volatility]) || 0
    
    if volatility > 25 do
      %{
        type: :anomaly,
        severity: if(volatility > 35, do: :high, else: :medium),
        description: "High market volatility detected",
        value: volatility
      }
    end
  end
  
  defp find_opportunities(_pattern, data) do
    # Simplified opportunity detection
    emerging_tech = get_in(data, [:technology_trends, :emerging_tech]) || []
    
    if length(emerging_tech) > 0 do
      %{
        type: :opportunity,
        category: :technology,
        description: "Emerging technologies: #{Enum.join(emerging_tech, ", ")}",
        potential: get_in(data, [:technology_trends, :disruption_potential]) || :medium
      }
    end
  end
  
  defp identify_threats(_pattern, data) do
    # Simplified threat identification
    competitor_moves = get_in(data, [:competitor_monitor, :strategic_moves])
    regulatory_impact = get_in(data, [:regulatory_tracker, :impact_assessment])
    
    threats = []
    
    threats = if competitor_moves == :expansion do
      [%{
        type: :threat,
        source: :competitor,
        description: "Competitor expansion detected",
        severity: :medium
      } | threats]
    else
      threats
    end
    
    threats = if regulatory_impact == :high do
      [%{
        type: :threat,
        source: :regulatory,
        description: "High-impact regulatory changes",
        severity: :high
      } | threats]
    else
      threats
    end
    
    case threats do
      [] -> nil
      [threat] -> threat
      multiple -> %{type: :threat, threats: multiple, severity: :high}
    end
  end
  
  defp analyze_correlations(_pattern, data) do
    # Simplified correlation analysis
    sentiment = get_in(data, [:social_sentiment, :sentiment_score]) || 50
    market_trend = get_in(data, [:market_data, :trends])
    
    if sentiment && market_trend do
      %{
        type: :correlation,
        factors: [:social_sentiment, :market_trend],
        strength: :rand.uniform(100) / 100,
        relationship: if(sentiment > 70 && market_trend == :bullish, do: :positive, else: :mixed)
      }
    end
  end
  
  defp calculate_confidence(results) do
    case length(results) do
      0 -> 0.0
      n -> 
        # Simple confidence based on number and quality of findings
        base_confidence = min(n * 0.2, 0.8)
        quality_bonus = Enum.count(results, &(&1[:severity] == :high || &1[:potential] == :high)) * 0.1
        min(base_confidence + quality_bonus, 1.0)
    end
  end
  
  defp cache_results(state, scan_results) do
    timestamp = DateTime.utc_now()
    
    updated_cache = scan_results
    |> Enum.reduce(state.cache, fn {pattern, result}, cache ->
      Map.put(cache, {pattern, timestamp}, result)
    end)
    
    %{state | cache: updated_cache}
  end
  
  defp update_scan_history(state, patterns, results) do
    entry = %{
      timestamp: DateTime.utc_now(),
      patterns: patterns,
      summary: summarize_results(results)
    }
    
    history = [entry | state.scan_history]
    |> Enum.take(state.config.max_history_size)
    
    %{state | scan_history: history}
  end
  
  defp summarize_results(results) do
    %{
      patterns_scanned: map_size(results),
      findings_count: results |> Map.values() |> Enum.map(&length(&1.findings)) |> Enum.sum(),
      high_confidence: Enum.count(results, fn {_k, v} -> v.confidence > 0.7 end)
    }
  end
  
  defp assess_area(area, state) do
    # Use cached data if available and fresh
    recent_scans = get_recent_scans_for_area(area, state)
    
    %{
      status: determine_area_status(area, recent_scans),
      recent_activity: summarize_recent_activity(recent_scans),
      risk_level: assess_risk_level(area, recent_scans),
      recommendations: generate_recommendations(area, recent_scans)
    }
  end
  
  defp get_recent_scans_for_area(area, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)  # Last hour
    
    state.cache
    |> Enum.filter(fn {{pattern, timestamp}, _result} ->
      pattern_matches_area?(pattern, area) && DateTime.compare(timestamp, cutoff) == :gt
    end)
    |> Enum.map(fn {_key, result} -> result end)
  end
  
  defp pattern_matches_area?(pattern, area) do
    case {pattern, area} do
      {:market_conditions, :financial} -> true
      {:competitor_activity, :competitive} -> true
      {:technology_trends, :innovation} -> true
      {:regulatory_changes, :compliance} -> true
      _ -> false
    end
  end
  
  defp determine_area_status(_area, recent_scans) do
    if Enum.any?(recent_scans, &high_priority_finding?/1) do
      :attention_required
    else
      :normal
    end
  end
  
  defp high_priority_finding?(scan_result) do
    Enum.any?(scan_result.findings, fn finding ->
      finding[:severity] == :high || finding[:potential] == :high
    end)
  end
  
  defp summarize_recent_activity(recent_scans) do
    recent_scans
    |> Enum.flat_map(& &1.findings)
    |> Enum.map(& &1.type)
    |> Enum.frequencies()
  end
  
  defp assess_risk_level(_area, recent_scans) do
    threat_count = recent_scans
    |> Enum.flat_map(& &1.findings)
    |> Enum.count(&(&1.type == :threat))
    
    cond do
      threat_count >= 3 -> :high
      threat_count >= 1 -> :medium
      true -> :low
    end
  end
  
  defp generate_recommendations(area, recent_scans) do
    findings = Enum.flat_map(recent_scans, & &1.findings)
    
    recommendations = []
    
    recommendations = if Enum.any?(findings, &(&1.type == :threat)) do
      ["Develop mitigation strategies for identified threats" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Enum.any?(findings, &(&1.type == :opportunity)) do
      ["Evaluate and prioritize emerging opportunities" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Enum.empty?(recent_scans) do
      ["Increase scanning frequency for #{area} area" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
  
  defp initialize_source(source_config) do
    %{
      type: source_config.type,
      active: true,
      config: source_config,
      transform: get_transformer_for_type(source_config.type)
    }
  end
  
  defp get_transformer_for_type(type) do
    case type do
      :market -> &transform_market_data/1
      :competitor -> &transform_competitor_data/1
      :technology -> &transform_tech_data/1
      :regulatory -> &transform_regulatory_data/1
      :social -> &transform_social_data/1
      _ -> &Function.identity/1
    end
  end
  
  defp schedule_cache_cleanup(interval) do
    Process.send_after(self(), :cleanup_cache, interval)
  end
  
  defp cleanup_expired_cache(state) do
    cutoff = DateTime.add(DateTime.utc_now(), -state.config.cache_ttl, :millisecond)
    
    cleaned_cache = state.cache
    |> Enum.filter(fn {{_pattern, timestamp}, _result} ->
      DateTime.compare(timestamp, cutoff) == :gt
    end)
    |> Enum.into(%{})
    
    %{state | cache: cleaned_cache}
  end
end