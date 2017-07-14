defmodule ZipperTest do
  use ExUnit.Case
  alias RoseTree.Zipper
  use Generators
  doctest Zipper

  property "descend/2 followed by ascend/1 results in no change" do
    for_all {tree} in such_that({t} in {rose_tree(2)} when length(t.children) > 0) do
      tree
      |> Zipper.from_tree()
      |> Zipper.descend(0)
      |> Zipper.lift(&Zipper.ascend/1)
      |> Zipper.to_tree() == tree
    end
  end
end
