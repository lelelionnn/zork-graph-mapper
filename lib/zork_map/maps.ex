defmodule ZorkMap.Maps do
  @moduledoc "Context for maps, rooms, and connections."

  import Ecto.Query
  alias ZorkMap.Repo
  alias ZorkMap.Maps.{Map, Room, Connection}

  # Maps

  def list_maps do
    rooms_count =
      from r in Room,
        group_by: r.map_id,
        select: {r.map_id, count(r.id)}

    counts = rooms_count |> Repo.all() |> Enum.into(%{})

    Map
    |> order_by(asc: :inserted_at)
    |> Repo.all()
    |> Enum.map(fn m -> %{m | __meta__: m.__meta__} |> add_count(counts) end)
  end

  defp add_count(map, counts) do
    Elixir.Map.put(map, :rooms_count, Elixir.Map.get(counts, map.id, 0))
  end

  def get_map!(id), do: Repo.get!(Map, id)

  def get_map_with_graph!(id) do
    Map
    |> Repo.get!(id)
    |> Repo.preload([:rooms, :connections])
  end

  def create_map(attrs) do
    %Map{} |> Map.changeset(attrs) |> Repo.insert()
  end

  def update_map(%Map{} = map, attrs) do
    map |> Map.changeset(attrs) |> Repo.update()
  end

  def delete_map(%Map{} = map), do: Repo.delete(map)

  # Rooms

  def create_room(attrs) do
    %Room{} |> Room.changeset(attrs) |> Repo.insert()
  end

  def get_room!(id), do: Repo.get!(Room, id)

  def update_room(%Room{} = room, attrs) do
    room |> Room.changeset(attrs) |> Repo.update()
  end

  def delete_room(%Room{} = room), do: Repo.delete(room)

  # Connections

  def list_connections_for_map(map_id) do
    Connection
    |> where(map_id: ^map_id)
    |> Repo.all()
  end

  def create_connection(attrs) do
    %Connection{} |> Connection.changeset(attrs) |> Repo.insert()
  end

  def get_connection!(id), do: Repo.get!(Connection, id)

  def update_connection(%Connection{} = c, attrs) do
    c |> Connection.changeset(attrs) |> Repo.update()
  end

  def delete_connection(%Connection{} = c), do: Repo.delete(c)
end
