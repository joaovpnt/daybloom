class_name NpcState
extends RefCounted
## Estado dinâmico de um morador (necessidades, humor, estado, andar e
## posição...). A definição estática (personalidade base, gostos, rotina) vem
## de NpcDefinition.

const STATES := ["IDLE", "WALKING", "RESTING", "WORKING", "SOCIALIZING", "EXPLORING", "LEISURE"]
const NEED_KEYS := NeedsComponent.KEYS
const STATE_LABELS := {"IDLE": "parado", "WALKING": "andando", "RESTING": "descansando", "WORKING": "trabalhando", "SOCIALIZING": "socializando", "EXPLORING": "explorando", "LEISURE": "lazer"}

var def: NpcDefinition
var id: String = ""
var traits: Dictionary = {}
var needs: Dictionary = {"fome": 75.0, "energia": 85.0, "higiene": 80.0, "banheiro": 80.0, "diversao": 60.0, "social": 60.0, "conforto": 70.0}
## Humor (0.4): estado do momento ("feliz", "cansado"...) e palavra exibida.
var mood_state: String = "neutro"
var mood: String = "neutra"
var valence: float = 0.2
## Modificador emocional genérico (acontecimentos), decai com o tempo.
var mood_modifier: float = 0.0
## Modificadores com causa e duração (MoodSystem).
var mood_mods: Array = []
var state: String = "IDLE"
var activity: String = "parado"
## Andar atual e posição local nesse andar.
var floor_id: String = ""
var position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
## No elevador/escadas entre andares (transitório).
var in_transit: bool = false
var cooldowns: Dictionary = {}
var goal_progress: float = 0.0
## Comida em casa (refeições). Quando acaba, o morador vai ao mercadinho.
var pantry: int = 3
## Objetivo em etapas: {step, counts, started_day, completed_day, plan_note, legacy}
var goal_state: Dictionary = {"step": 0, "counts": {}, "started_day": 0, "completed_day": 0, "plan_note": ""}
var learned_likes: Array = []
var gift_counts: Dictionary = {}
var told_player: Array = []
var requests: Dictionary = {}
## Minuto absoluto mais recente visto pela simulação (para o humor).
var clock_now: float = 0.0

# Estado transitório (não persistido).
var pending_initiatives: Dictionary = {}
var invitation: Dictionary = {}
var drift_today: Dictionary = {}
var current_action: Dictionary = {}
var partner_id: String = ""
var action_log: Array = []
## Ação doméstica em andamento (taxas de necessidades e conforto do assento).
var action_rates: Dictionary = {}
var action_activity: String = ""
var comfort_target: float = 50.0
## Papel em uma situação social ou evento (ex.: anfitrião de visita).
var role: Dictionary = {}


func _init(definition: NpcDefinition = null) -> void:
	if definition != null:
		def = definition
		id = definition.id
		traits = definition.traits()
		floor_id = home_floor()


func home_floor() -> String:
	return BuildingLayout.floor_of_owner(id)


func home_place() -> String:
	return Places.apt_id(id)


## Está dentro do próprio apartamento?
func is_home() -> bool:
	return floor_id == home_floor() and not in_transit and BuildingLayout.in_apartment(floor_id, position)


func preference_for(item_id: String) -> int:
	if learned_likes.has(item_id):
		return 1
	return def.preference_for(item_id) if def else 0


func display_name() -> String:
	return def.display_name if def else id


func is_sleeping() -> bool:
	return state == "RESTING" and activity == "dormindo"


func is_busy_with_partner() -> bool:
	return partner_id != ""


## Disponível para uma interação social (com outro morador ou com a jogadora).
func is_available() -> bool:
	return not is_sleeping() and partner_id == "" and not in_transit and role.get("busy", false) == false


func set_state(new_state: String, new_activity: String) -> bool:
	assert(new_state in STATES, "estado inválido: %s" % new_state)
	if new_state == state and new_activity == activity:
		return false
	state = new_state
	activity = new_activity
	return true


func need(key: String) -> float:
	return float(needs.get(key, 50.0))


func add_need(key: String, amount: float) -> void:
	needs[key] = clampf(need(key) + amount, 0.0, 100.0)


func needs_component() -> NeedsComponent:
	return NeedsComponent.new(needs)


func trait_value(key: String) -> float:
	return float(traits.get(key, 0.5))


func cooldown_ready(key: String, now_abs: float) -> bool:
	return now_abs >= float(cooldowns.get(key, -INF))


func set_cooldown(key: String, now_abs: float, minutes: float) -> void:
	cooldowns[key] = now_abs + minutes


func prune_cooldowns(now_abs: float) -> void:
	for key in cooldowns.keys():
		if float(cooldowns[key]) < now_abs:
			cooldowns.erase(key)


func add_mood(mod_id: String, cause: String, state_key: String, intensity: float, duration: float) -> void:
	MoodSystem.add_modifier(mood_mods, mod_id, cause, state_key, intensity, duration, clock_now)


## Recalcula o humor a partir das necessidades, modificadores e acontecimentos.
func update_emotion() -> void:
	MoodSystem.prune(mood_mods, clock_now)
	var mods := mood_mods.duplicate()
	if mood_modifier > 0.05:
		mods.append({"id": "_mod", "cause": "bons momentos", "state": "feliz", "intensity": mood_modifier, "started": clock_now - 1.0, "until": clock_now + 9999.0})
	elif mood_modifier < -0.05:
		mods.append({"id": "_mod", "cause": "acontecimentos ruins", "state": "triste", "intensity": -mood_modifier, "started": clock_now - 1.0, "until": clock_now + 9999.0})
	var ev := MoodSystem.evaluate(needs, mods, clock_now, traits, is_sleeping())
	mood_state = str(ev["state"])
	valence = clampf(float(ev["valence"]) + (trait_value("gentileza") - 0.5) * 0.1, -1.0, 1.0)
	mood = "dormindo" if is_sleeping() else MoodSystem.word(mood_state, def.article() if def else "a")


func mood_causes() -> Array:
	var out := []
	for m in MoodSystem.describe(mood_mods, clock_now):
		out.append(m["cause"])
	return out


func to_dict(relationships: Dictionary, memories: Array) -> Dictionary:
	var pos := {"x": snappedf(position.x, 0.001), "y": snappedf(position.y, 0.001), "z": snappedf(position.z, 0.001)}
	return {
		"id": id,
		"name": display_name(),
		"species": def.species if def else "",
		"personality": traits.duplicate(),
		"needs": _rounded(needs),
		"emotion": {"mood": mood, "valence": snappedf(valence, 0.001), "modifier": snappedf(mood_modifier, 0.001), "state": mood_state, "mods": MoodSystem.mods_to_array(mood_mods)},
		"state": state,
		"activity": activity,
		"floor": floor_id,
		"position": pos,
		"rotation_y": snappedf(rotation_y, 0.001),
		"inside_home": is_home(),
		"pantry": pantry,
		"personal_goal": {
			"id": def.personal_goal_id if def else "",
			"description": def.personal_goal if def else "",
			"progress": snappedf(goal_progress, 0.001),
			"step": int(goal_state.get("step", 0)),
			"counts": (goal_state.get("counts", {}) as Dictionary).duplicate(),
			"started_day": int(goal_state.get("started_day", 0)),
			"completed_day": int(goal_state.get("completed_day", 0)),
			"plan_note": str(goal_state.get("plan_note", "")),
			"legacy": (goal_state.get("legacy", {}) as Dictionary).duplicate(true),
		},
		"learned_likes": learned_likes.duplicate(),
		"gift_counts": gift_counts.duplicate(),
		"told_player": told_player.duplicate(),
		"requests": _rounded(requests),
		"relationships": relationships,
		"memories": memories,
		"cooldowns": _rounded(cooldowns),
	}


func apply_dict(data: Dictionary, now: float = 0.0) -> void:
	clock_now = now
	var saved_traits: Dictionary = data.get("personality", {})
	for key in saved_traits:
		traits[key] = clampf(float(saved_traits[key]), 0.0, 1.0)
	var saved_needs: Dictionary = data.get("needs", {})
	for key in NEED_KEYS:
		if saved_needs.has(key):
			needs[key] = clampf(float(saved_needs[key]), 0.0, 100.0)
	var emotion: Dictionary = data.get("emotion", {})
	valence = clampf(float(emotion.get("valence", valence)), -1.0, 1.0)
	mood_modifier = clampf(float(emotion.get("modifier", 0.0)), -1.0, 1.0)
	mood_mods = MoodSystem.mods_from_array(emotion.get("mods", []), now)
	var ms := str(emotion.get("state", "neutro"))
	mood_state = ms if ms in MoodSystem.STATES else "neutro"
	var saved_state := str(data.get("state", "IDLE"))
	state = saved_state if saved_state in STATES else "IDLE"
	activity = str(data.get("activity", "parado"))
	var f := str(data.get("floor", ""))
	floor_id = f if BuildingLayout.has_floor(f) else home_floor()
	var p: Dictionary = data.get("position", {})
	position = BuildingLayout.clamp_to_floor(floor_id, Vector3(float(p.get("x", 0.0)), 0.0, float(p.get("z", 0.0))))
	rotation_y = float(data.get("rotation_y", 0.0))
	in_transit = false
	pantry = clampi(int(data.get("pantry", 3)), 0, 10)
	var goal: Dictionary = data.get("personal_goal", {})
	var n_steps := GoalLibrary.steps(def.personal_goal_id if def else "").size()
	var counts := {}
	var saved_counts: Dictionary = goal.get("counts", {})
	for k in saved_counts:
		counts[str(k)] = int(saved_counts[k])
	goal_progress = clampf(float(goal.get("progress", 0.0)), 0.0, 1.0)
	goal_state = {
		"step": clampi(int(goal.get("step", int(goal_progress * n_steps))), 0, n_steps),
		"counts": counts,
		"started_day": int(goal.get("started_day", 0)),
		"completed_day": int(goal.get("completed_day", 0)),
		"plan_note": str(goal.get("plan_note", "")).substr(0, 160),
		"legacy": (goal.get("legacy", {}) as Dictionary).duplicate(true) if goal.get("legacy", {}) is Dictionary else {},
	}
	learned_likes = []
	for it in data.get("learned_likes", []):
		if ItemDB.exists(str(it)) and learned_likes.size() < 3:
			learned_likes.append(str(it))
	gift_counts = {}
	var gc: Dictionary = data.get("gift_counts", {})
	for k in gc:
		gift_counts[str(k)] = int(gc[k])
	told_player = []
	for e in data.get("told_player", []):
		told_player.append(str(e))
	requests = {}
	var rq: Dictionary = data.get("requests", {})
	for k in rq:
		if ItemDB.exists(str(k)):
			requests[str(k)] = float(rq[k])
	pending_initiatives = {}
	invitation = {}
	cooldowns = {}
	var saved_cd: Dictionary = data.get("cooldowns", {})
	for key in saved_cd:
		cooldowns[str(key)] = float(saved_cd[key])
	current_action = {}
	partner_id = ""
	role = {}
	action_rates = {}
	update_emotion()


static func _rounded(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		out[key] = snappedf(float(d[key]), 0.001)
	return out
