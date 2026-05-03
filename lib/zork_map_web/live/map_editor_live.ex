defmodule ZorkMapWeb.MapEditorLive do
  use ZorkMapWeb, :live_view

  alias ZorkMap.Maps

  @directions ~w(N S W E NE NW SE SW U D)

  @opposites %{
    "N" => "S", "S" => "N", "W" => "E", "E" => "W",
    "NE" => "SW", "SW" => "NE", "NW" => "SE", "SE" => "NW",
    "U" => "D", "D" => "U"
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    map = Maps.get_map_with_graph!(id)

    {:ok,
     socket
     |> assign(:page_title, map.name)
     |> assign(:map, map)
     |> assign(:rooms, map.rooms)
     |> assign(:connections, map.connections)
     |> assign(:selection, nil)
     |> assign(:pending_from, nil)
     |> assign(:pending_to, nil)
     |> assign(:directions, @directions)}
  end

  defp graph_data(rooms, connections) do
    %{
      rooms: Enum.map(rooms, &room_payload/1),
      connections: Enum.map(connections, &edge_payload/1)
    }
    |> Jason.encode!()
  end

  defp room_payload(r) do
    %{id: r.id, name: r.name, x: r.x, y: r.y}
  end

  defp edge_payload(c) do
    %{id: c.id, from: c.from_room_id, to: c.to_room_id, direction: c.direction}
  end

  @impl true
  def handle_event("create_room", %{"x" => x, "y" => y}, socket) do
    {:ok, room} =
      Maps.create_room(%{
        map_id: socket.assigns.map.id,
        name: "Nova sala",
        x: x,
        y: y,
        items: []
      })

    {:noreply,
     socket
     |> update(:rooms, &(&1 ++ [room]))
     |> push_event("graph:add_room", room_payload(room))
     |> assign(:selection, {:room, room.id})}
  end

  def handle_event("room_clicked", %{"id" => id}, socket) do
    id = to_int(id)

    cond do
      socket.assigns.pending_from && socket.assigns.pending_from != id ->
        {:noreply, assign(socket, :pending_to, id)}

      true ->
        {:noreply, assign(socket, :selection, {:room, id})}
    end
  end

  def handle_event("edge_clicked", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selection, {:edge, to_int(id)})}
  end

  def handle_event("canvas_clicked", _, socket) do
    {:noreply, socket |> assign(:selection, nil) |> assign(:pending_from, nil) |> assign(:pending_to, nil)}
  end

  def handle_event("room_dragged", %{"id" => id, "x" => x, "y" => y}, socket) do
    room = Maps.get_room!(to_int(id))
    {:ok, room} = Maps.update_room(room, %{x: x, y: y})
    {:noreply, replace_room(socket, room)}
  end

  def handle_event("update_room", %{"_id" => id, "field" => field, "value" => value}, socket) do
    attrs =
      case field do
        "items" -> %{items: parse_items(value)}
        "name" -> %{name: value}
        "notes" -> %{notes: value}
      end

    room = Maps.get_room!(to_int(id))

    case Maps.update_room(room, attrs) do
      {:ok, room} ->
        socket = replace_room(socket, room)

        socket =
          if field == "name",
            do: push_event(socket, "graph:update_room", room_payload(room)),
            else: socket

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("delete_room", %{"id" => id}, socket) do
    id = to_int(id)
    room = Maps.get_room!(id)
    {:ok, _} = Maps.delete_room(room)

    rooms = Enum.reject(socket.assigns.rooms, &(&1.id == id))
    conns = Enum.reject(socket.assigns.connections, &(&1.from_room_id == id or &1.to_room_id == id))

    {:noreply,
     socket
     |> assign(:rooms, rooms)
     |> assign(:connections, conns)
     |> assign(:selection, nil)
     |> push_event("graph:remove_room", %{id: id})}
  end

  def handle_event("start_pending", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:pending_from, to_int(id)) |> assign(:pending_to, nil)}
  end

  def handle_event("cancel_pending", _, socket) do
    {:noreply, socket |> assign(:pending_from, nil) |> assign(:pending_to, nil)}
  end

  def handle_event("create_connection", params, socket) do
    %{"from_id" => from_id, "to_id" => to_id, "direction" => dir} = params
    also = params["also_reverse"] == "true"
    rev = String.trim(params["reverse_direction"] || "")

    from_id = to_int(from_id)
    to_id = to_int(to_id)
    map_id = socket.assigns.map.id

    forward_attrs = %{map_id: map_id, from_room_id: from_id, to_room_id: to_id, direction: dir}

    socket =
      case Maps.create_connection(forward_attrs) do
        {:ok, c} -> add_conn(socket, c)
        {:error, _} -> put_flash(socket, :error, "Conexão duplicada")
      end

    socket =
      if also and rev != "" do
        case Maps.create_connection(%{
               map_id: map_id,
               from_room_id: to_id,
               to_room_id: from_id,
               direction: rev
             }) do
          {:ok, c} -> add_conn(socket, c)
          {:error, _} -> put_flash(socket, :error, "Conexão de volta duplicada")
        end
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:pending_from, nil)
     |> assign(:pending_to, nil)
     |> assign(:selection, nil)}
  end

  def handle_event("update_connection", %{"_id" => id, "direction" => dir}, socket) do
    c = Maps.get_connection!(to_int(id))

    case Maps.update_connection(c, %{direction: dir}) do
      {:ok, c} ->
        conns = Enum.map(socket.assigns.connections, fn x -> if x.id == c.id, do: c, else: x end)

        {:noreply,
         socket
         |> assign(:connections, conns)
         |> push_event("graph:update_edge", edge_payload(c))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Direção inválida ou duplicada")}
    end
  end

  def handle_event("delete_connection", %{"id" => id}, socket) do
    id = to_int(id)
    c = Maps.get_connection!(id)
    {:ok, _} = Maps.delete_connection(c)

    {:noreply,
     socket
     |> assign(:connections, Enum.reject(socket.assigns.connections, &(&1.id == id)))
     |> assign(:selection, nil)
     |> push_event("graph:remove_edge", %{id: id})}
  end

  def handle_event("relayout", _, socket) do
    {:noreply, push_event(socket, "graph:relayout", %{})}
  end

  # Helpers

  defp add_conn(socket, c) do
    socket
    |> update(:connections, &(&1 ++ [c]))
    |> push_event("graph:add_edge", edge_payload(c))
  end

  defp replace_room(socket, room) do
    rooms = Enum.map(socket.assigns.rooms, fn r -> if r.id == room.id, do: room, else: r end)
    assign(socket, :rooms, rooms)
  end

  defp parse_items(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_items(_), do: []

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v), do: String.to_integer(v)

  defp selected_room(assigns) do
    case assigns.selection do
      {:room, id} -> Enum.find(assigns.rooms, &(&1.id == id))
      _ -> nil
    end
  end

  defp selected_edge(assigns) do
    case assigns.selection do
      {:edge, id} -> Enum.find(assigns.connections, &(&1.id == id))
      _ -> nil
    end
  end

  defp used_directions(connections, from_room_id, except_id \\ nil) do
    connections
    |> Enum.filter(&(&1.from_room_id == from_room_id and &1.id != except_id))
    |> Enum.map(& &1.direction)
    |> MapSet.new()
  end

  defp available_directions(directions, used) do
    Enum.reject(directions, &MapSet.member?(used, &1))
  end

  defp room_name(rooms, id) do
    case Enum.find(rooms, &(&1.id == id)) do
      nil -> "?"
      r -> r.name
    end
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:room, selected_room(assigns))
      |> assign(:edge, selected_edge(assigns))

    ~H"""
    <div class="relative h-screen w-screen flex flex-col">
      <div class="flex flex-col flex-1 min-h-0">
        <div class="flex items-center gap-3 px-4 py-2 border-b bg-zinc-50">
          <.link navigate={~p"/"} class="text-sm text-blue-600">← Mapas</.link>
          <h1 class="font-semibold">{@map.name}</h1>
          <button phx-click="relayout" class="text-sm border rounded px-2 py-1">
            Re-layout
          </button>
          <div :if={@pending_from} class="ml-auto flex items-center gap-2 text-sm">
            <span class="text-amber-700">
              Conectando de: <strong>{room_name(@rooms, @pending_from)}</strong> — clique no destino
            </span>
            <button phx-click="cancel_pending" class="border rounded px-2 py-1">Cancelar</button>
          </div>
          <div :if={!@pending_from} class="ml-auto text-sm text-zinc-500">
            Duplo-clique no canvas pra criar sala
          </div>
        </div>

        <div
          id="cy"
          phx-hook="Cytoscape"
          phx-update="ignore"
          data-graph={graph_data(@rooms, @connections)}
          class="flex-1 bg-white"
        >
        </div>
      </div>

      <aside :if={@room || @edge || @pending_to} class="absolute top-12 right-0 bottom-0 w-80 border-l bg-zinc-50 p-4 overflow-y-auto shadow-lg z-10">
        <.room_panel :if={@room} room={@room} />
        <.edge_panel
          :if={@edge}
          edge={@edge}
          rooms={@rooms}
          directions={
            available_directions(
              @directions,
              used_directions(@connections, @edge.from_room_id, @edge.id)
            )
          }
        />
        <.connection_modal
          :if={@pending_to}
          from_id={@pending_from}
          to_id={@pending_to}
          rooms={@rooms}
          forward_directions={
            available_directions(@directions, used_directions(@connections, @pending_from))
          }
          reverse_directions={
            available_directions(@directions, used_directions(@connections, @pending_to))
          }
        />
      </aside>
    </div>
    """
  end

  attr :room, :map, required: true

  defp room_panel(assigns) do
    ~H"""
    <div>
      <h2 class="font-semibold text-lg mb-3">Sala</h2>

      <form phx-change="update_room" class="space-y-3">
        <input type="hidden" name="_id" value={@room.id} />
        <input type="hidden" name="field" value="name" />

        <label class="block">
          <span class="text-xs text-zinc-600">Nome</span>
          <input
            type="text"
            name="value"
            value={@room.name}
            phx-debounce="500"
            class="w-full border rounded px-2 py-1"
          />
        </label>
      </form>

      <form phx-change="update_room" class="space-y-3 mt-3">
        <input type="hidden" name="_id" value={@room.id} />
        <input type="hidden" name="field" value="notes" />

        <label class="block">
          <span class="text-xs text-zinc-600">Notas</span>
          <textarea
            name="value"
            rows="4"
            phx-debounce="500"
            class="w-full border rounded px-2 py-1"
          >{@room.notes || ""}</textarea>
        </label>
      </form>

      <form phx-change="update_room" class="space-y-3 mt-3">
        <input type="hidden" name="_id" value={@room.id} />
        <input type="hidden" name="field" value="items" />

        <label class="block">
          <span class="text-xs text-zinc-600">Itens (um por linha)</span>
          <textarea
            name="value"
            rows="4"
            phx-debounce="500"
            class="w-full border rounded px-2 py-1"
          >{Enum.join(@room.items || [], "\n")}</textarea>
        </label>
      </form>

      <div class="flex gap-2 mt-4">
        <button
          phx-click="start_pending"
          phx-value-id={@room.id}
          class="bg-blue-600 text-white px-3 py-1 rounded text-sm"
        >
          Nova conexão a partir daqui
        </button>
        <button
          phx-click="delete_room"
          phx-value-id={@room.id}
          data-confirm={"Apagar #{@room.name}? Conexões serão removidas."}
          class="text-red-600 text-sm ml-auto"
        >
          Apagar sala
        </button>
      </div>
    </div>
    """
  end

  attr :edge, :map, required: true
  attr :rooms, :list, required: true
  attr :directions, :list, required: true

  defp edge_panel(assigns) do
    ~H"""
    <div>
      <h2 class="font-semibold text-lg mb-3">Conexão</h2>
      <p class="text-sm text-zinc-600 mb-3">
        <strong>{room_name(@rooms, @edge.from_room_id)}</strong>
        →
        <strong>{room_name(@rooms, @edge.to_room_id)}</strong>
      </p>

      <form phx-change="update_connection" class="space-y-2">
        <input type="hidden" name="_id" value={@edge.id} />
        <label class="block">
          <span class="text-xs text-zinc-600">Direção</span>
          <select name="direction" class="w-full border rounded px-2 py-1">
            <option :for={d <- @directions} value={d} selected={d == @edge.direction}>
              {d}
            </option>
          </select>
        </label>
      </form>

      <button
        phx-click="delete_connection"
        phx-value-id={@edge.id}
        data-confirm="Apagar conexão?"
        class="text-red-600 text-sm mt-4"
      >
        Apagar conexão
      </button>
    </div>
    """
  end

  attr :from_id, :integer, required: true
  attr :to_id, :integer, required: true
  attr :rooms, :list, required: true
  attr :forward_directions, :list, required: true
  attr :reverse_directions, :list, required: true

  defp connection_modal(assigns) do
    fwd_default = List.first(assigns.forward_directions)
    rev_default =
      case Elixir.Map.get(@opposites, fwd_default) do
        nil -> List.first(assigns.reverse_directions)
        opp -> if opp in assigns.reverse_directions, do: opp, else: List.first(assigns.reverse_directions)
      end

    assigns =
      assigns
      |> assign(:default_forward, fwd_default)
      |> assign(:default_reverse, rev_default)
    ~H"""
    <div class="border rounded bg-white p-3">
      <h2 class="font-semibold mb-2">Nova conexão</h2>
      <p class="text-sm text-zinc-600 mb-3">
        <strong>{room_name(@rooms, @from_id)}</strong>
        →
        <strong>{room_name(@rooms, @to_id)}</strong>
      </p>

      <form phx-submit="create_connection" class="space-y-3">
        <input type="hidden" name="from_id" value={@from_id} />
        <input type="hidden" name="to_id" value={@to_id} />

        <label class="block">
          <span class="text-xs text-zinc-600">Direção</span>
          <select name="direction" class="w-full border rounded px-2 py-1" required autofocus>
            <option :for={d <- @forward_directions} value={d} selected={d == @default_forward}>
              {d}
            </option>
          </select>
          <p :if={@forward_directions == []} class="text-xs text-red-600 mt-1">
            Sala de origem já usa todas as direções.
          </p>
        </label>

        <label class={["flex items-center gap-2 text-sm", @reverse_directions == [] && "opacity-50"]}>
          <input
            type="checkbox"
            name="also_reverse"
            value="true"
            checked={@reverse_directions != []}
            disabled={@reverse_directions == []}
          />
          Criar conexão de volta
        </label>

        <label :if={@reverse_directions != []} class="block">
          <span class="text-xs text-zinc-600">Direção de volta</span>
          <select name="reverse_direction" class="w-full border rounded px-2 py-1">
            <option :for={d <- @reverse_directions} value={d} selected={d == @default_reverse}>
              {d}
            </option>
          </select>
        </label>

        <div class="flex gap-2">
          <button
            type="submit"
            disabled={@forward_directions == []}
            class="bg-zinc-900 text-white px-3 py-1 rounded disabled:opacity-50"
          >
            Criar
          </button>
          <button
            type="button"
            phx-click="cancel_pending"
            class="border rounded px-3 py-1"
          >
            Cancelar
          </button>
        </div>
      </form>
    </div>
    """
  end
end
