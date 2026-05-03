defmodule ZorkMap.Repo.Migrations.CreateConnections do
  use Ecto.Migration

  def change do
    create table(:connections) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :from_room_id, references(:rooms, on_delete: :delete_all), null: false
      add :to_room_id, references(:rooms, on_delete: :delete_all), null: false
      add :direction, :string, null: false
      timestamps()
    end

    create index(:connections, [:map_id])
    create index(:connections, [:from_room_id])
    create index(:connections, [:to_room_id])
    create unique_index(:connections, [:from_room_id, :to_room_id, :direction])
  end
end
