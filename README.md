# Zork Graph Mapper

App web local pra mapear dungeons de jogos text-adventure (Zork I, etc.) como grafos.
Direções usam o vocabulário de Zork: N, S, W, E, NE, NW, SE, SW, U (up), D (down).
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

Isso instala Erlang/OTP 27 e Elixir 1.18.

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

O DB é `zork_map_dev.db` na raiz do projeto — copie/backup à vontade, é só um arquivo.

## Como usar o editor

- **Criar sala**: dois cliques (dblclick) em uma área vazia do canvas.
- **Mover sala**: arrastar.
- **Editar**: clique numa sala ou conexão — o painel lateral abre.
  - Sala: nome, notas (texto livre), itens (um por linha).
  - Conexão: direção (texto livre, autocompleta com N/S/W/E/NE/NW/SE/SW/U/D).
- **Criar conexão**: clique numa sala → painel lateral → "Nova conexão a partir daqui" →
  clique na sala destino → modal pergunta direção (e opcionalmente cria a volta de uma vez).
  Cada direção é uma aresta independente — pra one-way, desmarque "criar conexão de volta".
- **Apagar**: pelo painel lateral.
- **Re-layout**: botão na barra superior, recalcula posições com `cose`.

Tudo é salvo automaticamente (debounce de 500ms nos campos de texto, imediato nas direções).

## Modelo de dados

- `maps(id, name, description)`
- `rooms(id, map_id, name, notes, items[], x, y)`
- `connections(id, map_id, from_room_id, to_room_id, direction)`

Cada conexão é uma aresta direcionada (one-way). Passagens bidirecionais simétricas viram
duas linhas — o editor cria as duas de uma vez por padrão.

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

