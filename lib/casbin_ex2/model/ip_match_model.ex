defmodule CasbinEx2.Model.IpMatchModel do
  @moduledoc """
  IP Match Model for network-based access control.

  This model enables authorization based on IP addresses and network ranges.
  It supports CIDR notation for subnet matching and individual IP addresses.

  ## Example Usage

      iex> model = CasbinEx2.Model.IpMatchModel.new()
      iex> enforcer = CasbinEx2.Enforcer.new(model, adapter)
      iex> CasbinEx2.Enforcer.enforce(enforcer, "192.168.1.100", "data1", "read")
      true

  ## Model Configuration

  - **Request Definition**: sub (IP address), obj (resource), act (action)
  - **Policy Definition**: sub (IP/CIDR), obj (resource), act (action)
  - **Matcher**: Uses ipMatch function to compare client IP with policy IP/CIDR

  ## Policy Examples

      p, 192.168.1.0/24, data1, read
      p, 10.0.0.100, data2, write
      p, 172.16.0.0/16, data3, read
  """

  alias CasbinEx2.Model

  @model_text """
  [request_definition]
  r = sub, obj, act

  [policy_definition]
  p = sub, obj, act

  [policy_effect]
  e = some(where (p.eft == allow))

  [matchers]
  m = ipMatch(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
  """

  @doc """
  Creates a new IP Match model.

  Returns a CasbinEx2.Model struct configured for IP-based access control.
  """
  @spec new() :: {:ok, Model.t()} | {:error, term()}
  def new do
    Model.load_model_from_text(@model_text)
  end

  @doc """
  Creates a new IP Match model with custom matcher.

  Allows customization of the matching logic while maintaining IP-based access control.

  ## Parameters

  - `custom_matcher` - Custom matcher expression that must include ipMatch function

  ## Example

      custom_matcher = "ipMatch(r.sub, p.sub) && r.obj == p.obj && r.act == p.act && r.time >= p.start_time"
      {:ok, model} = CasbinEx2.Model.IpMatchModel.new_with_matcher(custom_matcher)
  """
  @spec new_with_matcher(String.t()) :: {:ok, Model.t()} | {:error, term()}
  def new_with_matcher(custom_matcher) do
    model_text = """
    [request_definition]
    r = sub, obj, act

    [policy_definition]
    p = sub, obj, act

    [policy_effect]
    e = some(where (p.eft == allow))

    [matchers]
    m = #{custom_matcher}
    """

    Model.load_model_from_text(model_text)
  end

  @doc """
  Creates a new IP Match model with domains support.

  Extends the basic IP match model to support multi-tenant scenarios
  where different domains have different IP-based access policies.

  ## Example Policy

      p, alice, domain1, 192.168.1.0/24, data1, read
      p, bob, domain2, 10.0.0.0/16, data2, write
  """
  @spec new_with_domains() :: {:ok, Model.t()} | {:error, term()}
  def new_with_domains do
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
    m = g(r.sub, p.sub, r.dom) && ipMatch(r.sub, p.sub) && r.dom == p.dom && r.obj == p.obj && r.act == p.act
    """

    Model.load_model_from_text(model_text)
  end

  @doc """
  Creates a new IP Match model with time-based constraints.

  Combines IP-based access control with time-based restrictions.
  Useful for implementing time-sensitive network access policies.

  ## Request Definition

  - `sub` - IP address of the requesting client
  - `obj` - Resource being accessed
  - `act` - Action being performed
  - `time` - Current timestamp

  ## Policy Definition

  - `sub` - IP address or CIDR range
  - `obj` - Protected resource
  - `act` - Allowed action
  - `start_time` - Access start time (Unix timestamp)
  - `end_time` - Access end time (Unix timestamp)
  """
  @spec new_with_time() :: {:ok, Model.t()} | {:error, term()}
  def new_with_time do
    model_text = """
    [request_definition]
    r = sub, obj, act, time

    [policy_definition]
    p = sub, obj, act, start_time, end_time

    [policy_effect]
    e = some(where (p.eft == allow))

    [matchers]
    m = ipMatch(r.sub, p.sub) && r.obj == p.obj && r.act == p.act && r.time >= p.start_time && r.time <= p.end_time
    """

    Model.load_model_from_text(model_text)
  end

  @doc """
  Validates if an IP address matches the model's expected format.

  ## Parameters

  - `ip` - IP address string to validate

  ## Returns

  - `{:ok, ip}` - If IP is valid
  - `{:error, reason}` - If IP is invalid

  ## Examples

      iex> CasbinEx2.Model.IpMatchModel.validate_ip("192.168.1.1")
      {:ok, "192.168.1.1"}

      iex> CasbinEx2.Model.IpMatchModel.validate_ip("invalid")
      {:error, "Invalid IP address format"}
  """
  @spec validate_ip(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_ip(ip) when is_binary(ip) do
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, _parsed} ->
        # Additional validation to ensure it's a complete IP address
        if complete_ip?(ip) do
          {:ok, ip}
        else
          {:error, "Invalid IP address format"}
        end

      {:error, _reason} ->
        {:error, "Invalid IP address format"}
    end
  end

  def validate_ip(_), do: {:error, "IP address must be a string"}

  # Helper function to ensure IP address is complete
  defp complete_ip?(ip) do
    cond do
      # IPv6 address (contains colons)
      String.contains?(ip, ":") ->
        complete_ipv6?(ip)

      # IPv4 address (contains dots)
      String.contains?(ip, ".") ->
        complete_ipv4?(ip)

      # Not a valid IP format
      true ->
        false
    end
  end

  # Helper function to validate IPv4 address has all 4 octets
  defp complete_ipv4?(ip) do
    parts = String.split(ip, ".")

    length(parts) == 4 and
      Enum.all?(parts, fn part ->
        case Integer.parse(part) do
          {num, ""} when num >= 0 and num <= 255 -> true
          _ -> false
        end
      end)
  end

  # Helper function to validate IPv6 address
  defp complete_ipv6?(ip) do
    # Basic IPv6 validation - let :inet.parse_address/1 do the heavy lifting
    # We just need to ensure it's not an incomplete address like "192:168"
    parts = String.split(ip, ":")
    # IPv6 should have at least 2 parts separated by colons
    length(parts) >= 2
  end

  @doc """
  Validates if a CIDR range matches the model's expected format.

  ## Parameters

  - `cidr` - CIDR notation string to validate (e.g., "192.168.1.0/24")

  ## Examples

      iex> CasbinEx2.Model.IpMatchModel.validate_cidr("192.168.1.0/24")
      {:ok, "192.168.1.0/24"}

      iex> CasbinEx2.Model.IpMatchModel.validate_cidr("192.168.1.0/33")
      {:error, "Invalid CIDR notation"}
  """
  @spec validate_cidr(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_cidr(cidr) when is_binary(cidr) do
    case String.split(cidr, "/") do
      [ip, prefix] ->
        with {:ok, _} <- validate_ip(ip),
             {prefix_int, ""} <- Integer.parse(prefix),
             true <- prefix_int >= 0 and prefix_int <= 32 do
          {:ok, cidr}
        else
          _ -> {:error, "Invalid CIDR notation"}
        end

      _ ->
        {:error, "Invalid CIDR notation"}
    end
  end

  def validate_cidr(_), do: {:error, "CIDR notation must be a string"}

  @doc """
  Validates if an IP or CIDR string is suitable for use in policies.

  ## Parameters

  - `ip_or_cidr` - IP address or CIDR notation string

  ## Examples

      iex> CasbinEx2.Model.IpMatchModel.validate_ip_or_cidr("192.168.1.1")
      {:ok, "192.168.1.1"}

      iex> CasbinEx2.Model.IpMatchModel.validate_ip_or_cidr("192.168.1.0/24")
      {:ok, "192.168.1.0/24"}
  """
  @spec validate_ip_or_cidr(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_ip_or_cidr(ip_or_cidr) when is_binary(ip_or_cidr) do
    if String.contains?(ip_or_cidr, "/") do
      validate_cidr(ip_or_cidr)
    else
      validate_ip(ip_or_cidr)
    end
  end

  def validate_ip_or_cidr(_), do: {:error, "Input must be a string"}

  @doc """
  Creates example policies for testing IP match functionality.

  Returns a list of policy tuples that can be used with adapters.
  """
  @spec example_policies() :: [list(String.t())]
  def example_policies do
    [
      ["192.168.1.0/24", "data1", "read"],
      ["192.168.1.0/24", "data1", "write"],
      ["10.0.0.100", "data2", "read"],
      ["172.16.0.0/16", "data3", "read"],
      ["172.16.0.0/16", "data3", "write"],
      ["0.0.0.0/0", "public_data", "read"]
    ]
  end

  @doc """
  Creates example requests for testing IP match functionality.

  Returns a list of request tuples that can be used for testing.
  """
  @spec example_requests() :: [list(String.t())]
  def example_requests do
    [
      ["192.168.1.100", "data1", "read"],
      ["192.168.1.50", "data1", "write"],
      ["10.0.0.100", "data2", "read"],
      ["10.0.0.200", "data2", "read"],
      ["172.16.5.10", "data3", "read"],
      ["8.8.8.8", "public_data", "read"],
      ["192.168.2.100", "data1", "read"]
    ]
  end
end
