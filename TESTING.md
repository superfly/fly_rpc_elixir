# Testing

Instructions for testing and developing multi-node RPC applications locally in a development environment.

## Start Nodes Locally

Start multiple nodes locally on the same developer machine. Multiple nodes can be started in separate terminals.

Node 1 - Primary Region:

```shell
MY_REGION=xyz PRIMARY_REGION=xyz iex --name node1@127.0.0.1 -S mix
```

Node 2 - Non-Primary Region:

```shell
MY_REGION=abc PRIMARY_REGION=xyz iex --name node2@127.0.0.1 -S mix
```

In the IEx shell, run this command to connect `node2` to `node1`.

```elixir
Node.connect(:"node1@127.0.0.1")
```

The following command verifies the nodes are connected by showing the other connected node.

```elixir
Node.list
```

The nodes are now verified as connected. Commands can be executed from either node to the other.

NOTE: If running the test on the library itself, it won't work because the GenServer must be started first. Testing the library as part of another application is easier as the functions to execute on the other node are present and the GenServer will have started with the Application supervision tree. To start the GenServer manually in each node, execute: `Fly.RPC.start_link([])`

Example:

```elixir
Fly.rpc_primary(String, :upcase, ["fly"])
#=> "FLY"
```

Additional nodes can be started similarly with additional regions for testing.
