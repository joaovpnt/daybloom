extends Node
## Estado da partida em andamento. Monta e aplica o snapshot canônico do save
## e conecta a simulação ao relógio e ao barramento de eventos.

const SCHEMA_VERSION := 1
const GAME_VERSION := "0.3.0"
const DEFAULT_SLOT := "slot1"
const PLAYER_SPAWN := Vector3(2.0, 0.0, 15.5)

var sim: Simulation = null
var inventory := Inventory.new()
var defs: Array = []
var save_slot_id: String = DEFAULT_SLOT
var island_id: String = ""
var resources: Dictionary = {}  # id -> {id, kind, item_id, available, respawn_day}
var player_position: Vector3 = PLAYER_SPAWN
var player_rotation: float = PI
var session_active: bool = false
## Nó do mundo (opcional) que sincroniza posições antes de salvar.
var world_node: Node = null


func _ready() -> void:
	defs = Simulation.load_definitions()
	inventory.changed.connect(func(): EventBus.inventory_changed.emit())
	GameClock.minute_ticked.connect(_on_minute_ticked)
	GameClock.day_started.connect(_on_day_started)


static func _random_id(prefix: String) -> String:
	var crypto := Crypto.new()
	return prefix + crypto.generate_random_bytes(5).hex_encode()


func new_game(player_name: String, island_name: String, seed_value: int = 0) -> void:
	_bind_sim(Simulation.new())
	island_id = _random_id("ilha_")
	var player_id := _random_id("jogadora_")
	sim.island_name = island_name if island_name.strip_edges() != "" else "Daybloom"
	GameClock.reset(1, 480.0)
	sim.set_time(1, 480.0)
	sim.setup_new(defs, player_id, player_name.strip_edges() if player_name.strip_edges() != "" else "Jogadora", seed_value)
	inventory.load_from([])
	_init_resources([])
	player_position = Places.house_door("casa_jogadora") + Vector3(0, 0, 1.2)
	player_rotation = PI
	session_active = true


func _bind_sim(new_sim: Simulation) -> void:
	sim = new_sim
	sim.journal_added.connect(func(e): EventBus.journal_entry_added.emit(e))
	sim.relationship_changed.connect(func(o, t, r): EventBus.relationship_changed.emit(o, t, r))
	sim.memory_added.connect(func(n, m): EventBus.memory_added.emit(n, m))
	sim.npc_state_changed.connect(func(n, s, a): EventBus.npc_state_changed.emit(n, s, a))
	sim.interaction_started.connect(func(a, b, k): EventBus.social_interaction_started.emit(a, b, k))
	sim.interaction_finished.connect(func(a, b, k, o): EventBus.social_interaction_finished.emit(a, b, k, o))


func _init_resources(saved: Array) -> void:
	resources.clear()
	var saved_by_id := {}
	for r in saved:
		saved_by_id[str(r["id"])] = r
	for spec in IslandLayout.generate()["resources"]:
		var state := {"id": spec["id"], "kind": spec["kind"], "item_id": spec["item_id"], "available": true, "respawn_day": 0}
		if saved_by_id.has(spec["id"]):
			var s: Dictionary = saved_by_id[spec["id"]]
			state["available"] = bool(s.get("available", true))
			state["respawn_day"] = int(s.get("respawn_day", 0))
			if ItemDB.exists(str(s.get("item_id", ""))):
				state["item_id"] = str(s["item_id"])
		resources[spec["id"]] = state


func resource_position(resource_id: String) -> Vector3:
	for spec in IslandLayout.generate()["resources"]:
		if spec["id"] == resource_id:
			return Places.pos3(spec["pos"])
	return Vector3.ZERO


## Coleta um recurso: só funciona se ele estiver disponível e houver espaço.
func collect_resource(resource_id: String) -> Dictionary:
	if not resources.has(resource_id):
		return {"ok": false, "reason": "recurso inexistente"}
	var r: Dictionary = resources[resource_id]
	if not r["available"]:
		return {"ok": false, "reason": "já foi coletado"}
	var item_id: String = r["item_id"]
	if inventory.add(item_id, 1) != 1:
		return {"ok": false, "reason": "inventário cheio"}
	r["available"] = false
	r["respawn_day"] = GameClock.day + 1
	return {"ok": true, "item_id": item_id}


func _on_day_started(day: int) -> void:
	if not session_active:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(island_id) + day
	for r in resources.values():
		if not r["available"] and int(r["respawn_day"]) <= day:
			r["available"] = true
			if r["kind"] == "shell":
				r["item_id"] = "estrela_do_mar" if rng.randf() < 0.12 else "concha"
	sim.set_time(day, GameClock.minute)
	sim.on_new_day()
	EventBus.toast_requested.emit("Um novo dia começou na ilha! (Dia %d)" % day)


func _on_minute_ticked(day: int, minute: float, elapsed: int) -> void:
	if not session_active or sim == null:
		return
	sim.set_time(day, minute)
	sim.tick(float(elapsed))
	sim.update_interactions()
	for npc_id in sim.expire_invitations():
		EventBus.npc_reaction.emit(npc_id, "invite_missed")


func build_snapshot() -> Dictionary:
	assert(sim != null, "nenhuma partida em andamento")
	if world_node != null and is_instance_valid(world_node) and world_node.has_method("sync_to_state"):
		world_node.sync_to_state()
	sim.set_time(GameClock.day, GameClock.minute)
	var res_list := []
	var ids := resources.keys()
	ids.sort()
	for id in ids:
		var r: Dictionary = resources[id]
		res_list.append({"id": r["id"], "kind": r["kind"], "item_id": r["item_id"], "available": r["available"], "respawn_day": int(r["respawn_day"])})
	return {
		"schema_version": SCHEMA_VERSION,
		"game_version": GAME_VERSION,
		"save_slot_id": save_slot_id,
		"player_id": sim.player_id,
		"island_id": island_id,
		"saved_at": Time.get_datetime_string_from_system(true) + "Z",
		"world": {
			"day": GameClock.day,
			"minute": snappedf(GameClock.minute, 0.01),
			"island_name": sim.island_name,
			"event_seq": sim.event_seq,
			"resources": res_list,
			"pair_cooldowns": sim.pair_cooldowns_to_dict(),
		},
		"player": {
			"id": sim.player_id,
			"name": sim.player_name,
			"position": {"x": snappedf(player_position.x, 0.001), "y": snappedf(player_position.y, 0.001), "z": snappedf(player_position.z, 0.001)},
			"rotation_y": snappedf(player_rotation, 0.001),
			"inventory": inventory.to_array(),
		},
		"npcs": sim.npcs_to_array(),
		"journal": sim.journal.to_array(),
	}


## Restaura a partida inteira a partir de um snapshot (substitui, nunca soma).
func apply_snapshot(snapshot: Dictionary) -> Dictionary:
	var check: Dictionary = SaveMigrator.migrate(snapshot)
	if not check["ok"]:
		return check
	var data: Dictionary = check["snapshot"]
	_bind_sim(Simulation.new())
	sim.load_from_snapshot(data, defs)
	island_id = str(data["island_id"])
	save_slot_id = str(data["save_slot_id"])
	var world: Dictionary = data["world"]
	GameClock.reset(int(world["day"]), float(world["minute"]))
	inventory.load_from(data["player"].get("inventory", []))
	_init_resources(world.get("resources", []))
	var p: Dictionary = data["player"]["position"]
	player_position = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
	player_rotation = float(data["player"].get("rotation_y", PI))
	session_active = true
	return {"ok": true}


func end_session() -> void:
	session_active = false
	GameClock.running = false
	world_node = null


func player_name() -> String:
	return sim.player_name if sim else "Jogadora"
