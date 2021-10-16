defmodule Fly do
  @moduledoc """
  Functions and features to help Elixir applications more easily take advantage
  of the features that Fly.io provides.
  """

  @doc """
  Return the configured primary region. Reads and requires an ENV setting for
  `PRIMARY_REGION`.
  """
  def primary_region do
    System.fetch_env!("PRIMARY_REGION")
  end

  @doc """
  Return the configured current region. Reads the `FLY_REGION` ENV setting
  that's available when deployed on the Fly.io platform.
  """
  def my_region do
    System.fetch_env!("FLY_REGION")
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
