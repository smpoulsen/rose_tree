defmodule RoseTree do
  @moduledoc """
  A rose tree is an tree in which each node has zero or more children, all
  of which are themselves rose trees.

  Trees are unbalanced and children are unordered.
  """

  defstruct node: :empty, children: []

  @type t :: %RoseTree{node: any(), children: [%RoseTree{}]}

  @doc """
  Initialize a new rose tree using the argument as the node value.

  ## Examples
      iex> RoseTree.new(5)
      %RoseTree{node: 5, children: []}
  """
  @spec new(any()) :: RoseTree.t
  def new(value) do
    %RoseTree{node: value, children: []}
  end

  @doc """
  Initialize a new rose tree with an empty node.

  ## Examples
  iex> RoseTree.empty()
  %RoseTree{node: :empty, children: []}
  """
  @spec empty() :: RoseTree.t
  def empty do
    %RoseTree{}
  end

  @doc """
  Add a new child to a tree.

  ## Examples
      iex> RoseTree.new(:hello)
      ...> |> RoseTree.add_child(RoseTree.empty())
      %RoseTree{node: :hello, children: [%RoseTree{node: :empty, children: []}]}
  """
  @spec add_child(RoseTree.t, RoseTree.t) :: RoseTree.t
  def add_child(%RoseTree{node: n, children: children}, child) do
    %RoseTree{node: n, children: [child | children]}
  end

  @doc """
  Extract the values from all the nodes of a tree.

  Evaluates to a list of lists of all possible paths.

  TODO optimize to use lazy lists

  ## Examples
      iex> RoseTree.new(:a)
      ...> |> RoseTree.add_child(RoseTree.new(:b))
      ...> |> RoseTree.add_child(RoseTree.new(:c) |> RoseTree.add_child(RoseTree.new(:d)) |> RoseTree.add_child(RoseTree.new(:z)))
      ...> |> RoseTree.values()
      [[:a, :b], [[:a, :c, :d], [:a, :c, :z]]]
  """
  @spec values(RoseTree.t) :: [any()]
  def values(%RoseTree{node: node} = tree), do: values(tree, [])
  def values(%RoseTree{node: node, children: []}, acc), do: Enum.reverse([node | acc])
  def values(%RoseTree{node: node, children: children}, acc) do
    Enum.reverse(for child <- children, do: values(child, [node | acc]))
  end

  @doc """
  Replace the value of any node that matches a given value.

  ## Examples
      iex> tree = RoseTree.new(:a) |> RoseTree.add_child(RoseTree.new(:b))
      ...> RoseTree.update_node(tree, :a, :hello)
      %RoseTree{node: :hello, children: [%RoseTree{node: :b, children: []}]}
  """
  @spec update_node(RoseTree.t, any(), any()) :: RoseTree.t
  def update_node(%RoseTree{node: value, children: children}, value, new_value) do
    %RoseTree{node: new_value, children: children}
  end
  def update_node(%RoseTree{node: node, children: []} = tree, _value, _new_value), do: tree
  def update_node(%RoseTree{node: node, children: children}, value, new_value) do
    updated_children = for child <- children, do: update_node(child, value, new_value)
    %RoseTree{node: node, children: updated_children}
  end

  @doc """
  Replace the children of a given node.

  ## Examples
      iex> tree = RoseTree.new(:a) |> RoseTree.add_child(RoseTree.new(:b))
      ...> RoseTree.update_children(tree, :a, [RoseTree.new(:c)])
      %RoseTree{node: :a, children: [%RoseTree{node: :c, children: []}]}
  """
  @spec update_children(RoseTree.t, any(), any()) :: RoseTree.t
  def update_children(%RoseTree{node: value, children: children}, value, new_children) do
    %RoseTree{node: value, children: new_children}
  end
  def update_children(%RoseTree{node: node, children: []} = tree, _value, _new_children), do: tree
  def update_children(%RoseTree{node: node, children: children}, value, new_children) do
    updated_children = for child <- children, do: update_children(child, value, new_children)
    %RoseTree{node: node, children: updated_children}
  end

  # TODO Not finished below

  def traverse_depth(%RoseTree{node: _node, children: []} = tree), do: tree
  def traverse_depth(%RoseTree{node: _node, children: [c1 | children]}), do: c1

  def traverse_children(%RoseTree{node: node, children: children} = tree) do
    #for child <- children, do: f.(child)
    Stream.unfold(tree,
      fn %RoseTree{node: _n, children: []} -> nil;
        %RoseTree{node: _n, children: [c1 | children]} = tree -> {tree, c1}
      end)
  end
end
