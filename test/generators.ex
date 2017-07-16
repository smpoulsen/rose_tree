defmodule Generators do
  use ExUnit.CaseTemplate

  using do
    quote do
      use ExCheck

      @node_values [:a, :b, :c, 0, 1, 2, 3, "hello", "world"]

      # Generator for RoseTrees
      def rose_tree(n) do
        domain(:rose_tree,
          fn(self, size) ->
            {_, node} = :triq_dom.pick(elements(@node_values), size)
            {_, child_count} = :triq_dom.pick(elements([0,1, 2]), size)
            children = if child_count > 0 do
              gen_child_trees(size, n)
            else
              []
            end
            tree = %RoseTree{node: node, children: children}
            {self, tree}
          end, fn
            (self, %RoseTree{node: node, children: children}) ->
              new_node = :x
              new_children = if Enum.empty?(children), do: [], else: tl(children)
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
    end
  end
end
