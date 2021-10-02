defmodule Fly.RPCTest do
  use ExUnit.Case, async: true

  doctest Fly.RPC, import: true

  alias Fly.RPC

  # describe "put_node/2" do
  #   test "if new node doesn't support RPC, no change"

  #   test "if node supports RPC, track node and it's region"
  # end

  describe "drop_node/2" do
    test "handles a node dropping that isn't in the cache or state" do
      tab = :ets.new(:test_empty_table, [:named_table, :public, read_concurrency: true])
      state = %{nodes: MapSet.new(), tab: tab}
      new_state = RPC.drop_node(state, :"missing@127.0.0.1")
      assert new_state == state
    end

    test "removes a known entry from the cache and from state" do
      nodes = MapSet.new([{:"stays@1.1.1.1", "hkg"}, {:"removed@2.2.2.2", "hkg"}])
      tab = :ets.new(:test_empty_table, [:named_table, :public, read_concurrency: true])
      :ets.insert(tab, {"hkg", [:"stays@1.1.1.1", :"removed@2.2.2.2"]})
      state = %{nodes: nodes, tab: tab}

      new_state = RPC.drop_node(state, :"removed@2.2.2.2")
      assert new_state != state
      assert new_state.nodes == MapSet.new([{:"stays@1.1.1.1", "hkg"}])
      assert [:"stays@1.1.1.1"] == RPC.region_nodes(:test_empty_table, "hkg")
    end
  end
end
