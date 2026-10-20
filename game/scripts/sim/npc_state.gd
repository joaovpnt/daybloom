class_name NpcState
extends RefCounted
## Estado dinâmico de um morador (necessidades, emoção, estado, posição...).
## A definição estática (personalidade base, gostos, rotina) vem de NpcDefinition.

const STATES := ["IDLE", "WALKING", "RESTING", "WORKING", "SOCIALIZING", "EXPLORING", "LEISURE"]
const NEED_KEYS := ["energia", "social", "diversao", "conforto"]

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

# Estado de execução (não persistido; recriado pela IA após carregar).
var current_action: Dictionary = {}
var partner_id: String = ""
var action_log: Array = []


func _init(definition: NpcDefinition = null) -> void:
	if definition != null:
		def = definition
		id = definition.id
		traits = definition.traits()


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
		"personal_goal": {"id": def.personal_goal_id if def else "", "description": def.personal_goal if def else "", "progress": snappedf(goal_progress, 0.001)},
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
