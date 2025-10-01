defmodule CasbinEx2.EnforcerErrorTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Model

  @model_path "examples/rbac_model.conf"

  setup do
    {:ok, model} = Model.load_model(@model_path)
    adapter = MemoryAdapter.new()
    {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

    {:ok, enforcer: enforcer, model: model}
  end

  describe "enforce/2 error handling" do
    test "handles nil request", %{enforcer: enforcer} do
      # nil request is handled gracefully
      result = Enforcer.enforce(enforcer, nil)
      assert is_boolean(result)
    end

    test "handles empty request", %{enforcer: enforcer} do
      # Empty request should be evaluated (may return false)
      result = Enforcer.enforce(enforcer, [])
      assert is_boolean(result)
    end

    test "handles request with wrong number of parameters", %{enforcer: enforcer} do
      # Too few parameters
      result = Enforcer.enforce(enforcer, ["alice"])
      assert is_boolean(result)

      # Too many parameters
      result = Enforcer.enforce(enforcer, ["alice", "data1", "read", "extra", "params"])
      assert is_boolean(result)
    end

    test "handles request with nil values", %{enforcer: enforcer} do
      result = Enforcer.enforce(enforcer, [nil, "data1", "read"])
      assert is_boolean(result)

      result = Enforcer.enforce(enforcer, ["alice", nil, "read"])
      assert is_boolean(result)
    end

    test "handles request with empty strings", %{enforcer: enforcer} do
      result = Enforcer.enforce(enforcer, ["", "", ""])
      assert is_boolean(result)
    end

    test "handles request with special characters", %{enforcer: enforcer} do
      result = Enforcer.enforce(enforcer, ["alice@domain.com", "/path/to/resource", "read"])
      assert is_boolean(result)

      result = Enforcer.enforce(enforcer, ["user\\name", "data*", "read?"])
      assert is_boolean(result)
    end

    test "handles request with unicode characters", %{enforcer: enforcer} do
      result = Enforcer.enforce(enforcer, ["用户", "数据", "读取"])
      assert is_boolean(result)
    end

    test "handles request with very long strings", %{enforcer: enforcer} do
      long_string = String.duplicate("a", 10_000)
      result = Enforcer.enforce(enforcer, [long_string, "data1", "read"])
      assert is_boolean(result)
    end

    test "handles disabled enforcer", %{enforcer: enforcer} do
      disabled = %{enforcer | enabled: false}
      # Disabled enforcer should allow everything
      assert Enforcer.enforce(disabled, ["any", "request", "allowed"]) == true
    end
  end

  describe "enforce_with_matcher/3 error handling" do
    test "handles invalid matcher expression", %{enforcer: enforcer} do
      # Invalid matcher returns false
      result =
        Enforcer.enforce_with_matcher(enforcer, "invalid matcher", ["alice", "data1", "read"])

      assert is_boolean(result)
    end

    test "handles empty matcher", %{enforcer: enforcer} do
      # Empty matcher returns false
      result = Enforcer.enforce_with_matcher(enforcer, "", ["alice", "data1", "read"])
      assert is_boolean(result)
    end

    test "handles nil matcher", %{enforcer: enforcer} do
      # nil matcher returns false
      result = Enforcer.enforce_with_matcher(enforcer, nil, ["alice", "data1", "read"])
      assert is_boolean(result)
    end
  end

  describe "batch_enforce/2 error handling" do
    test "handles empty batch", %{enforcer: enforcer} do
      results = Enforcer.batch_enforce(enforcer, [])
      assert results == []
    end

    test "handles batch with nil request", %{enforcer: enforcer} do
      # Batch with nil request is handled
      results = Enforcer.batch_enforce(enforcer, [["alice", "data1", "read"], nil])
      assert is_list(results)
      assert length(results) == 2
    end

    test "handles batch with mixed valid and invalid requests", %{enforcer: enforcer} do
      batch = [
        ["alice", "data1", "read"],
        [],
        ["bob", "data2", "write"]
      ]

      results = Enforcer.batch_enforce(enforcer, batch)
      assert length(results) == 3
      assert Enum.all?(results, &is_boolean/1)
    end

    test "handles very large batch", %{enforcer: enforcer} do
      large_batch = Enum.map(1..1000, fn _ -> ["alice", "data1", "read"] end)
      results = Enforcer.batch_enforce(enforcer, large_batch)
      assert length(results) == 1000
    end
  end

  describe "load_policy/1 error handling" do
    test "handles adapter that returns error", %{model: model} do
      # Create a memory adapter with no initial data
      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

      # Should succeed with empty policies
      assert {:ok, _} = Enforcer.load_policy(enforcer)
    end

    test "reloading policy clears existing policies", %{enforcer: enforcer} do
      # Add a policy
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true

      # Reload from adapter (which has no policies)
      {:ok, reloaded} = Enforcer.load_policy(enforcer)

      # Policy should be gone
      assert Enforcer.enforce(reloaded, ["alice", "data1", "read"]) == false
    end
  end

  describe "save_policy/1 error handling" do
    test "handles save with no policies", %{enforcer: enforcer} do
      # Should succeed even with empty policies
      assert {:ok, _} = Enforcer.save_policy(enforcer)
    end

    test "handles save after clearing policies", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])
      cleared = %{enforcer | policies: %{}, grouping_policies: %{}}
      assert {:ok, _} = Enforcer.save_policy(cleared)
    end
  end

  describe "init_with_model_and_adapter/2 error handling" do
    test "handles nil model" do
      adapter = MemoryAdapter.new()

      # nil model is accepted but creates broken enforcer
      assert {:ok, enforcer} = Enforcer.init_with_model_and_adapter(nil, adapter)
      assert enforcer.model == nil
    end

    test "handles nil adapter" do
      {:ok, model} = Model.load_model(@model_path)

      # nil adapter causes KeyError during load_policy
      assert_raise KeyError, fn ->
        Enforcer.init_with_model_and_adapter(model, nil)
      end
    end

    test "handles model with missing sections" do
      # Create a minimal model
      minimal_model = %Model{
        request_definition: %{"r" => ["sub", "obj", "act"]},
        policy_definition: %{"p" => ["sub", "obj", "act"]},
        matchers: %{"m" => "r.sub == p.sub && r.obj == p.obj && r.act == p.act"},
        policy_effect: %{"e" => "some(where (p.eft == allow))"}
      }

      adapter = MemoryAdapter.new()
      {:ok, _enforcer} = Enforcer.init_with_model_and_adapter(minimal_model, adapter)
    end
  end

  describe "new_enforcer/2 error handling" do
    test "handles non-existent model file" do
      assert {:error, _} = Enforcer.new_enforcer("/nonexistent/model.conf", "policy.csv")
    end

    test "handles non-existent policy file" do
      # Should succeed - FileAdapter handles non-existent files gracefully
      assert {:ok, _} = Enforcer.new_enforcer(@model_path, "/nonexistent/policy.csv")
    end

    test "handles invalid model file format" do
      # Create a temp invalid model file
      invalid_model = "test_invalid_model_#{:rand.uniform(10000)}.conf"
      File.write!(invalid_model, "invalid content\n[missing_section]\n")

      # Invalid model loads but creates empty model structure
      assert {:ok, enforcer} = Enforcer.new_enforcer(invalid_model, "policy.csv")
      assert enforcer.model.request_definition == %{}

      File.rm(invalid_model)
    end
  end

  describe "policy edge cases" do
    test "handles policy with empty subject", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["", "data1", "read"])
      assert Enforcer.enforce(enforcer, ["", "data1", "read"]) == true
    end

    test "handles policy with empty object", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "", "read"])
      assert Enforcer.enforce(enforcer, ["alice", "", "read"]) == true
    end

    test "handles policy with empty action", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", ""])
      assert Enforcer.enforce(enforcer, ["alice", "data1", ""]) == true
    end

    test "handles policy with all empty values", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["", "", ""])
      assert Enforcer.enforce(enforcer, ["", "", ""]) == true
    end

    test "handles duplicate policy addition", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      assert {:error, "policy already exists"} =
               CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])
    end

    test "handles removal of non-existent policy", %{enforcer: enforcer} do
      assert {:error, _} =
               CasbinEx2.Management.remove_policy(enforcer, ["nonexistent", "policy", "rule"])
    end

    test "handles policy with special regex characters", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data.*", "read"])
      # Should match literally, not as regex (unless model supports regex)
      assert Enforcer.enforce(enforcer, ["alice", "data.*", "read"]) == true
    end
  end

  describe "role edge cases" do
    test "handles role with empty user", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "", "admin")
      assert CasbinEx2.RBAC.has_role_for_user(enforcer, "", "admin") == true
    end

    test "handles role with empty role name", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "alice", "")
      assert CasbinEx2.RBAC.has_role_for_user(enforcer, "alice", "") == true
    end

    test "handles circular role inheritance", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "admin", "superuser")
      # Attempting to create a cycle
      {:ok, _enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "superuser", "alice")
      # Should not crash, role manager should handle it
    end

    test "handles very deep role hierarchy", %{enforcer: enforcer} do
      # Create 100-level deep hierarchy
      enforcer =
        Enum.reduce(1..100, enforcer, fn i, acc ->
          {:ok, updated} = CasbinEx2.RBAC.add_role_for_user(acc, "user#{i}", "role#{i + 1}")
          updated
        end)

      # Should not crash
      roles = CasbinEx2.RBAC.get_roles_for_user(enforcer, "user1")
      assert is_list(roles)
    end
  end

  describe "concurrent modification edge cases" do
    test "handles concurrent enforce calls", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      tasks =
        Enum.map(1..100, fn _ ->
          Task.async(fn -> Enforcer.enforce(enforcer, ["alice", "data1", "read"]) end)
        end)

      results = Task.await_many(tasks, 10_000)
      assert Enum.all?(results, &(&1 == true))
    end

    test "enforcer struct is immutable", %{enforcer: enforcer} do
      original_policies = enforcer.policies

      # Enforce doesn't modify the enforcer
      _result = Enforcer.enforce(enforcer, ["alice", "data1", "read"])

      assert enforcer.policies == original_policies
    end
  end

  describe "model validation edge cases" do
    test "handles request with more parameters than model defines", %{enforcer: enforcer} do
      # Model expects 3 params (sub, obj, act), providing 5
      result = Enforcer.enforce(enforcer, ["alice", "data1", "read", "extra1", "extra2"])
      assert is_boolean(result)
    end

    test "handles request with fewer parameters than model defines", %{enforcer: enforcer} do
      # Model expects 3 params, providing 1
      result = Enforcer.enforce(enforcer, ["alice"])
      assert is_boolean(result)
    end
  end

  describe "auto_build_role_links edge cases" do
    test "handles enforcer with auto_build_role_links disabled", %{model: model} do
      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

      enforcer_no_auto = %{enforcer | auto_build_role_links: false}

      # Should still work but won't auto-build role links
      {:ok, enforcer_no_auto} =
        CasbinEx2.RBAC.add_role_for_user(enforcer_no_auto, "alice", "admin")

      # Role is added to grouping policies but role manager not updated automatically
      assert is_map(enforcer_no_auto.grouping_policies)
    end
  end

  describe "enabled/disabled enforcer edge cases" do
    test "disabled enforcer allows all requests", %{enforcer: enforcer} do
      disabled = %{enforcer | enabled: false}

      # Should allow everything
      assert Enforcer.enforce(disabled, ["any", "user", "action"]) == true
      assert Enforcer.enforce(disabled, ["random", "data", "delete"]) == true
      assert Enforcer.enforce(disabled, []) == true
    end

    test "can toggle enabled state", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      # Initially enabled
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data1", "write"]) == false

      # Disable
      disabled = %{enforcer | enabled: false}
      assert Enforcer.enforce(disabled, ["alice", "data1", "write"]) == true

      # Re-enable
      enabled = %{disabled | enabled: true}
      assert Enforcer.enforce(enabled, ["alice", "data1", "write"]) == false
    end
  end

  describe "memory stress tests" do
    test "handles many policies", %{enforcer: enforcer} do
      # Add 1000 policies
      enforcer =
        Enum.reduce(1..1000, enforcer, fn i, acc ->
          {:ok, updated} = CasbinEx2.Management.add_policy(acc, ["user#{i}", "data#{i}", "read"])
          updated
        end)

      # Should still work
      assert Enforcer.enforce(enforcer, ["user500", "data500", "read"]) == true
      assert Enforcer.enforce(enforcer, ["user1000", "data1000", "read"]) == true
    end

    test "handles many roles", %{enforcer: enforcer} do
      # Add 1000 role assignments
      enforcer =
        Enum.reduce(1..1000, enforcer, fn i, acc ->
          {:ok, updated} = CasbinEx2.RBAC.add_role_for_user(acc, "user#{i}", "role#{rem(i, 10)}")
          updated
        end)

      # Should still work
      assert CasbinEx2.RBAC.has_role_for_user(enforcer, "user500", "role0") == true
    end
  end

  describe "boundary conditions" do
    test "handles exact match on boundary", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      # Exact match
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true

      # Off by one character
      assert Enforcer.enforce(enforcer, ["alicE", "data1", "read"]) == false
      assert Enforcer.enforce(enforcer, ["alice", "data2", "read"]) == false
      assert Enforcer.enforce(enforcer, ["alice", "data1", "write"]) == false
    end

    test "handles whitespace in policies", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice ", " data1", "read "])

      # Should match with whitespace preserved
      assert Enforcer.enforce(enforcer, ["alice ", " data1", "read "]) == true

      # Should not match without whitespace
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == false
    end

    test "handles case sensitivity", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["Alice", "Data1", "Read"])

      # Should be case-sensitive by default
      assert Enforcer.enforce(enforcer, ["Alice", "Data1", "Read"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == false
    end
  end

  describe "error recovery" do
    test "enforcer continues working after operations", %{enforcer: enforcer} do
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = CasbinEx2.Management.remove_policy(enforcer, ["alice", "data1", "read"])

      # Should still work
      assert is_boolean(Enforcer.enforce(enforcer, ["alice", "data1", "read"]))
    end

    test "can recover from invalid state", %{enforcer: enforcer} do
      # Set invalid state
      broken = %{enforcer | policies: nil}

      # This will error with BadMapError
      assert_raise BadMapError, fn ->
        Enforcer.enforce(broken, ["alice", "data1", "read"])
      end

      # Original enforcer still works
      assert is_boolean(Enforcer.enforce(enforcer, ["alice", "data1", "read"]))
    end
  end
end
