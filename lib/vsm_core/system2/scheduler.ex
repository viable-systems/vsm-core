defmodule VSMCore.System2.Scheduler do
  @moduledoc """
  Schedule coordination module for System 2.
  
  Manages temporal coordination between S1 units to prevent conflicts,
  optimize throughput, and ensure smooth operations.
  """
  
  require Logger
  
  @type schedule_entry :: %{
    unit_id: atom(),
    task_id: String.t(),
    start_time: DateTime.t(),
    end_time: DateTime.t(),
    priority: atom(),
    dependencies: list(String.t()),
    resources: map()
  }
  
  @type schedule :: %{atom() => [schedule_entry()]}
  
  @doc """
  Coordinates schedules across multiple S1 units to prevent conflicts.
  """
  @spec coordinate(schedule(), schedule()) :: schedule()
  def coordinate(new_schedules, existing_schedules) do
    # Merge new and existing schedules
    merged = merge_schedules(new_schedules, existing_schedules)
    
    # Detect conflicts
    conflicts = detect_conflicts(merged)
    
    # Resolve conflicts
    resolved = resolve_conflicts(merged, conflicts)
    
    # Optimize schedule
    optimize_schedule(resolved)
  end
  
  @doc """
  Detects scheduling conflicts between units.
  """
  @spec detect_conflicts(schedule()) :: list()
  def detect_conflicts(schedules) do
    all_entries = schedules
    |> Map.values()
    |> List.flatten()
    
    # Find temporal overlaps
    temporal_conflicts = find_temporal_conflicts(all_entries)
    
    # Find resource conflicts
    resource_conflicts = find_resource_conflicts(all_entries)
    
    # Find dependency conflicts
    dependency_conflicts = find_dependency_conflicts(all_entries)
    
    Enum.uniq(temporal_conflicts ++ resource_conflicts ++ dependency_conflicts)
  end
  
  @doc """
  Optimizes schedule for maximum throughput and minimum latency.
  """
  @spec optimize_schedule(schedule()) :: schedule()
  def optimize_schedule(schedule) do
    schedule
    |> apply_compression()
    |> balance_load()
    |> minimize_gaps()
    |> prioritize_critical_path()
  end
  
  @doc """
  Validates that a schedule is feasible.
  """
  @spec validate_schedule(schedule()) :: {:ok, schedule()} | {:error, list()}
  def validate_schedule(schedule) do
    validations = [
      validate_no_overlaps(schedule),
      validate_dependencies(schedule),
      validate_resource_availability(schedule),
      validate_time_constraints(schedule)
    ]
    
    errors = Enum.filter(validations, fn
      {:error, _} -> true
      _ -> false
    end)
    
    if Enum.empty?(errors) do
      {:ok, schedule}
    else
      {:error, errors}
    end
  end
  
  @doc """
  Calculates schedule metrics for monitoring.
  """
  @spec calculate_metrics(schedule()) :: map()
  def calculate_metrics(schedule) do
    entries = Map.values(schedule) |> List.flatten()
    
    %{
      total_tasks: length(entries),
      units_active: map_size(schedule),
      utilization: calculate_utilization(entries),
      avg_task_duration: calculate_avg_duration(entries),
      critical_path_length: calculate_critical_path(entries),
      idle_time: calculate_idle_time(entries)
    }
  end
  
  # Private Functions
  
  defp merge_schedules(new_schedules, existing_schedules) do
    Map.merge(existing_schedules, new_schedules, fn _unit_id, existing, new ->
      # Combine schedules for each unit
      (existing ++ new)
      |> Enum.uniq_by(& &1.task_id)
      |> Enum.sort_by(& &1.start_time, DateTime)
    end)
  end
  
  defp find_temporal_conflicts(entries) do
    # Find entries that overlap in time
    entries
    |> Enum.with_index()
    |> Enum.flat_map(fn {entry1, idx1} ->
      entries
      |> Enum.with_index()
      |> Enum.filter(fn {entry2, idx2} ->
        idx2 > idx1 && temporal_overlap?(entry1, entry2)
      end)
      |> Enum.map(fn {entry2, _} ->
        %{
          type: :temporal,
          entries: [entry1, entry2],
          overlap: calculate_overlap(entry1, entry2)
        }
      end)
    end)
  end
  
  defp temporal_overlap?(entry1, entry2) do
    # Check if two schedule entries overlap in time
    not (DateTime.compare(entry1.end_time, entry2.start_time) == :lt ||
         DateTime.compare(entry2.end_time, entry1.start_time) == :lt)
  end
  
  defp calculate_overlap(entry1, entry2) do
    overlap_start = max_datetime(entry1.start_time, entry2.start_time)
    overlap_end = min_datetime(entry1.end_time, entry2.end_time)
    
    DateTime.diff(overlap_end, overlap_start, :millisecond)
  end
  
  defp find_resource_conflicts(entries) do
    # Group entries by time slots
    time_slots = group_by_time_slots(entries)
    
    # Check each time slot for resource conflicts
    Enum.flat_map(time_slots, fn {_time_slot, slot_entries} ->
      check_resource_conflicts_in_slot(slot_entries)
    end)
  end
  
  defp group_by_time_slots(entries, slot_duration \\ 300_000) do
    # Group entries into 5-minute time slots
    Enum.group_by(entries, fn entry ->
      timestamp = DateTime.to_unix(entry.start_time, :millisecond)
      div(timestamp, slot_duration) * slot_duration
    end)
  end
  
  defp check_resource_conflicts_in_slot(entries) do
    # Sum resource requirements for all entries in the slot
    total_resources = Enum.reduce(entries, %{}, fn entry, acc ->
      Map.merge(acc, entry.resources, fn _key, v1, v2 -> v1 + v2 end)
    end)
    
    # Check if any resource is oversubscribed
    oversubscribed = Enum.filter(total_resources, fn {_resource, amount} ->
      amount > 100 # Assuming 100 units per resource
    end)
    
    if Enum.empty?(oversubscribed) do
      []
    else
      [%{
        type: :resource,
        entries: entries,
        oversubscribed: Map.new(oversubscribed)
      }]
    end
  end
  
  defp find_dependency_conflicts(entries) do
    # Build dependency graph
    dep_graph = build_dependency_graph(entries)
    
    # Find circular dependencies
    circular = find_circular_dependencies(dep_graph)
    
    # Find timing violations
    timing_violations = find_timing_violations(entries, dep_graph)
    
    circular ++ timing_violations
  end
  
  defp build_dependency_graph(entries) do
    # Create a map of task_id to entry
    entry_map = Map.new(entries, & {&1.task_id, &1})
    
    # Build adjacency list
    Enum.reduce(entries, %{}, fn entry, graph ->
      deps = entry.dependencies
      |> Enum.filter(&Map.has_key?(entry_map, &1))
      |> Enum.map(&Map.get(entry_map, &1))
      
      Map.put(graph, entry.task_id, deps)
    end)
  end
  
  defp find_circular_dependencies(graph) do
    # DFS to detect cycles
    visited = MapSet.new()
    rec_stack = MapSet.new()
    
    Enum.reduce(Map.keys(graph), [], fn node, cycles ->
      if MapSet.member?(visited, node) do
        cycles
      else
        {new_visited, new_cycles} = dfs_detect_cycle(
          node, graph, visited, rec_stack, []
        )
        cycles ++ new_cycles
      end
    end)
  end
  
  defp dfs_detect_cycle(node, graph, visited, rec_stack, cycles) do
    visited = MapSet.put(visited, node)
    rec_stack = MapSet.put(rec_stack, node)
    
    neighbors = Map.get(graph, node, [])
    
    {final_visited, new_cycles} = Enum.reduce(neighbors, {visited, cycles}, 
      fn neighbor, {vis, cyc} ->
        cond do
          MapSet.member?(rec_stack, neighbor.task_id) ->
            # Cycle detected
            {vis, [%{type: :circular_dependency, cycle: [node, neighbor.task_id]} | cyc]}
            
          not MapSet.member?(vis, neighbor.task_id) ->
            dfs_detect_cycle(neighbor.task_id, graph, vis, rec_stack, cyc)
            
          true ->
            {vis, cyc}
        end
      end)
    
    {final_visited, new_cycles}
  end
  
  defp find_timing_violations(entries, dep_graph) do
    entry_map = Map.new(entries, & {&1.task_id, &1})
    
    Enum.flat_map(entries, fn entry ->
      deps = Map.get(dep_graph, entry.task_id, [])
      
      Enum.filter_map(deps, fn dep ->
        dep_entry = Map.get(entry_map, dep.task_id)
        
        # Check if dependency finishes before this task starts
        if dep_entry && DateTime.compare(dep_entry.end_time, entry.start_time) == :gt do
          %{
            type: :dependency_timing,
            dependent: entry,
            dependency: dep_entry,
            violation: DateTime.diff(dep_entry.end_time, entry.start_time, :millisecond)
          }
        end
      end)
    end)
  end
  
  defp resolve_conflicts(schedule, conflicts) do
    Enum.reduce(conflicts, schedule, fn conflict, sched ->
      resolve_single_conflict(sched, conflict)
    end)
  end
  
  defp resolve_single_conflict(schedule, conflict) do
    case conflict.type do
      :temporal ->
        resolve_temporal_conflict(schedule, conflict)
        
      :resource ->
        resolve_resource_conflict(schedule, conflict)
        
      :dependency_timing ->
        resolve_dependency_conflict(schedule, conflict)
        
      :circular_dependency ->
        resolve_circular_dependency(schedule, conflict)
        
      _ ->
        schedule
    end
  end
  
  defp resolve_temporal_conflict(schedule, conflict) do
    [entry1, entry2] = conflict.entries
    
    # Determine which entry to delay based on priority
    {to_delay, to_keep} = if entry1.priority > entry2.priority do
      {entry2, entry1}
    else
      {entry1, entry2}
    end
    
    # Calculate delay needed
    delay = DateTime.diff(to_keep.end_time, to_delay.start_time, :millisecond) + 60_000 # 1 minute buffer
    
    # Update schedule with delayed entry
    update_entry_timing(schedule, to_delay, delay)
  end
  
  defp resolve_resource_conflict(schedule, conflict) do
    # Stagger entries to reduce concurrent resource usage
    entries = Enum.sort_by(conflict.entries, & &1.priority, :desc)
    
    Enum.reduce(Enum.with_index(entries), schedule, fn {{entry, idx}, sched} ->
      if idx > 0 do
        # Delay by idx * 5 minutes
        delay = idx * 300_000
        update_entry_timing(sched, entry, delay)
      else
        sched
      end
    end)
  end
  
  defp resolve_dependency_conflict(schedule, conflict) do
    # Adjust dependent task to start after dependency completes
    delay = conflict.violation + 60_000 # Add 1 minute buffer
    update_entry_timing(schedule, conflict.dependent, delay)
  end
  
  defp resolve_circular_dependency(schedule, conflict) do
    # Break cycle by removing the lower priority dependency
    Logger.warning("Circular dependency detected: #{inspect(conflict.cycle)}")
    # In a real system, this would require more sophisticated resolution
    schedule
  end
  
  defp update_entry_timing(schedule, entry, delay_ms) do
    Map.update!(schedule, entry.unit_id, fn entries ->
      Enum.map(entries, fn e ->
        if e.task_id == entry.task_id do
          %{e | 
            start_time: DateTime.add(e.start_time, delay_ms, :millisecond),
            end_time: DateTime.add(e.end_time, delay_ms, :millisecond)
          }
        else
          e
        end
      end)
    end)
  end
  
  defp apply_compression(schedule) do
    # Compress schedule by removing unnecessary gaps
    Map.new(schedule, fn {unit_id, entries} ->
      compressed = compress_unit_schedule(entries)
      {unit_id, compressed}
    end)
  end
  
  defp compress_unit_schedule(entries) do
    sorted = Enum.sort_by(entries, & &1.start_time, DateTime)
    
    {compressed, _} = Enum.reduce(sorted, {[], nil}, fn entry, {acc, last_end} ->
      new_entry = if last_end do
        gap = DateTime.diff(entry.start_time, last_end, :millisecond)
        if gap > 300_000 do # More than 5 minutes gap
          # Compress by moving entry earlier
          duration = DateTime.diff(entry.end_time, entry.start_time, :millisecond)
          new_start = DateTime.add(last_end, 60_000, :millisecond) # 1 minute buffer
          new_end = DateTime.add(new_start, duration, :millisecond)
          
          %{entry | start_time: new_start, end_time: new_end}
        else
          entry
        end
      else
        entry
      end
      
      {[new_entry | acc], new_entry.end_time}
    end)
    
    Enum.reverse(compressed)
  end
  
  defp balance_load(schedule) do
    # Balance load across units
    total_load = calculate_total_load(schedule)
    target_load = total_load / map_size(schedule)
    
    balanced = Enum.reduce(schedule, %{}, fn {unit_id, entries}, acc ->
      unit_load = calculate_unit_load(entries)
      
      if unit_load > target_load * 1.2 do
        # Unit is overloaded, try to redistribute
        {kept, moved} = split_entries(entries, target_load)
        
        # Find underloaded unit
        underloaded_unit = find_underloaded_unit(acc, target_load)
        
        if underloaded_unit do
          acc
          |> Map.put(unit_id, kept)
          |> Map.update(underloaded_unit, moved, &(&1 ++ moved))
        else
          Map.put(acc, unit_id, entries)
        end
      else
        Map.put(acc, unit_id, entries)
      end
    end)
    
    balanced
  end
  
  defp calculate_total_load(schedule) do
    schedule
    |> Map.values()
    |> List.flatten()
    |> Enum.map(&calculate_entry_load/1)
    |> Enum.sum()
  end
  
  defp calculate_unit_load(entries) do
    entries
    |> Enum.map(&calculate_entry_load/1)
    |> Enum.sum()
  end
  
  defp calculate_entry_load(entry) do
    duration = DateTime.diff(entry.end_time, entry.start_time, :millisecond)
    resource_intensity = Enum.sum(Map.values(entry.resources))
    
    duration * resource_intensity / 100.0
  end
  
  defp split_entries(entries, target_load) do
    sorted = Enum.sort_by(entries, & &1.priority)
    
    {kept, moved, _} = Enum.reduce(sorted, {[], [], 0}, fn entry, {k, m, load} ->
      entry_load = calculate_entry_load(entry)
      
      if load + entry_load <= target_load do
        {[entry | k], m, load + entry_load}
      else
        {k, [entry | m], load}
      end
    end)
    
    {Enum.reverse(kept), Enum.reverse(moved)}
  end
  
  defp find_underloaded_unit(schedule, target_load) do
    Enum.find(schedule, fn {_unit_id, entries} ->
      calculate_unit_load(entries) < target_load * 0.8
    end)
    |> case do
      {unit_id, _} -> unit_id
      nil -> nil
    end
  end
  
  defp minimize_gaps(schedule) do
    # Already handled in compression
    schedule
  end
  
  defp prioritize_critical_path(schedule) do
    # Identify critical path and ensure it gets priority
    all_entries = Map.values(schedule) |> List.flatten()
    critical_tasks = find_critical_path(all_entries)
    
    # Boost priority of critical path tasks
    Map.new(schedule, fn {unit_id, entries} ->
      updated_entries = Enum.map(entries, fn entry ->
        if entry.task_id in critical_tasks do
          %{entry | priority: :critical}
        else
          entry
        end
      end)
      
      {unit_id, updated_entries}
    end)
  end
  
  defp find_critical_path(entries) do
    # Simplified critical path - tasks with most dependencies
    entry_map = Map.new(entries, & {&1.task_id, &1})
    
    # Count dependent tasks
    dependency_counts = Enum.reduce(entries, %{}, fn entry, counts ->
      Enum.reduce(entry.dependencies, counts, fn dep, c ->
        Map.update(c, dep, 1, &(&1 + 1))
      end)
    end)
    
    # Top 20% are critical
    threshold = length(entries) * 0.2
    
    dependency_counts
    |> Enum.sort_by(fn {_task, count} -> -count end)
    |> Enum.take(round(threshold))
    |> Enum.map(fn {task, _} -> task end)
  end
  
  defp validate_no_overlaps(schedule) do
    conflicts = detect_conflicts(schedule)
    temporal_conflicts = Enum.filter(conflicts, & &1.type == :temporal)
    
    if Enum.empty?(temporal_conflicts) do
      :ok
    else
      {:error, {:temporal_overlaps, temporal_conflicts}}
    end
  end
  
  defp validate_dependencies(schedule) do
    all_entries = Map.values(schedule) |> List.flatten()
    dep_graph = build_dependency_graph(all_entries)
    circular = find_circular_dependencies(dep_graph)
    
    if Enum.empty?(circular) do
      :ok
    else
      {:error, {:circular_dependencies, circular}}
    end
  end
  
  defp validate_resource_availability(schedule) do
    all_entries = Map.values(schedule) |> List.flatten()
    conflicts = find_resource_conflicts(all_entries)
    
    if Enum.empty?(conflicts) do
      :ok
    else
      {:error, {:resource_oversubscription, conflicts}}
    end
  end
  
  defp validate_time_constraints(schedule) do
    # Check if all tasks fit within reasonable time bounds
    all_entries = Map.values(schedule) |> List.flatten()
    
    invalid = Enum.filter(all_entries, fn entry ->
      duration = DateTime.diff(entry.end_time, entry.start_time, :millisecond)
      duration <= 0 || duration > 86_400_000 # More than 24 hours
    end)
    
    if Enum.empty?(invalid) do
      :ok
    else
      {:error, {:invalid_durations, invalid}}
    end
  end
  
  defp calculate_utilization(entries) do
    if Enum.empty?(entries) do
      0.0
    else
      # Calculate time span
      earliest = Enum.min_by(entries, & &1.start_time, DateTime)
      latest = Enum.max_by(entries, & &1.end_time, DateTime)
      
      total_span = DateTime.diff(latest.end_time, earliest.start_time, :millisecond)
      
      # Calculate total busy time
      total_busy = Enum.reduce(entries, 0, fn entry, acc ->
        duration = DateTime.diff(entry.end_time, entry.start_time, :millisecond)
        acc + duration
      end)
      
      if total_span > 0 do
        total_busy / total_span
      else
        0.0
      end
    end
  end
  
  defp calculate_avg_duration(entries) do
    if Enum.empty?(entries) do
      0
    else
      total_duration = Enum.reduce(entries, 0, fn entry, acc ->
        acc + DateTime.diff(entry.end_time, entry.start_time, :millisecond)
      end)
      
      div(total_duration, length(entries))
    end
  end
  
  defp calculate_critical_path(entries) do
    # Simplified - return longest chain of dependencies
    if Enum.empty?(entries) do
      0
    else
      # This would need a proper DAG analysis in production
      length(entries) * 300_000 # Estimate
    end
  end
  
  defp calculate_idle_time(entries) do
    if length(entries) < 2 do
      0
    else
      sorted = Enum.sort_by(entries, & &1.start_time, DateTime)
      
      Enum.chunk_every(sorted, 2, 1, :discard)
      |> Enum.reduce(0, fn [e1, e2], acc ->
        gap = DateTime.diff(e2.start_time, e1.end_time, :millisecond)
        acc + max(0, gap)
      end)
    end
  end
  
  defp max_datetime(dt1, dt2) do
    if DateTime.compare(dt1, dt2) == :gt, do: dt1, else: dt2
  end
  
  defp min_datetime(dt1, dt2) do
    if DateTime.compare(dt1, dt2) == :lt, do: dt1, else: dt2
  end
end