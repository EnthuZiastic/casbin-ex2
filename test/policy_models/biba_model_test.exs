defmodule CasbinEx2.BibaModelTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.StringAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Model

  @moduledoc """
  BIBA (Bell-LaPadula Integrity Model) Tests

  BIBA is an integrity model that enforces:
  - Read-down: Subjects can read objects at their level or below
  - Write-up: Subjects can write to objects at their level or above

  This prevents low-integrity data from contaminating high-integrity data.
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
    m = (r.act == "read" && r.sub_level <= r.obj_level) || (r.act == "write" && r.sub_level >= r.obj_level)
    """

    {:ok, model} = Model.load_model_from_text(model_config)
    # BIBA model doesn't use traditional policies - it evaluates based on security levels
    # Adding a universal policy to trigger matcher evaluation
    adapter = StringAdapter.new("p, *, *, *")

    {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

    {:ok, enforcer: enforcer}
  end

  describe "BIBA read operations" do
    test "alice (level 3) cannot read data1 (level 1) - read down violation", %{
      enforcer: enforcer
    } do
      # Level 3 trying to read level 1: not allowed (3 > 1)
      refute Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "read"])
    end

    test "bob (level 2) can read data2 (level 2) - same level", %{enforcer: enforcer} do
      # Level 2 reading level 2: allowed (2 <= 2)
      assert Enforcer.enforce(enforcer, ["bob", 2, "data2", 2, "read"])
    end

    test "charlie (level 1) can read data1 (level 1) - same level", %{enforcer: enforcer} do
      # Level 1 reading level 1: allowed (1 <= 1)
      assert Enforcer.enforce(enforcer, ["charlie", 1, "data1", 1, "read"])
    end

    test "bob (level 2) can read data3 (level 3) - read up allowed", %{enforcer: enforcer} do
      # Level 2 reading level 3: allowed (2 <= 3)
      assert Enforcer.enforce(enforcer, ["bob", 2, "data3", 3, "read"])
    end

    test "charlie (level 1) can read data2 (level 2) - read up allowed", %{
      enforcer: enforcer
    } do
      # Level 1 reading level 2: allowed (1 <= 2)
      assert Enforcer.enforce(enforcer, ["charlie", 1, "data2", 2, "read"])
    end
  end

  describe "BIBA write operations" do
    test "alice (level 3) can write to data3 (level 3) - same level", %{enforcer: enforcer} do
      # Level 3 writing to level 3: allowed (3 >= 3)
      assert Enforcer.enforce(enforcer, ["alice", 3, "data3", 3, "write"])
    end

    test "bob (level 2) cannot write to data3 (level 3) - write up violation", %{
      enforcer: enforcer
    } do
      # Level 2 trying to write to level 3: not allowed (2 < 3)
      refute Enforcer.enforce(enforcer, ["bob", 2, "data3", 3, "write"])
    end

    test "charlie (level 1) cannot write to data2 (level 2) - write up violation", %{
      enforcer: enforcer
    } do
      # Level 1 trying to write to level 2: not allowed (1 < 2)
      refute Enforcer.enforce(enforcer, ["charlie", 1, "data2", 2, "write"])
    end

    test "alice (level 3) can write to data1 (level 1) - write down allowed", %{
      enforcer: enforcer
    } do
      # Level 3 writing to level 1: allowed (3 >= 1)
      assert Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "write"])
    end

    test "bob (level 2) can write to data1 (level 1) - write down allowed", %{
      enforcer: enforcer
    } do
      # Level 2 writing to level 1: allowed (2 >= 1)
      assert Enforcer.enforce(enforcer, ["bob", 2, "data1", 1, "write"])
    end
  end

  describe "BIBA model semantics" do
    test "verifies integrity protection - low cannot corrupt high", %{enforcer: enforcer} do
      # A low-integrity subject (level 1) cannot write to high-integrity data (level 3)
      refute Enforcer.enforce(enforcer, ["charlie", 1, "data3", 3, "write"])

      # A high-integrity subject (level 3) cannot read low-integrity data (level 1)
      refute Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "read"])
    end

    test "allows information flow that preserves integrity", %{enforcer: enforcer} do
      # High can write down (degrading their own data)
      assert Enforcer.enforce(enforcer, ["alice", 3, "data1", 1, "write"])

      # Low can read up (reading trusted data)
      assert Enforcer.enforce(enforcer, ["charlie", 1, "data3", 3, "read"])
    end
  end
end
