defmodule FlyPostgres.MixProject do
  use Mix.Project

  def project do
    [
      app: :fly_postgres,
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
    [
      {:fly_rpc, git: "https://github.com/superfly/fly_rpc_elixir.git", branch: "main"},
      {:postgrex, ">= 0.0.0"}
    ]
  end

  defp description do
    """
    Library for working with local read-replica postgres databases and performing writes through RPC calls to other nodes in the primary Fly.io region.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Mark Ericksen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/superfly/fly_rpc_elixir/fly_postgres"}
    ]
  end
end
