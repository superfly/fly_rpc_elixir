defmodule Fly.MixProject do
  use Mix.Project

  def project do
    [
      app: :fly_rpc,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    []
  end

  defp description do
    """
    Library for making RPC calls to nodes in other Fly.io regions.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Mark Ericksen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/superfly/fly_rpc_elixir/fly_rpc"}
    ]
  end
end
