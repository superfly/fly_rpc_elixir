defmodule FlyTest do
  use ExUnit.Case
  doctest Fly

  test "greets the world" do
    assert Fly.hello() == :world
  end
end
