defmodule FlyTest do
  # Manipulates System ENV settings, don't run async
  use ExUnit.Case, async: false

  doctest Fly

  describe "primary_region/0" do
    test "when no primary set, sets to local" do
      System.delete_env("PRIMARY_REGION")
      assert "local" == Fly.primary_region()
      assert "local" == System.fetch_env!("PRIMARY_REGION")
    end

    test "returns ENV for PRIMARY_REGION when set" do
      System.put_env("PRIMARY_REGION", "abc")
      assert "abc" == Fly.primary_region()
    end
  end

  describe "my_region/0" do
    test "when no fly set, sets to local" do
      System.delete_env("FLY_REGION")
      assert "local" == Fly.my_region()
      assert "local" == System.fetch_env!("FLY_REGION")
    end

    test "returns ENV for FLY_REGION when set" do
      System.put_env("FLY_REGION", "abc")
      assert "abc" == Fly.my_region()
    end
  end
end
