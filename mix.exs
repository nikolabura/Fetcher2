defmodule Fetcher2.MixProject do
  use Mix.Project

  def project do
    [
      app: :fetcher2,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Fetcher2.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, git: "https://github.com/Kraigie/nostrum.git"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:httpoison, "~> 1.7"},
      {:jason, "~> 1.2"},
      {:typed_struct, "~> 0.2.1"},
      {:tzdata, "~> 1.1"}
    ]
  end
end
