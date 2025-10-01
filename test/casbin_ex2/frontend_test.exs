defmodule CasbinEx2.FrontendTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Frontend
  alias CasbinEx2.Management
  alias CasbinEx2.Model

  describe "casbin_js_get_permission_for_user/2" do
    test "exports model and policies as JSON" do
      # Create a simple enforcer with RBAC model
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [role_definition]
      g = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, MemoryAdapter.new())

      # Add some policies
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "write"])

      # Add grouping policies
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["alice", "admin"])

      # Get permission data
      {:ok, json} = Frontend.casbin_js_get_permission_for_user(enforcer, "alice")

      # Decode and verify
      assert is_binary(json)
      {:ok, data} = Jason.decode(json)

      # Check structure
      assert Map.has_key?(data, "m")
      assert Map.has_key?(data, "p")
      assert Map.has_key?(data, "g")

      # Verify model is a string
      assert is_binary(data["m"])
      assert String.contains?(data["m"], "[request_definition]")
      assert String.contains?(data["m"], "[policy_definition]")
      assert String.contains?(data["m"], "[matchers]")

      # Verify policies are arrays
      assert is_list(data["p"])
      assert ["p", "alice", "data1", "read"] in data["p"]
      assert ["p", "bob", "data2", "write"] in data["p"]

      # Verify grouping policies are arrays
      assert is_list(data["g"])
      assert ["g", "alice", "admin"] in data["g"]
    end

    test "handles empty policies correctly" do
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, MemoryAdapter.new())

      {:ok, json} = Frontend.casbin_js_get_permission_for_user(enforcer, "alice")
      {:ok, data} = Jason.decode(json)

      # Empty policies should be empty arrays
      assert data["p"] == []
      assert data["g"] == []
    end

    test "handles multiple policy types" do
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act
      p2 = sub, obj, act

      [role_definition]
      g = _, _
      g2 = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, MemoryAdapter.new())

      # Add policies for different types
      {:ok, enforcer} = Management.add_named_policy(enforcer, "p", ["alice", "data1", "read"])
      {:ok, enforcer} = Management.add_named_policy(enforcer, "p2", ["bob", "data2", "write"])

      {:ok, enforcer} = Management.add_named_grouping_policy(enforcer, "g", ["alice", "admin"])

      {:ok, enforcer} =
        Management.add_named_grouping_policy(enforcer, "g2", ["bob", "developer"])

      {:ok, json} = Frontend.casbin_js_get_permission_for_user(enforcer, "alice")
      {:ok, data} = Jason.decode(json)

      # Check all policy types are present
      assert ["p", "alice", "data1", "read"] in data["p"]
      assert ["p2", "bob", "data2", "write"] in data["p"]
      assert ["g", "alice", "admin"] in data["g"]
      assert ["g2", "bob", "developer"] in data["g"]
    end

    test "user parameter is preserved for API compatibility" do
      # The user parameter is not currently used but kept for Go API compatibility
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, MemoryAdapter.new())
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])

      # Should work with any user parameter
      {:ok, json1} = Frontend.casbin_js_get_permission_for_user(enforcer, "alice")
      {:ok, json2} = Frontend.casbin_js_get_permission_for_user(enforcer, "bob")
      {:ok, json3} = Frontend.casbin_js_get_permission_for_user(enforcer, "anyone")

      # All should return the same data since user is not used
      {:ok, data1} = Jason.decode(json1)
      {:ok, data2} = Jason.decode(json2)
      {:ok, data3} = Jason.decode(json3)

      assert data1 == data2
      assert data2 == data3
    end

    test "handles domain-based policies" do
      model_text = """
      [request_definition]
      r = sub, dom, obj, act

      [policy_definition]
      p = sub, dom, obj, act

      [role_definition]
      g = _, _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, MemoryAdapter.new())

      {:ok, enforcer} =
        Management.add_policy(enforcer, ["alice", "domain1", "data1", "read"])

      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "domain2", "data2", "write"])

      {:ok, enforcer} =
        Management.add_grouping_policy(enforcer, ["alice", "admin", "domain1"])

      {:ok, json} = Frontend.casbin_js_get_permission_for_user(enforcer, "alice")
      {:ok, data} = Jason.decode(json)

      # Verify domain policies are included
      assert ["p", "alice", "domain1", "data1", "read"] in data["p"]
      assert ["p", "bob", "domain2", "data2", "write"] in data["p"]
      assert ["g", "alice", "admin", "domain1"] in data["g"]
    end
  end

  describe "model_to_text/1" do
    test "converts model struct to text format" do
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      text = Frontend.model_to_text(model)

      # Check all sections are present
      assert String.contains?(text, "[request_definition]")
      assert String.contains?(text, "[policy_definition]")
      assert String.contains?(text, "[policy_effect]")
      assert String.contains?(text, "[matchers]")

      # Check content is present
      assert String.contains?(text, "r = sub, obj, act")
      assert String.contains?(text, "p = sub, obj, act")
      assert String.contains?(text, "e = some(where (p.eft == allow))")
      assert String.contains?(text, "m = r.sub == p.sub")
    end

    test "handles model with role definition" do
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [role_definition]
      g = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      text = Frontend.model_to_text(model)

      assert String.contains?(text, "[role_definition]")
      assert String.contains?(text, "g = _, _")
    end

    test "handles model with multiple policy types" do
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act
      p2 = sub, obj, act

      [role_definition]
      g = _, _
      g2 = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      text = Frontend.model_to_text(model)

      # Multiple policy definitions
      assert String.contains?(text, "p = sub, obj, act")
      assert String.contains?(text, "p2 = sub, obj, act")

      # Multiple role definitions
      assert String.contains?(text, "g = _, _")
      assert String.contains?(text, "g2 = _, _")
    end
  end

  describe "integration tests" do
    test "exported data can be used to recreate enforcer" do
      # Create original enforcer
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [role_definition]
      g = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      {:ok, enforcer1} = Enforcer.init_with_model_and_adapter(model, MemoryAdapter.new())
      {:ok, enforcer1} = Management.add_policy(enforcer1, ["alice", "data1", "read"])
      {:ok, enforcer1} = Management.add_grouping_policy(enforcer1, ["alice", "admin"])

      # Export data
      {:ok, json} = Frontend.casbin_js_get_permission_for_user(enforcer1, "alice")
      {:ok, data} = Jason.decode(json)

      # Recreate model from exported text
      {:ok, model2} = Model.load_model_from_text(data["m"])
      {:ok, enforcer2} = Enforcer.init_with_model_and_adapter(model2, MemoryAdapter.new())

      # Add policies from exported data
      enforcer2 =
        Enum.reduce(data["p"], enforcer2, fn [_ptype | rule], acc ->
          {:ok, updated} = Management.add_policy(acc, rule)
          updated
        end)

      enforcer2 =
        Enum.reduce(data["g"], enforcer2, fn [_ptype | rule], acc ->
          {:ok, updated} = Management.add_grouping_policy(acc, rule)
          updated
        end)

      # Both enforcers should behave identically
      assert Enforcer.enforce(enforcer1, ["alice", "data1", "read"]) ==
               Enforcer.enforce(enforcer2, ["alice", "data1", "read"])

      assert Enforcer.enforce(enforcer1, ["alice", "data2", "write"]) ==
               Enforcer.enforce(enforcer2, ["alice", "data2", "write"])
    end

    test "JSON output is valid and parseable" do
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      {:ok, model} = Model.load_model_from_text(model_text)
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, MemoryAdapter.new())
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])

      {:ok, json} = Frontend.casbin_js_get_permission_for_user(enforcer, "alice")

      # Should be valid JSON
      assert {:ok, _data} = Jason.decode(json)

      # Should not have HTML escaping
      refute String.contains?(json, "\\u003c")
      refute String.contains?(json, "\\u003e")
    end
  end
end
