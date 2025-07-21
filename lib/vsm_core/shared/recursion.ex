defmodule VsmCore.Shared.Recursion do
  @moduledoc """
  Implements recursive structure management for Viable System Model.
  
  Manages the fractal nature of VSM where each System 1 unit can itself be
  a complete VSM, enabling navigation between levels and maintaining context
  across recursive structures.
  """
  
  @type recursion_level :: %{
    level: non_neg_integer(),
    context: map(),
    parent: String.t() | nil,
    children: [String.t()],
    system_type: atom()
  }
  
  @type recursion_path :: [String.t()]
  
  @type navigation_result :: {:ok, recursion_level} | {:error, atom()}
  
  @doc """
  Initializes a recursive VSM structure.
  """
  def initialize_structure(root_config \\ %{}) do
    root_id = Map.get(root_config, :id, generate_system_id())
    
    %{
      root: root_id,
      levels: %{
        root_id => %{
          level: 0,
          context: Map.get(root_config, :context, %{}),
          parent: nil,
          children: [],
          system_type: Map.get(root_config, :type, :complete_vsm),
          metadata: %{
            created_at: System.system_time(:millisecond),
            last_modified: System.system_time(:millisecond)
          }
        }
      },
      active_path: [root_id],
      max_depth: Map.get(root_config, :max_depth, 10)
    }
  end
  
  @doc """
  Creates a new recursive level (subsystem).
  """
  def create_level(structure, parent_id, level_config \\ %{}) do
    with {:ok, parent_level} <- get_level(structure, parent_id),
         :ok <- validate_depth(structure, parent_level.level),
         new_id <- Map.get(level_config, :id, generate_system_id()) do
      
      new_level = %{
        level: parent_level.level + 1,
        context: merge_contexts(parent_level.context, Map.get(level_config, :context, %{})),
        parent: parent_id,
        children: [],
        system_type: Map.get(level_config, :type, :subsystem),
        metadata: %{
          created_at: System.system_time(:millisecond),
          last_modified: System.system_time(:millisecond),
          created_by: parent_id
        }
      }
      
      updated_structure = 
        structure
        |> put_in([:levels, new_id], new_level)
        |> update_in([:levels, parent_id, :children], &(&1 ++ [new_id]))
        |> update_in([:levels, parent_id, :metadata, :last_modified], fn _ -> 
          System.system_time(:millisecond) 
        end)
      
      {:ok, updated_structure, new_id}
    end
  end
  
  @doc """
  Navigates to a specific level in the recursive structure.
  """
  def navigate_to(structure, target_id) do
    case get_level(structure, target_id) do
      {:ok, level} ->
        path = build_path_to(structure, target_id)
        updated_structure = Map.put(structure, :active_path, path)
        {:ok, updated_structure, level}
        
      error -> error
    end
  end
  
  @doc """
  Navigates up one level in the hierarchy.
  """
  def navigate_up(structure) do
    current_path = Map.get(structure, :active_path, [])
    
    case current_path do
      [_root] -> 
        {:error, :at_root}
        
      path when length(path) > 1 ->
        new_path = Enum.drop(path, -1)
        parent_id = List.last(new_path)
        
        case get_level(structure, parent_id) do
          {:ok, level} ->
            updated_structure = Map.put(structure, :active_path, new_path)
            {:ok, updated_structure, level}
            
          error -> error
        end
        
      _ ->
        {:error, :invalid_path}
    end
  end
  
  @doc """
  Navigates down to a child level.
  """
  def navigate_down(structure, child_id) do
    current_id = get_current_id(structure)
    
    with {:ok, current_level} <- get_level(structure, current_id),
         true <- child_id in current_level.children,
         {:ok, child_level} <- get_level(structure, child_id) do
      
      new_path = Map.get(structure, :active_path, []) ++ [child_id]
      updated_structure = Map.put(structure, :active_path, new_path)
      
      {:ok, updated_structure, child_level}
    else
      false -> {:error, :not_a_child}
      error -> error
    end
  end
  
  @doc """
  Gets the current active level.
  """
  def get_current_level(structure) do
    current_id = get_current_id(structure)
    get_level(structure, current_id)
  end
  
  @doc """
  Updates context at a specific level.
  """
  def update_context(structure, level_id, context_updates) do
    with {:ok, level} <- get_level(structure, level_id) do
      updated_context = Map.merge(level.context, context_updates)
      
      updated_structure = 
        structure
        |> put_in([:levels, level_id, :context], updated_context)
        |> update_in([:levels, level_id, :metadata, :last_modified], fn _ -> 
          System.system_time(:millisecond) 
        end)
      
      # Propagate context changes if needed
      updated_structure = 
        if Map.get(context_updates, :propagate, false) do
          propagate_context_changes(updated_structure, level_id, context_updates)
        else
          updated_structure
        end
      
      {:ok, updated_structure}
    end
  end
  
  @doc """
  Switches context between recursive levels while maintaining state.
  """
  def switch_context(structure, from_id, to_id, options \\ []) do
    preserve_state = Keyword.get(options, :preserve_state, true)
    transition_data = Keyword.get(options, :transition_data, %{})
    
    with {:ok, from_level} <- get_level(structure, from_id),
         {:ok, to_level} <- get_level(structure, to_id),
         {:ok, path} <- find_path_between(structure, from_id, to_id) do
      
      # Save current state if requested
      structure = 
        if preserve_state do
          save_level_state(structure, from_id, from_level)
        else
          structure
        end
      
      # Create context transition
      transition_context = create_transition_context(
        from_level,
        to_level,
        path,
        transition_data
      )
      
      # Update target level with transition context
      structure = 
        structure
        |> update_in([:levels, to_id, :context], &Map.merge(&1, transition_context))
        |> Map.put(:active_path, build_path_to(structure, to_id))
      
      # Record transition
      structure = record_transition(structure, from_id, to_id, transition_data)
      
      {:ok, structure, to_level}
    end
  end
  
  @doc """
  Gets the complete hierarchy tree from a given level.
  """
  def get_hierarchy_tree(structure, root_id \\ nil, options \\ []) do
    root_id = root_id || Map.get(structure, :root)
    max_depth = Keyword.get(options, :max_depth, 10)
    include_metadata = Keyword.get(options, :include_metadata, false)
    
    build_tree(structure, root_id, 0, max_depth, include_metadata)
  end
  
  @doc """
  Finds all levels matching a predicate function.
  """
  def find_levels(structure, predicate_fn) do
    structure.levels
    |> Enum.filter(fn {_id, level} -> predicate_fn.(level) end)
    |> Enum.map(fn {id, level} -> {id, level} end)
  end
  
  @doc """
  Calculates metrics for the recursive structure.
  """
  def calculate_metrics(structure) do
    levels = Map.get(structure, :levels, %{})
    
    depth_map = calculate_depths(structure)
    max_depth = depth_map |> Map.values() |> Enum.max(fn -> 0 end)
    
    %{
      total_levels: map_size(levels),
      max_depth: max_depth,
      average_children: calculate_average_children(levels),
      depth_distribution: calculate_depth_distribution(depth_map),
      branching_factor: calculate_branching_factor(levels),
      complexity_index: calculate_complexity_index(structure)
    }
  end
  
  @doc """
  Validates the integrity of the recursive structure.
  """
  def validate_structure(structure) do
    levels = Map.get(structure, :levels, %{})
    errors = []
    
    # Check for orphaned nodes
    errors = errors ++ check_orphaned_nodes(levels)
    
    # Check for circular references
    errors = errors ++ check_circular_references(levels)
    
    # Check depth constraints
    errors = errors ++ check_depth_constraints(structure)
    
    # Check parent-child consistency
    errors = errors ++ check_parent_child_consistency(levels)
    
    if Enum.empty?(errors) do
      :ok
    else
      {:error, errors}
    end
  end
  
  @doc """
  Prunes empty or inactive levels from the structure.
  """
  def prune_structure(structure, options \\ []) do
    inactive_threshold = Keyword.get(options, :inactive_threshold, 30 * 24 * 60 * 60 * 1000)  # 30 days
    preserve_depth = Keyword.get(options, :preserve_depth, 1)
    
    current_time = System.system_time(:millisecond)
    
    levels_to_prune = 
      structure.levels
      |> Enum.filter(fn {id, level} ->
        # Don't prune root or minimum depth
        id != structure.root and
        level.level > preserve_depth and
        Enum.empty?(level.children) and
        (current_time - level.metadata.last_modified) > inactive_threshold
      end)
      |> Enum.map(fn {id, _} -> id end)
    
    pruned_structure = 
      Enum.reduce(levels_to_prune, structure, fn id, acc ->
        remove_level(acc, id)
      end)
    
    {:ok, pruned_structure, length(levels_to_prune)}
  end
  
  @doc """
  Merges two recursive structures.
  """
  def merge_structures(structure1, structure2, merge_point_id, options \\ []) do
    conflict_resolution = Keyword.get(options, :conflict_resolution, :error)
    
    with {:ok, merge_point} <- get_level(structure1, merge_point_id),
         {:ok, root2} <- get_level(structure2, structure2.root) do
      
      # Rebase structure2 IDs to avoid conflicts
      id_mapping = create_id_mapping(structure2)
      rebased_structure2 = rebase_structure(structure2, id_mapping)
      
      # Adjust levels in structure2
      adjusted_levels = 
        rebased_structure2.levels
        |> Enum.map(fn {new_id, level} ->
          adjusted_level = %{level | 
            level: level.level + merge_point.level + 1,
            parent: if(level.parent, do: Map.get(id_mapping, level.parent), else: merge_point_id)
          }
          {new_id, adjusted_level}
        end)
        |> Map.new()
      
      # Merge the structures
      merged_structure = 
        structure1
        |> update_in([:levels], &Map.merge(&1, adjusted_levels, fn _k, v1, v2 ->
          resolve_conflict(v1, v2, conflict_resolution)
        end))
        |> update_in([:levels, merge_point_id, :children], &(&1 ++ [Map.get(id_mapping, structure2.root)]))
      
      {:ok, merged_structure, id_mapping}
    end
  end
  
  # Private helper functions
  
  defp generate_system_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
  
  defp get_level(structure, level_id) do
    case Map.get(structure.levels, level_id) do
      nil -> {:error, :level_not_found}
      level -> {:ok, level}
    end
  end
  
  defp validate_depth(structure, current_depth) do
    max_depth = Map.get(structure, :max_depth, 10)
    
    if current_depth >= max_depth do
      {:error, :max_depth_exceeded}
    else
      :ok
    end
  end
  
  defp merge_contexts(parent_context, child_context) do
    # Child context overrides parent, but inherits unspecified values
    inherited_keys = [:organization, :domain, :constraints]
    
    inherited_context = 
      inherited_keys
      |> Enum.filter(fn key -> Map.has_key?(parent_context, key) end)
      |> Enum.map(fn key -> {key, Map.get(parent_context, key)} end)
      |> Map.new()
    
    Map.merge(inherited_context, child_context)
  end
  
  defp build_path_to(structure, target_id) do
    build_path_to(structure, target_id, [])
  end
  
  defp build_path_to(structure, target_id, acc) do
    case get_level(structure, target_id) do
      {:ok, level} ->
        new_path = [target_id | acc]
        
        if level.parent do
          build_path_to(structure, level.parent, new_path)
        else
          new_path
        end
        
      _ -> acc
    end
  end
  
  defp get_current_id(structure) do
    structure
    |> Map.get(:active_path, [])
    |> List.last()
  end
  
  defp propagate_context_changes(structure, level_id, context_updates) do
    case get_level(structure, level_id) do
      {:ok, level} ->
        # Propagate to children
        Enum.reduce(level.children, structure, fn child_id, acc ->
          case Map.get(context_updates, :propagate_keys) do
            nil -> acc
            keys ->
              propagated_updates = 
                context_updates
                |> Map.take(keys)
                |> Map.put(:propagate, true)
              
              case update_context(acc, child_id, propagated_updates) do
                {:ok, updated} -> updated
                _ -> acc
              end
          end
        end)
        
      _ -> structure
    end
  end
  
  defp find_path_between(structure, from_id, to_id) do
    from_path = build_path_to(structure, from_id)
    to_path = build_path_to(structure, to_id)
    
    # Find common ancestor
    common_prefix = 
      Enum.zip(from_path, to_path)
      |> Enum.take_while(fn {a, b} -> a == b end)
      |> Enum.map(fn {a, _} -> a end)
    
    if Enum.empty?(common_prefix) do
      {:error, :no_common_ancestor}
    else
      # Build path: up from 'from' to common ancestor, then down to 'to'
      up_path = from_path |> Enum.drop(length(common_prefix)) |> Enum.reverse()
      down_path = to_path |> Enum.drop(length(common_prefix))
      
      {:ok, %{
        up: up_path,
        common: List.last(common_prefix),
        down: down_path,
        total_distance: length(up_path) + length(down_path)
      }}
    end
  end
  
  defp save_level_state(structure, level_id, level) do
    state_key = "state_#{level_id}_#{System.system_time(:millisecond)}"
    
    state_data = %{
      context: level.context,
      metadata: level.metadata,
      timestamp: System.system_time(:millisecond)
    }
    
    put_in(structure, [:saved_states, state_key], state_data)
  end
  
  defp create_transition_context(from_level, to_level, path, transition_data) do
    %{
      previous_level: from_level.level,
      previous_context: Map.take(from_level.context, [:key_data]),
      transition_path: path,
      transition_type: classify_transition(from_level.level, to_level.level),
      transition_data: transition_data,
      transition_timestamp: System.system_time(:millisecond)
    }
  end
  
  defp classify_transition(from_level, to_level) do
    cond do
      from_level == to_level -> :lateral
      from_level < to_level -> :descending
      from_level > to_level -> :ascending
    end
  end
  
  defp record_transition(structure, from_id, to_id, transition_data) do
    transition_record = %{
      from: from_id,
      to: to_id,
      timestamp: System.system_time(:millisecond),
      data: transition_data
    }
    
    update_in(structure, [:transition_history], fn history ->
      [transition_record | (history || [])] |> Enum.take(100)  # Keep last 100 transitions
    end)
  end
  
  defp build_tree(structure, node_id, current_depth, max_depth, include_metadata) do
    if current_depth >= max_depth do
      %{id: node_id, children: :max_depth_reached}
    else
      case get_level(structure, node_id) do
        {:ok, level} ->
          base_tree = %{
            id: node_id,
            level: level.level,
            type: level.system_type,
            children: Enum.map(level.children, fn child_id ->
              build_tree(structure, child_id, current_depth + 1, max_depth, include_metadata)
            end)
          }
          
          if include_metadata do
            Map.put(base_tree, :metadata, level.metadata)
          else
            base_tree
          end
          
        _ -> %{id: node_id, error: :not_found}
      end
    end
  end
  
  defp calculate_depths(structure) do
    structure.levels
    |> Enum.map(fn {id, level} -> {id, level.level} end)
    |> Map.new()
  end
  
  defp calculate_average_children(levels) do
    child_counts = 
      levels
      |> Map.values()
      |> Enum.map(fn level -> length(level.children) end)
    
    if Enum.empty?(child_counts) do
      0
    else
      Enum.sum(child_counts) / length(child_counts)
    end
  end
  
  defp calculate_depth_distribution(depth_map) do
    depth_map
    |> Map.values()
    |> Enum.frequencies()
    |> Enum.sort_by(fn {depth, _count} -> depth end)
  end
  
  defp calculate_branching_factor(levels) do
    non_leaf_nodes = 
      levels
      |> Map.values()
      |> Enum.filter(fn level -> not Enum.empty?(level.children) end)
    
    if Enum.empty?(non_leaf_nodes) do
      0
    else
      total_children = 
        non_leaf_nodes
        |> Enum.map(fn level -> length(level.children) end)
        |> Enum.sum()
      
      total_children / length(non_leaf_nodes)
    end
  end
  
  defp calculate_complexity_index(structure) do
    metrics = calculate_metrics(structure)
    
    # Complexity based on depth, branching, and total nodes
    depth_factor = :math.log2(metrics.max_depth + 1)
    branching_factor = :math.log2(metrics.branching_factor + 1)
    size_factor = :math.log2(metrics.total_levels + 1)
    
    depth_factor * branching_factor * size_factor
  end
  
  defp check_orphaned_nodes(levels) do
    root_connected = find_root_connected_nodes(levels)
    
    levels
    |> Enum.reject(fn {id, level} -> 
      MapSet.member?(root_connected, id) or is_nil(level.parent)
    end)
    |> Enum.map(fn {id, _} -> {:orphaned_node, id} end)
  end
  
  defp find_root_connected_nodes(levels) do
    # Find root node(s)
    roots = 
      levels
      |> Enum.filter(fn {_id, level} -> is_nil(level.parent) end)
      |> Enum.map(fn {id, _} -> id end)
    
    # DFS to find all connected nodes
    Enum.reduce(roots, MapSet.new(), fn root, acc ->
      find_connected_nodes(levels, root, acc)
    end)
  end
  
  defp find_connected_nodes(levels, node_id, visited) do
    if MapSet.member?(visited, node_id) do
      visited
    else
      case Map.get(levels, node_id) do
        nil -> visited
        level ->
          visited = MapSet.put(visited, node_id)
          
          Enum.reduce(level.children, visited, fn child_id, acc ->
            find_connected_nodes(levels, child_id, acc)
          end)
      end
    end
  end
  
  defp check_circular_references(levels) do
    levels
    |> Enum.flat_map(fn {id, _level} ->
      case detect_cycle(levels, id, MapSet.new()) do
        {:cycle, path} -> [{:circular_reference, id, path}]
        :ok -> []
      end
    end)
  end
  
  defp detect_cycle(levels, node_id, visited) do
    if MapSet.member?(visited, node_id) do
      {:cycle, MapSet.to_list(visited)}
    else
      case Map.get(levels, node_id) do
        nil -> :ok
        level ->
          if level.parent do
            detect_cycle(levels, level.parent, MapSet.put(visited, node_id))
          else
            :ok
          end
      end
    end
  end
  
  defp check_depth_constraints(structure) do
    max_allowed = Map.get(structure, :max_depth, 10)
    
    structure.levels
    |> Enum.filter(fn {_id, level} -> level.level > max_allowed end)
    |> Enum.map(fn {id, level} -> {:depth_exceeded, id, level.level} end)
  end
  
  defp check_parent_child_consistency(levels) do
    levels
    |> Enum.flat_map(fn {parent_id, parent_level} ->
      parent_level.children
      |> Enum.flat_map(fn child_id ->
        case Map.get(levels, child_id) do
          nil -> [{:missing_child, parent_id, child_id}]
          child_level ->
            if child_level.parent != parent_id do
              [{:parent_mismatch, child_id, parent_id, child_level.parent}]
            else
              []
            end
        end
      end)
    end)
  end
  
  defp remove_level(structure, level_id) do
    case get_level(structure, level_id) do
      {:ok, level} ->
        # Remove from parent's children
        structure = 
          if level.parent do
            update_in(structure, [:levels, level.parent, :children], fn children ->
              Enum.reject(children, &(&1 == level_id))
            end)
          else
            structure
          end
        
        # Remove the level itself
        update_in(structure, [:levels], &Map.delete(&1, level_id))
        
      _ -> structure
    end
  end
  
  defp create_id_mapping(structure) do
    structure.levels
    |> Map.keys()
    |> Enum.map(fn old_id ->
      {old_id, generate_system_id()}
    end)
    |> Map.new()
  end
  
  defp rebase_structure(structure, id_mapping) do
    rebased_levels = 
      structure.levels
      |> Enum.map(fn {old_id, level} ->
        new_id = Map.get(id_mapping, old_id)
        
        updated_level = %{level |
          parent: if(level.parent, do: Map.get(id_mapping, level.parent), else: nil),
          children: Enum.map(level.children, &Map.get(id_mapping, &1))
        }
        
        {new_id, updated_level}
      end)
      |> Map.new()
    
    %{structure |
      root: Map.get(id_mapping, structure.root),
      levels: rebased_levels,
      active_path: Enum.map(structure.active_path, &Map.get(id_mapping, &1))
    }
  end
  
  defp resolve_conflict(v1, _v2, :error) do
    raise "Merge conflict detected"
  end
  
  defp resolve_conflict(v1, _v2, :keep_first) do
    v1
  end
  
  defp resolve_conflict(_v1, v2, :keep_second) do
    v2
  end
  
  defp resolve_conflict(v1, v2, :merge) when is_map(v1) and is_map(v2) do
    Map.merge(v1, v2)
  end
  
  defp resolve_conflict(v1, _v2, _) do
    v1
  end
end