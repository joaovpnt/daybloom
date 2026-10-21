class_name PlayerLife
extends RefCounted
## Vida da jogadora no prédio: necessidades, humor, carteira, emprego, andar
## atual e primeiras visitas. Tudo aqui é persistido no save.

var needs: NeedsComponent
var needs_data: Dictionary = {}
var mood_mods: Array = []
var mood: Dictionary = {"state": "neutro", "valence": 0.0, "causes": []}
var wallet := Wallet.new()
var job: Dictionary = JobSystem.new_state()
var floor_id: String = "andar_9"
## Primeira visita a cada morador: npc_id -> dia.
var visited: Dictionary = {}
## Ação em andamento (transitória).
var current_action: Dictionary = {}


func _init() -> void:
	needs_data = {"fome": 80.0, "energia": 85.0, "higiene": 80.0, "banheiro": 85.0, "diversao": 70.0, "social": 60.0, "conforto": 65.0}
	needs = NeedsComponent.new(needs_data)


func setup_new(time: Dictionary) -> void:
	_init()
	mood_mods = []
	wallet = Wallet.new()
	wallet.credit(Wallet.START_BALANCE, "inicial", "Boas-vindas do Daybloom Residence", "boas_vindas", time)
	job = JobSystem.new_state()
	floor_id = BuildingLayout.floor_of_owner("player")
	visited = {}


func add_mood(id: String, cause: String, state: String, intensity: float, duration: float, now: float) -> void:
	MoodSystem.add_modifier(mood_mods, id, cause, state, intensity, duration, now)


func evaluate_mood(now: float) -> Dictionary:
	MoodSystem.prune(mood_mods, now)
	mood = MoodSystem.evaluate(needs.values, mood_mods, now, {"gentileza": 0.6, "energia": 0.6}, current_action.get("id", "") == "dormir")
	return mood


func to_dict() -> Dictionary:
	return {
		"needs": needs.to_dict(),
		"mood_mods": MoodSystem.mods_to_array(mood_mods),
		"wallet": wallet.to_dict(),
		"job": job.duplicate(true),
		"floor": floor_id,
		"visited": visited.duplicate(),
	}


func load_from(data: Dictionary, now: float) -> void:
	_init()
	var nd: Dictionary = data.get("needs", {})
	for k in NeedsComponent.KEYS:
		if nd.has(k):
			needs.set_value(k, float(nd[k]))
	mood_mods = MoodSystem.mods_from_array(data.get("mood_mods", []), now)
	wallet = Wallet.new()
	if data.has("wallet"):
		wallet.load_from(data["wallet"])
	else:
		wallet.balance = Wallet.START_BALANCE
	job = JobSystem.load_state(data.get("job", {}))
	var f := str(data.get("floor", "andar_9"))
	floor_id = f if BuildingLayout.has_floor(f) else "andar_9"
	visited = {}
	var vd: Dictionary = data.get("visited", {})
	for k in vd:
		visited[str(k)] = int(vd[k])
	current_action = {}
