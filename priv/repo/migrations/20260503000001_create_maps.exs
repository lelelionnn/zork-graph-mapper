defmodule ZorkMap.Repo.Migrations.CreateMaps do
  use Ecto.Migration

  def change do
    create table(:maps) do
      add :name, :string, null: false
      add :description, :text
      timestamps()
    end
  end
end
