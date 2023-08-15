# Changelog

## v0.3.0

Breaking changes:
- Functions at the room `Fly` module were refactored into the `Fly.RPC` module.
  - It should be an easy update where a call to `Fly.is_primary?` becomes `Fly.RPC.is_primary?`.
  - This opens up the `Fly` namespace for other libraries as well.
- `Fly.rpc_region/5` was changed to `Fly.RPC.rpc_region/3`.
  - The namespace changed.
  - The way the function to execute is passed in has changed. It now supports passing in an anonymous function like this: `Fly.RPC.rpc_region("hkg", fn -> 1 + 2 end)`
  - It still supports the MFA format (Module, Function, Arguments) but now uses a tuple like this: `Fly.RPC.rpc_region(:primary, {Kernel, :+, [1, 2]})`

