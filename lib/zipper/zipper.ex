defmodule RoseTree.Zipper do
  alias RoseTree.Zipper
  @moduledoc """
  A zipper provides a mechanism for traversing a tree by focusing on
  a given node and maintaining enough data to reconstruct the overall
  tree from any given node.

  Because most of the functions in `RoseTree.Zipper` can attempt to access data that
  may not exist, e.g. an out-of-bounds index in a node's array of chlidren, the majority
  of the functions return values with tagged tuples to let the user explicitly handle
  success and error cases: `{:ok, {%RoseTree{}, []}} | {:error, {:rose_tree, error_message}}`

  To make working with these values easier, the function `lift/2` takes one of these tagged
  tuple (`either zipper | error`) values and a function. If the first argument is an error,
  the error is passed through; if it is an `{:ok, zipper}` tuple, the function is applied to
  the zipper. This lets you easily chain successive calls to tree manipulation functions.
  """

  @type breadcrumb :: %{parent: any(), left_siblings: [any()], right_siblings: [any()]}
  @type t :: {RoseTree.t, [breadcrumb]}
  @type either_zipper :: {:ok, Zipper.t} | {:error, tuple()}

  @doc """
  Build a zipper focusing on the current tree.

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
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
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> Zipper.nth_child({tree, []}, 0)
      ...> |> Zipper.lift(&Zipper.to_tree(&1))
      %RoseTree{node: :b, children: []}
  """
  @spec to_tree(Zipper.t) :: RoseTree.t
  def to_tree({%RoseTree{} = tree, _crumbs} = _zipper), do: tree

  @doc """
  Move the zipper's focus to the child at the given index.

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> Zipper.nth_child({tree, []}, 0)
      {:ok, {%RoseTree{node: :b, children: []}, [%{
        parent: :a,
        left_siblings: [],
        right_siblings: [
          %RoseTree{node: :c, children: [
            %RoseTree{node: :d, children: []},
            %RoseTree{node: :z, children: []}
          ]}
        ]
      }]}}
  """
  @spec nth_child(Zipper.t, integer()) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_children}}
  def nth_child({%RoseTree{children: []}, _breadcrumbs} = _zipper, _index), do: {:error, {:rose_tree, :no_children}}
  def nth_child({%RoseTree{node: node, children: [h | t]}, breadcrumbs} = zipper, index) when is_list(breadcrumbs) and is_integer(index) do
    case index do
      0 ->
        {:ok, {h, [%{parent: node, left_siblings: [], right_siblings: t} | breadcrumbs]}}
      _ ->
        lift(nth_child(zipper, index - 1), &next_sibling/1)
    end
  end

  @doc """
  Move up the tree to the parent of the node that the zipper is currently focused on.

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> {:ok, nth_childed} = Zipper.nth_child({tree, []}, 0)
      ...> Zipper.ascend(nth_childed)
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
  def ascend({%RoseTree{}, []} = _zipper), do: {:error, {:rose_tree, :no_parent}}
  def ascend({%RoseTree{} = tree, [%{parent: parent_value, left_siblings: l, right_siblings: r} | crumbs]} = _zipper) do
    children = Enum.reverse(l) ++ [tree | r]
    {:ok, {%RoseTree{node: parent_value, children: children}, crumbs}}
  end

  @doc """
  Apply a function to the value of a tree under the focus of a zipper.

  ## Examples
      iex> {:ok, b} = RoseTree.new(1)
      ...> {:ok, d} = RoseTree.new(11)
      ...> {:ok, z} = RoseTree.new(12)
      ...> {:ok, c} = RoseTree.new(10, [d, z])
      ...> {:ok, tree} = RoseTree.new(0, [b, c])
      ...> {:ok, nth_childed} = Zipper.nth_child({tree, []}, 0)
      ...> Zipper.modify(nth_childed, fn(x) -> x * 5 end)
      {%RoseTree{node: 5, children: []}, [%{
        parent: 0,
        left_siblings: [],
        right_siblings: [
          %RoseTree{node: 10, children: [
            %RoseTree{node: 11, children: []},
            %RoseTree{node: 12, children: []}
          ]}
        ]
      }]}
  """
  @spec modify(Zipper.t, (any() -> any())) :: Zipper.t
  def modify({%RoseTree{node: node} = tree, crumbs} = _zipper, f) do
    {%RoseTree{tree | node: f.(node)}, crumbs}
  end

  @doc """
  Remove a subtree from a tree and move focus to the parent node.

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.nth_child(0)
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
  def prune({%RoseTree{}, [%{parent: value, left_siblings: l, right_siblings: r} | crumbs]} = _zipper) do
      {%RoseTree{node: value, children: l ++ r}, crumbs}
  end

  @doc """
  Ascend from any node to the root of the tree.

  If the focus is already on the root, it does not move.

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.nth_child(1)
      ...> |> Zipper.lift(&Zipper.nth_child(&1, 0))
      ...> |> Zipper.lift(&Zipper.to_root(&1))
      %RoseTree{node: :a, children: [
        %RoseTree{node: :b, children: []},
        %RoseTree{node: :c, children: [
          %RoseTree{node: :d, children: []},
          %RoseTree{node: :z, children: []}
        ]}
      ]}

      iex> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, e} = RoseTree.new(:e)
      ...> {:ok, x} = RoseTree.new(:x)
      ...> {:ok, y} = RoseTree.new(:y)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, b} = RoseTree.new(:b, [x, y, z])
      ...> {:ok, c} = RoseTree.new(:c, [d, e])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.nth_child(&1, 2))
      ...> |> Zipper.lift(&Zipper.to_root/1)
      %RoseTree{node: :a, children: [
        %RoseTree{node: :b, children: [
          %RoseTree{node: :x, children: []},
          %RoseTree{node: :y, children: []},
          %RoseTree{node: :z, children: []},
        ]},
        %RoseTree{node: :c, children: [
          %RoseTree{node: :d, children: []},
          %RoseTree{node: :e, children: []},
        ]},
      ]}
  """
  @spec to_root(Zipper.t) :: RoseTree.t
  def to_root({tree, []} = _zipper), do: tree
  def to_root({_tree, _crumbs} = zipper), do: lift(ascend(zipper), &to_root/1)

  @doc """
  Nth_Child from the current focus to the left-most child tree.

  If the focus is already on a leaf, it does not move.

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.to_leaf()
      {%RoseTree{node: :b, children: []}, [
        %{
          parent: :a,
          left_siblings: [],
          right_siblings: [
            %RoseTree{node: :c, children: [
              %RoseTree{node: :d, children: []},
              %RoseTree{node: :z, children: []}
            ]}
          ]
        }
      ]}

      iex> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, e} = RoseTree.new(:e)
      ...> {:ok, x} = RoseTree.new(:x)
      ...> {:ok, y} = RoseTree.new(:y)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, b} = RoseTree.new(:b, [x, y, z])
      ...> {:ok, c} = RoseTree.new(:c, [d, e])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.to_leaf()
      {%RoseTree{node: :x, children: []}, [
        %{parent: :b,
          left_siblings: [],
          right_siblings: [
            %RoseTree{node: :y, children: []},
            %RoseTree{node: :z, children: []},
          ]
        },
        %{parent: :a,
          left_siblings: [],
          right_siblings: [
            %RoseTree{node: :c, children: [
              %RoseTree{node: :d, children: []},
              %RoseTree{node: :e, children: []}
            ]}
          ]
        }
      ]}
  """
  @spec to_leaf(Zipper.t) :: Zipper.t
  def to_leaf({%RoseTree{children: []}, _crumbs} = zipper), do: zipper
  def to_leaf({%RoseTree{children: _children}, _crumbs} = zipper) do
    zipper
    |> first_child()
    |> lift(&to_leaf/1)
  end


  @doc """
  Move the zipper's focus to the node's first child.

  If the node is a leaf (and thus has no children), returns {:error, {:rose_tree, :no_children}}.
  Otherwise, returns {:ok, zipper}

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      {:ok, {%RoseTree{node: :b, children: []}, [%{
        parent: :a,
        left_siblings: [],
        right_siblings: [
          %RoseTree{node: :c, children: [
            %RoseTree{node: :d, children: []},
            %RoseTree{node: :z, children: []}
          ]}
        ]
      }]}}
  """
  @spec first_child(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_children}}
  def first_child({%RoseTree{children: []}, _crumbs}), do: {:error, {:rose_tree, :bad_path}}
  def first_child({%RoseTree{}, _crumbs} = zipper), do: nth_child(zipper, 0)

  @doc """
  Move the zipper's focus to the node's last child.

  If the node is a leaf (and thus has no children), returns {:error, {:rose_tree, :no_children}}.
  Otherwise, returns {:ok, zipper}

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.last_child()
      {:ok, {
        %RoseTree{node: :c, children: [
          %RoseTree{node: :d, children: []},
          %RoseTree{node: :z, children: []}
        ]},
        [%{parent: :a, left_siblings: [%RoseTree{node: :b, children: []}], right_siblings: []}]
      }}
  """
  @spec last_child(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_children}}
  def last_child({%RoseTree{children: []}, _crumbs}), do: {:error, {:rose_tree, :bad_path}}
  def last_child({%RoseTree{} = tree, _crumbs} = zipper), do: nth_child(zipper, Enum.count(tree.children) - 1)

  @doc """
  Move the zipper's focus to the next sibling of the currently focused node.

  ## Examples
      iex> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.first_child(&1))
      ...> |> Zipper.lift(&Zipper.next_sibling/1)
      {:ok, {
        %RoseTree{children: [], node: :z}, [
          %{parent: :c, left_siblings: [%RoseTree{children: [], node: :d}], right_siblings: []},
          %{parent: :a, left_siblings: [], right_siblings: []}
        ]
      }}

      iex> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.nth_child(&1, 1))
      ...> |> Zipper.lift(&Zipper.next_sibling/1)
      {:error, {:rose_tree, :no_next_sibling}}
  """
  @spec next_sibling(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_siblings}} | {:error, {:rose_tree, :no_next_sibling}}
  def next_sibling({%RoseTree{}, []}), do: {:error, {:rose_tree, :no_siblings}}
  def next_sibling({%RoseTree{} = tree, [%{} = h | t] = _crumbs} = _zipper) do
    case h.right_siblings do
      [] -> {:error, {:rose_tree, :no_next_sibling}}
      [r | rs] -> {:ok, {r, [%{h | right_siblings: rs, left_siblings: [tree | h.left_siblings]} | t]}}
    end
  end

  @doc """
  Move the zipper's focus to the previous sibling of the currently focused node.

  ## Examples
      iex> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.nth_child(0)
      ...> |> Zipper.lift(&Zipper.nth_child(&1, 1))
      ...> |> Zipper.lift(&Zipper.previous_sibling/1)
      {:ok, {
        %RoseTree{children: [], node: :d}, [
          %{parent: :c, left_siblings: [], right_siblings: [%RoseTree{children: [], node: :z}]},
          %{parent: :a, left_siblings: [], right_siblings: []}
        ]
      }}

      iex> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.nth_child(0)
      ...> |> Zipper.lift(&Zipper.nth_child(&1, 0))
      ...> |> Zipper.lift(&Zipper.previous_sibling/1)
      {:error, {:rose_tree, :no_previous_sibling}}
  """
  @spec previous_sibling(Zipper.t) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_siblings}} | {:error, {:rose_tree, :no_previous_sibling}}
  def previous_sibling({%RoseTree{}, []}), do: {:error, {:rose_tree, :no_siblings}}
  def previous_sibling({%RoseTree{} = tree, [%{} = h | t] = _crumbs} = _zipper) do
    case h.left_siblings do
      [] -> {:error, {:rose_tree, :no_previous_sibling}}
      [l | ls] -> {:ok, {l, [%{h | left_siblings: ls, right_siblings: [tree | h.right_siblings]} | t]}}
    end
  end

  @doc """
  Move the zipper's focus to the node's first child that matches a predicate.

  ## Examples
      iex> {:ok, d} = RoseTree.new(15)
      ...> {:ok, z} = RoseTree.new(5)
      ...> {:ok, c} = RoseTree.new(1, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.nth_child(0)
      ...> |> Zipper.lift(&Zipper.find_child(&1, fn(child) -> child.node > 10 end))
      {:ok, {
        %RoseTree{children: [], node: 15}, [
          %{parent: 1, left_siblings: [], right_siblings: [%RoseTree{children: [], node: 5}]},
          %{parent: :a, left_siblings: [], right_siblings: []}
        ]
      }}

      iex> {:ok, d} = RoseTree.new(15)
      ...> {:ok, z} = RoseTree.new(5)
      ...> {:ok, c} = RoseTree.new(1, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.nth_child(0)
      ...> |> Zipper.lift(&Zipper.find_child(&1, fn(child) -> length(child.children) > 5 end))
      {:error, {:rose_tree, :no_child_match}}
  """
  @spec find_child(Zipper.t, (any() -> any())) :: {:ok, Zipper.t} | {:error, {:rose_tree, :no_child_match}}
  def find_child({%RoseTree{children: children}, _crumbs} = zipper, predicate) when is_function(predicate) do
    matching_index = Enum.find_index(children, predicate)
    if matching_index == nil do
      {:error, {:rose_tree, :no_child_match}}
    else
      nth_child(zipper, matching_index)
    end
  end

  @doc """
  Lift a function expecting a zipper as an argument to one that can handle either
  {:ok, zipper} | {:error, error}.

  If the first argument is an :error tuple, the error is passed through.
  Otherwise, the function is applied to the zipper in the :ok tuple.

  ## Examples
      iex> {:ok, b} = RoseTree.new(:b)
      ...> {:ok, d} = RoseTree.new(:d)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, c} = RoseTree.new(:c, [d, z])
      ...> {:ok, tree} = RoseTree.new(:a, [b, c])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.nth_child(1)
      ...> |> Zipper.lift(&Zipper.nth_child(&1, 0))
      ...> |> Zipper.lift(&Zipper.to_tree(&1))
      %RoseTree{node: :d, children: []}

      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.nth_child(1)
      ...> |> Zipper.lift(&Zipper.nth_child(&1, 0))
      ...> |> Zipper.lift(&Zipper.nth_child(&1, 1))
      {:error, {:rose_tree, :bad_path}}
  """
  @spec lift(either_zipper, (any() -> any())) :: either_zipper
  def lift({:ok, zipper} = _either_zipper_error, f), do: f.(zipper)
  def lift({:error, _} = either_zipper_error, _f), do: either_zipper_error

  ## Predicates
  @doc """
  Test whether the current focus is the root of the tree.

  ## Examples
      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.root?()
      true

      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.root?/1)
      false
  """
  @spec root?(Zipper.t) :: boolean()
  def root?({%RoseTree{}, []} = _zipper), do: true
  def root?({%RoseTree{}, _crumbs} = _zipper), do: false

  @doc """
  Test whether the current focus is a leaf of the tree.

  ## Examples
      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.leaf?/1)
      true

      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.leaf?()
      false
  """
  @spec leaf?(Zipper.t) :: boolean()
  def leaf?({%RoseTree{children: []}, _crumbs} = _zipper), do: true
  def leaf?({%RoseTree{}, _crumbs} = _zipper), do: false

  @doc """
  Test whether the current focus is a the first (left-most) node among its siblings.

  ## Examples
      iex> {:ok, x} = RoseTree.new(:x)
      ...> {:ok, y} = RoseTree.new(:y)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, tree} = RoseTree.new(:a, [x, y, z])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.first?/1)
      true

      iex> {:ok, x} = RoseTree.new(:x)
      ...> {:ok, y} = RoseTree.new(:y)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, tree} = RoseTree.new(:a, [x, y, z])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.next_sibling/1)
      ...> |> Zipper.lift(&Zipper.next_sibling/1)
      ...> |> Zipper.lift(&Zipper.first?/1)
      false
  """
  @spec first?(Zipper.t) :: boolean()
  def first?({%RoseTree{}, [%{left_siblings: []} | _t]} = _zipper), do: true
  def first?({%RoseTree{}, _crumbs} = _zipper), do: false

  @doc """
  Test whether the current focus is a the last (right-most) node among its siblings.

  ## Examples
      iex> {:ok, x} = RoseTree.new(:x)
      ...> {:ok, y} = RoseTree.new(:y)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, tree} = RoseTree.new(:a, [x, y, z])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.next_sibling/1)
      ...> |> Zipper.lift(&Zipper.next_sibling/1)
      ...> |> Zipper.lift(&Zipper.last?/1)
      true

      iex> {:ok, x} = RoseTree.new(:x)
      ...> {:ok, y} = RoseTree.new(:y)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, tree} = RoseTree.new(:a, [x, y, z])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.last?/1)
      false
  """
  @spec last?(Zipper.t) :: boolean()
  def last?({%RoseTree{}, [%{right_siblings: []} | _t]} = _zipper), do: true
  def last?({%RoseTree{}, _crumbs} = _zipper), do: false

  @doc """
  Test whether the current focus is a the only child of its parent.

  ## Examples
      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.only_child?/1)
      true

      iex> {:ok, x} = RoseTree.new(:x)
      ...> {:ok, y} = RoseTree.new(:y)
      ...> {:ok, z} = RoseTree.new(:z)
      ...> {:ok, tree} = RoseTree.new(:a, [x, y, z])
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.only_child?/1)
      false
  """
  @spec only_child?(Zipper.t) :: boolean()
  def only_child?({%RoseTree{}, [%{right_siblings: [], left_siblings: []} | _t]} = _zipper), do: true
  def only_child?({%RoseTree{}, _crumbs} = _zipper), do: false


  @doc """
  Test whether the current focus has a parent node.

  ## Examples
      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.has_parent?/1)
      true

      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.has_parent?()
      false
  """
  @spec has_parent?(Zipper.t) :: boolean()
  def has_parent?({%RoseTree{}, _crumbs} = zipper), do: !root?(zipper)

  @doc """
  Test whether the current focus has any child nodes.

  ## Examples
      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.has_children?()
      true

      iex> {:ok, tree} = RoseTree.new(:a, :b)
      ...> tree
      ...> |> Zipper.from_tree()
      ...> |> Zipper.first_child()
      ...> |> Zipper.lift(&Zipper.has_children?/1)
      false
  """
  @spec has_children?(Zipper.t) :: boolean()
  def has_children?({%RoseTree{children: []}, _crumbs} = _zipper), do: false
  def has_children?({%RoseTree{}, _crumbs} = _zipper), do: true

end
