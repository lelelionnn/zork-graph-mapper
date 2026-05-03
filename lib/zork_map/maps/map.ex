defmodule ZorkMap.Maps.Map do
  use Ecto.Schema
  import Ecto.Changeset

  schema "maps" do
    field :name, :string
    field :description, :string
    has_many :rooms, ZorkMap.Maps.Room, on_delete: :delete_all
    has_many :connections, ZorkMap.Maps.Connection, on_delete: :delete_all
    timestamps()
  end

  def changeset(map, attrs) do
    map
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 200)
  end
end
