defmodule VSMCore.Channels.AlgedonicTest do
  use ExUnit.Case, async: true
  
  alias VSMCore.Channels.Algedonic
  alias VSMCore.Channels.Algedonic.{Signals, Filtering, Routing}
  
  setup do
    {:ok, pid} = Algedonic.start_link(name: :test_algedonic)
    %{channel: pid}
  end
  
  describe "signal handling" do
    test "accepts valid pain signals", %{channel: channel} do
      assert :ok = Algedonic.send_pain_signal(channel, :test_source, %{"metric" => "cpu", "value" => 95}, :high)
    end
    
    test "accepts valid pleasure signals", %{channel: channel} do
      assert :ok = Algedonic.send_pleasure_signal(channel, :test_source, %{"metric" => "performance", "value" => 98}, :high)
    end
    
    test "processes signals asynchronously", %{channel: channel} do
      # Send multiple signals
      for i <- 1..5 do
        Algedonic.send_pain_signal(channel, :test_source, %{"metric" => "test", "value" => i}, :medium)
      end
      
      # Allow processing time
      Process.sleep(200)
      
      # Check that signals were processed
      {:ok, active} = Algedonic.get_active_signals(channel)
      assert map_size(active) > 0
    end
    
    test "handles emergency bypass for critical signals", %{channel: channel} do
      # Send critical signal
      Algedonic.send_pain_signal(channel, :emergency_source, %{"metric" => "system_failure"}, :critical)
      
      # Critical signals should bypass normal processing
      Process.sleep(50)
      
      {:ok, metrics} = Algedonic.get_metrics(channel)
      assert metrics.emergency_signals_routed > 0
    end
  end
  
  describe "filtering" do
    test "applies severity filters", %{channel: channel} do
      # Configure to only accept high and critical
      filters = [
        Filtering.create_filter(:severity, "High severity only", %{min_severity: :high})
      ]
      
      assert :ok = Algedonic.configure_filters(channel, filters)
      
      # Send signals of different severities
      Algedonic.send_pain_signal(channel, :test, %{"value" => 1}, :low)
      Algedonic.send_pain_signal(channel, :test, %{"value" => 2}, :medium)
      Algedonic.send_pain_signal(channel, :test, %{"value" => 3}, :high)
      
      Process.sleep(200)
      
      {:ok, metrics} = Algedonic.get_metrics(channel)
      assert metrics.signals_filtered > 0
    end
    
    test "validates filter configuration", %{channel: channel} do
      invalid_filter = %{type: :invalid}
      assert {:error, _} = Algedonic.configure_filters(channel, [invalid_filter])
    end
  end
  
  describe "metrics and telemetry" do
    test "tracks signal metrics", %{channel: channel} do
      # Send various signals
      Algedonic.send_pain_signal(channel, :test, %{"value" => 50}, :medium)
      Algedonic.send_pleasure_signal(channel, :test, %{"value" => 80}, :high)
      
      Process.sleep(100)
      
      {:ok, metrics} = Algedonic.get_metrics(channel)
      
      assert metrics.signals_received >= 2
      assert Map.has_key?(metrics, :queue_depth)
      assert Map.has_key?(metrics, :active_signals)
    end
    
    test "publishes telemetry events" do
      {:ok, channel} = Algedonic.start_link()
      
      # Attach telemetry handler
      ref = make_ref()
      test_pid = self()
      
      :telemetry.attach(
        "test-handler-#{inspect(ref)}",
        [:vsm_core, :algedonic, :metrics],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, measurements, metadata})
        end,
        nil
      )
      
      # Wait for metric collection
      Process.sleep(10_100)
      
      assert_receive {:telemetry, measurements, metadata}, 5000
      assert Map.has_key?(measurements, :signals_received)
      assert metadata.channel == :algedonic
      
      :telemetry.detach("test-handler-#{inspect(ref)}")
    end
  end
end