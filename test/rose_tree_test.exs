defmodule RoseTreeTest do
  use ExUnit.Case
  use ExCheck
  doctest RoseTree

  # Generator for RoseTrees
  def rose_tree(n) do
    domain(:rose_tree,
      fn(self, size) ->
        {_, node} = :triq_dom.pick(int(), size)
        {_, child_count} = :triq_dom.pick(elements([0,1]), size)
        children = if child_count == 1 do
          gen_child_trees(size, n)
        else
          []
        end
        tree = %RoseTree{node: node, children: children}
        {self, tree}
      end, fn
        (self, %RoseTree{node: node, children: children}) ->
          new_node = max(node, 0)
          new_children = if length(children) == 0, do: [], else: [hd(children)]
          tree = %RoseTree{node: new_node, children: new_children}
          {self, tree}
      end)
  end

  defp gen_child_trees(size, count) do
    for n <- Range.new(0, count) do
      {_, child} = :triq_dom.pick(rose_tree(n), size)
      child
    end
  end

  property "adding a child to a tree" do
    for_all {t1, t2} in {rose_tree(0), rose_tree(1)} do
      added_child = RoseTree.add_child(t1, t2)
      RoseTree.is_child?(added_child, t2) == true
    end
  end
end
