defmodule ZorkMap.Maps.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :name, :string, default: "New Room"
    field :notes, :string
    field :items, {:array, :string}, default: []
    field :x, :float
    field :y, :float
    belongs_to :map, ZorkMap.Maps.Map
    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:map_id, :name, :notes, :items, :x, :y])
    |> validate_required([:map_id, :name])
    |> validate_length(:name, min: 1, max: 200)
  end
end
