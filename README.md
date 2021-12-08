# Fly RPC

Helps a clustered Elixir application know what [Fly.io](https:://fly.io) region it is deployed in, if that is the primary region, and provides features for executing a function through RPC (Remote Procedure Call) on another node by specifying the region to run it in.

[Online Documentation](https://hexdocs.pm/fly_rpc)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `fly_rpc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fly_rpc, "~> 0.1.0"}
  ]
end
```

Through ENV configuration, you can to tell the app which region is the "primary" region.

`fly.toml`

This example configuration says that the Sydney Australia region is the
"primary" region.

```yaml
[env]
  PRIMARY_REGION = "syd"
```

Add `Fly.RPC` to your application's supervision tree.

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # ...

    children = [
      # Start the RPC server
      {Fly.RPC, []},
      #...
    ]

    # ...
  end
end
```

This starts a GenServer that reaches out to other nodes in the cluster to learn
what Fly.io regions they are located in. The GenServer caches those results in a
local ETS table for fast access.

## Usage

The Fly.io platform already provides and ENV value of `FLY_REGION` which this library accesses.

```elixir
Fly.primary_region()
#=> "syd"

Fly.current_region()
#=> "lax"

Fly.is_primary?()
#=> false
```

The real benefit comes in using the `Fly.RPC` module.

```elixir
Fly.RPC.rpc_region("hkg", String, :upcase, ["fly"])
#=> "FLY"

Fly.RPC.rpc_region(Fly.primary_region(), String, :upcase, ["fly"])
#=> "FLY"

Fly.RPC.rpc_region(:primary, String, :upcase, ["fly"])
#=> "FLY"
```

Underneath the call, it's using `Node.spawn_link/4`. This spawns a new process on a node in the desired region. Normally, that spawn becomes an asynchronous process and what you get back is a `pid`. In this case, the call executes on the other node and the caller is blocked until the result is received or the request times out.

By blocking the process, this makes it much easier to reason about your application code.


The following is a convenience function for performing work on the primary.

```elixir
Fly.rpc_primary(String, :upcase, ["fly"])
#=> "FLY"
```

## Local Development

When doing local development, without updating some settings, you will see an error like:

```
(ArgumentError) could not fetch environment variable "PRIMARY_REGION" because it is not set
```

There are 2 ENV values that need to be set for local development work.

- `FLY_REGION` - Fly.io tells you which region your app is running in.
- `PRIMARY_REGION` - You tell Fly.io which region is your "primary".

When you are running locally, the `FLY_REGION` isn't being set since the app isn't on Fly.io. Also, the `PRIMARY_REGION` set in your `fly.toml` file isn't being used. We just need a way to set those values when the application is running locally.

I like using [direnv](https://direnv.net/) to automatically set and load ENV values when I enter specific directories. Using `direnv`, you can create a file named `.envrc` in your project directory. Add the following lines:

```
export FLY_REGION=xyz
export PRIMARY_REGION=xyz
```

This tells the app that it's running in the primary region. It will connect to the database and perform writes directly.

Another option is to start you application like this:

```
FLY_REGION=xyz PRIMARY_REGION=xyz iex -S mix phx.server
```

You can also create a bash script file named `start` and have it perform the above command.

## Features

- [ ] Instrument with telemetry