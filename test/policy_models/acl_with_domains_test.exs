defmodule CasbinEx2.Model.AclWithDomainsTest do
  use ExUnit.Case
  doctest CasbinEx2.Model.AclWithDomains

  alias CasbinEx2.Model.AclWithDomains

  setup do
    model = AclWithDomains.new()
    {:ok, model: model}
  end

  describe "new/0" do
    test "creates a new ACL with Domains model with default values" do
      model = AclWithDomains.new()

      assert model.domains == %{}
      assert model.domain_hierarchy == %{}
      assert model.cross_domain_policies == []
      assert model.domain_metadata == %{}
      assert model.inheritance_enabled == true
    end
  end

  describe "add_domain/4" do
    test "adds a domain without parent", %{model: model} do
      {:ok, updated_model} = AclWithDomains.add_domain(model, "tech", nil, %{region: "us-west"})

      domain_info = AclWithDomains.get_domain(updated_model, "tech")
      assert domain_info.name == "tech"
      assert domain_info.parent == nil
      assert domain_info.children == []
      assert domain_info.metadata == %{region: "us-west"}
    end

    test "adds a domain with parent", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})

      {:ok, updated_model} =
        AclWithDomains.add_domain(model, "engineering", "tech", %{team: "backend"})

      # Check child domain
      engineering_info = AclWithDomains.get_domain(updated_model, "engineering")
      assert engineering_info.name == "engineering"
      assert engineering_info.parent == "tech"
      assert engineering_info.metadata == %{team: "backend"}

      # Check parent domain
      tech_info = AclWithDomains.get_domain(updated_model, "tech")
      assert "engineering" in tech_info.children
    end

    test "returns error when domain already exists", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:error, :domain_already_exists} = AclWithDomains.add_domain(model, "tech", nil, %{})
    end

    test "returns error when parent domain doesn't exist", %{model: model} do
      {:error, :parent_domain_not_found} =
        AclWithDomains.add_domain(model, "engineering", "nonexistent", %{})
    end
  end

  describe "remove_domain/2" do
    test "removes a domain without children", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, updated_model} = AclWithDomains.remove_domain(model, "tech")

      assert AclWithDomains.get_domain(updated_model, "tech") == nil
    end

    test "removes a child domain and updates parent", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, model} = AclWithDomains.add_domain(model, "engineering", "tech", %{})
      {:ok, updated_model} = AclWithDomains.remove_domain(model, "engineering")

      # Check child domain is removed
      assert AclWithDomains.get_domain(updated_model, "engineering") == nil

      # Check parent domain's children list is updated
      tech_info = AclWithDomains.get_domain(updated_model, "tech")
      refute "engineering" in tech_info.children
    end

    test "returns error when domain doesn't exist", %{model: model} do
      {:error, :domain_not_found} = AclWithDomains.remove_domain(model, "nonexistent")
    end

    test "returns error when domain has children", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, model} = AclWithDomains.add_domain(model, "engineering", "tech", %{})

      {:error, :domain_has_children} = AclWithDomains.remove_domain(model, "tech")
    end
  end

  describe "get_domain/2" do
    test "returns domain information", %{model: model} do
      {:ok, updated_model} = AclWithDomains.add_domain(model, "tech", nil, %{region: "us-west"})

      domain_info = AclWithDomains.get_domain(updated_model, "tech")
      assert domain_info.name == "tech"
      assert domain_info.metadata == %{region: "us-west"}
    end

    test "returns nil for non-existent domain", %{model: model} do
      assert AclWithDomains.get_domain(model, "nonexistent") == nil
    end
  end

  describe "get_all_domains/1" do
    test "returns all domain names", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "marketing", nil, %{})

      domains = AclWithDomains.get_all_domains(updated_model)
      assert "tech" in domains
      assert "marketing" in domains
    end

    test "returns empty list when no domains", %{model: model} do
      domains = AclWithDomains.get_all_domains(model)
      assert domains == []
    end
  end

  describe "get_child_domains/2" do
    test "returns child domains", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, model} = AclWithDomains.add_domain(model, "engineering", "tech", %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "qa", "tech", %{})

      children = AclWithDomains.get_child_domains(updated_model, "tech")
      assert "engineering" in children
      assert "qa" in children
    end

    test "returns empty list for domain without children", %{model: model} do
      {:ok, updated_model} = AclWithDomains.add_domain(model, "tech", nil, %{})

      children = AclWithDomains.get_child_domains(updated_model, "tech")
      assert children == []
    end

    test "returns empty list for non-existent domain", %{model: model} do
      children = AclWithDomains.get_child_domains(model, "nonexistent")
      assert children == []
    end
  end

  describe "get_parent_domain/2" do
    test "returns parent domain", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "engineering", "tech", %{})

      parent = AclWithDomains.get_parent_domain(updated_model, "engineering")
      assert parent == "tech"
    end

    test "returns nil for root domain", %{model: model} do
      {:ok, updated_model} = AclWithDomains.add_domain(model, "tech", nil, %{})

      parent = AclWithDomains.get_parent_domain(updated_model, "tech")
      assert parent == nil
    end

    test "returns nil for non-existent domain", %{model: model} do
      parent = AclWithDomains.get_parent_domain(model, "nonexistent")
      assert parent == nil
    end
  end

  describe "get_ancestor_domains/2" do
    test "returns all ancestor domains including self", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "company", nil, %{})
      {:ok, model} = AclWithDomains.add_domain(model, "tech", "company", %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "engineering", "tech", %{})

      ancestors = AclWithDomains.get_ancestor_domains(updated_model, "engineering")
      assert "engineering" in ancestors
      assert "tech" in ancestors
      assert "company" in ancestors
    end

    test "returns only self for root domain", %{model: model} do
      {:ok, updated_model} = AclWithDomains.add_domain(model, "tech", nil, %{})

      ancestors = AclWithDomains.get_ancestor_domains(updated_model, "tech")
      assert ancestors == ["tech"]
    end
  end

  describe "get_descendant_domains/2" do
    test "returns all descendant domains including self", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, model} = AclWithDomains.add_domain(model, "engineering", "tech", %{})
      {:ok, model} = AclWithDomains.add_domain(model, "qa", "tech", %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "backend", "engineering", %{})

      descendants = AclWithDomains.get_descendant_domains(updated_model, "tech")
      assert "tech" in descendants
      assert "engineering" in descendants
      assert "qa" in descendants
      assert "backend" in descendants
    end

    test "returns only self for leaf domain", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "engineering", "tech", %{})

      descendants = AclWithDomains.get_descendant_domains(updated_model, "engineering")
      assert descendants == ["engineering"]
    end
  end

  describe "add_cross_domain_policy/2" do
    test "adds a cross-domain policy", %{model: model} do
      policy = ["alice", "domain1", "data", "domain2", "read"]
      {:ok, updated_model} = AclWithDomains.add_cross_domain_policy(model, policy)

      policies = AclWithDomains.get_cross_domain_policies(updated_model)
      assert policy in policies
    end

    test "returns error when policy already exists", %{model: model} do
      policy = ["alice", "domain1", "data", "domain2", "read"]
      {:ok, model} = AclWithDomains.add_cross_domain_policy(model, policy)

      {:error, :policy_already_exists} = AclWithDomains.add_cross_domain_policy(model, policy)
    end
  end

  describe "remove_cross_domain_policy/2" do
    test "removes a cross-domain policy", %{model: model} do
      policy = ["alice", "domain1", "data", "domain2", "read"]
      {:ok, model} = AclWithDomains.add_cross_domain_policy(model, policy)
      {:ok, updated_model} = AclWithDomains.remove_cross_domain_policy(model, policy)

      policies = AclWithDomains.get_cross_domain_policies(updated_model)
      refute policy in policies
    end

    test "returns error when policy doesn't exist", %{model: model} do
      policy = ["alice", "domain1", "data", "domain2", "read"]
      {:error, :policy_not_found} = AclWithDomains.remove_cross_domain_policy(model, policy)
    end
  end

  describe "set_domain_metadata/3" do
    test "sets metadata for existing domain", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      metadata = %{region: "us-west", team_size: 50}
      {:ok, updated_model} = AclWithDomains.set_domain_metadata(model, "tech", metadata)

      retrieved_metadata = AclWithDomains.get_domain_metadata(updated_model, "tech")
      assert retrieved_metadata == metadata

      # Check domain info is also updated
      domain_info = AclWithDomains.get_domain(updated_model, "tech")
      assert domain_info.metadata == metadata
    end

    test "returns error for non-existent domain", %{model: model} do
      metadata = %{region: "us-west"}

      {:error, :domain_not_found} =
        AclWithDomains.set_domain_metadata(model, "nonexistent", metadata)
    end
  end

  describe "get_domain_metadata/2" do
    test "returns metadata for domain", %{model: model} do
      metadata = %{region: "us-west", team_size: 50}
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, metadata)

      retrieved_metadata = AclWithDomains.get_domain_metadata(model, "tech")
      assert retrieved_metadata == metadata
    end

    test "returns empty map for domain without metadata", %{model: model} do
      {:ok, updated_model} = AclWithDomains.add_domain(model, "tech", nil, %{})

      metadata = AclWithDomains.get_domain_metadata(updated_model, "tech")
      assert metadata == %{}
    end

    test "returns empty map for non-existent domain", %{model: model} do
      metadata = AclWithDomains.get_domain_metadata(model, "nonexistent")
      assert metadata == %{}
    end
  end

  describe "set_inheritance_enabled/2" do
    test "enables and disables inheritance", %{model: model} do
      assert AclWithDomains.inheritance_enabled?(model) == true

      disabled_model = AclWithDomains.set_inheritance_enabled(model, false)
      assert AclWithDomains.inheritance_enabled?(disabled_model) == false

      enabled_model = AclWithDomains.set_inheritance_enabled(disabled_model, true)
      assert AclWithDomains.inheritance_enabled?(enabled_model) == true
    end
  end

  describe "find_domains_by_metadata/2" do
    test "finds domains by metadata criteria", %{model: model} do
      {:ok, model} =
        AclWithDomains.add_domain(model, "tech", nil, %{region: "us-west", type: "engineering"})

      {:ok, model} =
        AclWithDomains.add_domain(model, "marketing", nil, %{region: "us-west", type: "business"})

      {:ok, updated_model} =
        AclWithDomains.add_domain(model, "sales", nil, %{region: "us-east", type: "business"})

      # Find by single criterion
      west_domains = AclWithDomains.find_domains_by_metadata(updated_model, %{region: "us-west"})
      assert "tech" in west_domains
      assert "marketing" in west_domains
      refute "sales" in west_domains

      # Find by multiple criteria
      west_business_domains =
        AclWithDomains.find_domains_by_metadata(updated_model, %{
          region: "us-west",
          type: "business"
        })

      assert "marketing" in west_business_domains
      refute "tech" in west_business_domains
      refute "sales" in west_business_domains
    end

    test "returns empty list when no matches", %{model: model} do
      {:ok, updated_model} = AclWithDomains.add_domain(model, "tech", nil, %{region: "us-west"})

      domains = AclWithDomains.find_domains_by_metadata(updated_model, %{region: "us-east"})
      assert domains == []
    end
  end

  describe "get_domain_tree/1" do
    test "returns domain hierarchy as tree structure", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "company", nil, %{level: 0})
      {:ok, model} = AclWithDomains.add_domain(model, "tech", "company", %{level: 1})
      {:ok, model} = AclWithDomains.add_domain(model, "marketing", "company", %{level: 1})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "engineering", "tech", %{level: 2})

      tree = AclWithDomains.get_domain_tree(updated_model)

      # Check root structure
      assert Map.has_key?(tree, "company")
      company_node = tree["company"]

      # Check company has tech and marketing as children
      assert Map.has_key?(company_node.children, "tech")
      assert Map.has_key?(company_node.children, "marketing")

      # Check tech has engineering as child
      tech_node = company_node.children["tech"]
      assert Map.has_key?(tech_node.children, "engineering")

      # Check leaf node
      engineering_node = tech_node.children["engineering"]
      assert engineering_node.children == %{}
    end

    test "returns empty map when no domains", %{model: model} do
      tree = AclWithDomains.get_domain_tree(model)
      assert tree == %{}
    end

    test "handles multiple root domains", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "company1", nil, %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "company2", nil, %{})

      tree = AclWithDomains.get_domain_tree(updated_model)

      assert Map.has_key?(tree, "company1")
      assert Map.has_key?(tree, "company2")
    end
  end

  describe "complex scenarios" do
    test "handles deep domain hierarchy", %{model: model} do
      # Build: root -> level1 -> level2 -> level3
      {:ok, model} = AclWithDomains.add_domain(model, "root", nil, %{})
      {:ok, model} = AclWithDomains.add_domain(model, "level1", "root", %{})
      {:ok, model} = AclWithDomains.add_domain(model, "level2", "level1", %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "level3", "level2", %{})

      # Test ancestor relationships
      ancestors = AclWithDomains.get_ancestor_domains(updated_model, "level3")
      # includes self
      assert length(ancestors) == 4
      assert "level3" in ancestors
      assert "level2" in ancestors
      assert "level1" in ancestors
      assert "root" in ancestors

      # Test descendant relationships
      descendants = AclWithDomains.get_descendant_domains(updated_model, "root")
      # includes self
      assert length(descendants) == 4
      assert "root" in descendants
      assert "level1" in descendants
      assert "level2" in descendants
      assert "level3" in descendants
    end

    test "handles multiple child domains", %{model: model} do
      {:ok, model} = AclWithDomains.add_domain(model, "tech", nil, %{})
      {:ok, model} = AclWithDomains.add_domain(model, "engineering", "tech", %{})
      {:ok, model} = AclWithDomains.add_domain(model, "qa", "tech", %{})
      {:ok, model} = AclWithDomains.add_domain(model, "devops", "tech", %{})
      {:ok, updated_model} = AclWithDomains.add_domain(model, "backend", "engineering", %{})

      children = AclWithDomains.get_child_domains(updated_model, "tech")
      assert length(children) == 3
      assert "engineering" in children
      assert "qa" in children
      assert "devops" in children

      descendants = AclWithDomains.get_descendant_domains(updated_model, "tech")
      # includes self
      assert length(descendants) == 5
      assert "backend" in descendants
    end

    test "preserves metadata through operations", %{model: model} do
      metadata = %{region: "us-west", team: "backend", active: true}
      {:ok, model} = AclWithDomains.add_domain(model, "engineering", nil, metadata)

      # Add child domain
      {:ok, updated_model} = AclWithDomains.add_domain(model, "backend", "engineering", %{})

      # Verify parent metadata is preserved
      retrieved_metadata = AclWithDomains.get_domain_metadata(updated_model, "engineering")
      assert retrieved_metadata == metadata

      # Verify in domain info as well
      domain_info = AclWithDomains.get_domain(updated_model, "engineering")
      assert domain_info.metadata == metadata
    end
  end
end
