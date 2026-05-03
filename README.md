# Zork Graph Mapper

App web local pra mapear dungeons de jogos text-adventure (Zork I, etc.) como grafos.
Salas viram nós, conexões viram arestas com direções (N/S/L/O/up/down/...).
Edição interativa com auto-save, persistência em SQLite.

## Stack

- Phoenix LiveView (servidor)
- Cytoscape.js (visualização do grafo, via CDN)
- Ecto + SQLite (persistência local em arquivo `.db`)
- esbuild (bundling JS)

## Pré-requisitos

`mise` com as versões pinnadas em `.mise.toml`:

```bash
mise install
```

Isso instala Erlang/OTP 27 e Elixir 1.17.

## Setup

```bash
mix setup
```

Esse alias roda: `deps.get`, `ecto.create`, `ecto.migrate`, baixa o esbuild e builda os assets.

## Rodar

```bash
mix phx.server
```

Abre [http://localhost:4000](http://localhost:4000).

O DB é `priv/zork_map_dev.db` — copie/backup à vontade, é só um arquivo.

## Como usar o editor

- **Criar sala**: dois cliques (dblclick) em uma área vazia do canvas.
- **Criar conexão**: clique em uma sala (vira ciano), depois clique em outra sala.
- **Mover sala**: arrastar.
- **Editar**: clique numa sala ou conexão — o painel lateral abre.
  - Sala: nome, notas (texto livre), itens (um por linha).
  - Conexão: direção forward (origem → destino) e backward (destino → origem).
    Deixar uma vazia = passagem one-way.
- **Apagar**: pelo painel lateral.
- **Re-layout**: botão na barra superior, recalcula posições com `cose`.

Tudo é salvo automaticamente (debounce de 500ms nos campos de texto, imediato nas direções).

## Modelo de dados

- `maps(id, name, description)`
- `rooms(id, map_id, name, notes, items[], x, y)`
- `connections(id, map_id, from_room_id, to_room_id, direction_forward, direction_backward)`

`items` é serializado como JSON pelo `ecto_sqlite3`.

## Estrutura

```
lib/
  zork_map/
    application.ex       # supervisor tree
    repo.ex
    maps.ex              # context
    maps/{map,room,connection}.ex
  zork_map_web/
    endpoint.ex, router.ex, telemetry.ex
    components/layouts/  # root + app templates
    live/
      map_index_live.ex  # lista de mapas
      map_editor_live.ex # editor

assets/
  js/app.js
  js/hooks/cytoscape.js  # bridge LiveView ↔ Cytoscape
  css/app.css

priv/
  repo/migrations/
  static/                # arquivos servidos (favicon, robots, assets compilados)
```

