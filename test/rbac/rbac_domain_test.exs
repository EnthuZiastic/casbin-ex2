defmodule CasbinEx2.RBACDomainTest do
  @moduledoc """
  Tests for RBAC domain management functions.
  """
  use ExUnit.Case

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.RBAC

  @moduletag :unit

  describe "Domain Management" do
    setup do
      model_content = """
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

      model_path = "/tmp/test_domain_model.conf"
      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      # Add domain-specific roles and policies
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "user", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "bob", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "charlie", "user", "domain2")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "dave", "admin", "domain2")

      on_exit(fn -> File.rm(model_path) end)

      {:ok, enforcer: enforcer}
    end

    test "delete_roles_for_user_in_domain/3 removes all roles for user in domain", %{
      enforcer: enforcer
    } do
      # Verify alice has roles in domain1
      roles = RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain1")
      assert "admin" in roles
      assert "user" in roles

      # Delete all of alice's roles in domain1
      {:ok, updated_enforcer} = RBAC.delete_roles_for_user_in_domain(enforcer, "alice", "domain1")

      # Verify alice has no roles in domain1
      roles_after = RBAC.get_roles_for_user_in_domain(updated_enforcer, "alice", "domain1")

      assert roles_after == []

      # Verify bob's roles in domain1 are unaffected
      bob_roles = RBAC.get_roles_for_user_in_domain(updated_enforcer, "bob", "domain1")
      assert "admin" in bob_roles
    end

    test "delete_all_users_by_domain/2 removes all users and roles in domain", %{
      enforcer: enforcer
    } do
      # Verify domain1 has users
      alice_roles = RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain1")
      bob_roles = RBAC.get_roles_for_user_in_domain(enforcer, "bob", "domain1")
      assert length(alice_roles) > 0
      assert length(bob_roles) > 0

      # Delete all users in domain1
      {:ok, updated_enforcer} = RBAC.delete_all_users_by_domain(enforcer, "domain1")

      # Verify domain1 users are removed
      alice_roles_after = RBAC.get_roles_for_user_in_domain(updated_enforcer, "alice", "domain1")

      bob_roles_after = RBAC.get_roles_for_user_in_domain(updated_enforcer, "bob", "domain1")

      assert alice_roles_after == []
      assert bob_roles_after == []

      # Verify domain2 users are unaffected
      charlie_roles = RBAC.get_roles_for_user_in_domain(updated_enforcer, "charlie", "domain2")

      dave_roles = RBAC.get_roles_for_user_in_domain(updated_enforcer, "dave", "domain2")
      assert "user" in charlie_roles
      assert "admin" in dave_roles
    end

    test "delete_domains/2 batch deletes multiple domains", %{enforcer: enforcer} do
      # Add a third domain
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "eve", "user", "domain3")

      # Verify all domains have users
      domains = ["domain1", "domain2"]

      # Delete multiple domains
      {:ok, updated_enforcer} = RBAC.delete_domains(enforcer, domains)

      # Verify domain1 and domain2 are cleared
      alice_roles = RBAC.get_roles_for_user_in_domain(updated_enforcer, "alice", "domain1")

      charlie_roles = RBAC.get_roles_for_user_in_domain(updated_enforcer, "charlie", "domain2")

      assert alice_roles == []
      assert charlie_roles == []

      # Verify domain3 is unaffected
      eve_roles = RBAC.get_roles_for_user_in_domain(updated_enforcer, "eve", "domain3")
      assert "user" in eve_roles
    end

    test "get_all_domains/1 returns list of unique domains", %{enforcer: enforcer} do
      domains = RBAC.get_all_domains(enforcer)

      # Should return sorted unique domains
      assert "domain1" in domains
      assert "domain2" in domains
      assert length(domains) == 2
      assert domains == Enum.sort(domains)
    end

    test "get_all_domains/1 returns empty list when no domains exist" do
      model_content = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [role_definition]
      g = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      model_path = "/tmp/test_no_domain_model.conf"
      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      # No domain policies added
      domains = RBAC.get_all_domains(enforcer)
      assert domains == []

      File.rm(model_path)
    end
  end
end
