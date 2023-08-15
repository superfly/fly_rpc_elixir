defmodule Fly.MixProject do
  use Mix.Project

  def project do
    [
      app: :fly_rpc,
      version: "0.3.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      name: "Fly RPC",
      source_url: "https://github.com/superfly/fly_rpc_elixir",
      description: description(),
      deps: deps(),
      package: package(),
      docs: docs()
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
      {:ex_doc, "~> 0.25", only: :dev},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Library for making RPC calls to nodes in other fly.io regions. Specifically designed to make it easier to execute code in the "primary" region.
    """
  end

  defp docs do
    [
      main: "readme",
      # logo: "path/to/logo.png",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Mark Ericksen"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/superfly/fly_rpc_elixir"}
    ]
  end
end
