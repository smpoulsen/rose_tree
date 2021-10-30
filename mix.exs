defmodule RoseTree.Mixfile do
  use Mix.Project

  def project do
    [app: :rose_tree,
     version: "0.3.0",
     elixir: "~> 1.10",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def description() do
    """
    A rose tree is a recursive n-ary tree. rose_tree implements the data structure
    and provides raw and zipper-based traversal and manipulation.
    """
  end

  defp deps do
    [
      {:excheck, "~> 0.5.3", only: :test},
      {:triq, "~> 1.3", only: :test},
      {:ex_doc, ">= 0.25.0", only: :dev},
      {:credo, "~> 1.5.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.1.0", only: [:dev, :test]},
    ]
  end

  defp package do
    [
      name: :rose_tree,
      licenses: ["BSD2"],
      maintainers: ["Sylvie Poulsen"],
      links: %{
        "GitHub" => "https://github.com/smpoulsen/rose_tree",
      }
    ]
  end
end
