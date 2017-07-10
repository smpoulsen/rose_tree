defmodule RoseTree.Mixfile do
  use Mix.Project

  def project do
    [app: :rose_tree,
     version: "0.1.0",
     elixir: "~> 1.4",
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
    An implementation of a Rose tree
    """
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:credo, "~> 0.8.2", only: [:dev, :test]},
      {:dialyxir, "~> 0.5.0", only: [:dev, :test]},
    ]
  end

  defp package do
    [
      name: :rose_tree,
      licenses: ["BSD2"],
      maintainers: ["Travis Poulsen"],
      links: %{
        "GitHub" => "https://github.com/tpoulsen/rose_tree",
      }
    ]
  end
end
