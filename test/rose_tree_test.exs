defmodule RoseTreeTest do
  use ExUnit.Case
  use Generators
  doctest RoseTree

  property "add_child/2 adds a child to a tree" do
    for_all {t1, t2} in {rose_tree(0), rose_tree(1)} do
      added_child = RoseTree.add_child(t1, t2)
      RoseTree.is_child?(added_child, t2) == true
    end
  end

  property "child_values/1 returns a list of child values" do
    for_all tree in rose_tree(3) do
      child_values = for child <- tree.children, do: child.node
      RoseTree.child_values(tree) == child_values
    end
  end

  property "merge_nodes/2 merges nodes and their children" do
    for_all {t1, t2} in such_that({tt1, tt2} in {rose_tree(1), rose_tree(1)} when tt1.node == tt2.node) do
      merged = RoseTree.merge_nodes(t1, t2)
      all_children = t1
      |> RoseTree.child_values
      |> MapSet.new()
      |> MapSet.union(MapSet.new(RoseTree.child_values(t2)))

      Enum.all?(RoseTree.child_values(merged),  &MapSet.member?(all_children, &1))
    end
  end

  property "is_child?/2 is a predicate" do
    for_all {t1, t2} in {rose_tree(2), rose_tree(2)} do
      RoseTree.is_child?(t1, t2) == Enum.member?(RoseTree.child_values(t1), t2.node)
    end
  end

  property "pop_child/1 returns the first of a node's children" do
    for_all {tree} in {rose_tree(3)} do
      res = RoseTree.pop_child(tree)
      case tree do
        %RoseTree{children: [h | t]} ->
          res == {h, %{tree | children: t}}
        _ ->
          res == {nil, tree}
      end
    end
  end

  property "pop_child_at/2 returns the node's child at an index" do
    for_all {tree, idx} in such_that({t, i} in {rose_tree(3), int(0, 5)}
        when i < Enum.count(t.children)) do
      {child, new_tree} = RoseTree.pop_child_at(tree, idx)
      case tree do
        %RoseTree{children: []} ->
          child == nil && new_tree == tree
        _ ->
          child == Enum.at(tree.children, idx) && Enum.count(new_tree.children) < Enum.count(tree.children)
      end
    end
  end
end
