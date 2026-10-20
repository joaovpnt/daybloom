class_name NpcActor
extends CharacterBody3D
## Representação física de um morador. Executa o plano escolhido pela Utility
## AI como uma máquina de estados (ocioso → andando → executando → ...),
## navega pelo NavigationAgent3D e detecta quando fica preso.

enum Phase { NEEDS_DECISION, MOVING, PERFORMING, SOCIAL, TALKING_PLAYER, INSIDE_HOME }

const WALK_SPEED := 2.7
const ARRIVE_DISTANCE := 0.7
const STUCK_CHECK_INTERVAL := 1.0
const MAX_TRAVEL_SECONDS := 75.0

var npc: NpcState
var sim: Simulation
var director: Node
var agent: NavigationAgent3D
var visual: CharacterVisual
var name_label: Label3D
var emote: EmoteBubble
var label_height: float = 1.6

var phase: Phase = Phase.NEEDS_DECISION
var action: Dictionary = {}
var action_end_abs: float = 0.0
var talk_partner: Node3D = null

var _travel_time := 0.0
var _stuck_timer := 0.0
var _stuck_count := 0
var _last_pos := Vector3.ZERO
var _retarget_timer := 0.0
var _check_timer := 0.0
var _walk_phase := 0.0
var _nav_ready := false


func setup(p_npc: NpcState, p_sim: Simulation, p_director: Node) -> void:
	npc = p_npc
	sim = p_sim
	director = p_director
	name = "Morador_" + npc.id
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.4
	shape.shape = capsule
	shape.position = Vector3(0, 0.7, 0)
	add_child(shape)
	visual = CharacterVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup("characters/villager_%s" % npc.id)
	label_height = 1.45 * npc.def.height_scale + 0.25
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = ARRIVE_DISTANCE
	agent.radius = 0.4
	agent.height = 1.4
	agent.path_max_distance = 3.0
	add_child(agent)
	name_label = Label3D.new()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font = UiTheme.font_bold()
	name_label.font_size = 40
	name_label.pixel_size = 0.0042
	name_label.outline_size = 14
	name_label.modulate = Color(0.32, 0.22, 0.15)
	name_label.outline_modulate = Color(1, 0.98, 0.92)
	name_label.position = Vector3(0, label_height + 0.15, 0)
	name_label.visibility_range_end = 11.0
	name_label.visibility_range_end_margin = 2.0
	name_label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(name_label)
	emote = EmoteBubble.new()
	emote.position = Vector3(0.0, label_height + 0.7, 0)
	add_child(emote)
	add_to_group("interactable")
	add_to_group("npc_actor")
	global_position = npc.position
	rotation.y = npc.rotation_y
	if npc.inside_home:
		_enter_home_visual()
		phase = Phase.INSIDE_HOME
		# Após carregar, o morador continua dormindo até a IA decidir acordar.
		action = {"kind": "sleep", "activity": "dormindo", "arrive_state": "RESTING", "duration": 30.0}
		action_end_abs = sim.now_abs() + 10.0
	_update_label()


func on_navigation_ready() -> void:
	_nav_ready = true
	if not npc.inside_home:
		var map := get_world_3d().navigation_map
		var p := NavigationServer3D.map_get_closest_point(map, global_position)
		if p.distance_to(global_position) > 0.3:
			global_position = p


func needs_decision() -> bool:
	return phase == Phase.NEEDS_DECISION


## Recebe o plano escolhido pela Utility AI e começa a executá-lo.
func start_action(new_action: Dictionary) -> void:
	action = new_action
	npc.current_action = new_action
	npc.action_log.append(new_action["kind"])
	if npc.action_log.size() > 12:
		npc.action_log.pop_front()
	if npc.inside_home and new_action.get("kind", "") == "sleep":
		# Continua dormindo.
		phase = Phase.INSIDE_HOME
		action_end_abs = sim.now_abs() + float(new_action["duration"])
		sim.set_npc_state(npc.id, "RESTING", "dormindo")
		return
	if npc.inside_home:
		_exit_home_visual()
	_travel_time = 0.0
	_stuck_count = 0
	_stuck_timer = 0.0
	_last_pos = global_position
	agent.target_position = new_action["target_pos"]
	phase = Phase.MOVING
	var dest := ""
	if new_action.get("target_npc", "") != "":
		dest = "indo ver " + sim.npcs[new_action["target_npc"]].display_name()
	elif new_action.get("kind", "") == "sleep":
		dest = "voltando para casa"
	elif new_action.get("place", "") != "":
		dest = "indo para " + _place_with_article(new_action["place"])
	else:
		dest = "passeando"
	sim.set_npc_state(npc.id, "WALKING", dest)
	_update_label()


func _place_with_article(place: String) -> String:
	var label := Places.poi_label(place)
	if place.begins_with("casa_"):
		if place == npc.def.home_id:
			return "casa"
		return "a " + label.to_lower()
	return ("o " if Simulation._prep(label) == "o" else "a ") + label


func _physics_process(delta: float) -> void:
	if npc == null:
		return
	# Interações começam/terminam na simulação; o ator apenas acompanha.
	if npc.partner_id != "" and phase != Phase.SOCIAL and phase != Phase.TALKING_PLAYER:
		if npc.partner_id == sim.player_id:
			phase = Phase.TALKING_PLAYER
		else:
			phase = Phase.SOCIAL
		velocity = Vector3.ZERO
	match phase:
		Phase.MOVING:
			_process_moving(delta)
		Phase.PERFORMING:
			_process_performing(delta)
		Phase.SOCIAL:
			_process_social(delta)
		Phase.TALKING_PLAYER:
			_process_talking(delta)
		Phase.INSIDE_HOME:
			if sim.now_abs() >= action_end_abs:
				_finish_action(true)
			return
		Phase.NEEDS_DECISION:
			velocity = Vector3.ZERO
	_animate(delta)
	npc.position = global_position
	npc.rotation_y = rotation.y


func _process_moving(delta: float) -> void:
	if not _nav_ready:
		return
	_travel_time += delta
	var target_npc: String = action.get("target_npc", "")
	if target_npc != "":
		var other_actor: NpcActor = director.get_actor(target_npc)
		var other: NpcState = sim.npcs[target_npc]
		if other_actor == null or not other.is_available():
			if other.partner_id != npc.id:
				_finish_action(false)
				return
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = 0.4
			agent.target_position = other_actor.global_position
		var dist := global_position.distance_to(other_actor.global_position)
		if dist <= SocialRules.MEET_DISTANCE - 0.2:
			var res := sim.try_start_interaction(npc.id, target_npc, dist)
			if res["ok"]:
				director.on_interaction_started(npc.id, target_npc)
				return
			_finish_action(false)
			return
	elif agent.is_navigation_finished() or _flat_distance(global_position, action["target_pos"]) <= ARRIVE_DISTANCE:
		_arrive()
		return
	if _travel_time > MAX_TRAVEL_SECONDS:
		_finish_action(false)
		return
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 8.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	_check_stuck(delta)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _check_stuck(delta: float) -> void:
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK_INTERVAL:
		return
	_stuck_timer = 0.0
	if global_position.distance_to(_last_pos) < 0.35:
		_stuck_count += 1
		if _stuck_count == 2:
			# Tenta um pequeno desvio lateral.
			var side := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			global_position += side.normalized() * 0.3
			agent.target_position = agent.target_position
		elif _stuck_count >= 4:
			# Desiste do plano e reposiciona no navmesh mais próximo.
			var map := get_world_3d().navigation_map
			global_position = NavigationServer3D.map_get_closest_point(map, global_position)
			director.stuck_events += 1
			director.stuck_log.append({"npc": npc.id, "pos": global_position, "target": action.get("target_pos"), "kind": action.get("kind"), "place": action.get("place", "")})
			_finish_action(false)
	else:
		_stuck_count = 0
	_last_pos = global_position


func _arrive() -> void:
	velocity = Vector3.ZERO
	var kind: String = action.get("kind", "wander")
	if kind == "socialize":
		_finish_action(false)
		return
	sim.set_npc_state(npc.id, action["arrive_state"], action["activity"])
	action_end_abs = sim.now_abs() + float(action["duration"])
	if action.get("enter_home", false):
		_enter_home_visual()
		phase = Phase.INSIDE_HOME
	else:
		phase = Phase.PERFORMING
		_face_activity()
	_update_label()


func _face_activity() -> void:
	var place: String = action.get("place", "")
	if place != "" and Places.POIS.has(place):
		var c := Places.poi_pos(place)
		var d := c - global_position
		if Vector2(d.x, d.z).length() > 0.3:
			rotation.y = atan2(d.x, d.z)


func _process_performing(delta: float) -> void:
	velocity = Vector3.ZERO
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.5
		if should_interrupt():
			_finish_action(false)
			return
	if sim.now_abs() >= action_end_abs:
		_finish_action(true)


## Interrompe atividades quando surge algo mais urgente (sono, exaustão).
func should_interrupt() -> bool:
	var kind: String = action.get("kind", "")
	if kind == "sleep":
		return false
	var hour := sim.minute / 60.0
	if UtilityBrain.is_sleep_time(npc.def, hour) and kind != "gathering":
		return true
	if npc.need("energia") < 8.0:
		return true
	return false


func _process_social(_delta: float) -> void:
	velocity = Vector3.ZERO
	if npc.partner_id == "":
		sim.set_npc_state(npc.id, "IDLE", "parado")
		phase = Phase.NEEDS_DECISION
		_update_label()
		return
	var partner: NpcActor = director.get_actor(npc.partner_id)
	if partner:
		var d := partner.global_position - global_position
		if Vector2(d.x, d.z).length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 0.2)


func _process_talking(_delta: float) -> void:
	velocity = Vector3.ZERO
	if npc.partner_id != sim.player_id:
		phase = Phase.NEEDS_DECISION
		sim.set_npc_state(npc.id, "IDLE", "parado")
		_update_label()
		return
	if talk_partner:
		var d := talk_partner.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 0.25)


func _finish_action(completed: bool) -> void:
	if completed:
		sim.complete_activity(npc.id, action)
		if action.get("kind", "") in ["work", "leisure"] and visible:
			react("activity_done")
	if npc.inside_home and action.get("kind", "") == "sleep":
		_exit_home_visual()
	velocity = Vector3.ZERO
	if npc.partner_id == "":
		sim.set_npc_state(npc.id, "IDLE", "parado")
	phase = Phase.NEEDS_DECISION
	npc.current_action = {}
	_update_label()


func _enter_home_visual() -> void:
	npc.inside_home = true
	visible = false
	collision_layer = 0
	global_position = Places.house_door(npc.def.home_id)


func _exit_home_visual() -> void:
	npc.inside_home = false
	visible = true
	collision_layer = 4
	global_position = Places.house_door(npc.def.home_id) + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
	if _nav_ready:
		global_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position)


## Conversa com a jogadora: interrompe o que estava fazendo (sem registrar
## a interação social interrompida) e fica de frente para ela.
func begin_player_talk(player: Node3D) -> void:
	if npc.partner_id != "" and npc.partner_id != sim.player_id:
		var other_id := npc.partner_id
		sim.cancel_interaction(npc.id)
		var other_actor: NpcActor = director.get_actor(other_id)
		if other_actor:
			other_actor.phase = Phase.NEEDS_DECISION
			sim.set_npc_state(other_id, "IDLE", "parado")
	npc.partner_id = sim.player_id
	talk_partner = player
	phase = Phase.TALKING_PLAYER
	velocity = Vector3.ZERO
	sim.set_npc_state(npc.id, "SOCIALIZING", "conversando com " + sim.player_name)
	react("greet_player")
	_update_label()


func end_player_talk() -> void:
	if npc.partner_id == sim.player_id:
		npc.partner_id = ""
	talk_partner = null
	phase = Phase.NEEDS_DECISION
	sim.set_npc_state(npc.id, "IDLE", "parado")
	_update_label()


func _update_label() -> void:
	if name_label == null:
		return
	name_label.text = npc.display_name()
	var style := ""
	if npc.state == "SOCIALIZING" and npc.partner_id != "":
		var key := SocialRules.pair_key(npc.id, npc.partner_id)
		var it: Dictionary = sim.active_interactions.get(key, {})
		match it.get("kind", ""):
			SocialRules.KIND_DISAGREEMENT:
				style = "angry"
			SocialRules.KIND_RECONCILIATION:
				style = "love"
			SocialRules.KIND_SHARED:
				style = "music"
			_:
				style = "chat"
	elif npc.state == "LEISURE":
		style = "music"
	elif npc.mood == "triste" or npc.mood.begins_with("chatead"):
		style = "sad"
	emote.set_persistent(style)
	visual.set_base_expression(expression_for_mood())


## Expressão facial de base derivada do humor real do morador.
func expression_for_mood() -> String:
	var m := npc.mood
	if npc.is_sleeping():
		return "sleep"
	if m == "radiante":
		return "happy"
	if m == "triste" or m.begins_with("chatead") or m.begins_with("solit"):
		return "sad"
	if m.begins_with("cansad"):
		return "tired"
	return "neutral"


## Reações visuais a acontecimentos reais da simulação.
func react(kind: String) -> void:
	match kind:
		"gift_loved":
			visual.play_once("happy")
			visual.flash_expression("happy", 3.0)
			emote.flash("love", 2.5)
		"gift_liked":
			visual.flash_expression("happy", 2.0)
			emote.flash("love", 1.5)
		"gift_disliked":
			visual.play_once("sad")
			visual.flash_expression("sad", 3.0)
			emote.flash("sad", 2.0)
		"interaction_start":
			visual.play_once("surprised")
			emote.flash("surprise", 1.0)
		"disagreement_start":
			visual.play_once("surprised")
			visual.flash_expression("angry", 4.0)
			emote.flash("angry", 2.0)
		"positive_end":
			visual.play_once("happy")
			visual.flash_expression("happy", 2.5)
			emote.flash("love", 1.5)
		"negative_end":
			visual.flash_expression("sad", 5.0)
			emote.flash("sad", 2.5)
		"activity_done":
			visual.flash_expression("happy", 1.5)
			emote.flash("done", 1.4)
		"greet_player":
			visual.play_once("surprised")
			visual.flash_expression("happy", 2.0)
			emote.flash("surprise", 1.0)


func refresh_label() -> void:
	_update_label()


func _animate(_delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	visual.talking = phase == Phase.SOCIAL or phase == Phase.TALKING_PLAYER
	if speed > 0.2:
		visual.play("walk", clampf(speed / WALK_SPEED, 0.6, 1.3))
	elif visual.talking:
		visual.play("talk")
	elif expression_for_mood() == "sad" and phase == Phase.PERFORMING:
		visual.play("sad")
	else:
		visual.play("idle")


# --- interação da jogadora ----------------------------------------------

func can_interact() -> bool:
	return visible and not npc.inside_home


func get_interaction_text() -> String:
	if npc.is_sleeping():
		return "%s está dormindo" % npc.display_name()
	return "Conversar com %s · %s" % [npc.display_name(), npc.activity]


func interact(player: Node) -> void:
	EventBus.dialogue_requested.emit(npc.id)
