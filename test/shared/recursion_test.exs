defmodule VsmCore.Shared.RecursionTest do
  use ExUnit.Case, async: true
  alias VsmCore.Shared.Recursion

  describe "initialize_structure/1" do
    test "creates root structure with defaults" do
      structure = Recursion.initialize_structure()
      
      assert Map.has_key?(structure, :root)
      assert Map.has_key?(structure, :levels)
      assert Map.has_key?(structure, :active_path)
      assert structure.max_depth == 10
      
      root_level = structure.levels[structure.root]
      assert root_level.level == 0
      assert root_level.parent == nil
      assert root_level.children == []
      assert root_level.system_type == :complete_vsm
    end

    test "creates structure with custom config" do
      config = %{
        id: "custom_root",
        context: %{domain: "manufacturing"},
        type: :production_system,
        max_depth: 5
      }
      
      structure = Recursion.initialize_structure(config)
      
      assert structure.root == "custom_root"
      assert structure.max_depth == 5
      
      root_level = structure.levels["custom_root"]
      assert root_level.context.domain == "manufacturing"
      assert root_level.system_type == :production_system
    end
  end

  describe "create_level/3" do
    test "creates child level" do
      structure = Recursion.initialize_structure()
      
      {:ok, updated, child_id} = Recursion.create_level(structure, structure.root)
      
      child_level = updated.levels[child_id]
      assert child_level.level == 1
      assert child_level.parent == structure.root
      assert child_id in updated.levels[structure.root].children
    end

    test "inherits and merges context" do
      structure = Recursion.initialize_structure(%{
        context: %{organization: "ACME", domain: "manufacturing"}
      })
      
      child_config = %{
        context: %{domain: "assembly", location: "plant1"}
      }
      
      {:ok, updated, child_id} = Recursion.create_level(structure, structure.root, child_config)
      
      child_level = updated.levels[child_id]
      assert child_level.context.organization == "ACME"  # Inherited
      assert child_level.context.domain == "assembly"    # Overridden
      assert child_level.context.location == "plant1"    # New
    end

    test "enforces max depth constraint" do
      structure = Recursion.initialize_structure(%{max_depth: 2})
      
      # Create level 1
      {:ok, s1, id1} = Recursion.create_level(structure, structure.root)
      
      # Create level 2 (at max depth)
      {:ok, s2, id2} = Recursion.create_level(s1, id1)
      
      # Try to create level 3 (exceeds max depth)
      result = Recursion.create_level(s2, id2)
      assert result == {:error, :max_depth_exceeded}
    end
  end

  describe "navigation functions" do
    setup do
      structure = Recursion.initialize_structure()
      {:ok, s1, child1} = Recursion.create_level(structure, structure.root)
      {:ok, s2, child2} = Recursion.create_level(s1, structure.root)
      {:ok, s3, grandchild} = Recursion.create_level(s2, child1)
      
      {:ok, structure: s3, child1: child1, child2: child2, grandchild: grandchild}
    end

    test "navigate_to moves to specific level", %{structure: structure, child1: child1} do
      {:ok, updated, level} = Recursion.navigate_to(structure, child1)
      
      assert updated.active_path == [structure.root, child1]
      assert level.level == 1
    end

    test "navigate_up moves up hierarchy", %{structure: structure, grandchild: grandchild} do
      # Navigate to grandchild first
      {:ok, s1, _} = Recursion.navigate_to(structure, grandchild)
      
      # Navigate up
      {:ok, s2, parent_level} = Recursion.navigate_up(s1)
      
      assert length(s2.active_path) == 2
      assert parent_level.level == 1
    end

    test "navigate_up at root returns error", %{structure: structure} do
      result = Recursion.navigate_up(structure)
      assert result == {:error, :at_root}
    end

    test "navigate_down moves to child", %{structure: structure, child1: child1, grandchild: grandchild} do
      # Navigate to child1
      {:ok, s1, _} = Recursion.navigate_to(structure, child1)
      
      # Navigate down to grandchild
      {:ok, s2, level} = Recursion.navigate_down(s1, grandchild)
      
      assert List.last(s2.active_path) == grandchild
      assert level.level == 2
    end

    test "navigate_down validates child relationship", %{structure: structure, child2: child2} do
      # Try to navigate to child2 from root (valid)
      {:ok, _, _} = Recursion.navigate_down(structure, child2)
      
      # Navigate to child2
      {:ok, s1, _} = Recursion.navigate_to(structure, child2)
      
      # Try to navigate to non-child
      result = Recursion.navigate_down(s1, "non_existent")
      assert result == {:error, :not_a_child}
    end
  end

  describe "update_context/3" do
    test "updates context at specific level" do
      structure = Recursion.initialize_structure()
      
      updates = %{new_field: "value", existing: "updated"}
      {:ok, updated} = Recursion.update_context(structure, structure.root, updates)
      
      root_level = updated.levels[structure.root]
      assert root_level.context.new_field == "value"
      assert root_level.context.existing == "updated"
    end

    test "propagates context changes to children" do
      structure = Recursion.initialize_structure()
      {:ok, s1, child1} = Recursion.create_level(structure, structure.root)
      {:ok, s2, child2} = Recursion.create_level(s1, structure.root)
      
      updates = %{
        shared_config: "parent_value",
        propagate: true,
        propagate_keys: [:shared_config]
      }
      
      {:ok, updated} = Recursion.update_context(s2, structure.root, updates)
      
      # Check children received propagated context
      assert updated.levels[child1].context.shared_config == "parent_value"
      assert updated.levels[child2].context.shared_config == "parent_value"
    end
  end

  describe "switch_context/4" do
    setup do
      structure = Recursion.initialize_structure()
      {:ok, s1, branch1} = Recursion.create_level(structure, structure.root, 
        %{context: %{branch: "A"}})
      {:ok, s2, branch2} = Recursion.create_level(s1, structure.root, 
        %{context: %{branch: "B"}})
      
      {:ok, structure: s2, branch1: branch1, branch2: branch2}
    end

    test "switches between sibling contexts", %{structure: structure, branch1: b1, branch2: b2} do
      {:ok, switched, target_level} = Recursion.switch_context(structure, b1, b2)
      
      assert List.last(switched.active_path) == b2
      assert target_level.context.branch == "B"
      assert Map.has_key?(target_level.context, :transition_type)
    end

    test "preserves state during switch", %{structure: structure, branch1: b1, branch2: b2} do
      {:ok, switched, _} = Recursion.switch_context(structure, b1, b2, 
        preserve_state: true)
      
      # State should be saved
      assert Map.has_key?(switched, :saved_states)
    end
  end

  describe "get_hierarchy_tree/3" do
    test "builds complete hierarchy tree" do
      structure = Recursion.initialize_structure()
      {:ok, s1, c1} = Recursion.create_level(structure, structure.root)
      {:ok, s2, c2} = Recursion.create_level(s1, structure.root)
      {:ok, s3, gc1} = Recursion.create_level(s2, c1)
      
      tree = Recursion.get_hierarchy_tree(s3)
      
      assert tree.id == structure.root
      assert tree.level == 0
      assert length(tree.children) == 2
      
      child1_tree = Enum.find(tree.children, & &1.id == c1)
      assert length(child1_tree.children) == 1
      assert hd(child1_tree.children).id == gc1
    end

    test "respects max depth parameter" do
      structure = Recursion.initialize_structure()
      {:ok, s1, c1} = Recursion.create_level(structure, structure.root)
      {:ok, s2, gc1} = Recursion.create_level(s1, c1)
      
      tree = Recursion.get_hierarchy_tree(s2, nil, max_depth: 1)
      
      assert tree.id == structure.root
      assert length(tree.children) == 1
      
      child_tree = hd(tree.children)
      assert child_tree.children == :max_depth_reached
    end
  end

  describe "find_levels/2" do
    test "finds levels matching predicate" do
      structure = Recursion.initialize_structure()
      {:ok, s1, _} = Recursion.create_level(structure, structure.root, 
        %{type: :subsystem})
      {:ok, s2, _} = Recursion.create_level(s1, structure.root, 
        %{type: :subsystem})
      {:ok, s3, _} = Recursion.create_level(s2, structure.root, 
        %{type: :special})
      
      subsystems = Recursion.find_levels(s3, & &1.system_type == :subsystem)
      
      assert length(subsystems) == 2
      assert Enum.all?(subsystems, fn {_, level} -> 
        level.system_type == :subsystem 
      end)
    end
  end

  describe "calculate_metrics/1" do
    test "calculates structure metrics" do
      structure = Recursion.initialize_structure()
      {:ok, s1, c1} = Recursion.create_level(structure, structure.root)
      {:ok, s2, c2} = Recursion.create_level(s1, structure.root)
      {:ok, s3, gc1} = Recursion.create_level(s2, c1)
      {:ok, s4, gc2} = Recursion.create_level(s3, c1)
      
      metrics = Recursion.calculate_metrics(s4)
      
      assert metrics.total_levels == 5  # root + 2 children + 2 grandchildren
      assert metrics.max_depth == 2
      assert metrics.average_children > 0
      assert length(metrics.depth_distribution) == 3  # levels 0, 1, 2
      assert metrics.complexity_index > 0
    end
  end

  describe "validate_structure/1" do
    test "validates correct structure" do
      structure = Recursion.initialize_structure()
      {:ok, s1, _} = Recursion.create_level(structure, structure.root)
      
      assert Recursion.validate_structure(s1) == :ok
    end

    test "detects orphaned nodes" do
      structure = Recursion.initialize_structure()
      
      # Manually create orphaned node
      orphan_level = %{
        level: 1,
        parent: "non_existent_parent",
        children: [],
        system_type: :subsystem,
        context: %{}
      }
      
      invalid = put_in(structure, [:levels, "orphan"], orphan_level)
      
      {:error, errors} = Recursion.validate_structure(invalid)
      assert Enum.any?(errors, fn
        {:orphaned_node, "orphan"} -> true
        _ -> false
      end)
    end

    test "detects parent-child inconsistencies" do
      structure = Recursion.initialize_structure()
      {:ok, s1, child} = Recursion.create_level(structure, structure.root)
      
      # Manually break parent-child relationship
      broken = put_in(s1, [:levels, child, :parent], "wrong_parent")
      
      {:error, errors} = Recursion.validate_structure(broken)
      assert Enum.any?(errors, fn
        {:parent_mismatch, _, _, _} -> true
        _ -> false
      end)
    end
  end

  describe "prune_structure/2" do
    test "removes inactive leaf nodes" do
      structure = Recursion.initialize_structure()
      {:ok, s1, active} = Recursion.create_level(structure, structure.root)
      {:ok, s2, inactive} = Recursion.create_level(s1, structure.root)
      
      # Make inactive node old
      old_time = System.system_time(:millisecond) - 40 * 24 * 60 * 60 * 1000
      s3 = put_in(s2, [:levels, inactive, :metadata, :last_modified], old_time)
      
      {:ok, pruned, count} = Recursion.prune_structure(s3, preserve_depth: 0)
      
      assert count == 1
      assert not Map.has_key?(pruned.levels, inactive)
      assert Map.has_key?(pruned.levels, active)
    end
  end

  describe "merge_structures/4" do
    test "merges two structures" do
      # Create first structure
      s1 = Recursion.initialize_structure(%{id: "root1"})
      {:ok, s1, child1} = Recursion.create_level(s1, "root1")
      
      # Create second structure
      s2 = Recursion.initialize_structure(%{id: "root2"})
      {:ok, s2, child2} = Recursion.create_level(s2, "root2")
      
      # Merge s2 into s1 at child1
      {:ok, merged, mapping} = Recursion.merge_structures(s1, s2, child1)
      
      # Check merge results
      new_root2_id = Map.get(mapping, "root2")
      assert Map.has_key?(merged.levels, new_root2_id)
      assert new_root2_id in merged.levels[child1].children
      
      # Check level adjustment
      merged_root2 = merged.levels[new_root2_id]
      assert merged_root2.level == 2  # Was 0, now under level 1
      assert merged_root2.parent == child1
    end
  end
end