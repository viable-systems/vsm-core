defmodule VSMCore.System1.Transaction do
  @moduledoc """
  Represents a transaction to be processed by System 1 operational units.
  
  Transactions carry the work to be done and help measure variety
  in the system according to Ashby's Law of Requisite Variety.
  """
  
  alias __MODULE__
  
  @enforce_keys [:id, :type, :payload]
  defstruct [
    :id,
    :type,
    :payload,
    :priority,
    :required_capabilities,
    :source,
    :created_at,
    :deadline,
    :metadata
  ]
  
  @type t :: %Transaction{
    id: String.t(),
    type: atom(),
    payload: any(),
    priority: :low | :normal | :high | :critical,
    required_capabilities: list(atom()),
    source: atom() | String.t(),
    created_at: DateTime.t(),
    deadline: DateTime.t() | nil,
    metadata: map()
  }
  
  @doc """
  Creates a new transaction with the given parameters.
  """
  def new(type, payload, opts \\ []) do
    %Transaction{
      id: Keyword.get(opts, :id, generate_id()),
      type: type,
      payload: payload,
      priority: Keyword.get(opts, :priority, :normal),
      required_capabilities: Keyword.get(opts, :required_capabilities, []),
      source: Keyword.get(opts, :source, :external),
      created_at: DateTime.utc_now(),
      deadline: Keyword.get(opts, :deadline),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
  
  @doc """
  Creates a compute transaction.
  """
  def compute(operation, params, opts \\ []) do
    payload = %{
      operation: operation,
      params: params
    }
    
    new(:compute, payload, Keyword.put(opts, :required_capabilities, [:compute]))
  end
  
  @doc """
  Creates a data transaction.
  """
  def data(operation, data, opts \\ []) do
    payload = %{
      operation: operation,
      data: data
    }
    
    new(:data, payload, Keyword.put(opts, :required_capabilities, [:data]))
  end
  
  @doc """
  Creates an I/O transaction.
  """
  def io(operation, target, data, opts \\ []) do
    payload = %{
      operation: operation,
      target: target,
      data: data
    }
    
    new(:io, payload, Keyword.put(opts, :required_capabilities, [:io]))
  end
  
  @doc """
  Validates a transaction.
  """
  def valid?(%Transaction{} = transaction) do
    with :ok <- validate_type(transaction),
         :ok <- validate_payload(transaction),
         :ok <- validate_deadline(transaction) do
      true
    else
      _ -> false
    end
  end
  
  @doc """
  Calculates the input variety of a transaction.
  
  Variety represents the number of possible states or complexity of the input.
  """
  def calculate_input_variety(%Transaction{} = transaction) do
    base_variety = case transaction.type do
      :compute -> calculate_compute_variety(transaction.payload)
      :data -> calculate_data_variety(transaction.payload)
      :io -> calculate_io_variety(transaction.payload)
      _ -> 1
    end
    
    # Adjust for priority
    priority_multiplier = case transaction.priority do
      :critical -> 2.0
      :high -> 1.5
      :normal -> 1.0
      :low -> 0.8
    end
    
    # Adjust for capabilities
    capability_factor = length(transaction.required_capabilities || []) + 1
    
    base_variety * priority_multiplier * capability_factor
  end
  
  @doc """
  Calculates the output variety of a transaction result.
  
  This helps measure how well the system handled the input variety.
  """
  def calculate_output_variety(result) do
    case result do
      {:ok, output} ->
        calculate_result_variety(output)
        
      {:error, _reason} ->
        # Error represents minimal variety handling
        0.1
        
      _ ->
        1.0
    end
  end
  
  @doc """
  Checks if a transaction has expired based on its deadline.
  """
  def expired?(%Transaction{deadline: nil}), do: false
  
  def expired?(%Transaction{deadline: deadline}) do
    DateTime.compare(DateTime.utc_now(), deadline) == :gt
  end
  
  @doc """
  Gets the remaining time until deadline in milliseconds.
  """
  def time_remaining(%Transaction{deadline: nil}), do: :infinity
  
  def time_remaining(%Transaction{deadline: deadline}) do
    diff = DateTime.diff(deadline, DateTime.utc_now(), :millisecond)
    max(0, diff)
  end
  
  @doc """
  Serializes a transaction for storage or transmission.
  """
  def serialize(%Transaction{} = transaction) do
    %{
      id: transaction.id,
      type: transaction.type,
      payload: transaction.payload,
      priority: transaction.priority,
      required_capabilities: transaction.required_capabilities,
      source: transaction.source,
      created_at: DateTime.to_iso8601(transaction.created_at),
      deadline: transaction.deadline && DateTime.to_iso8601(transaction.deadline),
      metadata: transaction.metadata
    }
  end
  
  @doc """
  Deserializes a transaction from storage format.
  """
  def deserialize(data) when is_map(data) do
    %Transaction{
      id: data.id,
      type: String.to_existing_atom(to_string(data.type)),
      payload: data.payload,
      priority: String.to_existing_atom(to_string(data.priority || :normal)),
      required_capabilities: Enum.map(data.required_capabilities || [], &String.to_existing_atom(to_string(&1))),
      source: parse_source(data.source),
      created_at: DateTime.from_iso8601!(data.created_at),
      deadline: data.deadline && DateTime.from_iso8601!(data.deadline),
      metadata: data.metadata || %{}
    }
  end
  
  # Private Functions
  
  defp generate_id do
    "txn_#{:erlang.unique_integer([:positive])}_#{System.os_time(:nanosecond)}"
  end
  
  defp validate_type(%Transaction{type: type}) when is_atom(type), do: :ok
  defp validate_type(_), do: {:error, :invalid_type}
  
  defp validate_payload(%Transaction{payload: nil}), do: {:error, :missing_payload}
  defp validate_payload(%Transaction{}), do: :ok
  
  defp validate_deadline(%Transaction{deadline: nil}), do: :ok
  defp validate_deadline(%Transaction{deadline: deadline, created_at: created_at}) do
    if DateTime.compare(deadline, created_at) == :gt do
      :ok
    else
      {:error, :invalid_deadline}
    end
  end
  
  defp calculate_compute_variety(payload) do
    # Estimate variety based on computational complexity
    case payload do
      %{operation: :factorial, params: %{n: n}} ->
        # Factorial has linear variety with input size
        n * 1.0
        
      %{operation: :fibonacci, params: %{n: n}} ->
        # Fibonacci has exponential variety
        :math.pow(1.618, n)
        
      %{operation: :sort, params: %{data: data}} when is_list(data) ->
        # Sorting variety is n log n
        n = length(data)
        n * :math.log(max(n, 2))
        
      _ ->
        # Default compute variety
        10.0
    end
  end
  
  defp calculate_data_variety(payload) do
    # Estimate variety based on data complexity
    case payload do
      %{operation: :store, data: data} ->
        estimate_data_complexity(data)
        
      %{operation: :retrieve, data: %{key: _}} ->
        # Retrieval has low variety
        2.0
        
      %{operation: :transform, data: data} ->
        # Transformation variety depends on data
        estimate_data_complexity(data) * 1.5
        
      _ ->
        5.0
    end
  end
  
  defp calculate_io_variety(payload) do
    # Estimate variety based on I/O complexity
    case payload do
      %{operation: :read} ->
        3.0
        
      %{operation: :write, data: data} ->
        estimate_data_complexity(data)
        
      %{operation: :stream} ->
        # Streaming has high variety
        50.0
        
      _ ->
        5.0
    end
  end
  
  defp calculate_result_variety(output) do
    # Estimate variety of the output
    case output do
      data when is_map(data) ->
        map_size(data) * 2.0
        
      data when is_list(data) ->
        length(data) * 1.5
        
      data when is_binary(data) ->
        byte_size(data) / 100.0
        
      _ ->
        1.0
    end
  end
  
  defp estimate_data_complexity(data) do
    # Recursively estimate data structure complexity
    case data do
      data when is_map(data) ->
        map_size(data) + Enum.reduce(data, 0, fn {_k, v}, acc ->
          acc + estimate_data_complexity(v) / 10
        end)
        
      data when is_list(data) ->
        length(data) + Enum.reduce(data, 0, fn item, acc ->
          acc + estimate_data_complexity(item) / 10
        end)
        
      data when is_binary(data) ->
        byte_size(data) / 100
        
      data when is_number(data) ->
        :math.log(abs(data) + 1)
        
      _ ->
        1.0
    end
  end
  
  defp parse_source(source) when is_binary(source) do
    try do
      String.to_existing_atom(source)
    rescue
      _ -> source
    end
  end
  defp parse_source(source), do: source
end