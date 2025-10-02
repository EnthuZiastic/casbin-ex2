defmodule CasbinEx2.BLPModelTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.StringAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Model

  @moduledoc """
  BLP (Bell-LaPadula Confidentiality Model) Tests

  BLP is a confidentiality model that enforces:
  - No read up: Subjects cannot read objects at higher security levels
  - No write down: Subjects cannot write to objects at lower security levels

  This prevents classified information from leaking to lower classification levels.
  """

  setup do
    model_config = """
    [request_definition]
    r = sub, sub_level, obj, obj_level, act

    [policy_definition]
    p = sub, obj, act

    [role_definition]
    g = _, _

    [policy_effect]
    e = allow

    [matchers]
    m = (r.act == "read" && r.sub_level >= r.obj_level) || (r.act == "write" && r.sub_level <= r.obj_level)
    """

    {:ok, model} = Model.load_model_from_text(model_config)
    # BLP model doesn't use traditional policies - it evaluates based on security levels
    # Adding a universal policy to trigger matcher evaluation
    adapter = StringAdapter.new("p, *, *, *")

    {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

    {:ok, enforcer: enforcer}
  end

  describe "BLP read operations" do
    test "alice (level 3) can read data1 (level 1) - read down allowed", %{enforcer: enforcer} do
      # Level 3 reading level 1: allowed (3 >= 1)
      assert Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "read"])
    end

    test "bob (level 2) can read data2 (level 2) - same level", %{enforcer: enforcer} do
      # Level 2 reading level 2: allowed (2 >= 2)
      assert Enforcer.enforce(enforcer, ["bob", 2, "data2", 2, "read"])
    end

    test "charlie (level 1) can read data1 (level 1) - same level", %{enforcer: enforcer} do
      # Level 1 reading level 1: allowed (1 >= 1)
      assert Enforcer.enforce(enforcer, ["charlie", 1, "data1", 1, "read"])
    end

    test "bob (level 2) cannot read data3 (level 3) - no read up", %{enforcer: enforcer} do
      # Level 2 trying to read level 3: not allowed (2 < 3)
      refute Enforcer.enforce(enforcer, ["bob", 2, "data3", 3, "read"])
    end

    test "charlie (level 1) cannot read data2 (level 2) - no read up", %{enforcer: enforcer} do
      # Level 1 trying to read level 2: not allowed (1 < 2)
      refute Enforcer.enforce(enforcer, ["charlie", 1, "data2", 2, "read"])
    end
  end

  describe "BLP write operations" do
    test "alice (level 3) can write to data3 (level 3) - same level", %{enforcer: enforcer} do
      # Level 3 writing to level 3: allowed (3 <= 3)
      assert Enforcer.enforce(enforcer, ["alice", 3, "data3", 3, "write"])
    end

    test "bob (level 2) can write to data3 (level 3) - write up allowed", %{enforcer: enforcer} do
      # Level 2 writing to level 3: allowed (2 <= 3)
      assert Enforcer.enforce(enforcer, ["bob", 2, "data3", 3, "write"])
    end

    test "charlie (level 1) can write to data2 (level 2) - write up allowed", %{
      enforcer: enforcer
    } do
      # Level 1 writing to level 2: allowed (1 <= 2)
      assert Enforcer.enforce(enforcer, ["charlie", 1, "data2", 2, "write"])
    end

    test "alice (level 3) cannot write to data1 (level 1) - no write down", %{
      enforcer: enforcer
    } do
      # Level 3 trying to write to level 1: not allowed (3 > 1)
      refute Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "write"])
    end

    test "bob (level 2) cannot write to data1 (level 1) - no write down", %{enforcer: enforcer} do
      # Level 2 trying to write to level 1: not allowed (2 > 1)
      refute Enforcer.enforce(enforcer, ["bob", 2, "data1", 1, "write"])
    end
  end

  describe "BLP model semantics" do
    test "verifies confidentiality protection - no information leakage down", %{
      enforcer: enforcer
    } do
      # A high-clearance subject (level 3) cannot write to low-classified data (level 1)
      refute Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "write"])

      # A low-clearance subject (level 1) cannot read high-classified data (level 3)
      refute Enforcer.enforce(enforcer, ["charlie", 1, "data3", 3, "read"])
    end

    test "allows information flow that preserves confidentiality", %{enforcer: enforcer} do
      # High can read down (reading less classified data)
      assert Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "read"])

      # Low can write up (contributing to higher classification)
      assert Enforcer.enforce(enforcer, ["charlie", 1, "data3", 3, "write"])
    end
  end

  describe "BLP vs BIBA comparison" do
    test "BLP is opposite of BIBA for read/write rules", %{enforcer: enforcer} do
      # BLP: read down (>=), write up (<=)
      # BIBA: read up (<=), write down (>=)

      # BLP allows high to read low
      assert Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "read"])

      # BLP allows low to write high
      assert Enforcer.enforce(enforcer, ["charlie", 1, "data3", 3, "write"])

      # BLP denies high writing low
      refute Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "write"])

      # BLP denies low reading high
      refute Enforcer.enforce(enforcer, ["charlie", 1, "data3", 3, "read"])
    end
  end
end
