defmodule VSMCore.System4.Intelligence do
  @moduledoc """
  System 4: Intelligence - The Future and Outside
  
  Responsible for:
  - Environmental scanning
  - Trend analysis and forecasting
  - Threat and opportunity detection
  - Model building and simulation
  - Strategic intelligence gathering
  """
  
  use GenServer
  require Logger
  
  alias VSMCore.{Registry}
  alias VSMCore.Shared.Message
  alias VSMCore.System4.{Scanner, Analytics, Forecasting}
  alias VSMCore.Channels.{CommandChannel, AlgedonicChannel}
  
  @subsystem_id :system4
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def scan_environment(patterns) do
    GenServer.call(__MODULE__, {:scan_environment, patterns})
  end
  
  def analyze_trends(data, timeframe) do
    GenServer.call(__MODULE__, {:analyze_trends, data, timeframe})
  end
  
  def forecast(model, horizon) do
    GenServer.call(__MODULE__, {:forecast, model, horizon})
  end
  
  def detect_anomalies(data) do
    GenServer.call(__MODULE__, {:detect_anomalies, data})
  end
  
  def build_model(data, model_type) do
    GenServer.call(__MODULE__, {:build_model, data, model_type})
  end
  
  def get_intelligence_report do
    GenServer.call(__MODULE__, :get_intelligence_report)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("System 4 (Intelligence) starting...")
    
    # Subscribe to relevant channels
    VSMCore.Channels.CommandChannel.subscribe(@subsystem_id)
    
    # Initialize telemetry
    :telemetry.execute(
      [:vsm_core, :system4, :init],
      %{},
      %{subsystem: @subsystem_id}
    )
    
    state = %{
      id: @subsystem_id,
      scanner: nil,
      analytics: nil,
      forecasting: nil,
      environment_data: %{},
      trends: %{},
      models: %{},
      alerts: [],
      config: Keyword.get(opts, :config, default_config())
    }
    
    # Start sub-components
    {:ok, scanner} = Scanner.start_link()
    {:ok, analytics} = Analytics.start_link()
    {:ok, forecasting} = Forecasting.start_link()
    
    state = %{state | 
      scanner: scanner,
      analytics: analytics,
      forecasting: forecasting
    }
    
    # Schedule periodic environmental scanning
    schedule_environmental_scan(state.config.scan_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:scan_environment, patterns}, _from, state) do
    Logger.debug("S4: Scanning environment with patterns: #{inspect(patterns)}")
    
    scan_results = Scanner.scan(state.scanner, patterns)
    
    # Update environment data
    state = update_environment_data(state, scan_results)
    
    # Check for threats or opportunities
    alerts = detect_threats_opportunities(scan_results, state)
    
    # Notify S5 if critical alerts
    if Enum.any?(alerts, &(&1.severity == :critical)) do
      send_algedonic_signal(alerts, state)
    end
    
    {:reply, {:ok, scan_results}, %{state | alerts: alerts}}
  end
  
  @impl true
  def handle_call({:analyze_trends, data, timeframe}, _from, state) do
    Logger.debug("S4: Analyzing trends for timeframe: #{inspect(timeframe)}")
    
    trends = Analytics.analyze_trends(state.analytics, data, timeframe)
    
    # Update state with new trends
    state = Map.update!(state, :trends, &Map.merge(&1, trends))
    
    # Check if trends indicate strategic changes needed
    if significant_trend_detected?(trends) do
      notify_system3_strategic_change(trends)
    end
    
    {:reply, {:ok, trends}, state}
  end
  
  @impl true
  def handle_call({:forecast, model, horizon}, _from, state) do
    Logger.debug("S4: Forecasting with model: #{inspect(model)}, horizon: #{inspect(horizon)}")
    
    forecast = Forecasting.predict(state.forecasting, model, horizon, state.environment_data)
    
    # Update S3 with forecast data for planning
    send_forecast_to_system3(forecast)
    
    {:reply, {:ok, forecast}, state}
  end
  
  @impl true
  def handle_call({:detect_anomalies, data}, _from, state) do
    Logger.debug("S4: Detecting anomalies in data")
    
    anomalies = Analytics.detect_anomalies(state.analytics, data, state.models)
    
    # If anomalies are significant, alert S5
    if significant_anomaly?(anomalies) do
      send_algedonic_signal(anomalies, state)
    end
    
    {:reply, {:ok, anomalies}, state}
  end
  
  @impl true
  def handle_call({:build_model, data, model_type}, _from, state) do
    Logger.debug("S4: Building model of type: #{inspect(model_type)}")
    
    model = Analytics.build_model(state.analytics, data, model_type)
    
    # Store model for future use
    state = Map.update!(state, :models, &Map.put(&1, model_type, model))
    
    {:reply, {:ok, model}, state}
  end
  
  @impl true
  def handle_call(:get_intelligence_report, _from, state) do
    report = %{
      environment: summarize_environment(state.environment_data),
      trends: summarize_trends(state.trends),
      alerts: state.alerts,
      models: Map.keys(state.models),
      last_scan: get_last_scan_time(state)
    }
    
    {:reply, {:ok, report}, state}
  end
  
  @impl true
  def handle_info(:environmental_scan, state) do
    Logger.debug("S4: Performing scheduled environmental scan")
    
    # Perform automatic scan
    scan_results = Scanner.scan(state.scanner, state.config.auto_scan_patterns)
    state = update_environment_data(state, scan_results)
    
    # Schedule next scan
    schedule_environmental_scan(state.config.scan_interval)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:channel_message, message}, state) do
    Logger.debug("S4: Received message: #{inspect(message)}")
    
    state = case message.type do
      :intelligence_request ->
        handle_intelligence_request(message, state)
      :model_update ->
        handle_model_update(message, state)
      _ ->
        Logger.warn("S4: Unknown message type: #{message.type}")
        state
    end
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp via_tuple do
    {:via, Registry, {VSMCore.Registry, @subsystem_id}}
  end
  
  defp default_config do
    %{
      scan_interval: :timer.minutes(5),
      auto_scan_patterns: [
        :market_conditions,
        :competitor_activity,
        :technology_trends,
        :regulatory_changes
      ],
      anomaly_threshold: 0.95,
      trend_significance_threshold: 0.8
    }
  end
  
  defp schedule_environmental_scan(interval) do
    Process.send_after(self(), :environmental_scan, interval)
  end
  
  defp update_environment_data(state, scan_results) do
    timestamp = DateTime.utc_now()
    
    updated_data = Map.merge(state.environment_data, %{
      timestamp => scan_results,
      :latest => scan_results
    })
    
    %{state | environment_data: updated_data}
  end
  
  defp detect_threats_opportunities(scan_results, state) do
    scan_results
    |> Enum.flat_map(fn {category, data} ->
      Analytics.assess_significance(state.analytics, category, data, state.models)
    end)
    |> Enum.filter(&significant_alert?/1)
  end
  
  defp significant_alert?(alert) do
    alert.confidence >= 0.7 && alert.impact >= :medium
  end
  
  defp send_algedonic_signal(alerts, _state) do
    message = Message.new(
      @subsystem_id,
      :system5,
      :algedonic_channel,
      :critical_alert,
      %{
        alerts: alerts,
        timestamp: DateTime.utc_now(),
        requires_immediate_attention: true
      }
    )
    
    VSMCore.Channels.AlgedonicChannel.send_message(message)
  end
  
  defp significant_trend_detected?(trends) do
    Enum.any?(trends, fn {_key, trend} ->
      trend.significance >= 0.8 && trend.direction != :stable
    end)
  end
  
  defp notify_system3_strategic_change(trends) do
    message = Message.command(
      @subsystem_id,
      :system3,
      :strategic_update,
      %{
        trends: trends,
        recommendation: :adapt_strategy,
        timestamp: DateTime.utc_now()
      }
    )
    
    VSMCore.Channels.CommandChannel.send_message(message)
  end
  
  defp send_forecast_to_system3(forecast) do
    message = Message.command(
      @subsystem_id,
      :system3,
      :forecast_update,
      %{
        forecast: forecast,
        timestamp: DateTime.utc_now()
      }
    )
    
    VSMCore.Channels.CommandChannel.send_message(message)
  end
  
  defp significant_anomaly?(anomalies) do
    Enum.any?(anomalies, &(&1.severity >= :high))
  end
  
  defp handle_intelligence_request(message, state) do
    # Process intelligence request from other systems
    request_type = message.payload[:request_type]
    
    case request_type do
      :environmental_assessment ->
        assessment = Scanner.assess_environment(state.scanner, message.payload[:focus_areas])
        send_response(message.from, assessment)
      :trend_analysis ->
        trends = Analytics.analyze_trends(state.analytics, message.payload[:data], message.payload[:timeframe])
        send_response(message.from, trends)
      _ ->
        Logger.warn("S4: Unknown intelligence request type: #{request_type}")
    end
    
    state
  end
  
  defp handle_model_update(message, state) do
    # Update models based on feedback from other systems
    model_type = message.payload[:model_type]
    update_data = message.payload[:update_data]
    
    updated_model = Analytics.update_model(state.analytics, state.models[model_type], update_data)
    
    Map.update!(state, :models, &Map.put(&1, model_type, updated_model))
  end
  
  defp send_response(to, payload) do
    message = Message.command(
      @subsystem_id,
      to,
      :intelligence_response,
      payload
    )
    
    VSMCore.Channels.CommandChannel.send_message(message)
  end
  
  defp summarize_environment(environment_data) do
    latest = Map.get(environment_data, :latest, %{})
    
    %{
      current_state: latest,
      data_points: map_size(environment_data) - 1,
      categories: Map.keys(latest)
    }
  end
  
  defp summarize_trends(trends) do
    trends
    |> Enum.map(fn {key, trend} ->
      {key, %{
        direction: trend.direction,
        significance: trend.significance,
        confidence: trend.confidence
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp get_last_scan_time(state) do
    state.environment_data
    |> Map.keys()
    |> Enum.filter(&is_struct(&1, DateTime))
    |> Enum.max(DateTime, fn -> nil end)
  end
end