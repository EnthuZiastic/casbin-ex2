defmodule CasbinEx2.Adapter.EctoAdapter.CasbinRule do
  @moduledoc """
  Ecto schema for storing Casbin rules in the database.

  This schema follows the standard Casbin table structure with:
  - ptype: policy type (p, p2, g, g2, etc.)
  - v0-v5: policy rule values
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "casbin_rules" do
    field(:ptype, :string)
    field(:v0, :string)
    field(:v1, :string)
    field(:v2, :string)
    field(:v3, :string)
    field(:v4, :string)
    field(:v5, :string)

    timestamps()
  end

  @doc """
  Creates a changeset for a casbin rule.
  """
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:ptype, :v0, :v1, :v2, :v3, :v4, :v5])
    |> validate_required([:ptype])
    |> validate_length(:ptype, max: 100)
    |> validate_length(:v0, max: 100)
    |> validate_length(:v1, max: 100)
    |> validate_length(:v2, max: 100)
    |> validate_length(:v3, max: 100)
    |> validate_length(:v4, max: 100)
    |> validate_length(:v5, max: 100)
  end

  @doc """
  Migration function to create the casbin_rules table.
  This can be used in Ecto migrations.
  """
  def create_table do
    """
    create table(:casbin_rules, primary_key: false) do
      add(:id, :serial, primary_key: true)
      add(:ptype, :string, size: 100, null: false)
      add(:v0, :string, size: 100)
      add(:v1, :string, size: 100)
      add(:v2, :string, size: 100)
      add(:v3, :string, size: 100)
      add(:v4, :string, size: 100)
      add(:v5, :string, size: 100)

      timestamps()
    end

    create(index(:casbin_rules, [:ptype]))
    create(index(:casbin_rules, [:ptype, :v0]))
    create(index(:casbin_rules, [:ptype, :v0, :v1]))
    """
  end
end