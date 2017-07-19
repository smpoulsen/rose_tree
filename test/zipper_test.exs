defmodule ZipperTest do
  use ExUnit.Case
  use Generators
  alias RoseTree.Zipper
  doctest Zipper

  property "nth_child/2 followed by ascend/1 results in no change" do
    for_all {tree} in such_that({t} in {rose_tree(2)} when length(t.children) > 0) do
      tree
      |> Zipper.from_tree()
      |> Zipper.nth_child(0)
      |> Zipper.lift(&Zipper.ascend/1)
      |> Zipper.lift(&Zipper.to_tree/1) == tree
    end
  end

  @tag iterations: 500
  property "to_root/1 always returns to the tree's root" do
    for_all {tree} in {rose_tree(5)} do
      zipper = Zipper.from_tree(tree)
      implies (Zipper.lift(Zipper.nth_child(zipper, 1), &Zipper.nth_child(&1, 1)) != {:error, {:rose_tree, :no_children}}) do
        zipper
        |> Zipper.nth_child(1)
        |> Zipper.lift(&Zipper.nth_child(&1, 1))
        |> Zipper.lift(&Zipper.to_root/1)
        |> Zipper.to_tree() == tree
      end
    end
  end

  property "result of to_root/1 is root?/1 and !has_parent/1" do
    for_all {tree} in {rose_tree(0)} do
      zipper = Zipper.from_tree(tree)
      implies Zipper.has_children?(zipper) == true do
        root = zipper
        |> Zipper.first_child()
        |> Zipper.lift(&Zipper.to_root/1)
        Zipper.root?(root) == true && Zipper.has_parent?(root) == false
      end
    end
  end

  property "result of to_leaf/1 has no children" do
    for_all {tree} in {rose_tree(1)} do
      tree
      |> Zipper.from_tree()
      |> Zipper.to_leaf()
      |> Zipper.has_children?() == false
    end
  end
end
