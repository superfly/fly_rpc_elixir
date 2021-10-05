# Testing

Instructions for testing and developing multi-node RPC applications locally in a development environment.

## Start Nodes Locally

Start multiple nodes locally on the same developer machine. Multiple nodes can be started in separate terminals.

Node 1 - Primary Region:

```shell
FLY_REGION=xyz PRIMARY_REGION=xyz iex --name node1@127.0.0.1 -S mix
```

Node 2 - Non-Primary Region:

```shell
FLY_REGION=abc PRIMARY_REGION=xyz iex --name node2@127.0.0.1 -S mix
```

In the IEx shell, run this command to connect `node2` to `node1`.

```elixir
Node.connect(:"node1@127.0.0.1")
```

The following command verifies the nodes are connected by showing the other connected node.

```elixir
Node.list
```

