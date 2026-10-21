class_name NpcState
extends RefCounted
## Estado dinâmico de um morador (necessidades, emoção, estado, posição...).
## A definição estática (personalidade base, gostos, rotina) vem de NpcDefinition.

const STATES := ["IDLE", "WALKING", "RESTING", "WORKING", "SOCIALIZING", "EXPLORING", "LEISURE"]
const NEED_KEYS := ["energia", "social", "diversao", "conforto"]
const STATE_LABELS := {"IDLE": "parado", "WALKING": "andando", "RESTING": "descansando", "WORKING": "trabalhando", "SOCIALIZING": "socializando", "EXPLORING": "explorando", "LEISURE": "lazer"}

var def: NpcDefinition
var id: String = ""
var traits: Dictionary = {}
var needs: Dictionary = {"energia": 85.0, "social": 60.0, "diversao": 60.0, "conforto": 70.0}
var mood: String = "tranquilo"
var valence: float = 0.2
## Modificador emocional temporário causado por acontecimentos (decai com o tempo).
var mood_modifier: float = 0.0
var state: String = "IDLE"
var activity: String = "parado"
var position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
var cooldowns: Dictionary = {}
var goal_progress: float = 0.0
var inside_home: bool = false
## Objetivo em etapas (0.3): {step, counts, started_day, completed_day, plan_note}
var goal_state: Dictionary = {"step": 0, "counts": {}, "started_day": 0, "completed_day": 0, "plan_note": ""}
## Preferências aprendidas com experiências marcantes (no máximo 3).
var learned_likes: Array = []
## Quantas vezes recebeu cada item da jogadora.
var gift_counts: Dictionary = {}
## Acontecimentos que já contou para a jogadora (evita repetir novidades).
var told_player: Array = []
## Pedidos feitos à jogadora: item_id -> minuto absoluto em que expira.
var requests: Dictionary = {}

# Estado transitório (não persistido).
var pending_initiatives: Dictionary = {}
var invitation: Dictionary = {}
var drift_today: Dictionary = {}

# Estado de execução (não persistido; recriado pela IA após carregar).
var current_action: Dictionary = {}
var partner_id: String = ""
var action_log: Array = []


func _init(definition: NpcDefinition = null) -> void:
	if definition != null:
		def = definition
		id = definition.id
		traits = definition.traits()


## Preferência por um item, incluindo gostos aprendidos.
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
	return not is_sleeping() and not inside_home and partner_id == ""


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


func update_emotion() -> void:
	var avg := 0.0
	for key in NEED_KEYS:
		avg += need(key)
	avg /= NEED_KEYS.size()
	valence = clampf((avg - 50.0) / 50.0 * 0.7 + mood_modifier + (trait_value("gentileza") - 0.5) * 0.1, -1.0, 1.0)
	if is_sleeping():
		mood = "dormindo"
	elif need("energia") < 20.0:
		mood = "cansad" + def.article()
	elif need("social") < 18.0:
		mood = "solitári" + def.article()
	elif need("diversao") < 18.0:
		mood = "entediad" + def.article()
	elif valence > 0.6:
		mood = "radiante"
	elif valence > 0.25:
		mood = "alegre"
	elif valence > -0.1:
		mood = "tranquil" + def.article()
	elif valence > -0.45:
		mood = "chatead" + def.article()
	else:
		mood = "triste"


func to_dict(relationships: Dictionary, memories: Array) -> Dictionary:
	var pos := {"x": snappedf(position.x, 0.001), "y": snappedf(position.y, 0.001), "z": snappedf(position.z, 0.001)}
	return {
		"id": id,
		"name": display_name(),
		"species": def.species if def else "",
		"personality": traits.duplicate(),
		"needs": _rounded(needs),
		"emotion": {"mood": mood, "valence": snappedf(valence, 0.001), "modifier": snappedf(mood_modifier, 0.001)},
		"state": state,
		"activity": activity,
		"position": pos,
		"rotation_y": snappedf(rotation_y, 0.001),
		"inside_home": inside_home,
		"personal_goal": {
			"id": def.personal_goal_id if def else "",
			"description": def.personal_goal if def else "",
			"progress": snappedf(goal_progress, 0.001),
			"step": int(goal_state.get("step", 0)),
			"counts": (goal_state.get("counts", {}) as Dictionary).duplicate(),
			"started_day": int(goal_state.get("started_day", 0)),
			"completed_day": int(goal_state.get("completed_day", 0)),
			"plan_note": str(goal_state.get("plan_note", "")),
		},
		"learned_likes": learned_likes.duplicate(),
		"gift_counts": gift_counts.duplicate(),
		"told_player": told_player.duplicate(),
		"requests": _rounded(requests),
		"relationships": relationships,
		"memories": memories,
		"cooldowns": _rounded(cooldowns),
	}


func apply_dict(data: Dictionary) -> void:
	var saved_traits: Dictionary = data.get("personality", {})
	for key in saved_traits:
		traits[key] = clampf(float(saved_traits[key]), 0.0, 1.0)
	var saved_needs: Dictionary = data.get("needs", {})
	for key in NEED_KEYS:
		if saved_needs.has(key):
			needs[key] = clampf(float(saved_needs[key]), 0.0, 100.0)
	var emotion: Dictionary = data.get("emotion", {})
	mood = str(emotion.get("mood", mood))
	valence = clampf(float(emotion.get("valence", valence)), -1.0, 1.0)
	mood_modifier = clampf(float(emotion.get("modifier", 0.0)), -1.0, 1.0)
	var saved_state := str(data.get("state", "IDLE"))
	state = saved_state if saved_state in STATES else "IDLE"
	activity = str(data.get("activity", "parado"))
	var p: Dictionary = data.get("position", {})
	position = Vector3(float(p.get("x", 0.0)), float(p.get("y", 0.0)), float(p.get("z", 0.0)))
	rotation_y = float(data.get("rotation_y", 0.0))
	inside_home = bool(data.get("inside_home", false))
	var goal: Dictionary = data.get("personal_goal", {})
	goal_progress = clampf(float(goal.get("progress", 0.0)), 0.0, 1.0)
	var n_steps := GoalLibrary.steps(def.personal_goal_id if def else "").size()
	var counts := {}
	var saved_counts: Dictionary = goal.get("counts", {})
	for k in saved_counts:
		counts[str(k)] = int(saved_counts[k])
	goal_state = {
		# Saves antigos (sem etapas): deriva a etapa do progresso salvo.
		"step": clampi(int(goal.get("step", int(goal_progress * n_steps))), 0, n_steps),
		"counts": counts,
		"started_day": int(goal.get("started_day", 0)),
		"completed_day": int(goal.get("completed_day", 0)),
		"plan_note": str(goal.get("plan_note", "")).substr(0, 160),
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


static func _rounded(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		out[key] = snappedf(float(d[key]), 0.001)
	return out
