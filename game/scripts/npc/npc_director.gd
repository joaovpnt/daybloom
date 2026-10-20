class_name NpcDirector
extends Node
## Orquestra os oito moradores: distribui as decisões da Utility AI ao longo
## dos frames (no máximo DECISIONS_PER_FRAME por frame), detecta encontros
## espontâneos e conclui o encontro comunitário do entardecer.

const DECISIONS_PER_FRAME := 2
const ENCOUNTER_INTERVAL := 1.5

var sim: Simulation
var actors: Dictionary = {}
var decisions_made: int = 0
var stuck_events: int = 0
var stuck_log: Array = []
var interactions_started: int = 0
var _queue_index := 0
var _encounter_timer := 0.0
var _gathering_done_day := 0
var _rng := RandomNumberGenerator.new()


func setup(p_sim: Simulation, parent: Node3D) -> void:
	sim = p_sim
	_rng.randomize()
	for npc_id in sim.npc_order:
		var actor := NpcActor.new()
		parent.add_child(actor)
		actor.setup(sim.npcs[npc_id], sim, self)
		actors[npc_id] = actor
	sim.npc_state_changed.connect(_on_state_changed)
	sim.interaction_started.connect(_on_interaction_started_signal)
	sim.interaction_finished.connect(_on_interaction_finished_signal)
	EventBus.npc_reaction.connect(_on_npc_reaction)


func get_actor(npc_id: String) -> NpcActor:
	return actors.get(npc_id)


func on_navigation_ready() -> void:
	for actor in actors.values():
		actor.on_navigation_ready()


func on_interaction_started(a_id: String, b_id: String) -> void:
	interactions_started += 1
	for id in [a_id, b_id]:
		var actor: NpcActor = actors[id]
		actor.phase = NpcActor.Phase.SOCIAL
		actor.velocity = Vector3.ZERO
		actor.refresh_label()


func _on_interaction_started_signal(a_id: String, b_id: String, kind: String) -> void:
	for id in [a_id, b_id]:
		var actor: NpcActor = actors.get(id)
		if actor and actor.visible:
			actor.react("disagreement_start" if kind == SocialRules.KIND_DISAGREEMENT else "interaction_start")


func _on_interaction_finished_signal(a_id: String, b_id: String, kind: String, _outcome: Dictionary) -> void:
	for id in [a_id, b_id]:
		var actor: NpcActor = actors.get(id)
		if actor and actor.visible:
			actor.react("negative_end" if kind == SocialRules.KIND_DISAGREEMENT else "positive_end")


func _on_npc_reaction(npc_id: String, kind: String) -> void:
	var actor: NpcActor = actors.get(npc_id)
	if actor:
		actor.react(kind)


func _on_state_changed(npc_id: String, _state: String, _activity: String) -> void:
	var actor: NpcActor = actors.get(npc_id)
	if actor:
		actor.refresh_label()


func _physics_process(delta: float) -> void:
	if sim == null or actors.is_empty():
		return
	# Decisões distribuídas: varre a fila circular e decide no máximo N por frame.
	var ids: Array = sim.npc_order
	var decided := 0
	var scanned := 0
	while scanned < ids.size() and decided < DECISIONS_PER_FRAME:
		var npc_id: String = ids[_queue_index % ids.size()]
		_queue_index += 1
		scanned += 1
		var actor: NpcActor = actors[npc_id]
		if actor.needs_decision() and actor._nav_ready:
			var ctx := {"minute": sim.minute, "abs": sim.now_abs(), "day": sim.day}
			var plan := UtilityBrain.choose_action(sim.npcs[npc_id], sim, ctx, sim.rng)
			actor.start_action(plan)
			decided += 1
			decisions_made += 1
	_encounter_timer -= delta
	if _encounter_timer <= 0.0:
		_encounter_timer = ENCOUNTER_INTERVAL
		_check_encounters()
	_check_gathering()


## Encontros espontâneos: dois moradores disponíveis e próximos podem parar
## para conversar, conforme sociabilidade.
func _check_encounters() -> void:
	var ids: Array = sim.npc_order
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: NpcState = sim.npcs[ids[i]]
			var b: NpcState = sim.npcs[ids[j]]
			if not a.is_available() or not b.is_available():
				continue
			if a.state in ["WORKING", "RESTING"] or b.state in ["WORKING", "RESTING"]:
				continue
			var aa: NpcActor = actors[a.id]
			var ab: NpcActor = actors[b.id]
			var dist := aa.global_position.distance_to(ab.global_position)
			if dist > SocialRules.MEET_DISTANCE:
				continue
			var chance := 0.15 + (a.trait_value("sociabilidade") + b.trait_value("sociabilidade")) * 0.2
			if _rng.randf() > chance:
				continue
			var res := sim.try_start_interaction(a.id, b.id, dist)
			if res["ok"]:
				on_interaction_started(a.id, b.id)


func _check_gathering() -> void:
	if sim.minute < UtilityBrain.GATHERING_END or sim.minute > UtilityBrain.GATHERING_END + 30.0:
		return
	if _gathering_done_day == sim.day:
		return
	_gathering_done_day = sim.day
	var attendees := []
	for npc_id in sim.npc_order:
		var npc: NpcState = sim.npcs[npc_id]
		var actor: NpcActor = actors[npc_id]
		if npc.inside_home or npc.is_sleeping():
			continue
		if actor.global_position.distance_to(Places.poi_pos("praca")) <= 8.5:
			attendees.append(npc_id)
	sim.conclude_gathering(attendees)


func sync_positions() -> void:
	for npc_id in actors:
		var actor: NpcActor = actors[npc_id]
		sim.npcs[npc_id].position = actor.global_position
		sim.npcs[npc_id].rotation_y = actor.rotation.y
