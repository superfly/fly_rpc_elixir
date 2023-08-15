defmodule Fly.RPC do
  @moduledoc """
  Performs RPC calls to nodes in Fly.io regions.

  Provides features to help Elixir applications more easily take advantage
  of the features that Fly.io provides.

  ## Configuration

  Assumes each node is running the `Fly.RPC` server in its supervision tree and
  exports `FLY_REGION` environment variable to identify the fly region.

  *Note*: anonymous function support only works when the release is identical
  across all nodes. This can be ensured by including the `FLY_IMAGE_REF` as part of
  the node name in your `rel/env.sh.eex` file:

      #!/bin/sh

      export ERL_AFLAGS="-proto_dist inet6_tcp"
      export RELEASE_DISTRIBUTION=name
      export RELEASE_NODE="${FLY_APP_NAME}-${FLY_IMAGE_REF##*-}@${FLY_PRIVATE_IP}"

  To run code on a specific region call `rpc_region/4`. A node found within the
  given region will be chosen at random. Raises if no nodes exist on the given
  region.

  The special `:primary` region may be passed to run the rpc against the region
  identified by the `PRIMARY_REGION` environment variable.

  ## Examples

      > rpc_region("hkg", fn -> String.upcase("fly") end)
      "FLY"

      > rpc_region("hkg", {String, :upcase, ["fly"]})
      "FLY"

      > rpc_region(Fly.RPC.primary_region(), {String, :upcase, ["fly"]])
      "FLY"

      > rpc_region(:primary, {String, :upcase, ["fly"]})
      "FLY"

  ## Server

  The GenServer's responsibility is just to monitor other nodes as they enter
  and leave the cluster. It maintains a list of nodes and the Fly.io region
  where they are deployed in an ETS table that other processes can use to find
  and initiate their own RPC calls to.
  """
  use GenServer
  require Logger

  @tab :fly_regions

  @doc """
  Return the configured primary region.

  Reads and requires an ENV setting for `PRIMARY_REGION`.
  If not set, it returns `"local"`.
  """
  def primary_region do
    case System.fetch_env("PRIMARY_REGION") do
      {:ok, region} -> region
      :error -> "local"
    end
  end

  @doc """
  Return the configured current region.

  Reads the `FLY_REGION` ENV setting
  available when deployed on the Fly.io platform. When running on a different
  platform, that ENV value will not be set. Setting the `MY_REGION` ENV value
  instructs the node how to identify what "region" it is in. If not set, it
  returns `"local"`.

  The value itself is not important. If the value matches the value for the
  `PRIMARY_REGION` then it behaves as though it is the primary.
  """
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
  Return if the app instance is running in the primary region or not.
  """
  def is_primary? do
    my_region() == primary_region()
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the Elixir OTP nodes registered the region. Reads from a local cache.
  """
  def region_nodes(tab \\ @tab, region) do
    case :ets.lookup(tab, region) do
      [{^region, nodes}] -> nodes
      [] -> []
    end
  end

  @doc """
  Asks a node what Fly region it's running in.

  Returns `:error` if RPC is not supported on remote node.
  """
  def region(node) do
    if is_rpc_supported?(node) do
      {:ok, rpc(node, {__MODULE__, :my_region, []})}
    else
      Logger.info("Detected Fly.RPC support is not available on node #{inspect(node)}")
      :error
    end
  end

  @doc """
  Executes the MFA on an available node in the desired region.

  If the region is the "primary" region or the "local" region then execute the
  function immediately. Supports the string name of the region or `:primary` for
  the current configured primary region.

  Otherwise find an available node and select one at random to execute the
  function.

  Raises `ArgumentError` when no available nodes.

  ## Example

      > RPC.rpc_region("hkg", fn -> 1 + 2 end)
      3

      > RPC.rpc_region("hkg", {Kernel, :+, [1, 2]})
      3

      > RPC.rpc_region(:primary, {Kernel, :+, [1, 2]})
      3

  """
  def rpc_region(region, func, opts \\ [])

  def rpc_region(region, func, opts)
      when (is_binary(region) or region == :primary) and (is_function(func, 0) or is_tuple(func)) and
             is_list(opts) do
    region = if region == :primary, do: primary_region(), else: region

    if region == my_region() do
      invoke(func)
    else
      timeout = Keyword.get(opts, :timeout, 5_000)
      available_nodes = region_nodes(region)

      if Enum.empty?(available_nodes),
        do: raise(ArgumentError, "no node found running in region #{inspect(region)}")

      node = Enum.random(available_nodes)

      rpc(node, func, timeout)
    end
  end

  def rpc_region(region, {mod, func, args}, opts)
      when is_binary(region) and is_atom(mod) and is_list(args) and is_list(opts) do
    rpc_region(region, fn -> apply(mod, func, args) end, opts)
  end

  @doc """
  Execute the MFA on a node in the primary region.
  """
  def rpc_primary(func, opts \\ [])

  def rpc_primary(func, opts) when is_function(func, 0) do
    rpc_region(:primary, func, opts)
  end

  def rpc_primary({module, func, args}, opts) do
    rpc_region(:primary, {module, func, args}, opts)
  end

  defp invoke(func) when is_function(func, 0), do: func.()
  defp invoke({mod, func, args}), do: apply(mod, func, args)

  @doc """
  Executes the function on the remote node and waits for the response.

  Exits after `timeout` milliseconds.
  """
  def rpc(node, func, timeout \\ 5000) do
    verbose_log(:info, func, "SEND")

    case erpc_call(node, func, timeout) do
      {:ok, result} ->
        verbose_log(:info, func, "RESP")

        result

      {:error, {:erpc, :timeout}} ->
        verbose_log(:error, func, "TIMEOUT")
        exit(:timeout)

      {:error, {:erpc, reason}} ->
        {:error, {:erpc, reason}}

      {:error, {:throw, value}} ->
        throw(value)

      {:error, {:exit, reason}} ->
        exit(reason)

      {:error, {_exception, reason, stack}} ->
        reraise(reason, stack)
    end
  end

  @doc """
  Executes a function on the remote node to determine if the RPC API support is
  available.

  Support may not exist on the remote node in a "first roll out" scenario.
  """
  def is_rpc_supported?(node) do
    case erpc_call(node, {Kernel, :function_exported?, [__MODULE__, :my_region, 0]}, 5000) do
      {:ok, result} when is_boolean(result) ->
        result

      {:error, reason} ->
        Logger.warning("Failed RPC supported test on #{inspect(node)}, got: #{inspect(reason)}")
        false
    end
  end

  defp erpc_call(node, {mod, func, args}, timeout) do
    try do
      {:ok, :erpc.call(node, mod, func, args, timeout)}
    catch
      :throw, value -> {:error, {:throw, value}}
      :exit, reason -> {:error, {:exit, reason}}
      :error, {:erpc, reason} -> {:error, {:erpc, reason}}
      :error, {exception, reason, stack} -> {:error, {exception, reason, stack}}
    end
  end

  defp erpc_call(node, func, timeout) when is_function(func, 0) do
    try do
      {:ok, :erpc.call(node, func, timeout)}
    catch
      :throw, value -> {:error, {:throw, value}}
      :exit, reason -> {:error, {:exit, reason}}
      :error, {:erpc, reason} -> {:error, {:erpc, reason}}
      :error, {exception, reason, stack} -> {:error, {exception, reason, stack}}
    end
  end

  ## RPC calls run on local node

  def init(_opts) do
    tab = :ets.new(@tab, [:named_table, :public, read_concurrency: true])
    # monitor new node up/down activity
    :global_group.monitor_nodes(true)
    {:ok, %{nodes: MapSet.new(), tab: tab}, {:continue, :get_node_regions}}
  end

  def handle_continue(:get_node_regions, state) do
    new_state =
      Enum.reduce(Node.list(:visible), state, fn node_name, acc ->
        put_node(acc, node_name)
      end)

    {:noreply, new_state}
  end

  def handle_info({:nodeup, node_name}, state) do
    Logger.debug("nodeup #{node_name}")

    # Only react/track visible nodes (hidden ones are for IEx, etc)
    if node_name in Node.list(:visible) do
      {:noreply, put_node(state, node_name)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:nodedown, node_name}, state) do
    Logger.debug("nodedown #{node_name}")
    {:noreply, drop_node(state, node_name)}
  end

  # Executed when a new node shows up in the cluster. Asks the node what region
  # it's running in. If the request isn't supported by the node, do nothing.
  # This happens when this node is the first node with this new code. It reaches
  # out to the other nodes (they show up as having just appeared) but they don't
  # yet have the new code. So this ignores that node until it gets new code,
  # restarts and will then again show up as a new node.
  @doc false
  def put_node(state, node_name) do
    case region(node_name) do
      {:ok, region} ->
        Logger.info("Discovered node #{inspect(node_name)} in region #{region}")
        region_nodes = region_nodes(state.tab, region)
        :ets.insert(state.tab, {region, [node_name | region_nodes]})

        %{state | nodes: MapSet.put(state.nodes, {node_name, region})}

      :error ->
        state
    end
  end

  @doc false
  def drop_node(state, node_name) do
    # find the node information for the node going down.
    case get_node(state, node_name) do
      {^node_name, region} ->
        Logger.info("Dropping node #{inspect(node_name)} for region #{region}")
        # get the list of nodes currently registered in that region
        region_nodes = region_nodes(state.tab, region)
        # Remove the node from the known regions and update the local cache
        new_regions = Enum.reject(region_nodes, fn n -> n == node_name end)
        :ets.insert(state.tab, {region, new_regions})

        # Remove the node entry from the GenServer's state
        new_nodes =
          Enum.reduce(state.nodes, state.nodes, fn
            {^node_name, ^region}, acc -> MapSet.delete(acc, {node_name, region})
            {_node, _region}, acc -> acc
          end)

        # Return the new state
        %{state | nodes: new_nodes}

      # Node is not known to us. Ignore it.
      nil ->
        state
    end
  end

  defp get_node(state, name) do
    Enum.find(state.nodes, fn {n, _region} -> n == name end)
  end

  defp verbose_log(kind, func, subject) do
    if Application.get_env(:fly_rpc, :verbose_logging) do
      Logger.log(kind, fn -> "RPC #{subject} from #{my_region()} #{mfa_string(func)}" end)
    end
  end

  defp mfa_string(func) when is_function(func), do: inspect(func)

  defp mfa_string({mod, func, args}) do
    "#{Atom.to_string(mod)}.#{Atom.to_string(func)}/#{length(args)}"
  end
end
