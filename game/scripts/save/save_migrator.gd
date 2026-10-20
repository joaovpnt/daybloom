class_name SaveMigrator
extends RefCounted
## Migração e verificação básica de snapshots no lado do jogo (o backend faz a
## validação completa). Garante compatibilidade com saves de versões anteriores.

const CURRENT := 1

## Migrações: versão -> Callable(snapshot) -> snapshot da versão seguinte.
static var MIGRATIONS: Dictionary = {}


static func migrate(snapshot: Dictionary) -> Dictionary:
	if not snapshot.has("schema_version"):
		return {"ok": false, "error": "save sem schema_version"}
	var version := int(snapshot["schema_version"])
	if version > CURRENT:
		return {"ok": false, "error": "este save foi criado por uma versão mais nova do Daybloom"}
	var data := snapshot.duplicate(true)
	while version < CURRENT:
		if not MIGRATIONS.has(version):
			return {"ok": false, "error": "não há migração para o schema %d" % version}
		data = (MIGRATIONS[version] as Callable).call(data)
		version += 1
		data["schema_version"] = version
	for key in ["player_id", "island_id", "save_slot_id", "world", "player", "npcs"]:
		if not data.has(key):
			return {"ok": false, "error": "save incompleto: falta %s" % key}
	if (data["npcs"] as Array).size() != Simulation.NPC_COUNT:
		return {"ok": false, "error": "save com número inválido de moradores"}
	return {"ok": true, "snapshot": data}
