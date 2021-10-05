# Fly Postgres

Helps take advantage of geographically distributed Elixir applications using
Ecto and PostgreSQL in a primary/replica configuration on [Fly.io](https://fly.io).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `fly_postgres` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fly_postgres, "~> 0.1.0"}
  ]
end
```

Note that `fly_postgres` depends on `fly_rpc` so it will be pulled along as
well. The configuration section includes the relevant parts for `fly_rpc`.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/fly_postgres](https://hexdocs.pm/fly_postgres).

## Configuration

### Repo

This assumes your project already has an `Ecto.Repo`. To start using the
`Fly.Repo`, here are the changes to make.

For a project named "MyApp", change it from this...

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres
end
```

To something like this...

```elixir
defmodule MyApp.Repo.Local do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  # Dynamically configure the database url based on runtime environment.
  def init(_type, config) do
    {:ok, Keyword.put(config, :url, Fly.Postgres.database_url())}
  end
end

defmodule MyApp.Repo do
  use Fly.Repo, local_repo: MyApp.Repo.Local
end
```

This renames your existing repo to "move it out of the way" and adds a new repo
to the same file. The new repo uses the `Fly.Repo` and links back to your
project's `Ecto.Repo`. The new repo has the same name as your original
`Ecto.Repo`, so your application will be referring to it now when talking to the
database.

The other change was to add the `init` function to your `Ecto.Repo`. This
dynamically configures your `Ecto.Repo` to connect to the **primary** (writable)
database when your application is running in the primary region. When your
application is **not** in the primary region, it is configured to connect to the
local read-only replica. The replica is like a fast local cache of all your
data. This means you `Ecto.Repo` is configured to talk to it's "local" database.

The `Fly.Repo` performs all **read** operations like `all`, `one`, and `get_by`
directly on the local replica. Other modifying functions like `insert`,
`update`, and `delete` are performed on the **primary database** through proxy
calls to a node in your Elixir cluster running in the primary region. That
ability is provided by the `fly_rpc` library.

### Repo References

The goal with using this repo wrapper, is to leave all of your application code
and business logic unchanged. However, there are a few places that need to be
updated to make it work smoothly.

The following examples are places in your project code that need reference your
actual `Ecto.Repo`. Following the above example, it should point to
`MyApp.Repo.Local`.

- `test_helper.exs` files make references like this `Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo.Local, :manual)`
- `data_case.exs` files start the repo using `Ecto.Adapters.SQL.Sandbox.start_owner!` calls.
- `channel_case.exs` need to start your local repo.
- `conn_case.exs` need to start your local repo.
- `config/config.exs` needs to identify your local repo module. Ex: `ecto_repos: [MyApp.Repo.Local]`
- `config/dev.exs`, `config/test.exs`, `config/runtime.exs` - any special repo configuration should refer to your local repo.

With these project plumbing changes, you application code can stay largely untouched!

### Primary Region

If your application is deployed to multiple Fly.io regions, the instances (or
nodes) must be clustered together.

Through ENV configuration, you can to tell the app which region is the "primary" region.

`fly.toml`

This example configuration says that the Sydney Australia region is the
"primary" region. This is where the primary postgres database is created and
where our application has fast write access to it.

```toml
[env]
  PRIMARY_REGION = "syd"
```

### Application

There are two entries to add to your application supervision tree.

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # ...

    children = [
      # Start the RPC server
      {Fly.RPC, []},
      # Start the Ecto repository
      MyApp.Repo.Local,
      # Start the tracker after your DB.
      {Fly.Postgres.LSN.Tracker, []},
      #...
    ]

    # ...
  end
end
```

The following changes were made:

- Added the `Fly.RPC` GenServer
- Start your Repo
- Added `Fly.Postgres.LSN.Tracker`

## Usage

### Simple Usage

Normal calls like `MyApp.Repo.all(User)` are performed on the local replica
repo. They are unchanged and work exactly as you'd expect.

Calls that _modify_ the database like "insert, update, and delete", are
performed through an RPC (Remote Procedure Call) in your application running in
the primary region.

In order for this to work, your application must be clustered together and
configured to identify which region is the "primary" region. Additionally, your
application needs to be deployed to multiple regions. There must be a deployment
in the primary region as well.

A call to `MyApp.Repo.insert(changeset)` will be proxied to perform the insert
in the primary region. If the function is already running in the primary region,
it just executes normally locally. If the function is running in a non-primary
region, it makes a RPC execution to run on the primary. Additionally, it gets
the Postgres LSN (Log Sequence Number) for the database after making the change.
The calling function then blocks, waits for the async database replication
process to complete, and continues on once the data modification has replayed on
the local replica.

In this way, it becomes seamless for you and your code! You get the benefits of
being globally distributed and running closer to your users without re-designing your application!

### More Advanced Usage

