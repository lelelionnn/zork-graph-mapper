defmodule ZorkMap.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :name, :string, null: false, default: "New Room"
      add :notes, :text
      add :items, :text
      add :x, :float
      add :y, :float
      timestamps()
    end

    create index(:rooms, [:map_id])
  end
end
