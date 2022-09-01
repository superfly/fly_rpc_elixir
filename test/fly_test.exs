defmodule FlyTest do
  # Manipulates System ENV settings, don't run async
  use ExUnit.Case, async: false

  doctest Fly

  describe "primary_region/0" do
    test "when no primary set, sets to local" do
      delete_env_if_present("PRIMARY_REGION")
      assert "local" == Fly.primary_region()
      assert "local" == System.fetch_env!("PRIMARY_REGION")
    end

    test "returns ENV for PRIMARY_REGION when set" do
      System.put_env("PRIMARY_REGION", "abc")
      assert "abc" == Fly.primary_region()
    end
  end

  describe "my_region/0" do
    test "when no FLY_REGION set, use MY_REGION" do
      delete_env_if_present("FLY_REGION")
      System.put_env("MY_REGION", "custom")
      assert "custom" == Fly.my_region()
      assert "custom" == System.fetch_env!("MY_REGION")
    end

    test "when no FLY_REGION and no MY_REGION set, sets to local" do
      delete_env_if_present("FLY_REGION")
      delete_env_if_present("MY_REGION")
      assert "local" == Fly.my_region()
      assert "local" == System.fetch_env!("MY_REGION")
    end

    test "returns ENV for FLY_REGION when set" do
      System.put_env("FLY_REGION", "abc")
      assert "abc" == Fly.my_region()
    end
  end

  defp delete_env_if_present(varname) do
    if System.get_env(varname) do
      System.delete_env(varname)
    end
  end
end
