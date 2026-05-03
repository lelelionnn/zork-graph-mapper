defmodule ZorkMap.Repo do
  use Ecto.Repo,
    otp_app: :zork_map,
    adapter: Ecto.Adapters.SQLite3
end
