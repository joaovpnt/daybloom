extends Node
## Coordena salvar/carregar usando uma implementação de SaveBackend.
## Nunca informa sucesso sem confirmação do backend.

var backend: SaveBackend
var revision: int = 0
var saving: bool = false
var last_status: Dictionary = {"state": "idle", "message": ""}
## Primeira gravação de uma nova partida sobrescreve o slot (confirmado no menu).
var pending_overwrite: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("DAYBLOOM_SAVE_BACKEND") == "local":
		backend = LocalFileSaveBackend.new()
	else:
		backend = ApiSaveBackend.new()


func use_backend(new_backend: SaveBackend) -> void:
	backend = new_backend
	revision = 0


func _set_status(state: String, message: String) -> void:
	last_status = {"state": state, "message": message, "time": Time.get_ticks_msec()}
	EventBus.save_status_changed.emit(last_status)


func start_new_game_session() -> void:
	revision = 0
	pending_overwrite = true


func save_game() -> Dictionary:
	if saving:
		return {"ok": false, "error": "um salvamento já está em andamento"}
	if not GameState.session_active:
		return {"ok": false, "error": "nenhuma partida em andamento"}
	saving = true
	_set_status("saving", "Salvando no %s..." % backend.backend_name())
	var snapshot := GameState.build_snapshot()
	var result: Dictionary = await backend.write_save(GameState.save_slot_id, snapshot, revision, pending_overwrite)
	saving = false
	if result["ok"]:
		revision = int(result["revision"])
		pending_overwrite = false
		var when := GameClock.format_hm(GameClock.minute)
		_set_status("saved", "Salvo no %s (dia %d, %s, revisão %d)" % [backend.backend_name(), GameClock.day, when, revision])
	else:
		var msg := "Falha ao salvar: %s. O progresso NÃO foi salvo." % result["error"]
		if result.get("conflict", false):
			msg = "Conflito: o save foi alterado em outro lugar. O progresso NÃO foi salvo."
		_set_status("error", msg)
	return result


func load_game(slot_id: String = GameState.DEFAULT_SLOT) -> Dictionary:
	_set_status("loading", "Carregando do %s..." % backend.backend_name())
	var result: Dictionary = await backend.load_save(slot_id)
	if not result["ok"]:
		_set_status("error", "Falha ao carregar: %s" % result["error"])
		return result
	if not result["found"]:
		_set_status("error", "Nenhum save encontrado.")
		return {"ok": false, "error": "nenhum save encontrado"}
	var applied := GameState.apply_snapshot(result["snapshot"])
	if not applied["ok"]:
		_set_status("error", "Save inválido: %s" % applied["error"])
		return applied
	revision = int(result["revision"])
	pending_overwrite = false
	_set_status("loaded", "Partida carregada (revisão %d)" % revision)
	return {"ok": true, "revision": revision}


func check_save_exists(slot_id: String = GameState.DEFAULT_SLOT) -> Dictionary:
	var result: Dictionary = await backend.load_save(slot_id)
	if not result["ok"]:
		return {"ok": false, "exists": false, "error": result["error"]}
	var info := {"ok": true, "exists": result["found"], "error": ""}
	if result["found"]:
		var snap: Dictionary = result["snapshot"]
		info["player_name"] = snap.get("player", {}).get("name", "")
		info["day"] = snap.get("world", {}).get("day", 1)
		info["island_name"] = snap.get("world", {}).get("island_name", "")
	return info
