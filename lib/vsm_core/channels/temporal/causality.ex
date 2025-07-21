defmodule VSMCore.Channels.Temporal.Causality do
  @moduledoc """
  Causal chain analysis and temporal correlation for the variety channel.
  
  This module analyzes causal relationships between variety changes across
  different timescales and identifies temporal correlations that may indicate
  cause-effect relationships in the system.
  
  ## Analysis Methods
  
  - **Granger Causality**: Tests if one time series helps predict another
  - **Transfer Entropy**: Measures information flow between variables
  - **Cross-Correlation**: Identifies lagged relationships
  - **Causal Graph Construction**: Builds directed causal networks
  """
  
  alias VSMCore.Channels.Temporal.{Timescales, Patterns}
  
  @type causal_link :: %{
    from: atom(),
    to: atom(),
    strength: float(),
    lag: integer(),
    confidence: float(),
    type: atom()
  }
  
  @type causal_chain :: %{
    id: String.t(),
    links: list(causal_link()),
    root_cause: atom(),
    effects: list(atom()),
    total_lag: integer(),
    detected_at: DateTime.t()
  }
  
  @type correlation :: %{
    variables: {atom(), atom()},
    coefficient: float(),
    lag: integer(),
    significance: float()
  }
  
  @doc """
  Analyzes causal chains in the temporal data.
  """
  @spec analyze_chains(list(map()), map()) :: list(causal_chain())
  def analyze_chains(buffer, patterns) do
    # Group data by dimension
    dimensional_data = group_by_dimension(buffer)
    
    # Find causal links
    causal_links = detect_causal_links(dimensional_data)
    
    # Construct causal chains
    chains = construct_causal_chains(causal_links)
    
    # Validate with patterns
    validate_chains_with_patterns(chains, patterns)
  end
  
  @doc """
  Analyzes correlations across timescales.
  """
  @spec analyze_correlations(Timescales.t()) :: list(correlation())
  def analyze_correlations(timescales) do
    scales = [:real_time, :minute, :hour, :day]
    
    # Cross-scale correlations
    cross_scale_correlations = analyze_cross_scale_correlations(timescales, scales)
    
    # Within-scale correlations
    within_scale_correlations = analyze_within_scale_correlations(timescales, scales)
    
    (cross_scale_correlations ++ within_scale_correlations)
    |> filter_significant_correlations()
    |> rank_by_significance()
  end
  
  @doc """
  Tests for Granger causality between two time series.
  """
  @spec granger_causality_test(list(float()), list(float()), pos_integer()) :: map()
  def granger_causality_test(series_x, series_y, max_lag \\ 10) do
    if length(series_x) < 20 or length(series_y) < 20 do
      %{causality: false, f_statistic: 0.0, p_value: 1.0, optimal_lag: 0}
    else
      # Find optimal lag
      optimal_lag = find_optimal_lag(series_x, series_y, max_lag)
      
      # Perform F-test
      f_statistic = calculate_granger_f_statistic(series_x, series_y, optimal_lag)
      p_value = calculate_p_value(f_statistic, length(series_x), optimal_lag)
      
      %{
        causality: p_value < 0.05,
        f_statistic: f_statistic,
        p_value: p_value,
        optimal_lag: optimal_lag
      }
    end
  end
  
  @doc """
  Calculates transfer entropy between time series.
  """
  @spec transfer_entropy(list(float()), list(float()), pos_integer()) :: float()
  def transfer_entropy(source, target, lag \\ 1) do
    if length(source) < lag + 10 or length(target) < lag + 10 do
      0.0
    else
      # Discretize the series
      source_discrete = discretize_series(source)
      target_discrete = discretize_series(target)
      
      # Calculate conditional entropies
      h_future_given_past = conditional_entropy(target_discrete, target_discrete, lag)
      h_future_given_both = conditional_entropy_with_source(
        target_discrete,
        target_discrete,
        source_discrete,
        lag
      )
      
      # Transfer entropy is the reduction in uncertainty
      max(h_future_given_past - h_future_given_both, 0.0)
    end
  end
  
  @doc """
  Builds a causal graph from detected relationships.
  """
  @spec build_causal_graph(list(causal_link())) :: map()
  def build_causal_graph(causal_links) do
    # Build adjacency matrix
    nodes = extract_nodes(causal_links)
    adjacency = build_adjacency_matrix(causal_links, nodes)
    
    # Find strongly connected components
    components = find_strongly_connected_components(adjacency, nodes)
    
    # Identify feedback loops
    loops = detect_feedback_loops(adjacency, nodes)
    
    %{
      nodes: nodes,
      edges: causal_links,
      adjacency: adjacency,
      components: components,
      feedback_loops: loops,
      root_causes: find_root_causes(causal_links, nodes),
      terminal_effects: find_terminal_effects(causal_links, nodes)
    }
  end
  
  # Private Functions
  
  defp group_by_dimension(buffer) do
    buffer
    |> Enum.flat_map(fn metric ->
      Enum.map(metric.dimensions, fn {dim, value} ->
        {dim, %{timestamp: metric.timestamp, value: value, variety: metric.value}}
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
  
  defp detect_causal_links(dimensional_data) do
    dimensions = Map.keys(dimensional_data)
    
    for from_dim <- dimensions,
        to_dim <- dimensions,
        from_dim != to_dim do
      
      from_series = extract_time_series(dimensional_data[from_dim])
      to_series = extract_time_series(dimensional_data[to_dim])
      
      if valid_series?(from_series) and valid_series?(to_series) do
        analyze_causal_relationship(from_dim, to_dim, from_series, to_series)
      else
        nil
      end
    end
    |> Enum.filter(&(&1 != nil))
    |> Enum.filter(&(&1.strength > 0.3))  # Filter weak links
  end
  
  defp extract_time_series(data_points) do
    data_points
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.map(& &1.variety)
  end
  
  defp valid_series?(series) do
    length(series) >= 10 and Enum.any?(series, &(&1 != 0))
  end
  
  defp analyze_causal_relationship(from_dim, to_dim, from_series, to_series) do
    # Multiple causality tests
    granger_result = granger_causality_test(from_series, to_series)
    te_value = transfer_entropy(from_series, to_series)
    correlation = calculate_lagged_correlation(from_series, to_series, granger_result.optimal_lag)
    
    # Combine evidence
    strength = combine_causality_evidence(granger_result, te_value, correlation)
    
    if strength > 0 do
      %{
        from: from_dim,
        to: to_dim,
        strength: strength,
        lag: granger_result.optimal_lag,
        confidence: calculate_confidence(granger_result, te_value),
        type: classify_causal_type(granger_result, te_value, correlation)
      }
    else
      nil
    end
  end
  
  defp find_optimal_lag(series_x, series_y, max_lag) do
    1..max_lag
    |> Enum.map(fn lag ->
      aic = calculate_aic(series_x, series_y, lag)
      {lag, aic}
    end)
    |> Enum.min_by(&elem(&1, 1))
    |> elem(0)
  end
  
  defp calculate_aic(series_x, series_y, lag) do
    # Akaike Information Criterion for lag selection
    n = length(series_y) - lag
    
    if n <= lag * 2 + 1 do
      Float.max_finite()
    else
      rss = calculate_residual_sum_squares(series_x, series_y, lag)
      n * :math.log(rss / n) + 2 * lag * 2
    end
  end
  
  defp calculate_residual_sum_squares(series_x, series_y, lag) do
    # Fit AR model and calculate RSS
    y_lagged = create_lagged_matrix(series_y, lag)
    x_lagged = create_lagged_matrix(series_x, lag)
    
    y_values = Enum.drop(series_y, lag)
    
    # Simple linear regression
    coefficients = estimate_coefficients(y_lagged ++ x_lagged, y_values)
    predictions = make_predictions(y_lagged ++ x_lagged, coefficients)
    
    Enum.zip(y_values, predictions)
    |> Enum.map(fn {actual, pred} -> (actual - pred) * (actual - pred) end)
    |> Enum.sum()
  end
  
  defp create_lagged_matrix(series, lag) do
    0..(lag - 1)
    |> Enum.map(fn l ->
      series
      |> Enum.drop(lag - l - 1)
      |> Enum.take(length(series) - lag)
    end)
  end
  
  defp estimate_coefficients(x_matrix, y_values) do
    # Simplified OLS estimation
    if Enum.empty?(x_matrix) or Enum.empty?(y_values) do
      []
    else
      # For simplicity, return average-based coefficients
      y_mean = Enum.sum(y_values) / length(y_values)
      
      x_matrix
      |> Enum.map(fn x_column ->
        x_mean = Enum.sum(x_column) / length(x_column)
        
        covariance = 
          Enum.zip(x_column, y_values)
          |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
          |> Enum.sum()
          |> Kernel./(length(x_column))
        
        variance = 
          x_column
          |> Enum.map(fn x -> (x - x_mean) * (x - x_mean) end)
          |> Enum.sum()
          |> Kernel./(length(x_column))
        
        if variance > 0, do: covariance / variance, else: 0.0
      end)
    end
  end
  
  defp make_predictions(x_matrix, coefficients) do
    if Enum.empty?(x_matrix) or Enum.empty?(coefficients) do
      []
    else
      # Matrix multiplication for predictions
      0..(length(List.first(x_matrix)) - 1)
      |> Enum.map(fn i ->
        Enum.zip(x_matrix, coefficients)
        |> Enum.map(fn {x_column, coef} ->
          Enum.at(x_column, i, 0) * coef
        end)
        |> Enum.sum()
      end)
    end
  end
  
  defp calculate_granger_f_statistic(series_x, series_y, lag) do
    # Calculate F-statistic for Granger causality
    n = length(series_y) - lag
    
    # Restricted model (only Y lags)
    rss_restricted = calculate_residual_sum_squares([], series_y, lag)
    
    # Unrestricted model (Y and X lags)
    rss_unrestricted = calculate_residual_sum_squares(series_x, series_y, lag)
    
    if rss_unrestricted > 0 and n > lag * 2 do
      ((rss_restricted - rss_unrestricted) / lag) / (rss_unrestricted / (n - 2 * lag))
    else
      0.0
    end
  end
  
  defp calculate_p_value(f_statistic, n, lag) do
    # Approximate p-value using F-distribution
    if f_statistic <= 0 do
      1.0
    else
      # Simplified p-value calculation
      df1 = lag
      df2 = n - 2 * lag
      
      # Use approximation for F-distribution
      if df2 > 0 do
        x = df2 / (df2 + df1 * f_statistic)
        incomplete_beta(x, df2 / 2, df1 / 2)
      else
        1.0
      end
    end
  end
  
  defp incomplete_beta(x, a, b) do
    # Simplified incomplete beta function approximation
    if x <= 0 do
      0.0
    else
      if x >= 1 do
        1.0
      else
        # Use series expansion for small x
        if x < (a + 1) / (a + b + 2) do
          bt = :math.exp(
            a * :math.log(x) + b * :math.log(1 - x) -
            log_beta(a, b)
          )
          bt * continued_fraction_beta(x, a, b) / a
        else
          1 - incomplete_beta(1 - x, b, a)
        end
      end
    end
  end
  
  defp log_beta(a, b) do
    :math.lgamma(a) + :math.lgamma(b) - :math.lgamma(a + b)
  end
  
  defp continued_fraction_beta(x, a, b, max_iter \\ 100) do
    # Continued fraction expansion
    eps = 1.0e-10
    
    {result, _} =
      1..max_iter
      |> Enum.reduce_while({1.0, 1.0}, fn m, {h, _} ->
        m2 = 2 * m
        aa = m * (b - m) * x / ((a + m2 - 1) * (a + m2))
        h = 1 + aa * h
        
        if abs(aa) < eps do
          {:halt, {h, 0}}
        else
          aa2 = -(a + m) * (a + b + m) * x / ((a + m2) * (a + m2 + 1))
          h2 = 1 + aa2 / h
          
          if abs(aa2 / h2) < eps do
            {:halt, {h * h2, 0}}
          else
            {:cont, {h * h2, 0}}
          end
        end
      end)
    
    result
  end
  
  defp discretize_series(series, bins \\ 10) do
    min_val = Enum.min(series)
    max_val = Enum.max(series)
    range = max_val - min_val
    
    if range > 0 do
      series
      |> Enum.map(fn value ->
        bin = min(floor((value - min_val) / range * bins), bins - 1)
        max(bin, 0)
      end)
    else
      List.duplicate(0, length(series))
    end
  end
  
  defp conditional_entropy(future, past, lag) do
    # H(Future|Past)
    joint_probs = calculate_joint_probabilities(
      Enum.drop(future, lag),
      Enum.take(past, length(past) - lag)
    )
    
    calculate_entropy_from_probs(joint_probs)
  end
  
  defp conditional_entropy_with_source(future, past, source, lag) do
    # H(Future|Past,Source)
    future_vals = Enum.drop(future, lag)
    past_vals = Enum.take(past, length(past) - lag)
    source_vals = Enum.take(source, length(source) - lag)
    
    # Calculate 3-way joint probabilities
    joint_probs = calculate_triple_joint_probabilities(future_vals, past_vals, source_vals)
    
    calculate_entropy_from_probs(joint_probs)
  end
  
  defp calculate_joint_probabilities(series1, series2) do
    n = min(length(series1), length(series2))
    
    if n == 0 do
      %{}
    else
      Enum.zip(Enum.take(series1, n), Enum.take(series2, n))
      |> Enum.frequencies()
      |> Enum.map(fn {key, count} -> {key, count / n} end)
      |> Enum.into(%{})
    end
  end
  
  defp calculate_triple_joint_probabilities(series1, series2, series3) do
    n = Enum.min([length(series1), length(series2), length(series3)])
    
    if n == 0 do
      %{}
    else
      [Enum.take(series1, n), Enum.take(series2, n), Enum.take(series3, n)]
      |> Enum.zip()
      |> Enum.map(fn {a, b, c} -> {a, b, c} end)
      |> Enum.frequencies()
      |> Enum.map(fn {key, count} -> {key, count / n} end)
      |> Enum.into(%{})
    end
  end
  
  defp calculate_entropy_from_probs(prob_map) do
    prob_map
    |> Map.values()
    |> Enum.reduce(0.0, fn p, entropy ->
      if p > 0 do
        entropy - p * :math.log2(p)
      else
        entropy
      end
    end)
  end
  
  defp calculate_lagged_correlation(series1, series2, lag) do
    if lag >= length(series1) or lag >= length(series2) do
      0.0
    else
      s1_lagged = Enum.drop(series1, lag)
      s2_no_lag = Enum.take(series2, length(series2) - lag)
      
      calculate_correlation(s1_lagged, s2_no_lag)
    end
  end
  
  defp calculate_correlation(series1, series2) do
    n = min(length(series1), length(series2))
    
    if n < 2 do
      0.0
    else
      s1 = Enum.take(series1, n)
      s2 = Enum.take(series2, n)
      
      mean1 = Enum.sum(s1) / n
      mean2 = Enum.sum(s2) / n
      
      {cov, var1, var2} =
        Enum.zip(s1, s2)
        |> Enum.reduce({0.0, 0.0, 0.0}, fn {x1, x2}, {c, v1, v2} ->
          d1 = x1 - mean1
          d2 = x2 - mean2
          {c + d1 * d2, v1 + d1 * d1, v2 + d2 * d2}
        end)
      
      if var1 > 0 and var2 > 0 do
        cov / :math.sqrt(var1 * var2)
      else
        0.0
      end
    end
  end
  
  defp combine_causality_evidence(granger_result, te_value, correlation) do
    # Weight different evidence types
    granger_weight = if granger_result.causality, do: 0.5, else: 0.0
    te_weight = min(te_value * 2, 1.0) * 0.3
    corr_weight = abs(correlation) * 0.2
    
    granger_weight + te_weight + corr_weight
  end
  
  defp calculate_confidence(granger_result, te_value) do
    # Confidence based on p-value and transfer entropy
    p_confidence = 1 - granger_result.p_value
    te_confidence = min(te_value * 5, 1.0)
    
    (p_confidence + te_confidence) / 2
  end
  
  defp classify_causal_type(granger_result, te_value, correlation) do
    cond do
      granger_result.causality and te_value > 0.2 -> :strong_causal
      granger_result.causality -> :granger_causal
      te_value > 0.3 -> :information_flow
      abs(correlation) > 0.7 -> :correlated
      true -> :weak_association
    end
  end
  
  defp construct_causal_chains(causal_links) do
    # Group links into chains
    graph = build_directed_graph(causal_links)
    
    # Find all paths
    all_paths = find_all_causal_paths(graph)
    
    # Convert paths to chains
    all_paths
    |> Enum.map(&path_to_chain(&1, causal_links))
    |> Enum.filter(&valid_chain?/1)
    |> assign_chain_ids()
  end
  
  defp build_directed_graph(causal_links) do
    causal_links
    |> Enum.reduce(%{}, fn link, graph ->
      Map.update(graph, link.from, [link], fn existing ->
        [link | existing]
      end)
    end)
  end
  
  defp find_all_causal_paths(graph) do
    nodes = Map.keys(graph)
    
    # Find paths starting from each node
    nodes
    |> Enum.flat_map(fn start_node ->
      find_paths_from_node(graph, start_node, [], MapSet.new())
    end)
    |> Enum.uniq()
    |> Enum.sort_by(&length/1, :desc)
  end
  
  defp find_paths_from_node(graph, current_node, current_path, visited) do
    if MapSet.member?(visited, current_node) do
      # Cycle detected
      [Enum.reverse([current_node | current_path])]
    else
      new_visited = MapSet.put(visited, current_node)
      new_path = [current_node | current_path]
      
      case Map.get(graph, current_node, []) do
        [] ->
          # Terminal node
          [Enum.reverse(new_path)]
          
        outgoing_links ->
          # Continue exploring
          outgoing_links
          |> Enum.flat_map(fn link ->
            find_paths_from_node(graph, link.to, new_path, new_visited)
          end)
      end
    end
  end
  
  defp path_to_chain(path, causal_links) do
    if length(path) < 2 do
      nil
    else
      # Convert path to chain links
      chain_links =
        path
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [from, to] ->
          Enum.find(causal_links, fn link ->
            link.from == from and link.to == to
          end)
        end)
        |> Enum.filter(&(&1 != nil))
      
      if Enum.empty?(chain_links) do
        nil
      else
        %{
          links: chain_links,
          root_cause: List.first(path),
          effects: tl(path),
          total_lag: Enum.sum(Enum.map(chain_links, & &1.lag)),
          detected_at: DateTime.utc_now()
        }
      end
    end
  end
  
  defp valid_chain?(nil), do: false
  defp valid_chain?(chain) do
    length(chain.links) >= 1 and chain.total_lag > 0
  end
  
  defp assign_chain_ids(chains) do
    chains
    |> Enum.with_index()
    |> Enum.map(fn {chain, idx} ->
      Map.put(chain, :id, "chain_#{idx}_#{:erlang.unique_integer([:positive])}")
    end)
  end
  
  defp validate_chains_with_patterns(chains, patterns) do
    # Enhance chains with pattern information
    dominant_pattern = patterns[:dominant_pattern]
    
    chains
    |> Enum.map(fn chain ->
      if dominant_pattern do
        validate_chain_timing(chain, dominant_pattern)
      else
        chain
      end
    end)
  end
  
  defp validate_chain_timing(chain, pattern) do
    case pattern.type do
      :cyclic ->
        # Check if chain lag matches pattern period
        if rem(chain.total_lag, pattern.parameters.period) < 2 do
          Map.put(chain, :pattern_aligned, true)
        else
          chain
        end
        
      _ ->
        chain
    end
  end
  
  defp analyze_cross_scale_correlations(timescales, scales) do
    for scale1 <- scales,
        scale2 <- scales,
        scale1 != scale2 do
      
      window1 = Map.get(timescales, scale1)
      window2 = Map.get(timescales, scale2)
      
      if window1 && window2 && length(window1.data) >= 10 && length(window2.data) >= 10 do
        analyze_window_correlation(window1, window2, scale1, scale2)
      else
        nil
      end
    end
    |> Enum.filter(&(&1 != nil))
  end
  
  defp analyze_within_scale_correlations(timescales, scales) do
    scales
    |> Enum.flat_map(fn scale ->
      window = Map.get(timescales, scale)
      
      if window && length(window.data) >= 20 do
        analyze_dimension_correlations(window, scale)
      else
        []
      end
    end)
  end
  
  defp analyze_window_correlation(window1, window2, scale1, scale2) do
    series1 = Enum.map(window1.data, & &1.value)
    series2 = Enum.map(window2.data, & &1.value)
    
    # Resample to common timeframe
    {aligned1, aligned2} = align_time_series(series1, series2)
    
    if length(aligned1) >= 10 do
      correlation = calculate_correlation(aligned1, aligned2)
      
      %{
        variables: {scale1, scale2},
        coefficient: correlation,
        lag: 0,  # Cross-scale doesn't use lag
        significance: calculate_significance(correlation, length(aligned1))
      }
    else
      nil
    end
  end
  
  defp align_time_series(series1, series2) do
    # Simple alignment - take minimum length
    min_len = min(length(series1), length(series2))
    
    {
      Enum.take(series1, min_len),
      Enum.take(series2, min_len)
    }
  end
  
  defp analyze_dimension_correlations(window, scale) do
    # Extract dimension-specific time series
    dimension_series =
      window.data
      |> Enum.flat_map(fn metric ->
        Enum.map(metric.dimensions, fn {dim, value} ->
          {dim, metric.timestamp, value}
        end)
      end)
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.map(fn {dim, entries} ->
        values = entries |> Enum.sort_by(&elem(&1, 1)) |> Enum.map(&elem(&1, 2))
        {dim, values}
      end)
      |> Enum.filter(fn {_dim, values} -> length(values) >= 10 end)
    
    # Calculate pairwise correlations
    for {dim1, series1} <- dimension_series,
        {dim2, series2} <- dimension_series,
        dim1 < dim2 do
      
      correlation = calculate_correlation(series1, series2)
      
      %{
        variables: {{scale, dim1}, {scale, dim2}},
        coefficient: correlation,
        lag: 0,
        significance: calculate_significance(correlation, length(series1))
      }
    end
  end
  
  defp calculate_significance(correlation, n) do
    if n < 3 do
      0.0
    else
      # t-statistic for correlation significance
      t_stat = correlation * :math.sqrt((n - 2) / (1 - correlation * correlation))
      df = n - 2
      
      # Approximate p-value
      p_value = 2 * (1 - student_t_cdf(abs(t_stat), df))
      1 - p_value
    end
  end
  
  defp student_t_cdf(t, df) do
    # Approximation of Student's t CDF
    x = df / (df + t * t)
    0.5 * incomplete_beta(x, df / 2, 0.5)
  end
  
  defp filter_significant_correlations(correlations) do
    correlations
    |> Enum.filter(fn corr ->
      abs(corr.coefficient) > 0.3 and corr.significance > 0.95
    end)
  end
  
  defp rank_by_significance(correlations) do
    correlations
    |> Enum.sort_by(fn corr ->
      abs(corr.coefficient) * corr.significance
    end, :desc)
  end
  
  defp extract_nodes(causal_links) do
    causal_links
    |> Enum.flat_map(fn link -> [link.from, link.to] end)
    |> Enum.uniq()
  end
  
  defp build_adjacency_matrix(causal_links, nodes) do
    node_index = nodes |> Enum.with_index() |> Enum.into(%{})
    
    matrix =
      for i <- 0..(length(nodes) - 1) do
        for j <- 0..(length(nodes) - 1) do
          0.0
        end
      end
    
    # Fill matrix with link strengths
    causal_links
    |> Enum.reduce(matrix, fn link, mat ->
      i = Map.get(node_index, link.from)
      j = Map.get(node_index, link.to)
      
      if i && j do
        update_in(mat, [Access.at(i), Access.at(j)], fn _ -> link.strength end)
      else
        mat
      end
    end)
  end
  
  defp find_strongly_connected_components(adjacency, nodes) do
    # Tarjan's algorithm (simplified)
    n = length(nodes)
    
    if n == 0 do
      []
    else
      # For simplicity, return single component if graph is connected
      if is_connected?(adjacency) do
        [nodes]
      else
        # Basic component detection
        partition_graph(adjacency, nodes)
      end
    end
  end
  
  defp is_connected?(adjacency) do
    # Check if graph has path between all nodes
    n = length(adjacency)
    
    if n == 0 do
      true
    else
      # Simplified: check if any row has all zeros (isolated node)
      not Enum.any?(adjacency, fn row ->
        Enum.all?(row, &(&1 == 0))
      end)
    end
  end
  
  defp partition_graph(adjacency, nodes) do
    # Simple partitioning based on connectivity
    {components, _} =
      nodes
      |> Enum.with_index()
      |> Enum.reduce({[], MapSet.new()}, fn {node, idx}, {comps, visited} ->
        if MapSet.member?(visited, idx) do
          {comps, visited}
        else
          component = find_connected_nodes(adjacency, idx, MapSet.new())
          component_nodes = 
            component
            |> MapSet.to_list()
            |> Enum.map(fn i -> Enum.at(nodes, i) end)
          
          {[component_nodes | comps], MapSet.union(visited, component)}
        end
      end)
    
    components
  end
  
  defp find_connected_nodes(adjacency, start_idx, visited) do
    if MapSet.member?(visited, start_idx) do
      visited
    else
      new_visited = MapSet.put(visited, start_idx)
      
      # Find all nodes reachable from start_idx
      adjacency
      |> Enum.at(start_idx)
      |> Enum.with_index()
      |> Enum.reduce(new_visited, fn {weight, idx}, vis ->
        if weight > 0 do
          find_connected_nodes(adjacency, idx, vis)
        else
          vis
        end
      end)
    end
  end
  
  defp detect_feedback_loops(adjacency, nodes) do
    # Find cycles in the graph
    n = length(nodes)
    
    if n == 0 do
      []
    else
      # Simple cycle detection
      0..(n - 1)
      |> Enum.flat_map(fn start ->
        find_cycles_from_node(adjacency, start, [start], MapSet.new([start]))
      end)
      |> Enum.uniq()
      |> Enum.map(fn cycle_indices ->
        Enum.map(cycle_indices, fn idx -> Enum.at(nodes, idx) end)
      end)
    end
  end
  
  defp find_cycles_from_node(adjacency, current, path, visited) do
    row = Enum.at(adjacency, current)
    
    row
    |> Enum.with_index()
    |> Enum.flat_map(fn {weight, next} ->
      cond do
        weight == 0 ->
          []
          
        next == List.first(path) and length(path) > 2 ->
          # Cycle found
          [path]
          
        MapSet.member?(visited, next) ->
          []
          
        true ->
          find_cycles_from_node(
            adjacency,
            next,
            path ++ [next],
            MapSet.put(visited, next)
          )
      end
    end)
  end
  
  defp find_root_causes(causal_links, nodes) do
    # Nodes with no incoming edges
    targets = MapSet.new(Enum.map(causal_links, & &1.to))
    
    nodes
    |> Enum.filter(fn node ->
      not MapSet.member?(targets, node)
    end)
  end
  
  defp find_terminal_effects(causal_links, nodes) do
    # Nodes with no outgoing edges
    sources = MapSet.new(Enum.map(causal_links, & &1.from))
    
    nodes
    |> Enum.filter(fn node ->
      not MapSet.member?(sources, node)
    end)
  end
end