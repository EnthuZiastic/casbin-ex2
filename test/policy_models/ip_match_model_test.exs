defmodule CasbinEx2.Model.IpMatchModelTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.{Adapter.MemoryAdapter, Enforcer}
  alias CasbinEx2.Model.IpMatchModel

  describe "new/0" do
    test "creates a valid IP match model" do
      assert {:ok, model} = IpMatchModel.new()
      assert model.request_definition["r"] == "sub, obj, act"
      assert model.policy_definition["p"] == "sub, obj, act"

      assert model.matchers["m"] ==
               "ipMatch(r.sub, p.sub) && r.obj == p.obj && r.act == p.act"
    end
  end

  describe "new_with_matcher/1" do
    test "creates model with custom matcher" do
      custom_matcher =
        "ipMatch(r.sub, p.sub) && r.obj == p.obj && r.act == p.act && r.time >= p.start_time"

      assert {:ok, model} = IpMatchModel.new_with_matcher(custom_matcher)
      assert model.matchers["m"] == custom_matcher
    end

    test "handles invalid matcher gracefully" do
      assert {:ok, _model} = IpMatchModel.new_with_matcher("invalid matcher")
    end
  end

  describe "new_with_domains/0" do
    test "creates model with domain support" do
      assert {:ok, model} = IpMatchModel.new_with_domains()
      assert model.request_definition["r"] == "sub, dom, obj, act"
      assert model.policy_definition["p"] == "sub, dom, obj, act"
      assert String.contains?(model.matchers["m"], "ipMatch(r.sub, p.sub)")
      assert String.contains?(model.matchers["m"], "r.dom == p.dom")
    end
  end

  describe "new_with_time/0" do
    test "creates model with time-based constraints" do
      assert {:ok, model} = IpMatchModel.new_with_time()
      assert model.request_definition["r"] == "sub, obj, act, time"
      assert model.policy_definition["p"] == "sub, obj, act, start_time, end_time"
      assert String.contains?(model.matchers["m"], "r.time >= p.start_time")
      assert String.contains?(model.matchers["m"], "r.time <= p.end_time")
    end
  end

  describe "validate_ip/1" do
    test "validates valid IPv4 addresses" do
      assert {:ok, "192.168.1.1"} = IpMatchModel.validate_ip("192.168.1.1")
      assert {:ok, "10.0.0.1"} = IpMatchModel.validate_ip("10.0.0.1")
      assert {:ok, "172.16.0.1"} = IpMatchModel.validate_ip("172.16.0.1")
      assert {:ok, "127.0.0.1"} = IpMatchModel.validate_ip("127.0.0.1")
    end

    test "validates valid IPv6 addresses" do
      assert {:ok, "::1"} = IpMatchModel.validate_ip("::1")
      assert {:ok, "2001:db8::1"} = IpMatchModel.validate_ip("2001:db8::1")
    end

    test "rejects invalid IP addresses" do
      assert {:error, "Invalid IP address format"} = IpMatchModel.validate_ip("256.256.256.256")
      assert {:error, "Invalid IP address format"} = IpMatchModel.validate_ip("not.an.ip.address")
      assert {:error, "Invalid IP address format"} = IpMatchModel.validate_ip("192.168.1")
      assert {:error, "IP address must be a string"} = IpMatchModel.validate_ip(123)
    end
  end

  describe "validate_cidr/1" do
    test "validates valid CIDR notation" do
      assert {:ok, "192.168.1.0/24"} = IpMatchModel.validate_cidr("192.168.1.0/24")
      assert {:ok, "10.0.0.0/16"} = IpMatchModel.validate_cidr("10.0.0.0/16")
      assert {:ok, "172.16.0.0/12"} = IpMatchModel.validate_cidr("172.16.0.0/12")
      assert {:ok, "0.0.0.0/0"} = IpMatchModel.validate_cidr("0.0.0.0/0")
    end

    test "rejects invalid CIDR notation" do
      assert {:error, "Invalid CIDR notation"} = IpMatchModel.validate_cidr("192.168.1.0/33")
      assert {:error, "Invalid CIDR notation"} = IpMatchModel.validate_cidr("192.168.1.0/-1")
      assert {:error, "Invalid CIDR notation"} = IpMatchModel.validate_cidr("192.168.1.0/abc")
      assert {:error, "Invalid CIDR notation"} = IpMatchModel.validate_cidr("192.168.1.0")
      assert {:error, "CIDR notation must be a string"} = IpMatchModel.validate_cidr(123)
    end
  end

  describe "validate_ip_or_cidr/1" do
    test "validates both IP addresses and CIDR notation" do
      assert {:ok, "192.168.1.1"} = IpMatchModel.validate_ip_or_cidr("192.168.1.1")
      assert {:ok, "192.168.1.0/24"} = IpMatchModel.validate_ip_or_cidr("192.168.1.0/24")
    end

    test "rejects invalid formats" do
      assert {:error, _} = IpMatchModel.validate_ip_or_cidr("invalid")
      assert {:error, "Input must be a string"} = IpMatchModel.validate_ip_or_cidr(123)
    end
  end

  describe "example_policies/0 and example_requests/0" do
    test "provides valid example data" do
      policies = IpMatchModel.example_policies()
      requests = IpMatchModel.example_requests()

      assert is_list(policies)
      assert is_list(requests)
      assert length(policies) > 0
      assert length(requests) > 0

      # Validate policy structure
      Enum.each(policies, fn policy ->
        assert is_list(policy)
        assert length(policy) == 3
        [ip_or_cidr, _resource, _action] = policy
        assert {:ok, _} = IpMatchModel.validate_ip_or_cidr(ip_or_cidr)
      end)

      # Validate request structure
      Enum.each(requests, fn request ->
        assert is_list(request)
        assert length(request) == 3
        [ip, _resource, _action] = request
        assert {:ok, _} = IpMatchModel.validate_ip(ip)
      end)
    end
  end

  describe "integration with enforcer" do
    setup do
      {:ok, model} = IpMatchModel.new()
      adapter = MemoryAdapter.new()
      enforcer = Enforcer.new(model, adapter)

      # Add example policies
      policies = %{
        "p" => [
          ["192.168.1.0/24", "data1", "read"],
          ["192.168.1.0/24", "data1", "write"],
          ["10.0.0.100", "data2", "read"],
          ["172.16.0.0/16", "data3", "read"],
          ["0.0.0.0/0", "public_data", "read"]
        ]
      }

      :ok = MemoryAdapter.save_policy(adapter, policies, %{})

      {:ok, %{enforcer: enforcer}}
    end

    test "enforces IP-based policies correctly", %{enforcer: enforcer} do
      # IP within subnet should have access
      assert Enforcer.enforce(enforcer, ["192.168.1.100", "data1", "read"])
      assert Enforcer.enforce(enforcer, ["192.168.1.50", "data1", "write"])

      # Exact IP match
      assert Enforcer.enforce(enforcer, ["10.0.0.100", "data2", "read"])

      # IP within larger subnet
      assert Enforcer.enforce(enforcer, ["172.16.5.10", "data3", "read"])

      # Global access
      assert Enforcer.enforce(enforcer, ["8.8.8.8", "public_data", "read"])

      # IP outside subnet should be denied
      refute Enforcer.enforce(enforcer, ["192.168.2.100", "data1", "read"])
      refute Enforcer.enforce(enforcer, ["10.0.0.200", "data2", "read"])
      refute Enforcer.enforce(enforcer, ["192.168.1.100", "data3", "read"])
    end

    test "handles different IP formats", %{enforcer: enforcer} do
      # IPv4 addresses
      assert Enforcer.enforce(enforcer, ["192.168.1.1", "data1", "read"])

      # Edge cases
      assert Enforcer.enforce(enforcer, ["192.168.1.255", "data1", "read"])
      refute Enforcer.enforce(enforcer, ["192.168.0.255", "data1", "read"])
    end

    test "rejects invalid IP addresses", %{enforcer: enforcer} do
      # Invalid IP should not crash but return false
      refute Enforcer.enforce(enforcer, ["invalid.ip", "data1", "read"])
      refute Enforcer.enforce(enforcer, ["256.256.256.256", "data1", "read"])
    end
  end

  describe "IP match model with domains" do
    setup do
      {:ok, model} = IpMatchModel.new_with_domains()
      adapter = MemoryAdapter.new()
      enforcer = Enforcer.new(model, adapter)

      policies = %{
        "p" => [
          ["alice", "domain1", "data1", "read"],
          ["bob", "domain2", "data2", "write"]
        ]
      }

      grouping_policies = %{
        "g" => [
          ["192.168.1.100", "alice", "domain1"],
          ["10.0.0.100", "bob", "domain2"]
        ]
      }

      :ok = MemoryAdapter.save_policy(adapter, policies, grouping_policies)

      {:ok, %{enforcer: enforcer}}
    end

    test "enforces domain-based IP policies", %{enforcer: enforcer} do
      # IP with correct domain should have access
      assert Enforcer.enforce(enforcer, ["192.168.1.100", "domain1", "data1", "read"])
      assert Enforcer.enforce(enforcer, ["10.0.0.100", "domain2", "data2", "write"])

      # IP with wrong domain should be denied
      refute Enforcer.enforce(enforcer, ["192.168.1.100", "domain2", "data2", "write"])
      refute Enforcer.enforce(enforcer, ["10.0.0.100", "domain1", "data1", "read"])
    end
  end

  describe "IP match model with time constraints" do
    setup do
      {:ok, model} = IpMatchModel.new_with_time()
      adapter = MemoryAdapter.new()
      enforcer = Enforcer.new(model, adapter)

      current_time = DateTime.utc_now() |> DateTime.to_unix()
      # 1 hour ago
      past_time = current_time - 3600
      # 1 hour from now
      future_time = current_time + 3600

      policies = %{
        "p" => [
          ["192.168.1.0/24", "data1", "read", to_string(past_time), to_string(future_time)],
          ["10.0.0.100", "data2", "read", to_string(future_time), to_string(future_time + 3600)]
        ]
      }

      :ok = MemoryAdapter.save_policy(adapter, policies, %{})

      {:ok, %{enforcer: enforcer, current_time: current_time, future_time: future_time}}
    end

    test "enforces time-based IP policies", %{
      enforcer: enforcer,
      current_time: current_time,
      future_time: future_time
    } do
      # Current time within allowed window
      assert Enforcer.enforce(enforcer, [
               "192.168.1.100",
               "data1",
               "read",
               to_string(current_time)
             ])

      # Future time outside allowed window
      refute Enforcer.enforce(enforcer, ["10.0.0.100", "data2", "read", to_string(current_time)])

      # Future time within allowed window
      assert Enforcer.enforce(enforcer, ["10.0.0.100", "data2", "read", to_string(future_time)])
    end
  end
end
