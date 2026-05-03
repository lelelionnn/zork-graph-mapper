defmodule ZorkMapWeb.MapIndexLive do
  use ZorkMapWeb, :live_view

  alias ZorkMap.Maps

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Mapas")
     |> assign(:new_name, "")
     |> load_maps()}
  end

  defp load_maps(socket), do: assign(socket, :maps, Maps.list_maps())

  @impl true
  def handle_event("create", %{"name" => name}, socket) do
    name = String.trim(name)

    case name do
      "" ->
        {:noreply, socket}

      _ ->
        case Maps.create_map(%{name: name}) do
          {:ok, _} -> {:noreply, socket |> assign(:new_name, "") |> load_maps()}
          {:error, _cs} -> {:noreply, put_flash(socket, :error, "Não foi possível criar")}
        end
    end
  end

  def handle_event("rename", %{"id" => id, "name" => name}, socket) do
    name = String.trim(name)
    map = Maps.get_map!(id)

    case Maps.update_map(map, %{name: name}) do
      {:ok, _} -> {:noreply, load_maps(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Nome inválido")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    Maps.get_map!(id) |> Maps.delete_map()
    {:noreply, load_maps(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-3xl mx-auto">
      <h1 class="text-3xl font-bold mb-6">Zork Map</h1>

      <form phx-submit="create" class="flex gap-2 mb-8">
        <input
          type="text"
          name="name"
          value={@new_name}
          placeholder="Nome do novo mapa (ex: Zork I — White House)"
          class="flex-1 border rounded px-3 py-2"
          autofocus
        />
        <button type="submit" class="bg-zinc-900 text-white px-4 py-2 rounded">
          Criar mapa
        </button>
      </form>

      <ul class="space-y-2">
        <li :for={m <- @maps} class="flex items-center gap-3 border rounded px-4 py-3">
          <form phx-change="rename" phx-value-id={m.id} phx-debounce="600" class="flex-1">
            <input
              type="text"
              name="name"
              value={m.name}
              class="w-full bg-transparent border-0 focus:ring-0 text-lg font-medium"
            />
          </form>
          <span class="text-sm text-zinc-500">{Map.get(m, :rooms_count, 0)} salas</span>
          <.link
            navigate={~p"/maps/#{m.id}"}
            class="bg-blue-600 text-white px-3 py-1 rounded text-sm"
          >
            Abrir
          </.link>
          <button
            phx-click="delete"
            phx-value-id={m.id}
            data-confirm={"Apagar #{m.name}?"}
            class="text-red-600 text-sm"
          >
            Apagar
          </button>
        </li>
        <li :if={@maps == []} class="text-zinc-500 text-center py-8">
          Nenhum mapa ainda. Crie um acima.
        </li>
      </ul>
    </div>
    """
  end
end
