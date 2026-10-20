# Formato do save (schema_version 1)

Documento `save_slots` no MongoDB:

```json
{
  "_id": "slot1",
  "slot_id": "slot1",
  "player_id": "jogadora_3fa2c1d4e5",
  "island_id": "ilha_9b8a7c6d5e",
  "schema_version": 1,
  "game_version": "0.1.0",
  "revision": 7,
  "checksum": "sha256 do snapshot canônico",
  "updated_at": "2026-10-20T01:23:45Z",
  "snapshot": { "...": "ver abaixo" }
}
```

Snapshot canônico (produzido por `GameState.build_snapshot()`):

| Campo | Conteúdo |
|---|---|
| `schema_version`, `game_version` | versionamento |
| `save_slot_id`, `player_id`, `island_id` | identificadores |
| `saved_at` | horário real do salvamento (UTC) |
| `world` | `day`, `minute`, `island_name`, `event_seq`, `resources[]` (id, kind, item_id, available, respawn_day), `pair_cooldowns` |
| `player` | `id`, `name`, `position`, `rotation_y`, `inventory[]` (item_id, count) |
| `npcs[8]` | `id`, `name`, `species`, `personality`, `needs`, `emotion`, `state`, `activity`, `position`, `inside_home`, `personal_goal` (id, descrição, progresso), `relationships` (por ID: affinity, trust, interactions, last_meeting, history[], conflict_open...), `memories[]`, `cooldowns` |
| `journal[]` | `event_id`, `day`, `minute`, `kind`, `participants`, `text` |

Regras:

- A gravação substitui o documento inteiro (`replace_one` condicionado a `revision`);
  revisão divergente → HTTP 409, nada é gravado.
- O snapshot é validado antes de gravar (HTTP 422 em caso de erro) e o checksum é
  conferido ao carregar (save adulterado não é carregado).
- Carregar sempre **substitui** o estado (nunca soma), e IDs duplicados são descartados.
- `world_events` é auxiliar e idempotente; a partida é reconstruída apenas pelo snapshot.
- Saves antigos passam por `migrate_snapshot` (backend) e `SaveMigrator` (jogo).
  Saves de versões futuras são recusados com mensagem clara.
