defmodule VSMCore.Shared.Message do
  @moduledoc """
  Defines the message structure and utilities for inter-subsystem communication
  in the VSM implementation.
  """
  
  alias __MODULE__
  alias VSMCore.Shared.Channel
  
  @enforce_keys [:id, :from, :to, :channel, :type, :payload, :timestamp]
  defstruct [
    :id,
    :from,
    :to,
    :channel,
    :type,
    :payload,
    :timestamp,
    :metadata,
    :correlation_id,
    :reply_to
  ]
  
  @type system_id :: :system1 | :system2 | :system3 | :system3_star | :system4 | :system5
  
  @type channel_type :: 
    :command_channel |
    :coordination_channel |
    :audit_channel |
    :algedonic_channel |
    :resource_bargain_channel
  
  @type t :: %Message{
    id: String.t(),
    from: system_id(),
    to: system_id(),
    channel: channel_type(),
    type: atom(),
    payload: any(),
    timestamp: DateTime.t(),
    metadata: map() | nil,
    correlation_id: String.t() | nil,
    reply_to: String.t() | nil
  }
  
  @doc """
  Creates a new message with auto-generated ID and timestamp.
  """
  def new(from, to, channel, type, payload, opts \\ []) do
    %Message{
      id: Keyword.get(opts, :id, generate_id()),
      from: from,
      to: to,
      channel: channel,
      type: type,
      payload: payload,
      timestamp: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata),
      correlation_id: Keyword.get(opts, :correlation_id),
      reply_to: Keyword.get(opts, :reply_to)
    }
  end

  @doc """
  Creates a command message (S5 -> S4 -> S3 -> S1).
  """
  def command(from, to, type, payload, opts \\ []) do
    new(from, to, :command_channel, type, payload, opts)
  end

  @doc """
  Creates an algedonic message (direct S1 -> S5 emergency channel).
  """
  def algedonic(from, payload, opts \\ []) do
    new(from, :system5, :algedonic_channel, :emergency_signal, payload, opts)
  end

  @doc """
  Creates a coordination message (S2 <-> S1).
  """
  def coordination(from, to, type, payload, opts \\ []) do
    new(from, to, :coordination_channel, type, payload, opts)
  end

  @doc """
  Creates an audit message (S3* <-> S1).
  """
  def audit(from, to, type, payload, opts \\ []) do
    new(from, to, :audit_channel, type, payload, opts)
  end

  @doc """
  Creates a resource bargain message (S1 <-> S3).
  """
  def resource_bargain(from, to, type, payload, opts \\ []) do
    new(from, to, :resource_bargain_channel, type, payload, opts)
  end
  
  @doc """
  Sends a message through the appropriate channel.
  """
  def send(from, to, channel, type, payload, opts \\ []) do
    message = new(from, to, channel, type, payload, opts)
    Channel.publish(channel, message)
    message
  end
  
  @doc """
  Creates a reply to an existing message.
  """
  def reply(%Message{} = original, type, payload, opts \\ []) do
    new(
      original.to,
      original.from,
      original.channel,
      type,
      payload,
      Keyword.merge(opts, [
        correlation_id: original.correlation_id || original.id,
        reply_to: original.id
      ])
    )
  end
  
  
  @doc """
  Serializes a message for storage or transmission.
  """
  def serialize(%Message{} = message) do
    %{
      id: message.id,
      from: message.from,
      to: message.to,
      channel: message.channel,
      type: message.type,
      payload: message.payload,
      timestamp: DateTime.to_iso8601(message.timestamp),
      metadata: message.metadata,
      correlation_id: message.correlation_id,
      reply_to: message.reply_to
    }
  end
  
  @doc """
  Validates if a message is properly formatted and complete.
  
  ## Examples
  
      iex> message = VSMCore.Shared.Message.command(:system1, :system3, :test, %{})
      iex> VSMCore.Shared.Message.valid?(message)
      true
      
      iex> VSMCore.Shared.Message.valid?(%{invalid: :structure})
      false
  """
  def valid?(%Message{} = message) do
    with :ok <- validate_required_fields(message),
         :ok <- validate_systems(message),
         :ok <- validate_channel(message),
         :ok <- validate_timestamp(message) do
      true
    else
      _ -> false
    end
  end
  
  def valid?(_), do: false
  
  @doc """
  Validates a message and returns detailed error information.
  
  ## Examples
  
      iex> message = VSMCore.Shared.Message.command(:system1, :system3, :test, %{})
      iex> VSMCore.Shared.Message.validate(message)
      :ok
      
      iex> VSMCore.Shared.Message.validate(%{invalid: :structure})
      {:error, :invalid_message_format}
  """
  def validate(%Message{} = message) do
    with :ok <- validate_required_fields(message),
         :ok <- validate_systems(message),
         :ok <- validate_channel(message),
         :ok <- validate_timestamp(message) do
      :ok
    else
      error -> error
    end
  end
  
  def validate(_), do: {:error, :invalid_message_format}

  @doc """
  Deserializes a message from storage format.
  """
  def deserialize(data) when is_map(data) do
    try do
      %Message{
        id: data.id,
        from: String.to_existing_atom(to_string(data.from)),
        to: String.to_existing_atom(to_string(data.to)),
        channel: String.to_existing_atom(to_string(data.channel)),
        type: String.to_existing_atom(to_string(data.type)),
        payload: data.payload,
        timestamp: DateTime.from_iso8601(to_string(data.timestamp)) |> elem(1),
        metadata: data.metadata,
        correlation_id: data.correlation_id,
        reply_to: data.reply_to
      }
    rescue
      _ -> {:error, :invalid_data_format}
    end
  end
  
  # Private Functions
  
  defp generate_id do
    "msg_#{:erlang.unique_integer([:positive])}_#{System.os_time(:nanosecond)}"
  end
  
  defp validate_required_fields(%Message{id: id, timestamp: %DateTime{}}) when is_binary(id) do
    :ok
  end
  defp validate_required_fields(_), do: {:error, :missing_required_fields}
  
  defp validate_systems(%Message{from: from, to: to}) do
    valid_systems = [:system1, :system2, :system3, :system3_star, :system4, :system5]
    # Allow additional systems for ecosystem integration
    extended_systems = valid_systems ++ [:rate_limiter, :telemetry, :goldrush, :starter_system, :ecosystem_test]
    
    if from in extended_systems and to in extended_systems do
      :ok
    else
      {:error, :invalid_system}
    end
  end
  
  defp validate_channel(%Message{channel: channel}) do
    valid_channels = [:command_channel, :coordination_channel, :audit_channel, :algedonic_channel, :resource_bargain_channel]
    
    if channel in valid_channels do
      :ok
    else
      {:error, :invalid_channel}
    end
  end
  
  defp validate_timestamp(%Message{timestamp: %DateTime{}}), do: :ok
  defp validate_timestamp(_), do: {:error, :invalid_timestamp}
  
  defp validate_channel_rules(%Message{} = message) do
    case message.channel do
      :command_channel ->
        validate_command_channel(message)
        
      :coordination_channel ->
        validate_coordination_channel(message)
        
      :audit_channel ->
        validate_audit_channel(message)
        
      :algedonic_channel ->
        validate_algedonic_channel(message)
        
      :resource_bargain_channel ->
        validate_resource_bargain_channel(message)
        
      _ ->
        {:error, :unknown_channel}
    end
  end
  
  # Channel-specific validation rules
  
  defp validate_command_channel(%Message{from: from, to: to}) do
    # Command flows: S5 → S4 → S3 → S1
    valid_flows = [
      {:system5, :system4},
      {:system5, :system3},
      {:system4, :system3},
      {:system3, :system1}
    ]
    
    if {from, to} in valid_flows do
      :ok
    else
      {:error, :invalid_command_flow}
    end
  end
  
  defp validate_coordination_channel(%Message{from: from, to: to}) do
    # Coordination is between S2 and S1 units
    if (from == :system2 and to == :system1) or 
       (from == :system1 and to == :system2) do
      :ok
    else
      {:error, :invalid_coordination_flow}
    end
  end
  
  defp validate_audit_channel(%Message{from: from, to: to}) do
    # Audit flows from S3* to S1, or responses back
    if (from == :system3_star and to == :system1) or
       (from == :system1 and to == :system3_star) do
      :ok
    else
      {:error, :invalid_audit_flow}
    end
  end
  
  defp validate_algedonic_channel(%Message{from: from, to: to}) do
    # Algedonic signals flow directly from S1 to S5
    if from == :system1 and to == :system5 do
      :ok
    else
      {:error, :invalid_algedonic_flow}
    end
  end
  
  defp validate_resource_bargain_channel(%Message{from: from, to: to}) do
    # Resource bargaining between S1 and S3
    if (from == :system1 and to == :system3) or
       (from == :system3 and to == :system1) do
      :ok
    else
      {:error, :invalid_resource_bargain_flow}
    end
  end
end