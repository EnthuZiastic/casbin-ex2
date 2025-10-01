defmodule CasbinEx2.ManagementAPITest do
  @moduledoc """
  Tests for Management API functions implemented to match Golang Casbin.
  Tests the 25 functions added for feature parity.
  """
  use ExUnit.Case, async: true

  alias CasbinEx2.{Enforcer, Management}

  setup do
    {:ok, enforcer} =
      Enforcer.new_enforcer("examples/rbac_model.conf", "examples/rbac_policy.csv")

    {:ok, enforcer: enforcer}
  end

  describe "add_grouping_policy/2" do
    test "adds a grouping policy successfully", %{enforcer: enforcer} do
      {:ok, updated_enforcer} = Management.add_grouping_policy(enforcer, ["bob", "admin"])

      assert Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
    end

    test "returns error when grouping policy already exists", %{enforcer: enforcer} do
      # alice is already in data_group_admin from the CSV
      assert {:error, "grouping policy already exists"} =
               Management.add_grouping_policy(enforcer, ["alice", "data_group_admin"])
    end

    test "updates role manager for g type policies", %{enforcer: enforcer} do
      {:ok, updated_enforcer} = Management.add_grouping_policy(enforcer, ["charlie", "admin"])

      # Verify role manager was updated
      assert Management.has_grouping_policy(updated_enforcer, ["charlie", "admin"])
    end
  end

  describe "add_grouping_policies/2" do
    test "adds multiple grouping policies successfully", %{enforcer: enforcer} do
      policies = [
        ["bob", "admin"],
        ["charlie", "moderator"]
      ]

      {:ok, updated_enforcer} = Management.add_grouping_policies(enforcer, policies)

      assert Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
      assert Management.has_grouping_policy(updated_enforcer, ["charlie", "moderator"])
    end

    test "returns error if any policy already exists", %{enforcer: enforcer} do
      policies = [
        ["bob", "admin"],
        ["alice", "data_group_admin"]
      ]

      assert {:error, _reason} = Management.add_grouping_policies(enforcer, policies)
    end
  end

  describe "add_named_grouping_policy/3" do
    test "adds a named grouping policy successfully", %{enforcer: enforcer} do
      {:ok, updated_enforcer} =
        Management.add_named_grouping_policy(enforcer, "g", ["bob", "admin"])

      assert Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])
    end

    test "returns error when named grouping policy already exists", %{enforcer: enforcer} do
      assert {:error, "grouping policy already exists"} =
               Management.add_named_grouping_policy(enforcer, "g", ["alice", "data_group_admin"])
    end
  end

  describe "add_named_grouping_policies/3" do
    test "adds multiple named grouping policies successfully", %{enforcer: enforcer} do
      policies = [
        ["bob", "admin"],
        ["charlie", "moderator"]
      ]

      {:ok, updated_enforcer} =
        Management.add_named_grouping_policies(enforcer, "g", policies)

      assert Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])

      assert Management.has_named_grouping_policy(updated_enforcer, "g", [
               "charlie",
               "moderator"
             ])
    end
  end

  describe "remove_grouping_policy/2" do
    test "removes a grouping policy successfully", %{enforcer: enforcer} do
      # First add a policy
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["bob", "admin"])

      # Then remove it
      {:ok, updated_enforcer} = Management.remove_grouping_policy(enforcer, ["bob", "admin"])

      refute Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
    end

    test "returns error when grouping policy doesn't exist", %{enforcer: enforcer} do
      assert {:error, "grouping policy does not exist"} =
               Management.remove_grouping_policy(enforcer, ["nonexistent", "role"])
    end

    test "updates role manager when removing g type policy", %{enforcer: enforcer} do
      # alice -> data_group_admin exists in CSV
      {:ok, updated_enforcer} =
        Management.remove_grouping_policy(enforcer, ["alice", "data_group_admin"])

      refute Management.has_grouping_policy(updated_enforcer, ["alice", "data_group_admin"])
    end
  end

  describe "remove_grouping_policies/2" do
    test "removes multiple grouping policies successfully", %{enforcer: enforcer} do
      # Add policies first
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["bob", "admin"])
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["charlie", "moderator"])

      # Remove them
      policies = [
        ["bob", "admin"],
        ["charlie", "moderator"]
      ]

      {:ok, updated_enforcer} = Management.remove_grouping_policies(enforcer, policies)

      refute Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
      refute Management.has_grouping_policy(updated_enforcer, ["charlie", "moderator"])
    end
  end

  describe "remove_named_grouping_policy/3" do
    test "removes a named grouping policy successfully", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_named_grouping_policy(enforcer, "g", ["bob", "admin"])

      {:ok, updated_enforcer} =
        Management.remove_named_grouping_policy(enforcer, "g", ["bob", "admin"])

      refute Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])
    end
  end

  describe "remove_named_grouping_policies/3" do
    test "removes multiple named grouping policies successfully", %{enforcer: enforcer} do
      {:ok, enforcer} =
        Management.add_named_grouping_policies(enforcer, "g", [
          ["bob", "admin"],
          ["charlie", "moderator"]
        ])

      {:ok, updated_enforcer} =
        Management.remove_named_grouping_policies(enforcer, "g", [
          ["bob", "admin"],
          ["charlie", "moderator"]
        ])

      refute Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])

      refute Management.has_named_grouping_policy(updated_enforcer, "g", [
               "charlie",
               "moderator"
             ])
    end
  end

  describe "remove_filtered_grouping_policy/3" do
    test "removes grouping policies matching filter", %{enforcer: enforcer} do
      # Add some policies
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["bob", "admin"])
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["bob", "moderator"])
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["charlie", "admin"])

      # Remove all policies where user is "bob"
      {:ok, updated_enforcer, count} =
        Management.remove_filtered_grouping_policy(enforcer, 0, ["bob"])

      assert count == 2
      refute Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
      refute Management.has_grouping_policy(updated_enforcer, ["bob", "moderator"])
      assert Management.has_grouping_policy(updated_enforcer, ["charlie", "admin"])
    end

    test "supports wildcard filtering with empty strings", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["bob", "admin"])
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["charlie", "admin"])

      # Remove all policies where role is "admin" (any user)
      {:ok, updated_enforcer, count} =
        Management.remove_filtered_grouping_policy(enforcer, 0, ["", "admin"])

      assert count == 2
      refute Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
      refute Management.has_grouping_policy(updated_enforcer, ["charlie", "admin"])
    end
  end

  describe "remove_filtered_named_grouping_policy/4" do
    test "removes named grouping policies matching filter", %{enforcer: enforcer} do
      {:ok, enforcer} =
        Management.add_named_grouping_policies(enforcer, "g", [
          ["bob", "admin"],
          ["bob", "moderator"],
          ["charlie", "admin"]
        ])

      {:ok, updated_enforcer, count} =
        Management.remove_filtered_named_grouping_policy(enforcer, "g", 0, ["bob"])

      assert count == 2
      refute Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])

      refute Management.has_named_grouping_policy(updated_enforcer, "g", [
               "bob",
               "moderator"
             ])

      assert Management.has_named_grouping_policy(updated_enforcer, "g", ["charlie", "admin"])
    end
  end

  describe "update_grouping_policy/3" do
    test "updates a grouping policy successfully", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_grouping_policy(enforcer, ["bob", "admin"])

      {:ok, updated_enforcer} =
        Management.update_grouping_policy(enforcer, ["bob", "admin"], ["bob", "superadmin"])

      refute Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
      assert Management.has_grouping_policy(updated_enforcer, ["bob", "superadmin"])
    end

    test "returns error if old policy doesn't exist", %{enforcer: enforcer} do
      assert {:error, :not_found} =
               Management.update_grouping_policy(
                 enforcer,
                 ["nonexistent", "role"],
                 ["bob", "admin"]
               )
    end
  end

  describe "update_grouping_policies/3" do
    test "updates multiple grouping policies successfully", %{enforcer: enforcer} do
      {:ok, enforcer} =
        Management.add_grouping_policies(enforcer, [
          ["bob", "admin"],
          ["charlie", "moderator"]
        ])

      old_rules = [["bob", "admin"], ["charlie", "moderator"]]
      new_rules = [["bob", "superadmin"], ["charlie", "supermoderator"]]

      {:ok, updated_enforcer} =
        Management.update_grouping_policies(enforcer, old_rules, new_rules)

      refute Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
      refute Management.has_grouping_policy(updated_enforcer, ["charlie", "moderator"])
      assert Management.has_grouping_policy(updated_enforcer, ["bob", "superadmin"])
      assert Management.has_grouping_policy(updated_enforcer, ["charlie", "supermoderator"])
    end

    test "returns error if lengths don't match", %{enforcer: enforcer} do
      assert {:error, "old_rules and new_rules must have same length"} =
               Management.update_grouping_policies(
                 enforcer,
                 [["bob", "admin"]],
                 [["bob", "superadmin"], ["charlie", "moderator"]]
               )
    end
  end

  describe "update_named_grouping_policy/4" do
    test "updates a named grouping policy successfully", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_named_grouping_policy(enforcer, "g", ["bob", "admin"])

      {:ok, updated_enforcer} =
        Management.update_named_grouping_policy(
          enforcer,
          "g",
          ["bob", "admin"],
          ["bob", "superadmin"]
        )

      refute Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])
      assert Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "superadmin"])
    end
  end

  describe "update_named_grouping_policies/4" do
    test "updates multiple named grouping policies successfully", %{enforcer: enforcer} do
      {:ok, enforcer} =
        Management.add_named_grouping_policies(enforcer, "g", [
          ["bob", "admin"],
          ["charlie", "moderator"]
        ])

      old_rules = [["bob", "admin"], ["charlie", "moderator"]]
      new_rules = [["bob", "superadmin"], ["charlie", "supermoderator"]]

      {:ok, updated_enforcer} =
        Management.update_named_grouping_policies(enforcer, "g", old_rules, new_rules)

      refute Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])

      refute Management.has_named_grouping_policy(updated_enforcer, "g", [
               "charlie",
               "moderator"
             ])

      assert Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "superadmin"])

      assert Management.has_named_grouping_policy(updated_enforcer, "g", [
               "charlie",
               "supermoderator"
             ])
    end
  end

  describe "add_function/3" do
    test "adds a custom function to the enforcer", %{enforcer: enforcer} do
      custom_func = fn arg1, arg2 ->
        String.contains?(to_string(arg1), to_string(arg2))
      end

      updated_enforcer = Management.add_function(enforcer, "customMatch", custom_func)

      assert Map.has_key?(updated_enforcer.function_map, "customMatch")
      assert is_function(updated_enforcer.function_map["customMatch"], 2)
    end

    test "function is callable after being added", %{enforcer: enforcer} do
      custom_func = fn arg1, arg2 -> String.starts_with?(arg1, arg2) end

      updated_enforcer = Management.add_function(enforcer, "startsWith", custom_func)

      func = updated_enforcer.function_map["startsWith"]
      assert func.("hello_world", "hello") == true
      assert func.("hello_world", "world") == false
    end

    test "overwrites existing function with same name", %{enforcer: enforcer} do
      func1 = fn _a, _b -> true end
      func2 = fn _a, _b -> false end

      enforcer = Management.add_function(enforcer, "testFunc", func1)
      enforcer = Management.add_function(enforcer, "testFunc", func2)

      # Should have the second function
      assert enforcer.function_map["testFunc"].(1, 2) == false
    end
  end

  describe "add_policies_ex/3" do
    test "adds all valid policies and skips duplicates", %{enforcer: enforcer} do
      # alice, data1, read and bob, data2, write already exist in CSV
      policies = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["charlie", "data3", "read"]
      ]

      {:ok, updated_enforcer, count} = Management.add_policies_ex(enforcer, policies)

      assert count == 1
      assert Management.has_policy(updated_enforcer, ["charlie", "data3", "read"])
    end

    test "returns count of 0 if all policies exist", %{enforcer: enforcer} do
      policies = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ]

      {:ok, updated_enforcer, count} = Management.add_policies_ex(enforcer, policies)

      assert count == 0
      # Enforcer unchanged
      assert updated_enforcer == enforcer
    end
  end

  describe "add_named_policies_ex/4" do
    test "adds valid named policies and skips duplicates", %{enforcer: enforcer} do
      policies = [
        ["alice", "data1", "read"],
        ["charlie", "data3", "read"],
        ["dave", "data4", "write"]
      ]

      {:ok, updated_enforcer, count} = Management.add_named_policies_ex(enforcer, "p", policies)

      assert count == 2
      assert Management.has_named_policy(updated_enforcer, "p", ["charlie", "data3", "read"])
      assert Management.has_named_policy(updated_enforcer, "p", ["dave", "data4", "write"])
    end
  end

  describe "add_grouping_policies_ex/2" do
    test "adds valid grouping policies and skips duplicates", %{enforcer: enforcer} do
      policies = [
        ["alice", "data_group_admin"],
        ["bob", "admin"],
        ["charlie", "moderator"]
      ]

      {:ok, updated_enforcer, count} = Management.add_grouping_policies_ex(enforcer, policies)

      assert count == 2
      assert Management.has_grouping_policy(updated_enforcer, ["bob", "admin"])
      assert Management.has_grouping_policy(updated_enforcer, ["charlie", "moderator"])
    end
  end

  describe "add_named_grouping_policies_ex/3" do
    test "adds valid named grouping policies and skips duplicates", %{enforcer: enforcer} do
      policies = [
        ["alice", "data_group_admin"],
        ["bob", "admin"],
        ["charlie", "moderator"]
      ]

      {:ok, updated_enforcer, count} =
        Management.add_named_grouping_policies_ex(enforcer, "g", policies)

      assert count == 2
      assert Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])

      assert Management.has_named_grouping_policy(updated_enforcer, "g", [
               "charlie",
               "moderator"
             ])
    end
  end

  describe "self_add_policy/4" do
    test "adds policy without watcher notification for p section", %{enforcer: enforcer} do
      {:ok, updated_enforcer} =
        Management.self_add_policy(enforcer, "p", "p", ["charlie", "data3", "read"])

      assert Management.has_named_policy(updated_enforcer, "p", ["charlie", "data3", "read"])
    end

    test "adds grouping policy without watcher notification for g section", %{
      enforcer: enforcer
    } do
      {:ok, updated_enforcer} =
        Management.self_add_policy(enforcer, "g", "g", ["bob", "admin"])

      assert Management.has_named_grouping_policy(updated_enforcer, "g", ["bob", "admin"])
    end

    test "returns error for invalid section", %{enforcer: enforcer} do
      assert {:error, "invalid section type, must be 'p' or 'g'"} =
               Management.self_add_policy(enforcer, "x", "p", ["alice", "data1", "read"])
    end
  end

  describe "self_add_policies_ex/4" do
    test "adds multiple policies without watcher notification", %{enforcer: enforcer} do
      policies = [
        ["charlie", "data3", "read"],
        ["dave", "data4", "write"]
      ]

      {:ok, updated_enforcer, count} =
        Management.self_add_policies_ex(enforcer, "p", "p", policies)

      assert count == 2
      assert Management.has_named_policy(updated_enforcer, "p", ["charlie", "data3", "read"])
      assert Management.has_named_policy(updated_enforcer, "p", ["dave", "data4", "write"])
    end
  end

  describe "self_remove_policy/4" do
    test "removes policy without watcher notification for p section", %{enforcer: enforcer} do
      # alice, data1, read exists in CSV
      {:ok, updated_enforcer} =
        Management.self_remove_policy(enforcer, "p", "p", ["alice", "data1", "read"])

      refute Management.has_named_policy(updated_enforcer, "p", ["alice", "data1", "read"])
    end

    test "removes grouping policy without watcher notification for g section", %{
      enforcer: enforcer
    } do
      # alice, data_group_admin exists in CSV
      {:ok, updated_enforcer} =
        Management.self_remove_policy(enforcer, "g", "g", ["alice", "data_group_admin"])

      refute Management.has_named_grouping_policy(updated_enforcer, "g", [
               "alice",
               "data_group_admin"
             ])
    end
  end

  describe "self_update_policy/5" do
    test "updates policy without watcher notification for p section", %{enforcer: enforcer} do
      {:ok, updated_enforcer} =
        Management.self_update_policy(
          enforcer,
          "p",
          "p",
          ["alice", "data1", "read"],
          ["alice", "data1", "write"]
        )

      refute Management.has_named_policy(updated_enforcer, "p", ["alice", "data1", "read"])
      assert Management.has_named_policy(updated_enforcer, "p", ["alice", "data1", "write"])
    end

    test "updates grouping policy without watcher notification for g section", %{
      enforcer: enforcer
    } do
      {:ok, updated_enforcer} =
        Management.self_update_policy(
          enforcer,
          "g",
          "g",
          ["alice", "data_group_admin"],
          ["alice", "superadmin"]
        )

      refute Management.has_named_grouping_policy(updated_enforcer, "g", [
               "alice",
               "data_group_admin"
             ])

      assert Management.has_named_grouping_policy(updated_enforcer, "g", ["alice", "superadmin"])
    end
  end

  describe "update_filtered_policies/4" do
    test "updates policies matching filter", %{enforcer: enforcer} do
      # Add test policies (bob, data2, write already exists, so add another)
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "read"])

      # Update all policies where subject is "bob" and object is "data2"
      new_policies = [["bob", "data2", "admin"]]

      {:ok, updated_enforcer, old_rules} =
        Management.update_filtered_policies(enforcer, new_policies, 0, ["bob", "data2"])

      # Should have removed 2 old policies (read and write)
      assert length(old_rules) == 2
      refute Management.has_policy(updated_enforcer, ["bob", "data2", "read"])
      refute Management.has_policy(updated_enforcer, ["bob", "data2", "write"])
      assert Management.has_policy(updated_enforcer, ["bob", "data2", "admin"])
    end
  end

  describe "update_filtered_named_policies/5" do
    test "updates named policies matching filter", %{enforcer: enforcer} do
      {:ok, enforcer} =
        Management.add_named_policies(enforcer, "p", [
          ["charlie", "data3", "read"],
          ["charlie", "data3", "write"]
        ])

      new_policies = [["charlie", "data3", "admin"]]

      {:ok, updated_enforcer, old_rules} =
        Management.update_filtered_named_policies(enforcer, "p", new_policies, 0, [
          "charlie",
          "data3"
        ])

      assert length(old_rules) == 2
      refute Management.has_named_policy(updated_enforcer, "p", ["charlie", "data3", "read"])
      refute Management.has_named_policy(updated_enforcer, "p", ["charlie", "data3", "write"])
      assert Management.has_named_policy(updated_enforcer, "p", ["charlie", "data3", "admin"])
    end

    test "supports wildcard filtering with empty strings", %{enforcer: enforcer} do
      {:ok, enforcer} =
        Management.add_named_policies(enforcer, "p", [
          ["user1", "resource1", "read"],
          ["user2", "resource1", "read"]
        ])

      # Update all policies where object is "resource1" and action is "read"
      new_policies = [["admin", "resource1", "admin"]]

      {:ok, updated_enforcer, old_rules} =
        Management.update_filtered_named_policies(enforcer, "p", new_policies, 0, [
          "",
          "resource1",
          "read"
        ])

      assert length(old_rules) == 2
      assert Management.has_named_policy(updated_enforcer, "p", ["admin", "resource1", "admin"])
    end
  end

  describe "get_filtered_named_policy_with_matcher/3" do
    test "filters policies with custom matcher function", %{enforcer: enforcer} do
      # Matcher: only policies where subject is "alice"
      matcher = fn [sub, _obj, _act] -> sub == "alice" end

      {:ok, filtered} =
        Management.get_filtered_named_policy_with_matcher(enforcer, "p", matcher)

      assert length(filtered) == 1
      assert ["alice", "data1", "read"] in filtered
    end

    test "filters policies with complex matcher", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["charlie", "data3", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["dave", "data4", "write"])

      # Matcher: only read actions
      matcher = fn [_sub, _obj, act] -> act == "read" end

      {:ok, filtered} =
        Management.get_filtered_named_policy_with_matcher(enforcer, "p", matcher)

      assert length(filtered) == 2
      assert ["alice", "data1", "read"] in filtered
      assert ["charlie", "data3", "read"] in filtered
    end

    test "returns empty list when no policies match", %{enforcer: enforcer} do
      matcher = fn [sub, _obj, _act] -> sub == "nonexistent" end

      {:ok, filtered} =
        Management.get_filtered_named_policy_with_matcher(enforcer, "p", matcher)

      assert filtered == []
    end

    test "returns error if matcher is not a function", %{enforcer: enforcer} do
      assert {:error, "matcher must be a function with arity 1"} =
               Management.get_filtered_named_policy_with_matcher(enforcer, "p", "not_a_function")
    end

    test "handles matcher errors gracefully", %{enforcer: enforcer} do
      # Matcher that will raise an error
      matcher = fn _rule -> raise "matcher error" end

      result = Management.get_filtered_named_policy_with_matcher(enforcer, "p", matcher)

      assert {:error, error_msg} = result
      assert error_msg =~ "matcher function error"
    end

    test "supports pattern matching in matcher", %{enforcer: enforcer} do
      # bob, data2, write already exists in CSV, add read
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "read"])

      # Matcher: bob with write action
      matcher = fn
        ["bob", _obj, "write"] -> true
        _ -> false
      end

      {:ok, filtered} =
        Management.get_filtered_named_policy_with_matcher(enforcer, "p", matcher)

      assert length(filtered) == 1
      assert ["bob", "data2", "write"] in filtered
    end
  end
end
