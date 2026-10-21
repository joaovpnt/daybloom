class_name UtilityBrain
extends RefCounted
## Utility AI (0.4): pontua cada ação possível a partir de necessidades,
## personalidade, horário, relacionamentos, objetivos e do que existe no prédio
## (camas, fogões, chuveiros, piscina...), e escolhe a melhor. O resultado é um
## plano concreto (andar, lugar, objeto, duração) executado pelo NpcRunner.
## Nenhuma decisão de rotina passa pelo modelo de linguagem.

const ACTIONS := ["sleep", "eat", "toilet", "shower", "rest", "work", "shopping", "socialize", "leisure", "explore", "wander", "gathering", "goal", "clean"]

const GATHERING_START := 17.5 * 60.0
const GATHERING_END := 19.5 * 60.0

## Trabalho de cada morador no prédio.
const WORK := {
	"lila": {"place": "horta", "aff": "cuidar_horta"},
	"tobias": {"place": "home", "aff": "cozinhar", "effect": "paes_mercadinho"},
	"marina": {"place": "piscina", "aff": ""},
	"otavio": {"place": "coworking", "aff": "estudar"},
	"pipa": {"place": "entregas", "aff": ""},
	"bento": {"place": "home", "aff": "tocar"},
	"ravena": {"place": "home", "aff": "pintar"},
	"celeste": {"place": "home", "aff": "costurar"},
}


static func is_sleep_time(def: NpcDefinition, hour_f: float) -> bool:
	if def.sleep_hour > def.wake_hour:
		return hour_f >= def.sleep_hour or hour_f < def.wake_hour
	return hour_f >= def.sleep_hour and hour_f < def.wake_hour


static func is_work_time(def: NpcDefinition, hour_f: float) -> bool:
	return hour_f >= def.work_start_hour and hour_f < def.work_end_hour


static func minutes_until_hour(minute: float, target_hour: float) -> float:
	var target := target_hour * 60.0
	var diff := target - minute
	if diff <= 0.0:
		diff += 1440.0
	return diff


static func _just_woke(def: NpcDefinition, hour_f: float) -> bool:
	var d := hour_f - def.wake_hour
	if d < 0.0:
		d += 24.0
	return d >= 0.0 and d < 1.5


## Pontuação de todas as ações. ctx: {minute, abs, day}
static func score_actions(npc: NpcState, sim, ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	var def := npc.def
	var minute: float = ctx["minute"]
	var hour_f := minute / 60.0
	var sleepy := is_sleep_time(def, hour_f)
	var energy := npc.need("energia")
	var social := npc.need("social")
	var fun := npc.need("diversao")
	var comfort := npc.need("conforto")
	var fome := npc.need("fome")
	var wc := npc.need("banheiro")
	var hyg := npc.need("higiene")
	var t_soc := npc.trait_value("sociabilidade")
	var t_cur := npc.trait_value("curiosidade")
	var t_brave := npc.trait_value("coragem")
	var t_energy := npc.trait_value("energia")
	var dark := hour_f >= 20.0 or hour_f < 5.5
	var scores := {}
	var tired := (100.0 - energy) / 100.0
	scores["sleep"] = (1.0 + tired * 0.3) if sleepy else pow(tired, 3.0) * 1.1
	var hunger := (100.0 - fome) / 100.0
	scores["eat"] = pow(hunger, 1.5) * 1.25
	if fome < 72.0 and ((hour_f >= 7.0 and hour_f < 9.0) or (hour_f >= 12.0 and hour_f < 14.0) or (hour_f >= 19.0 and hour_f < 21.0)):
		scores["eat"] += 0.18
	scores["toilet"] = pow((100.0 - wc) / 100.0, 2.0) * 1.45
	scores["shower"] = pow((100.0 - hyg) / 100.0, 1.6) * 0.9 + (0.35 if _just_woke(def, hour_f) and hyg < 85.0 else 0.0)
	scores["rest"] = (100.0 - comfort) / 100.0 * 0.6 + tired * 0.2
	if is_work_time(def, hour_f) and not sleepy:
		scores["work"] = 0.62 + t_energy * 0.15 + energy / 100.0 * 0.1
	else:
		scores["work"] = 0.0
	scores["shopping"] = 0.0
	if hour_f >= 8.0 and hour_f < 20.0 and npc.pantry <= 1:
		scores["shopping"] = (0.72 if npc.pantry <= 0 else 0.22) + hunger * 0.35
	var target := pick_social_target(npc, sim, rng)
	scores["socialize"] = (100.0 - social) / 100.0 * (0.35 + 0.75 * t_soc) + 0.05 if target != "" else 0.0
	scores["leisure"] = (100.0 - fun) / 100.0 * 0.85 + 0.05
	scores["explore"] = t_cur * 0.42 * (0.5 + (100.0 - fun) / 200.0) + 0.04
	if dark:
		scores["explore"] *= t_brave
	scores["wander"] = 0.12
	scores["gathering"] = (0.45 + t_soc * 0.45) if (minute >= GATHERING_START and minute < GATHERING_END and not sleepy) else 0.0
	scores["goal"] = 0.0
	var step := GoalLibrary.step_at(def.personal_goal_id, int(npc.goal_state.get("step", 0)))
	if step.get("type", "") == "decorar" and hour_f >= 9.0 and hour_f < 19.0 and not sleepy:
		scores["goal"] = 0.68
	scores["clean"] = 0.0
	var dirty := dirtiest_home_object(npc, sim)
	if not dirty.is_empty():
		var dv: float = sim.building.dirt_of(dirty["uid"])
		if dv >= 0.4:
			scores["clean"] = dv * 0.55 + npc.trait_value("gentileza") * 0.1
	# À noite, quem não está na janela de sono desacelera.
	if dark and not sleepy:
		for key in ["work", "explore", "leisure"]:
			scores[key] *= 0.75
	if energy < 25.0:
		for key in ["explore", "leisure", "socialize", "work", "shopping"]:
			scores[key] *= 0.5
	var last: String = npc.action_log.back() if npc.action_log.size() > 0 else ""
	if last in ["leisure", "explore", "wander", "rest", "socialize", "clean"] and scores.has(last):
		scores[last] -= 0.12
	var result := []
	for key in scores:
		var s: float = scores[key]
		if s <= 0.0:
			continue
		s += rng.randf() * 0.06
		result.append({"kind": key, "score": s, "target_npc": target if key == "socialize" else ""})
	result.sort_custom(func(a, b): return a["score"] > b["score"])
	return result


## Escolhe um morador para visitar, ponderando afinidade, distância (inclusive
## andares) e conflitos.
static func pick_social_target(npc: NpcState, sim, rng: RandomNumberGenerator) -> String:
	var best := ""
	var best_w := -INF
	for other_id in sim.npc_order:
		if other_id == npc.id:
			continue
		var other: NpcState = sim.npcs[other_id]
		if not other.is_available():
			continue
		if other.current_action.get("kind", "") in ["sleep", "toilet", "shower"]:
			continue
		if not npc.cooldown_ready("visit:" + other_id, sim.now_abs()):
			continue
		# Não invade o apartamento alheio sem convite (visitas são situações próprias).
		if other.is_home() and other.floor_id != npc.floor_id:
			continue
		var rel: Dictionary = sim.relationships.get_rel(npc.id, other_id)
		var w := (float(rel["affinity"]) + 40.0) / 140.0
		if bool(rel.get("conflict_open", false)):
			w = npc.trait_value("gentileza") * 0.7
		if other.floor_id == npc.floor_id:
			w -= clampf(npc.position.distance_to(other.position) / 120.0, 0.0, 0.3)
		else:
			w -= 0.15 + 0.03 * absi(BuildingLayout.level_of(other.floor_id) - BuildingLayout.level_of(npc.floor_id))
		w += rng.randf() * 0.35
		if w > best_w:
			best_w = w
			best = other_id
	return best


static func choose_action(npc: NpcState, sim, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var ranked := score_actions(npc, sim, ctx, rng)
	for choice in ranked:
		var plan := build_action(npc, sim, choice, ctx, rng)
		if not plan.is_empty():
			return plan
	return build_action(npc, sim, {"kind": "wander", "score": 0.1, "target_npc": ""}, ctx, rng)


static func dirtiest_home_object(npc: NpcState, sim) -> Dictionary:
	var best := {}
	var best_d := 0.0
	for o in sim.building.objects_on_floor(npc.home_floor()):
		if not FurnitureDB.can_get_dirty(str(o["def"])):
			continue
		var d: float = sim.building.dirt_of(o["uid"])
		if d > best_d:
			best_d = d
			best = o
	return best


## Objeto livre com a ação pedida (no apartamento do morador ou em um andar).
static func free_object(sim, floor_id: String, aff: String, only_apartment: bool, user: String, near: Vector3 = Vector3.INF) -> Dictionary:
	var list: Array = sim.building.objects_with(floor_id, aff, only_apartment)
	if near != Vector3.INF:
		list.sort_custom(func(a, b): return Vector2(a["pos"]).distance_to(Vector2(near.x, near.z)) < Vector2(b["pos"]).distance_to(Vector2(near.x, near.z)))
	for o in list:
		var who: String = sim.building.is_in_use(o["uid"])
		if who == "" or who == user:
			return o
	return {}


static func _base(kind: String, choice: Dictionary) -> Dictionary:
	return {
		"kind": kind, "score": choice.get("score", 0.0), "target_npc": choice.get("target_npc", ""),
		"place": "", "floor": "", "target_pos": Vector3.ZERO, "arrive_state": "IDLE", "activity": "parado",
		"duration": 20.0, "action_id": "", "object_uid": "", "pose": "", "seat_pos": null, "face_pos": null,
	}


## Usa um objeto: destino = ponto de uso; assento/cama quando houver.
static func _use_object(plan: Dictionary, obj: Dictionary, action_id: String, rng: RandomNumberGenerator) -> void:
	var floor_id: String = obj["floor"]
	plan["floor"] = floor_id
	plan["object_uid"] = obj["uid"]
	plan["target_pos"] = FurnitureDB.use_point(obj)
	plan["face_pos"] = Vector3(obj["pos"].x, 0, obj["pos"].y)
	plan["action_id"] = action_id
	var act := ActionLibrary.get_action(action_id)
	plan["pose"] = str(act.get("pose", ""))
	var d := FurnitureDB.get_def(str(obj["def"]))
	if plan["pose"] == "sleep" and d.has("lie"):
		plan["seat_pos"] = FurnitureDB.local_to_world(obj["pos"], float(obj["rot"]), d["lie"])
		plan["seat_rot"] = float(obj["rot"])
	elif d.has("seats") and plan["pose"] in ["sit", "read", "eat"]:
		var seats := FurnitureDB.seats(obj)
		if not seats.is_empty():
			plan["seat_pos"] = seats[rng.randi() % seats.size()]
			plan["seat_rot"] = float(obj["rot"]) + float(d.get("seat_facing", 0.0))
	elif d.has("stand_on"):
		plan["seat_pos"] = FurnitureDB.local_to_world(obj["pos"], float(obj["rot"]), d["stand_on"])
		plan["seat_rot"] = float(obj["rot"])
	plan["comfort"] = FurnitureDB.comfort(str(obj["def"])) if (d.has("seats") or d.has("lie")) else 45.0
	plan["duration"] = ActionLibrary.minutes(action_id)


static func _place_plan(plan: Dictionary, place: String, rng: RandomNumberGenerator, spread: float = 0.8) -> void:
	plan["place"] = place
	plan["floor"] = Places.floor_of(place)
	plan["target_pos"] = _scatter(plan["floor"], Places.poi_pos(place), Places.poi_radius(place) * spread, rng)


## Converte a escolha em um plano concreto. Retorna {} se não for possível.
static func build_action(npc: NpcState, sim, choice: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var def := npc.def
	var minute: float = ctx["minute"]
	var kind: String = choice["kind"]
	var plan := _base(kind, choice)
	var home := npc.home_floor()
	match kind:
		"sleep":
			var bed := free_object(sim, home, "dormir", true, npc.id)
			if bed.is_empty():
				return {}
			_use_object(plan, bed, "dormir", rng)
			plan["place"] = npc.home_place()
			plan["arrive_state"] = "RESTING"
			plan["activity"] = "dormindo"
			if is_sleep_time(def, minute / 60.0):
				plan["duration"] = clampf(minutes_until_hour(minute, def.wake_hour), 30.0, 720.0)
			else:
				plan["duration"] = 90.0
		"eat":
			if npc.pantry <= 0:
				var shop_open := minute >= 8.0 * 60.0 and minute < 20.0 * 60.0
				if shop_open and (int(sim.building.shop.stock.get("pao", 0)) > 0 or int(sim.building.shop.stock.get("ingredientes", 0)) > 0):
					return {}
				var cafe := free_object(sim, "terreo", "cafe", false, npc.id)
				if cafe.is_empty():
					return {}
				_use_object(plan, cafe, "cafe", rng)
				plan["place"] = "convivencia"
				plan["arrive_state"] = "LEISURE"
				plan["activity"] = "tomando um café na convivência"
				plan["eat_value"] = 18.0
				return plan
			var hungry := npc.need("fome") < 45.0
			var aff := "cozinhar" if hungry else "comer_lanche"
			var obj := free_object(sim, home, aff, true, npc.id)
			if obj.is_empty():
				obj = free_object(sim, home, "comer_lanche", true, npc.id)
				aff = "comer_lanche"
			if obj.is_empty():
				return {}
			_use_object(plan, obj, aff, rng)
			plan["place"] = npc.home_place()
			plan["arrive_state"] = "RESTING"
			plan["activity"] = "preparando uma refeição" if aff == "cozinhar" else "fazendo um lanche"
			plan["eat_value"] = 60.0 if aff == "cozinhar" else 30.0
		"toilet":
			var wc := free_object(sim, home, "banheiro", true, npc.id)
			if wc.is_empty():
				return {}
			_use_object(plan, wc, "banheiro", rng)
			plan["place"] = npc.home_place()
			plan["arrive_state"] = "RESTING"
			plan["activity"] = "no banheiro"
		"shower":
			var sh := free_object(sim, home, "banho", true, npc.id)
			if sh.is_empty():
				return {}
			_use_object(plan, sh, "banho", rng)
			plan["place"] = npc.home_place()
			plan["arrive_state"] = "RESTING"
			plan["activity"] = "tomando banho"
		"rest":
			var seat := {}
			if npc.floor_id == home or rng.randf() < 0.45:
				seat = free_object(sim, home, "sentar", true, npc.id)
				if not seat.is_empty():
					plan["place"] = npc.home_place()
					plan["activity"] = "descansando no sofá"
			if seat.is_empty():
				var common := ["convivencia", "descanso_cobertura", "patio"]
				var place: String = common[rng.randi() % common.size()]
				seat = free_object(sim, Places.floor_of(place), "sentar", false, npc.id, Places.poi_pos(place))
				if seat.is_empty():
					return {}
				plan["place"] = place
				plan["activity"] = "descansando na " + Places.poi_label(place) if place != "patio" else "descansando no pátio"
			_use_object(plan, seat, "sentar", rng)
			plan["arrive_state"] = "RESTING"
			plan["duration"] = rng.randf_range(25.0, 45.0)
		"work":
			if not _work_plan(plan, npc, sim, minute, rng):
				return {}
		"shopping":
			_place_plan(plan, "mercadinho", rng, 0.5)
			plan["arrive_state"] = "LEISURE"
			plan["activity"] = "fazendo compras no mercadinho"
			plan["duration"] = rng.randf_range(8.0, 14.0)
			plan["shopping"] = true
		"socialize":
			var other: NpcState = sim.npcs[plan["target_npc"]]
			plan["floor"] = other.floor_id
			plan["target_pos"] = other.position
			plan["arrive_state"] = "SOCIALIZING"
			plan["activity"] = "procurando companhia"
			plan["duration"] = rng.randf_range(20.0, 35.0)
		"leisure":
			if not _leisure_plan(plan, npc, sim, minute, rng):
				return {}
		"explore":
			var options: Array = Places.EXPLORE_SPOTS.duplicate()
			options.erase(Places.nearest_place(npc.position, npc.floor_id))
			if minute > 5.0 * 60.0 and minute < 19.0 * 60.0:
				options.erase("observatorio")
			_place_plan(plan, options[rng.randi() % options.size()], rng, 1.0)
			plan["arrive_state"] = "EXPLORING"
			plan["activity"] = "passeando pel" + ("o " if Simulation._prep(Places.poi_label(plan["place"])) == "o" else "a ") + Places.poi_label(plan["place"])
			plan["duration"] = rng.randf_range(20.0, 40.0)
		"gathering":
			_place_plan(plan, "convivencia", rng, 1.6)
			plan["arrive_state"] = "SOCIALIZING"
			plan["activity"] = "no encontro da convivência"
			plan["duration"] = maxf(10.0, GATHERING_END - minute)
		"goal":
			var step := GoalLibrary.step_at(def.personal_goal_id, int(npc.goal_state.get("step", 0)))
			if step.get("type", "") != "decorar":
				return {}
			_place_plan(plan, str(step["place"]), rng, 0.6)
			plan["arrive_state"] = "WORKING"
			plan["activity"] = str(step.get("activity", "trabalhando no objetivo"))
			plan["duration"] = 30.0
			plan["goal_step"] = step["id"]
		"clean":
			var dirty := dirtiest_home_object(npc, sim)
			if dirty.is_empty():
				return {}
			_use_object(plan, dirty, "limpar", rng)
			plan["place"] = npc.home_place()
			plan["arrive_state"] = "WORKING"
			plan["activity"] = "arrumando a casa"
			plan["pose"] = "clean"
		_:
			plan["kind"] = "wander"
			plan["floor"] = npc.floor_id
			plan["place"] = Places.nearest_place(npc.position, npc.floor_id)
			plan["target_pos"] = _scatter(npc.floor_id, npc.position, 4.0, rng)
			plan["arrive_state"] = "IDLE"
			plan["activity"] = "parado, pensando na vida"
			plan["duration"] = rng.randf_range(8.0, 18.0)
	return plan


static func _work_plan(plan: Dictionary, npc: NpcState, sim, minute: float, rng: RandomNumberGenerator) -> bool:
	var spec: Dictionary = WORK.get(npc.id, {"place": "convivencia", "aff": ""})
	var until_end := (npc.def.work_end_hour * 60.0) - minute
	plan["arrive_state"] = "WORKING"
	plan["activity"] = npc.def.work_activity
	if spec["place"] == "entregas":
		# A carteira entrega cartas na porta dos apartamentos (outros andares).
		var floors: Array = BuildingLayout.OWNER_FLOOR.values()
		floors.erase(npc.home_floor())
		var f: String = floors[rng.randi() % floors.size()]
		plan["floor"] = f
		plan["place"] = "corredor_" + f
		plan["target_pos"] = BuildingLayout.APT_DOOR_OUT + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(0.0, 0.5))
		plan["face_pos"] = BuildingLayout.APT_DOOR
		plan["activity"] = "entregando cartas no " + BuildingLayout.floor_label(f)
		plan["duration"] = rng.randf_range(6.0, 10.0)
		plan["delivery_to"] = BuildingLayout.owner_of(f)
		plan["pose"] = "use"
		return true
	if spec["place"] == "home":
		var obj := free_object(sim, npc.home_floor(), str(spec["aff"]), true, npc.id)
		if obj.is_empty():
			return false
		_use_object(plan, obj, str(spec["aff"]), rng)
		plan["place"] = npc.home_place()
		plan["activity"] = npc.def.work_activity
	else:
		var place: String = spec["place"]
		var floor_id := Places.floor_of(place)
		var obj2 := {}
		if str(spec["aff"]) != "":
			obj2 = free_object(sim, floor_id, str(spec["aff"]), false, npc.id, Places.poi_pos(place))
		if obj2.is_empty():
			_place_plan(plan, place, rng, 0.7)
		else:
			_use_object(plan, obj2, str(spec["aff"]), rng)
			plan["place"] = place
		plan["activity"] = npc.def.work_activity
	plan["arrive_state"] = "WORKING"
	plan["duration"] = clampf(minf(until_end, rng.randf_range(60.0, 100.0)), 15.0, 120.0)
	plan["work_effect"] = spec.get("effect", "")
	return true


static func _leisure_plan(plan: Dictionary, npc: NpcState, sim, minute: float, rng: RandomNumberGenerator) -> bool:
	var hobby := _pick_hobby(npc.def, minute, rng)
	var spot: Dictionary = Places.HOBBY_SPOTS.get(hobby, {"place": npc.def.favorite_place, "aff": "", "text": "aproveitando o dia"})
	var place: String = spot["place"]
	var aff: String = spot.get("aff", "")
	plan["hobby"] = hobby
	plan["arrive_state"] = "LEISURE"
	plan["activity"] = spot["text"]
	plan["duration"] = rng.randf_range(35.0, 60.0)
	if place == "home":
		var obj := free_object(sim, npc.home_floor(), aff, true, npc.id)
		if obj.is_empty():
			place = npc.def.favorite_place
			aff = ""
		else:
			_use_object(plan, obj, aff, rng)
			plan["place"] = npc.home_place()
			plan["duration"] = rng.randf_range(35.0, 60.0)
			plan["loud"] = bool(spot.get("loud", false))
			return true
	if Places.is_apartment(place):
		place = "convivencia"
	var floor_id := Places.floor_of(place)
	if floor_id == "":
		return false
	if aff != "":
		var obj2 := free_object(sim, floor_id, aff, false, npc.id, Places.poi_pos(place))
		if not obj2.is_empty():
			_use_object(plan, obj2, aff, rng)
			plan["place"] = place
			plan["duration"] = rng.randf_range(35.0, 60.0)
			return true
	_place_plan(plan, place, rng, 0.8)
	return true


static func _pick_hobby(def: NpcDefinition, minute: float, rng: RandomNumberGenerator) -> String:
	var options := []
	for h in def.hobbies:
		if h == "observar_estrelas" and minute > 5.0 * 60.0 and minute < 19.0 * 60.0:
			continue
		options.append(h)
	if options.is_empty():
		return "passear"
	return options[rng.randi() % options.size()]


## Ponto aleatório perto de `center`, dentro do andar e da mesma zona
## (não atravessa para dentro de um apartamento por acaso).
static func _scatter(floor_id: String, center: Vector3, radius: float, rng: RandomNumberGenerator) -> Vector3:
	var zone := BuildingLayout.zone_of(floor_id, center)
	for i in range(6):
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var p := BuildingLayout.clamp_to_floor(floor_id, center + Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		if BuildingLayout.zone_of(floor_id, p) == zone:
			return p
	return BuildingLayout.clamp_to_floor(floor_id, center)
