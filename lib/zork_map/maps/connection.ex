defmodule ZorkMap.Maps.Connection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "connections" do
    field :direction, :string
    belongs_to :map, ZorkMap.Maps.Map
    belongs_to :from_room, ZorkMap.Maps.Room
    belongs_to :to_room, ZorkMap.Maps.Room
    timestamps()
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:map_id, :from_room_id, :to_room_id, :direction])
    |> validate_required([:map_id, :from_room_id, :to_room_id, :direction])
    |> validate_length(:direction, min: 1, max: 20)
    |> unique_constraint([:from_room_id, :to_room_id, :direction])
  end
end
