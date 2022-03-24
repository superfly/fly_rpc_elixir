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

When doing local development, the local and primary regions will be set to "local" by default. However, if you want to simulate running in a non-primary region locally, you can set the `FLY_REGION` and `PRIMARY_REGION` environment variables explicitly:

- `FLY_REGION` - Fly.io tells you which region your app is running in.
- `PRIMARY_REGION` - You tell the library which Fly.io region is your "primary".

When running locally, the `FLY_REGION` isn't set since the app isn't on Fly.io. Also, the `PRIMARY_REGION` set in your `fly.toml` file isn't being used. We just need a way to set those values when the application is running locally.

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

## Production Environment

### Prevent temporary outages during deployments

When deploying on Fly.io, a new instance is rolled out before removing the old instance. This creates a period of time where both new and old instances are deployed together. By default, when deploying a Phoenix application, a new BEAM cookie is generated for each deployment. When the new instance rolls out with a new BEAM cookie, the old and new instances will not cluster together. BEAM instances must have the same cookie in order to connect. This is by design.

This means a newly deployed application running in a secondary region using [fly_postgres](https://github.com/superfly/fly_postgres_elixir) is unable to perform writes to the older application running in the primary region. It is possible for writes to fail during that rollout window.

To prevent this problem, the BEAM cookie can be explicitly set instead of randomly generated for new builds. When explicitly set, the newly deployed application is still able to connect and cluster with the older application running in the primary region.

Here is a guide to setting a static cookie for your project that is written into the code itself. This is fine to do because the cookie isn't considered a secret used for security.

[fly.io/docs/app-guides/elixir-static-cookie/](https://fly.io/docs/app-guides/elixir-static-cookie/)

When the cookie is static and unchanged from one deployment to the next, then applications can continue to cluster and access the applications running in primary region.

## Features

- [ ] Instrument with telemetry
