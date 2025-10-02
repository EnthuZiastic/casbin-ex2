defmodule CasbinEx2.LBACModelTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.StringAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Model

  @moduledoc """
  LBAC (Lattice-Based Access Control) Tests

  LBAC combines both confidentiality (BLP) and integrity (BIBA) controls
  in a lattice structure with two dimensions:

  - Confidentiality Level: Controls information disclosure
  - Integrity Level: Controls information modification

  Read operations require:
  - subject_confidentiality >= object_confidentiality (BLP: can read down)
  - subject_integrity >= object_integrity (BIBA: can read down)

  Write operations require:
  - subject_confidentiality <= object_confidentiality (BLP: can write up)
  - subject_integrity <= object_integrity (BIBA: can write up)
  """

  setup do
    model_config = """
    [request_definition]
    r = sub, subject_confidentiality, subject_integrity, obj, object_confidentiality, object_integrity, act

    [policy_definition]
    p = sub, obj, act

    [role_definition]
    g = _, _

    [policy_effect]
    e = allow

    [matchers]
    m = (r.act == "read" && r.subject_confidentiality >= r.object_confidentiality && r.subject_integrity >= r.object_integrity) || (r.act == "write" && r.subject_confidentiality <= r.object_confidentiality && r.subject_integrity <= r.object_integrity)
    """

    {:ok, model} = Model.load_model_from_text(model_config)
    # LBAC model doesn't use traditional policies - it evaluates based on security levels
    # Adding a universal policy to trigger matcher evaluation
    adapter = StringAdapter.new("p, *, *, *")

    {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

    {:ok, enforcer: enforcer}
  end

  describe "LBAC read operations - normal scenarios" do
    test "admin (5,5) can read file_topsecret (3,3) - both dimensions higher", %{
      enforcer: enforcer
    } do
      # Conf: 5 >= 3 ✓, Integ: 5 >= 3 ✓
      assert Enforcer.enforce(enforcer, ["admin", 5, 5, "file_topsecret", 3, 3, "read"])
    end

    test "manager (4,4) can read file_secret (4,2) - conf equal, integ higher", %{
      enforcer: enforcer
    } do
      # Conf: 4 >= 4 ✓, Integ: 4 >= 2 ✓
      assert Enforcer.enforce(enforcer, ["manager", 4, 4, "file_secret", 4, 2, "read"])
    end

    test "staff (3,3) can read file_internal (2,3) - conf higher, integ equal", %{
      enforcer: enforcer
    } do
      # Conf: 3 >= 2 ✓, Integ: 3 >= 3 ✓
      assert Enforcer.enforce(enforcer, ["staff", 3, 3, "file_internal", 2, 3, "read"])
    end

    test "guest (2,2) can read file_public (2,2) - both dimensions equal", %{
      enforcer: enforcer
    } do
      # Conf: 2 >= 2 ✓, Integ: 2 >= 2 ✓
      assert Enforcer.enforce(enforcer, ["guest", 2, 2, "file_public", 2, 2, "read"])
    end
  end

  describe "LBAC read operations - violation scenarios" do
    test "staff (3,3) cannot read file_secret (4,2) - insufficient confidentiality", %{
      enforcer: enforcer
    } do
      # Conf: 3 < 4 ✗, Integ: 3 >= 2 ✓
      refute Enforcer.enforce(enforcer, ["staff", 3, 3, "file_secret", 4, 2, "read"])
    end

    test "manager (4,4) cannot read file_sensitive (3,5) - insufficient integrity", %{
      enforcer: enforcer
    } do
      # Conf: 4 >= 3 ✓, Integ: 4 < 5 ✗
      refute Enforcer.enforce(enforcer, ["manager", 4, 4, "file_sensitive", 3, 5, "read"])
    end

    test "guest (2,2) cannot read file_internal (3,1) - insufficient confidentiality", %{
      enforcer: enforcer
    } do
      # Conf: 2 < 3 ✗, Integ: 2 >= 1 ✓
      refute Enforcer.enforce(enforcer, ["guest", 2, 2, "file_internal", 3, 1, "read"])
    end

    test "staff (3,3) cannot read file_protected (1,4) - insufficient integrity", %{
      enforcer: enforcer
    } do
      # Conf: 3 >= 1 ✓, Integ: 3 < 4 ✗
      refute Enforcer.enforce(enforcer, ["staff", 3, 3, "file_protected", 1, 4, "read"])
    end
  end

  describe "LBAC write operations - normal scenarios" do
    test "guest (2,2) can write to file_public (2,2) - both dimensions equal", %{
      enforcer: enforcer
    } do
      # Conf: 2 <= 2 ✓, Integ: 2 <= 2 ✓
      assert Enforcer.enforce(enforcer, ["guest", 2, 2, "file_public", 2, 2, "write"])
    end

    test "staff (3,3) can write to file_internal (5,4) - writing up in both dimensions", %{
      enforcer: enforcer
    } do
      # Conf: 3 <= 5 ✓, Integ: 3 <= 4 ✓
      assert Enforcer.enforce(enforcer, ["staff", 3, 3, "file_internal", 5, 4, "write"])
    end

    test "manager (4,4) can write to file_secret (4,5) - conf equal, integ lower", %{
      enforcer: enforcer
    } do
      # Conf: 4 <= 4 ✓, Integ: 4 <= 5 ✓
      assert Enforcer.enforce(enforcer, ["manager", 4, 4, "file_secret", 4, 5, "write"])
    end

    test "admin (5,5) can write to file_archive (5,5) - both dimensions equal", %{
      enforcer: enforcer
    } do
      # Conf: 5 <= 5 ✓, Integ: 5 <= 5 ✓
      assert Enforcer.enforce(enforcer, ["admin", 5, 5, "file_archive", 5, 5, "write"])
    end
  end

  describe "LBAC write operations - violation scenarios" do
    test "manager (4,4) cannot write to file_internal (3,5) - confidentiality too high", %{
      enforcer: enforcer
    } do
      # Conf: 4 > 3 ✗, Integ: 4 <= 5 ✓
      refute Enforcer.enforce(enforcer, ["manager", 4, 4, "file_internal", 3, 5, "write"])
    end

    test "staff (3,3) cannot write to file_public (2,2) - both dimensions too high", %{
      enforcer: enforcer
    } do
      # Conf: 3 > 2 ✗, Integ: 3 > 2 ✗
      refute Enforcer.enforce(enforcer, ["staff", 3, 3, "file_public", 2, 2, "write"])
    end

    test "admin (5,5) cannot write to file_secret (5,4) - integrity too high", %{
      enforcer: enforcer
    } do
      # Conf: 5 <= 5 ✓, Integ: 5 > 4 ✗
      refute Enforcer.enforce(enforcer, ["admin", 5, 5, "file_secret", 5, 4, "write"])
    end

    test "guest (2,2) cannot write to file_private (1,3) - confidentiality too high", %{
      enforcer: enforcer
    } do
      # Conf: 2 > 1 ✗, Integ: 2 <= 3 ✓
      refute Enforcer.enforce(enforcer, ["guest", 2, 2, "file_private", 1, 3, "write"])
    end
  end

  describe "LBAC lattice semantics" do
    test "verifies dual-dimension access control", %{enforcer: enforcer} do
      # Both dimensions must satisfy constraints for access
      # Read requires BOTH conf >= AND integ >=
      assert Enforcer.enforce(enforcer, ["admin", 5, 5, "file_public", 2, 2, "read"])
      refute Enforcer.enforce(enforcer, ["admin", 5, 3, "file_data", 2, 4, "read"])

      # Write requires BOTH conf <= AND integ <=
      assert Enforcer.enforce(enforcer, ["guest", 2, 2, "file_topsecret", 5, 5, "write"])
      refute Enforcer.enforce(enforcer, ["guest", 2, 4, "file_data", 5, 3, "write"])
    end

    test "demonstrates lattice partial ordering", %{enforcer: enforcer} do
      # (5,5) dominates (3,3): can read, cannot write down
      assert Enforcer.enforce(enforcer, ["admin", 5, 5, "file_mid", 3, 3, "read"])
      refute Enforcer.enforce(enforcer, ["admin", 5, 5, "file_mid", 3, 3, "write"])

      # (3,3) does not dominate (5,5): cannot read, can write up
      refute Enforcer.enforce(enforcer, ["staff", 3, 3, "file_high", 5, 5, "read"])
      assert Enforcer.enforce(enforcer, ["staff", 3, 3, "file_high", 5, 5, "write"])
    end

    test "shows incomparable elements in lattice", %{enforcer: enforcer} do
      # (4,2) and (2,4) are incomparable
      # (4,2) cannot read (2,4): conf OK (4>=2), integ FAIL (2<4)
      refute Enforcer.enforce(enforcer, ["user1", 4, 2, "obj1", 2, 4, "read"])

      # (2,4) cannot read (4,2): conf FAIL (2<4), integ OK (4>=2)
      refute Enforcer.enforce(enforcer, ["user2", 2, 4, "obj2", 4, 2, "read"])

      # Neither can write to the other
      refute Enforcer.enforce(enforcer, ["user1", 4, 2, "obj1", 2, 4, "write"])
      refute Enforcer.enforce(enforcer, ["user2", 2, 4, "obj2", 4, 2, "write"])
    end
  end

  describe "LBAC combines BLP and BIBA" do
    test "enforces BLP confidentiality rules", %{enforcer: enforcer} do
      # Read: subject_conf >= object_conf (BLP: no read up)
      assert Enforcer.enforce(enforcer, ["high_conf", 5, 3, "low_conf", 2, 3, "read"])
      refute Enforcer.enforce(enforcer, ["low_conf", 2, 3, "high_conf", 5, 3, "read"])

      # Write: subject_conf <= object_conf (BLP: no write down)
      assert Enforcer.enforce(enforcer, ["low_conf", 2, 3, "high_conf", 5, 3, "write"])
      refute Enforcer.enforce(enforcer, ["high_conf", 5, 3, "low_conf", 2, 3, "write"])
    end

    test "enforces BIBA integrity rules", %{enforcer: enforcer} do
      # Read: subject_integ >= object_integ (BIBA: no read up)
      assert Enforcer.enforce(enforcer, ["high_integ", 3, 5, "low_integ", 3, 2, "read"])
      refute Enforcer.enforce(enforcer, ["low_integ", 3, 2, "high_integ", 3, 5, "read"])

      # Write: subject_integ <= object_integ (BIBA: no write down)
      assert Enforcer.enforce(enforcer, ["low_integ", 3, 2, "high_integ", 3, 5, "write"])
      refute Enforcer.enforce(enforcer, ["high_integ", 3, 5, "low_integ", 3, 2, "write"])
    end
  end
end
