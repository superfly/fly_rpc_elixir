defmodule Fly do
  @moduledoc """
  Functions and features to help Elixir applications more easily take advantage
  of the features that Fly.io provides.
  """

  @doc """
  Return the configured primary region. Reads and requires an ENV setting for
  `PRIMARY_REGION`. If not set, it returns `"local"`.
  """
  @spec primary_region() :: String.t()
  def primary_region do
    case System.fetch_env("PRIMARY_REGION") do
      {:ok, region} ->
        region

      :error ->
        System.put_env("PRIMARY_REGION", "local")
        "local"
    end
  end

  @doc """
  Return the configured current region. Reads the `FLY_REGION` ENV setting
  available when deployed on the Fly.io platform. When running on a different
  platform, that ENV value will not be set. Setting the `MY_REGION` ENV value
  instructs the node how to identify what "region" it is in. If not set, it
  returns `"local"`.

  The value itself is not important. If the value matches the value for the
  `PRIMARY_REGION` then it behaves as though it is the primary.
  """
  @spec my_region() :: String.t()
  def my_region do
    case System.get_env("FLY_REGION") || System.get_env("MY_REGION") do
      nil ->
        System.put_env("MY_REGION", "local")
        "local"

      region ->
        region
    end
  end

  @doc """
  Return if the app instance is running in the primary region or not. Boolean
  result.
  """
  @spec is_primary? :: no_return() | boolean()
  def is_primary? do
    my_region() == primary_region()
  end

  @doc false
  # A "private" function that converts the MFA data into a string for logging.
  def mfa_string(module, func, args) do
    "#{Atom.to_string(module)}.#{Atom.to_string(func)}/#{length(args)}"
  end

  @doc """
  Execute the MFA on a node in the primary region.
  """
  @spec rpc_primary(module(), atom(), [any()], keyword()) :: any()
  def rpc_primary(module, func, args, opts \\ []) do
    Fly.RPC.rpc_region(:primary, module, func, args, opts)
  end
end
