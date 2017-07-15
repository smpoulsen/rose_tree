defmodule RoseTree.Zipper do
  alias RoseTree.Zipper
  @moduledoc """
  A zipper provides a mechanism for traversing a tree by focusing on
  a given node and maintaining enough data to reconstruct the overall
  tree from any given node.

  Because most of the functions in RoseTree.Zipper can attempt to access data that
  may not exist, e.g. an out-of-bounds index in a node's array of chlidren, the majority
  of the functions return values with tagged tuples to let the user explicitly handle
  success and error cases: {:ok, {%RoseTree{}, []}} | {:error, {:rose_tree, error_message}}

  To make working with these values easier, the function `lift/2` takes one of these tagged
  tuple, either zipper | error, values and a function. If the first argument is an error,
  the error is passed through; if it is an {:ok, zipper} tuple, the function is applied to
  the zipper. In this way, you can call successive tree manipulation functions with ease.
  """

  @type breadcrumb :: %{node: any(), index: integer(), other_children: [any()]}
  @type t :: {RoseTree.t, [breadcrumb]}
  @type either_zipper :: {:ok, Zipper.t} | {:error, tuple()}

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
      ...> |> Zipper.lift(&Zipper.to_tree(&1))
      %RoseTree{node: :b, children: []}
  """
  @spec to_tree(Zipper.t) :: RoseTree.t
  def to_tree({%RoseTree{} = tree, _crumbs}), do: tree

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
      {:ok, {%RoseTree{node: :b, children: []}, [%{
        node: :a,
        index: 0,
        other_children: [
          %RoseTree{node: :c, children: [
            %RoseTree{node: :d, children: []},
            %RoseTree{node: :z, children: []}
          ]}
        ]
      }]}}
  """
  @spec descend(Zipper.t, integer()) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_children}}
  def descend({%RoseTree{children: []}, _breadcrumbs}, _index), do: {:error, {:rose_tree, :no_children}}
  def descend({%RoseTree{} = tree, breadcrumbs}, index) when is_list(breadcrumbs) and is_integer(index) do
    with {elem, %RoseTree{node: node, children: updated_children}} <- RoseTree.pop_child_at(tree, index) do
      new_breadcrumb = %{node: node, index: index, other_children: updated_children}
      {:ok, {elem, [new_breadcrumb | breadcrumbs]}}
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
      ...> {:ok, descended} = Zipper.descend({tree, []}, 0)
      ...> Zipper.ascend(descended)
      {:ok,
        {%RoseTree{node: :a, children: [
          %RoseTree{node: :b, children: []},
          %RoseTree{node: :c, children: [
            %RoseTree{node: :d, children: []},
            %RoseTree{node: :z, children: []}
          ]}
        ]}, []}
      }
  """
  @spec ascend(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_parent}}
  def ascend({%RoseTree{}, []}), do: {:error, {:rose_tree, :no_parent}}
  def ascend({%RoseTree{} = tree, [%{index: idx, node: value, other_children: others} | crumbs]}) do
    siblings = List.insert_at(others, idx, tree)
    {:ok, {%RoseTree{node: value, children: siblings}, crumbs}}
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
    ...> {:ok, descended} = Zipper.descend({tree, []}, 0)
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
  Remove a subtree from a tree and move focus to the parent node.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(0)
      ...> |> Zipper.lift(&Zipper.prune(&1))
      ...> |> Zipper.to_tree()
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
    ...> tree
    ...> |> Zipper.from_tree()
    ...> |> Zipper.descend(1)
    ...> |> Zipper.lift(&Zipper.descend(&1, 0))
    ...> |> Zipper.lift(&Zipper.to_root(&1))
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
  def to_root({_tree, _crumbs} = zipper), do: lift(ascend(zipper), &to_root/1)


  @doc """
  Move the zipper's focus to the node's first child.

  If the node is a leaf (and thus has no children), returns {:error, {:rose_tree, :no_children}}.
  Otherwise, returns {:ok, zipper}

  ## Examples
  iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
  ...>      {:ok, d} <- RoseTree.new(:d),
  ...>      {:ok, z} <- RoseTree.new(:z),
  ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
  ...>   RoseTree.new(:a, [b, c])
  ...> end
  ...> tree
  ...> |> Zipper.from_tree()
  ...> |> Zipper.first_child()
  {:ok, {%RoseTree{node: :b, children: []}, [%{
    node: :a,
    index: 0,
    other_children: [
      %RoseTree{node: :c, children: [
        %RoseTree{node: :d, children: []},
        %RoseTree{node: :z, children: []}
      ]}
    ]
  }]}}
  """
  @spec first_child(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_children}}
  def first_child({%RoseTree{children: []}, _crumbs}), do: {:error, {:rose_tree, :bad_path}}
  def first_child({%RoseTree{}, _crumbs} = zipper), do: descend(zipper, 0)

  @doc """
  Move the zipper's focus to the node's last child.

  If the node is a leaf (and thus has no children), returns {:error, {:rose_tree, :no_children}}.
  Otherwise, returns {:ok, zipper}

  ## Examples
  iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
  ...>      {:ok, d} <- RoseTree.new(:d),
  ...>      {:ok, z} <- RoseTree.new(:z),
  ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
  ...>   RoseTree.new(:a, [b, c])
  ...> end
  ...> tree
  ...> |> Zipper.from_tree()
  ...> |> Zipper.last_child()
  {:ok, {
    %RoseTree{node: :c, children: [
      %RoseTree{node: :d, children: []},
      %RoseTree{node: :z, children: []}
    ]},
    [%{node: :a, index: 1, other_children: [%RoseTree{node: :b, children: []}]}]
  }}
  """
  @spec last_child(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_children}}
  def last_child({%RoseTree{children: []}, _crumbs}), do: {:error, {:rose_tree, :bad_path}}
  def last_child({%RoseTree{} = tree, _crumbs} = zipper), do: descend(zipper, Enum.count(tree.children) - 1)

  @doc """
  Move the zipper's focus to the next sibling of the currently focused node.

  ## Examples
      iex> {:ok, tree} = with {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [c])
      ...> end
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(0)
      ...> |> Zipper.lift(&Zipper.descend(&1, 0))
      ...> |> Zipper.lift(&Zipper.next_sibling/1)
      {:ok, {
        %RoseTree{children: [], node: :z}, [
          %{index: 1, node: :c, other_children: [%RoseTree{children: [], node: :d}]},
          %{index: 0, node: :a, other_children: []}
        ]
      }}

      iex> {:ok, tree} = with {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [c])
      ...> end
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(0)
      ...> |> Zipper.lift(&Zipper.descend(&1, 1))
      ...> |> Zipper.lift(&Zipper.next_sibling/1)
      {:error, {:rose_tree, :no_next_sibling}}
  """
  @spec next_sibling(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_siblings}} | {:error, {:rose_tree, :no_next_sibling}}
  def next_sibling({%RoseTree{}, []}), do: {:error, {:rose_tree, :no_siblings}}
  def next_sibling({%RoseTree{}, [%{index: index, other_children: children} | _t]} = zipper) do
    at_last_child = (index + 1) > length(children)
    if at_last_child do
      {:error, {:rose_tree, :no_next_sibling}}
    else
      zipper
      |> ascend()
      |> lift(&descend(&1, index + 1))
    end
  end

  @doc """
  Move the zipper's focus to the previous sibling of the currently focused node.

  ## Examples
      iex> {:ok, tree} = with {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [c])
      ...> end
      ...> d_focus = tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(0)
      ...> |> Zipper.lift(&Zipper.descend(&1, 1))
      ...> |> Zipper.lift(&Zipper.previous_sibling/1)
      {:ok, {
        %RoseTree{children: [], node: :d}, [
          %{index: 0, node: :c, other_children: [%RoseTree{children: [], node: :z}]},
          %{index: 0, node: :a, other_children: []}
        ]
      }}

      iex> {:ok, tree} = with {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [c])
      ...> end
      ...> d_focus = tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(0)
      ...> |> Zipper.lift(&Zipper.descend(&1, 0))
      ...> |> Zipper.lift(&Zipper.previous_sibling/1)
      {:error, {:rose_tree, :no_previous_sibling}}
  """
  @spec previous_sibling(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_siblings}} | {:error, {:rose_tree, :no_previous_sibling}}
  def previous_sibling({%RoseTree{}, []}), do: {:error, {:rose_tree, :no_siblings}}
  def previous_sibling({%RoseTree{}, [%{index: index} | _t]} = zipper) do
    at_first_child = (index - 1) < 0
    if at_first_child do
      {:error, {:rose_tree, :no_previous_sibling}}
    else
      zipper
      |> ascend()
      |> Zipper.lift(&descend(&1, index - 1))
    end
  end

  @doc """
  Move the zipper's focus to the node's first child that matches a predicate.

  ## Examples
      iex> {:ok, tree} = with {:ok, d} <- RoseTree.new(15),
      ...>      {:ok, z} <- RoseTree.new(5),
      ...>      {:ok, c} <- RoseTree.new(1, [d, z]) do
      ...>   RoseTree.new(:a, [c])
      ...> end
      ...> d_focus = tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(0)
      ...> |> Zipper.lift(&Zipper.find_child(&1, fn(child) -> child.node > 10 end))
      {:ok, {
        %RoseTree{children: [], node: 15}, [
          %{index: 0, node: 1, other_children: [%RoseTree{children: [], node: 5}]},
          %{index: 0, node: :a, other_children: []}
        ]
      }}

      iex> {:ok, tree} = with {:ok, d} <- RoseTree.new(15),
      ...>      {:ok, z} <- RoseTree.new(5),
      ...>      {:ok, c} <- RoseTree.new(1, [d, z]) do
      ...>   RoseTree.new(:a, [c])
      ...> end
      ...> d_focus = tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(0)
      ...> |> Zipper.lift(&Zipper.find_child(&1, fn(child) -> length(child.children) > 5 end))
      {:error, {:rose_tree, :no_child_match}}
  """
  @spec find_child(Zipper.t, (any() -> any())) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_child_match}}
  def find_child({%RoseTree{children: children}, _crumbs} = zipper, predicate) when is_function(predicate) do
    matching_index = Enum.find_index(children, predicate)
    if matching_index == nil do
      {:error, {:rose_tree, :no_child_match}}
    else
      descend(zipper, matching_index)
    end
  end

  @doc """
  Lift a function expecting a zipper as an argument to one that can handle either
  {:ok, zipper} | {:error, error}.

  If the first argument is an :error tuple, the error is passed through.
  Otherwise, the function is applied to the zipper in the :ok tuple.

  ## Examples
      iex> {:ok, tree} = with {:ok, b} <- RoseTree.new(:b),
      ...>      {:ok, d} <- RoseTree.new(:d),
      ...>      {:ok, z} <- RoseTree.new(:z),
      ...>      {:ok, c} <- RoseTree.new(:c, [d, z]) do
      ...>   RoseTree.new(:a, [b, c])
      ...> end
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(1)
      ...> |> Zipper.lift(&Zipper.descend(&1, 0))
      ...> |> Zipper.lift(&Zipper.to_tree(&1))
      %RoseTree{node: :d, children: []}

      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.descend(1)
      ...> |> Zipper.lift(&Zipper.descend(&1, 0))
      ...> |> Zipper.lift(&Zipper.descend(&1, 1))
      {:error, {:rose_tree, :bad_path}}
  """
  @spec lift(either_zipper, (any() -> any())) :: either_zipper
  def lift({:ok, zipper}, f), do: f.(zipper)
  def lift({:error, _} = error, _f), do: error
end
