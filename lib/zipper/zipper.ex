defmodule RoseTree.Zipper do
  alias RoseTree.Zipper
  @moduledoc """
  A zipper provides a mechanism for traversing a tree by focusing on
  a given node and maintaining enough data to reconstruct the overall
  tree from any given node.
  """

  @type breadcrumb :: %{node: any(), index: integer(), other_children: [any()]}
  @type t :: {RoseTree.t, [breadcrumb]}

  @doc """
  Build a zipper focusing on the current tree.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> Zipper.from_tree(tree)
      {%RoseTree{node: :a, children: [
        %RoseTree{node: :b, children: []},
        %RoseTree{node: :c, children: [
          %RoseTree{node: :d, children: []},
          %RoseTree{node: :z, children: []}
        ]}
      ]}, []}
  """
  @spec from_tree(RoseTree.t) :: Zipper.t
  def from_tree(%RoseTree{} = tree), do: {tree, []}

  @doc """
  Extract the currently focused tree from a zipper.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> Zipper.descend({tree, []}, 0)
      ...> |> Zipper.to_tree
      %RoseTree{node: :b, children: []}
  """
  @spec to_tree(Zipper.t) :: RoseTree.t
  def to_tree({tree, _crumbs}), do: tree

  @doc """
  Descend into a node in such a way that you can reconstruct the tree from the bottom up.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> Zipper.descend({tree, []}, 0)
      {%RoseTree{node: :b, children: []}, [%{
        node: :a,
        index: 0,
        other_children: [
          %RoseTree{node: :c, children: [
            %RoseTree{node: :d, children: []},
            %RoseTree{node: :z, children: []}
          ]}
        ]
      }]}
  """
  @spec descend(Zipper.t, integer()) :: Zipper.t
  def descend({%RoseTree{} = tree, breadcrumbs}, index) when is_list(breadcrumbs) do
    with {elem, %RoseTree{node: node, children: updated_children}} <- RoseTree.pop_child_at(tree, index) do
      new_breadcrumb = %{node: node, index: index, other_children: updated_children}
      {elem, [new_breadcrumb | breadcrumbs]}
    end
  end

  @doc """
  Reconstruct a node from the bottom up.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> descended = Zipper.descend({tree, []}, 0)
      ...> Zipper.ascend(descended)
      {%RoseTree{node: :a, children: [
        %RoseTree{node: :b, children: []},
        %RoseTree{node: :c, children: [
          %RoseTree{node: :d, children: []},
          %RoseTree{node: :z, children: []}
        ]}
      ]}, []}
  """
  @spec ascend(Zipper.t) :: Zipper.t
  def ascend({%RoseTree{} = tree, []}), do: {tree, []}
  def ascend({%RoseTree{} = tree, [%{index: idx, node: value, other_children: others} | crumbs]}) do
    siblings = List.insert_at(others, idx, tree)
    {%RoseTree{node: value, children: siblings}, crumbs}
  end

  @doc """
  Apply a function to the value of a tree under the focus of a zipper.

  ## Examples
    iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(1),
    ...>      {:ok, d} <- RoseTree.new(11),
    ...>      {:ok, z} <- RoseTree.new(12),
    ...>      {:ok, c} <- RoseTree.new(10, [d, z]) do
    ...>   RoseTree.new(0, [b, c])
    ...> end
    ...> descended = Zipper.descend({tree, []}, 0)
    ...> Zipper.modify(descended, fn(x) -> x * 5 end)
    {%RoseTree{node: 5, children: []}, [%{
      node: 0,
      index: 0,
      other_children: [
        %RoseTree{node: 10, children: [
          %RoseTree{node: 11, children: []},
          %RoseTree{node: 12, children: []}
        ]}
      ]
    }]}
  """
  @spec modify(Zipper.t, (any() -> any())) :: Zipper.t
  def modify({%RoseTree{node: node} = tree, crumbs}, f) do
    {%RoseTree{tree | node: f.(node)}, crumbs}
  end

  @doc """
  Remove a subtree from a tree and return to the parent node.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> {tree, []} = Zipper.descend({tree, []}, 0)
      ...> |> Zipper.prune()
      ...> tree
      %RoseTree{node: :a, children: [
        %RoseTree{node: :c, children: [
          %RoseTree{node: :d, children: []},
          %RoseTree{node: :z, children: []}
        ]}
      ]}
  """
  @spec prune(Zipper.t) :: Zipper.t
  def prune({%RoseTree{}, [%{node: value, other_children: siblings} | crumbs]}) do
      {%RoseTree{node: value, children: siblings}, crumbs}
  end

  @doc """
  Ascend from any node to the root of the tree.

  ## Examples
    iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
    ...>      {:ok, d} <- RoseTree.new(:d),
    ...>      {:ok, z} <- RoseTree.new(:z),
    ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
    ...>   RoseTree.new(:a, [b, c])
    ...> end
    ...> {tree, _crumbs} = zipper = {tree, []}
    ...> |> Zipper.descend(1)
    ...> |> Zipper.descend(0)
    ...> tree
    %RoseTree{node: :d, children: []}
    ...> Zipper.to_root(zipper)
    %RoseTree{node: :a, children: [
      %RoseTree{node: :b, children: []},
      %RoseTree{node: :c, children: [
        %RoseTree{node: :d, children: []},
        %RoseTree{node: :z, children: []}
      ]}
    ]}
  """
  @spec to_root(Zipper.t) :: RoseTree.t
  def to_root({tree, []}), do: tree
  def to_root({_tree, _crumbs} = zipper), do: to_root(ascend(zipper))
end
