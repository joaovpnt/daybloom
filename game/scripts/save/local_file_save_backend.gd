class_name LocalFileSaveBackend
extends SaveBackend
## Saves em arquivo JSON local com gravação atômica (arquivo temporário +
## renomeação) e o mesmo controle de revisão do backend MongoDB.

var directory: String = "user://saves"


func _init(dir: String = "user://saves") -> void:
	directory = dir


func backend_name() -> String:
	return "arquivo local"


func _path(slot_id: String) -> String:
	return "%s/%s.json" % [directory, slot_id]


func load_save(slot_id: String) -> Dictionary:
	var path := _path(slot_id)
	if not FileAccess.file_exists(path):
		return {"ok": true, "found": false, "error": ""}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has("snapshot"):
		return {"ok": false, "found": false, "error": "arquivo de save corrompido"}
	var expected := str(parsed.get("checksum", ""))
	if expected != JSON.stringify(parsed["snapshot"], "", true).sha256_text():
		return {"ok": false, "found": false, "error": "checksum do save não confere"}
	return {"ok": true, "found": true, "snapshot": parsed["snapshot"], "revision": int(parsed["revision"]), "error": ""}


func write_save(slot_id: String, snapshot: Dictionary, expected_revision: int, overwrite: bool) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(directory)
	var current := await load_save(slot_id)
	var current_rev: int = int(current.get("revision", 0)) if current.get("found", false) else 0
	if not overwrite:
		if expected_revision <= 0 and current.get("found", false):
			return {"ok": false, "error": "o slot já existe", "conflict": true}
		if expected_revision > 0 and expected_revision != current_rev:
			return {"ok": false, "error": "revisão divergente", "conflict": true}
	var new_rev := current_rev + 1
	var doc := {
		"revision": new_rev,
		"checksum": JSON.stringify(snapshot, "", true).sha256_text(),
		"saved_at": Time.get_datetime_string_from_system(true),
		"snapshot": snapshot,
	}
	var tmp := _path(slot_id) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "não foi possível escrever o arquivo", "conflict": false}
	f.store_string(JSON.stringify(doc))
	f.close()
	var err := DirAccess.rename_absolute(tmp, _path(slot_id))
	if err != OK:
		return {"ok": false, "error": "falha ao finalizar gravação (%s)" % error_string(err), "conflict": false}
	return {"ok": true, "revision": new_rev, "error": "", "conflict": false}


func delete_save(slot_id: String) -> void:
	if FileAccess.file_exists(_path(slot_id)):
		DirAccess.remove_absolute(_path(slot_id))
