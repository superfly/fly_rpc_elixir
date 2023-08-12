defmodule Fly.RPCTest do
  use ExUnit.Case, async: false

  doctest Fly.RPC, import: true

  describe "primary_region/0" do
    test "when no primary set, returns local" do
      delete_env_if_present("PRIMARY_REGION")
      assert "local" == Fly.RPC.primary_region()
    end

    test "returns ENV for PRIMARY_REGION when set" do
      System.put_env("PRIMARY_REGION", "abc")
      assert "abc" == Fly.RPC.primary_region()
    end
  end

  describe "my_region/0" do
    test "when no FLY_REGION set, use MY_REGION" do
      delete_env_if_present("FLY_REGION")
      System.put_env("MY_REGION", "custom")
      assert "custom" == Fly.RPC.my_region()
    end

    test "when no FLY_REGION and no MY_REGION set, sets to local" do
      delete_env_if_present("FLY_REGION")
      delete_env_if_present("MY_REGION")
      assert "local" == Fly.RPC.my_region()
    end

    test "returns ENV for FLY_REGION when set" do
      System.put_env("FLY_REGION", "abc")
      assert "abc" == Fly.RPC.my_region()
    end
  end

  defp delete_env_if_present(varname) do
    if System.get_env(varname) do
      System.delete_env(varname)
    end
  end
end
