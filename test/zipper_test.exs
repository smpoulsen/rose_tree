defmodule ZipperTest do
  use ExUnit.Case
  use Generators
  alias RoseTree.Zipper
  doctest Zipper

  property "descend/2 followed by ascend/1 results in no change" do
    for_all {tree} in such_that({t} in {rose_tree(2)} when length(t.children) > 0) do
      tree
      |> Zipper.from_tree()
      |> Zipper.descend(0)
      |> Zipper.lift(&Zipper.ascend/1)
      |> Zipper.lift(&Zipper.to_tree/1) == tree
    end
  end

  @tag iterations: 500
  property "to_root/1 always returns to the tree's root" do
    for_all {tree} in {rose_tree(5)} do
      zipper = Zipper.from_tree(tree)
      implies (Zipper.lift(Zipper.descend(zipper, 1), &Zipper.descend(&1, 1)) != {:error, {:rose_tree, :no_children}}) do
        zipper
        |> Zipper.descend(1)
        |> Zipper.lift(&Zipper.descend(&1, 1))
        |> Zipper.lift(&Zipper.to_root/1) == tree
      end
    end
  end
end
