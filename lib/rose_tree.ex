defmodule RoseTree do
  @moduledoc """
  A rose tree is an n-ary tree in which each node has zero or more children, all
  of which are themselves rose trees.

  Trees are unbalanced and children unordered.
  """

  @enforce_keys [:node, :children]
  defstruct node: :empty, children: []

  @type t :: %RoseTree{node: any(), children: [%RoseTree{}]}
  @type breadcrumb :: %{node: any(), index: integer(), other_children: [any()]}
  @type zipper :: {RoseTree.t, [breadcrumb]}

  @doc """
  Initialize a new rose tree with a node value and empty children.

  ## Examples
      iex> RoseTree.new(:a)
      {:ok, %RoseTree{node: :a, children: []}}
  """
  @spec new(any()) :: {:ok, RoseTree.t}
  def new(value), do: {:ok, %RoseTree{node: value, children: []}}

  @doc """
  Initialize a new rose tree with a node value and children.

  ## Examples
      iex> with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, c} <- RoseTree.new(:c) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      {:ok, %RoseTree{node: :a, children: [
        %RoseTree{node: :b, children: []},
        %RoseTree{node: :c, children: []}
      ]}}
  """
  @spec new(any(), any()) :: {:ok, RoseTree.t} | {:error, tuple()}
  def new(value, children) when is_list(children) do
    if Enum.all?(children, &(is_rose_tree?(&1))) do
      {:ok, %RoseTree{node: value, children: children}}
    else
      {:error, {:rose_tree, :bad_children}}
    end
  end
  def new(value, %RoseTree{} = child), do: {:ok, %RoseTree{node: value, children: [child]}}
  def new(value, child) do
    case new(child) do
      {:ok, child_tree} ->
        {:ok, %RoseTree{node: value, children: [child_tree]}}
    end
  end

  @doc """
  Add a new child to a tree.

  If the tree already has children, the new child is added to the front.

  If the value of the new child's node is already present in the tree's children,
  then the new child's children are merged with the existing child's children.

  ## Examples
      iex> {:ok, hello} = RoseTree.new(:hello)
      ...> {:ok, world} = RoseTree.new(:world)
      ...> RoseTree.add_child(hello, world)
      %RoseTree{node: :hello, children: [
        %RoseTree{node: :world, children: []}
      ]}

      iex> {:ok, hello} = RoseTree.new(:hello)
      ...> {:ok, world_wide} = RoseTree.new(:world, :wide)
      ...> {:ok, world_champ} = RoseTree.new(:world, :champ)
      ...> {:ok, dave} = RoseTree.new(:dave)
      ...> hello
      ...> |> RoseTree.add_child(world_wide)
      ...> |> RoseTree.add_child(world_champ)
      ...> |> RoseTree.add_child(dave)
      %RoseTree{children: [
        %RoseTree{children: [], node: :dave},
        %RoseTree{children: [
          %RoseTree{node: :champ, children: []},
          %RoseTree{node: :wide, children: []}],
          node: :world}
      ], node: :hello}
  """
  @spec add_child(RoseTree.t, RoseTree.t) :: RoseTree.t
  def add_child(%RoseTree{} = tree, {:ok, child}), do: add_child(tree, child)
  def add_child(%RoseTree{node: n, children: children} = tree, child) do
    if is_child?(tree, child) do
      matching_node = Enum.find(children, fn(c) -> c.node == child.node end)
      merged_children = Enum.map(child.children, &add_child(matching_node, &1))
      update_children(tree, n, merged_children)
    else
      %RoseTree{node: n, children: [child | children]}
    end
  end

  @doc """
  Determines whether a node is a child of a tree.

  The determination is based on whether the value of the node of the potential child
  matches a node value in the tree of interest.

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, tree} = with {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> RoseTree.is_child?(tree, b)
      true
      ...> {:ok, x} = RoseTree.new(:x)
      ...> RoseTree.is_child?(tree, x)
      false
  """
  @spec is_child?(RoseTree.t, RoseTree.t) :: boolean
  def is_child?(%RoseTree{children: children}, %RoseTree{node: child_node}) do
    children
    |> Enum.map(&(&1.node))
    |> Enum.member?(child_node)
  end

  @doc """
  Remove the first child from the children of a node.

  Returns a tuple containing the child that was removed and the modified tree.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> RoseTree.pop_child(tree)
      {%RoseTree{node: :b, children: []}, %RoseTree{
        node: :a, children: [
          %RoseTree{node: :c, children: [
            %RoseTree{node: :d, children: []},
            %RoseTree{node: :z, children: []}
          ]}
        ]
      }}

      iex> {:ok, hello} = RoseTree.new(:hello)
      ...> RoseTree.pop_child(hello)
      {nil, %RoseTree{node: :hello, children: []}}
  """
  @spec pop_child(RoseTree.t) :: {RoseTree.t, RoseTree.t} | {nil, RoseTree.t}
  def pop_child(tree), do: pop_child_at(tree, 0)

  @doc """
  Remove the child at a given index from the children of a node.

  Returns a tuple containing the child that was removed and the modified tree.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> RoseTree.pop_child_at(tree, 1)
      {%RoseTree{node: :c, children: [
        %RoseTree{node: :d, children: []},
        %RoseTree{node: :z, children: []}]},
        %RoseTree{node: :a, children: [
          %RoseTree{node: :b, children: []},
        ]}
      }
  """
  @spec pop_child_at(RoseTree.t, integer()) :: {RoseTree.t, RoseTree.t} | {nil, RoseTree.t}
  def pop_child_at(%RoseTree{children: []} = tree, _idx), do: {nil, tree}
  def pop_child_at(%RoseTree{node: node, children: children} = tree, idx) when is_number(idx) do
    {child, updated_children} = List.pop_at(children, idx)
    {child, update_children(tree, node, updated_children)}
  end

  @doc """
  Convert a map into a rose tree.

  ## Examples
      iex> RoseTree.from_map(%{a: [:b]})
      {:ok, %RoseTree{node: :a, children: [%RoseTree{node: :b, children: []}]}}

      iex> RoseTree.from_map(%{a: %{b: [:c]}})
      {:ok, %RoseTree{node: :a, children: [
        %RoseTree{node: :b, children: [
          %RoseTree{node: :c, children: []}
        ]}
      ]}}
  """
  @spec from_map(map()) :: {:error, tuple()} | {:ok, RoseTree.t}
  def from_map(%{} = map) do
    {:ok, from_map_helper(map)}
  end

  defp from_map_helper(children) when is_list(children) do
    for child <- children do
      {:ok, tree} = new(child)
      tree
    end
  end
  defp from_map_helper(%{} = map) do
    if length(Map.keys(map)) > 1 do
      {:error, {:rose_tree, :one_node_root}}
    else
      res = for {k, v} <- map do
        {:ok, tree} = new(k, from_map_helper(v))
        tree
      end
      hd(res)
    end
  end

  @doc """
  List all of the possible paths through a tree.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> RoseTree.paths(tree)
      [[:a, :b], [[:a, :c, :d], [:a, :c, :z]]]
  """
  @spec paths(RoseTree.t) :: [any()]
  def paths(%RoseTree{} = tree), do: paths(tree, [])
  def paths(%RoseTree{node: node, children: []}, acc), do: Enum.reverse([node | acc])
  def paths(%RoseTree{node: node, children: children}, acc) do
    for child <- children, do: paths(child, [node | acc])
  end

  @spec lazy_paths(RoseTree.t):: any()
  def lazy_paths(%RoseTree{} = tree) do
    # TODO Implement
  end

  @doc """
  Extract the node values of a rose tree into a list.

  TODO optimize to use lazy lists

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> RoseTree.to_list(tree)
      [:a, :b, :c, :d, :z]
  """
  @spec to_list(RoseTree.t) :: [any()]
  def to_list(%RoseTree{} = tree), do: to_list(tree, [])
  defp to_list(%RoseTree{node: node, children: []}, _acc), do: [node]
  defp to_list(%RoseTree{node: node, children: children}, acc) do
    reduced_children = for child <- children do
      to_list(child, acc)
    end
    List.flatten([node | reduced_children])
  end

  @doc """
  Fetch a node's value by traversing a path of indicies through nodes and their children.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> RoseTree.elem_at(tree, [])
      {:ok, :a}
      ...> RoseTree.elem_at(tree, [1, 0])
      {:ok, :d}
      ...> RoseTree.elem_at(tree, [1, 2])
      {:error, {:rose_tree, :bad_path}}
  """
  @spec elem_at(RoseTree.t, list(integer())) :: {:ok, any()} | {:error, tuple()}
  def elem_at(%RoseTree{node: node}, []), do: {:ok, node}
  def elem_at(%RoseTree{children: children}, [h | t]) when h <= length(children) do
    children
    |> Enum.at(h)
    |> elem_at(t)
  end
  def elem_at(_, _), do: {:error, {:rose_tree, :bad_path}}

  # Zipper stuff.
  @doc """
  Descend into a node in such a way that you can reconstruct the tree from the bottom up.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> RoseTree.descend({tree, []}, 0)
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
  @spec descend(zipper, integer()) :: zipper
  def descend({%RoseTree{} = tree, breadcrumbs}, index) when is_list(breadcrumbs) do
    with {elem, %RoseTree{node: node, children: updated_children}} <- pop_child_at(tree, index) do
      new_breadcrumb = %{node: node, index: index, other_children: updated_children}
      {elem, [new_breadcrumb | breadcrumbs]}
    end
  end

  @spec descend(RoseTree.t, integer()) :: zipper
  def descend(%RoseTree{} = tree, index) when is_integer(index), do: descend({tree, []}, index)

  @doc """
  Reconstruct a node from the bottom up.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> descended = RoseTree.descend({tree, []}, 0)
      ...> RoseTree.ascend(descended)
      {%RoseTree{node: :a, children: [
        %RoseTree{node: :b, children: []},
        %RoseTree{node: :c, children: [
          %RoseTree{node: :d, children: []},
          %RoseTree{node: :z, children: []}
        ]}
      ]}, []}
  """
  @spec ascend(zipper) :: zipper
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
    ...> descended = RoseTree.descend({tree, []}, 0)
    ...> RoseTree.modify(descended, fn(x) -> x * 5 end)
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
  @spec modify(zipper, (any() -> any())) :: zipper
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
      ...> {tree, []} = RoseTree.descend({tree, []}, 0)
      ...> |> RoseTree.prune()
      ...> tree
      %RoseTree{node: :a, children: [
        %RoseTree{node: :c, children: [
          %RoseTree{node: :d, children: []},
          %RoseTree{node: :z, children: []}
        ]}
      ]}
  """
  @spec prune(zipper) :: zipper
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
    ...> |> RoseTree.descend(1)
    ...> |> RoseTree.descend(0)
    ...> tree
    %RoseTree{node: :d, children: []}
    ...> RoseTree.to_root(zipper)
    %RoseTree{node: :a, children: [
      %RoseTree{node: :b, children: []},
      %RoseTree{node: :c, children: [
        %RoseTree{node: :d, children: []},
        %RoseTree{node: :z, children: []}
      ]}
    ]}
  """
  @spec to_root(zipper) :: RoseTree.t
  def to_root({tree, []}), do: tree
  def to_root({tree, crumbs} = zipper), do: to_root(ascend(zipper))


  @doc """
  Replace the value of any node that matches a given value.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b) do
      ...>   RoseTree.new(:a, [b])
      ...> end
      ...> RoseTree.update_node(tree, :a, :hello)
      %RoseTree{node: :hello, children: [%RoseTree{node: :b, children: []}]}
  """
  @spec update_node(RoseTree.t, any(), any()) :: RoseTree.t
  def update_node(%RoseTree{node: value, children: children}, value, new_value) do
    %RoseTree{node: new_value, children: children}
  end
  def update_node(%RoseTree{children: []} = tree, _value, _new_value), do: tree
  def update_node(%RoseTree{node: node, children: children}, value, new_value) do
    updated_children = for child <- children, do: update_node(child, value, new_value)
    %RoseTree{node: node, children: updated_children}
  end

  @doc """
  Replace the children of a node that matches a given value.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b) do
      ...>   RoseTree.new(:a, [b])
      ...> end
      ...> {:ok, c} = RoseTree.new(:c)
      ...> RoseTree.update_children(tree, :a, [c])
      %RoseTree{node: :a, children: [%RoseTree{node: :c, children: []}]}
  """
  @spec update_children(RoseTree.t, any(), any()) :: RoseTree.t
  def update_children(%RoseTree{children: []} = tree, _value, _new_children), do: tree
  def update_children(%RoseTree{node: value}, value, new_children) do
    %RoseTree{node: value, children: new_children}
  end
  def update_children(%RoseTree{node: node, children: children}, value, new_children) do
    updated_children = for child <- children, do: update_children(child, value, new_children)
    %RoseTree{node: node, children: updated_children}
  end

  defp is_rose_tree?(%RoseTree{}), do: true
  defp is_rose_tree?(_), do: false

  defimpl Enumerable do
    def count(%RoseTree{} = tree), do: {:ok, count(tree, 0)}

    defp count(%RoseTree{children: []}, acc), do: acc + 1 # This counts the leaves
    defp count(%RoseTree{children: children}, acc) do
      Enum.sum(Enum.map(children, &count(&1, acc))) + 1
    end

    def member?(%RoseTree{node: node}, node), do: {:ok, true}
    def member?(%RoseTree{node: node, children: []}, elem) when node != elem, do: {:ok, false}
    def member?(%RoseTree{} = tree, elem) do
      {:ok, member?(tree, elem, false)}
    end

    defp member?(%RoseTree{children: children}, elem, acc) do
      Enum.reduce(children, acc, fn(child, acc) ->
        {:ok, res} = member?(child, elem)
        if res, do: true, else: acc
      end)
    end

    def reduce(tree, acc, f) do
      reduce_tree(RoseTree.to_list(tree), acc, f)
    end

    defp reduce_tree(_, {:halt, acc}, _f), do: {:halted, acc}
    defp reduce_tree(tree, {:suspend, acc}, f), do: {:suspended, acc, &reduce_tree(tree, &1, f)}
    defp reduce_tree([], {:cont, acc}, _f), do: {:done, acc}
    defp reduce_tree([h | t], {:cont, acc}, f), do: reduce_tree(t, f.(h, acc), f)
  end
end
