class_name UtilityBrain
extends RefCounted
## Utility AI: pontua cada ação possível a partir de necessidades,
## personalidade, horário, relacionamentos e estado atual, e escolhe a melhor.
## O resultado é executado pela máquina de estados do NpcActor.

const ACTIONS := ["sleep", "rest", "work", "socialize", "leisure", "explore", "wander", "gathering"]

const GATHERING_START := 17.5 * 60.0
const GATHERING_END := 19.5 * 60.0


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


## Calcula a pontuação de todas as ações. ctx: {minute, abs, day}
static func score_actions(npc: NpcState, sim, ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	var def := npc.def
	var minute: float = ctx["minute"]
	var hour_f := minute / 60.0
	var sleepy := is_sleep_time(def, hour_f)
	var energy := npc.need("energia")
	var social := npc.need("social")
	var fun := npc.need("diversao")
	var comfort := npc.need("conforto")
	var t_soc := npc.trait_value("sociabilidade")
	var t_cur := npc.trait_value("curiosidade")
	var t_brave := npc.trait_value("coragem")
	var t_energy := npc.trait_value("energia")
	var dark := hour_f >= 20.0 or hour_f < 5.5

	var scores := {}
	# Dormir: muito forte na janela de sono; fora dela só se exausto.
	if sleepy:
		scores["sleep"] = 1.0 + (100.0 - energy) / 100.0 * 0.3
	else:
		var tired := (100.0 - energy) / 100.0
		scores["sleep"] = pow(tired, 3.0) * 1.1
	# Descansar (conforto): banco ou casa.
	scores["rest"] = (100.0 - comfort) / 100.0 * 0.75 + (100.0 - energy) / 100.0 * 0.2
	# Trabalho: horário de trabalho, ajustado pela energia.
	if is_work_time(def, hour_f) and not sleepy:
		scores["work"] = 0.62 + t_energy * 0.15 + energy / 100.0 * 0.1
	else:
		scores["work"] = 0.0
	# Socializar: necessidade social x sociabilidade, só se alguém estiver disponível.
	var target := pick_social_target(npc, sim, rng)
	if target != "":
		scores["socialize"] = (100.0 - social) / 100.0 * (0.35 + 0.75 * t_soc) + 0.05
	else:
		scores["socialize"] = 0.0
	# Lazer (hobby / lugar favorito).
	scores["leisure"] = (100.0 - fun) / 100.0 * 0.85 + 0.05
	# Explorar: curiosidade; à noite só os corajosos.
	scores["explore"] = t_cur * 0.45 * (0.5 + (100.0 - fun) / 200.0) + 0.04
	if dark:
		scores["explore"] *= t_brave
	# Vagar por perto: opção de baixa prioridade.
	scores["wander"] = 0.14
	# Encontro comunitário ao entardecer na praça.
	if minute >= GATHERING_START and minute < GATHERING_END and not sleepy:
		scores["gathering"] = 0.45 + t_soc * 0.45
	else:
		scores["gathering"] = 0.0

	# À noite, quem não está na janela de sono desacelera.
	if dark and not sleepy:
		for key in ["work", "explore", "leisure"]:
			scores[key] *= 0.75
	# Cansaço reduz atividades intensas.
	if energy < 25.0:
		for key in ["explore", "leisure", "socialize", "work"]:
			scores[key] *= 0.5
	# Variedade: evitar repetir a mesma ação (exceto dormir e trabalhar).
	var last: String = npc.action_log.back() if npc.action_log.size() > 0 else ""
	if last in ["leisure", "explore", "wander", "rest", "socialize"] and scores.has(last):
		scores[last] -= 0.12
	# Pequeno ruído para que os moradores não sejam previsíveis.
	var result := []
	for key in scores:
		var s: float = scores[key]
		if s <= 0.0:
			continue
		s += rng.randf() * 0.06
		result.append({"kind": key, "score": s, "target_npc": target if key == "socialize" else ""})
	result.sort_custom(func(a, b): return a["score"] > b["score"])
	return result


## Escolhe um morador para visitar, ponderando afinidade, distância e conflitos.
static func pick_social_target(npc: NpcState, sim, rng: RandomNumberGenerator) -> String:
	var best := ""
	var best_w := -INF
	for other_id in sim.npc_order:
		if other_id == npc.id:
			continue
		var other: NpcState = sim.npcs[other_id]
		if not other.is_available() or other.state == "WALKING" and other.current_action.get("kind", "") == "sleep":
			continue
		if not npc.cooldown_ready("visit:" + other_id, sim.now_abs()):
			continue
		var rel: Dictionary = sim.relationships.get_rel(npc.id, other_id)
		var w := (float(rel["affinity"]) + 40.0) / 140.0
		if bool(rel.get("conflict_open", false)):
			# Moradores gentis procuram a reconciliação; os outros evitam.
			w = npc.trait_value("gentileza") * 0.7
		var dist := npc.position.distance_to(other.position)
		w -= clampf(dist / 120.0, 0.0, 0.4)
		w += rng.randf() * 0.35
		if w > best_w:
			best_w = w
			best = other_id
	return best


static func choose_action(npc: NpcState, sim, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var ranked := score_actions(npc, sim, ctx, rng)
	if ranked.is_empty():
		return build_action(npc, {"kind": "wander", "score": 0.1, "target_npc": ""}, ctx, rng)
	return build_action(npc, ranked[0], ctx, rng)


## Converte a ação escolhida em um plano concreto: destino, estado ao chegar,
## texto de atividade e duração em minutos de jogo.
static func build_action(npc: NpcState, choice: Dictionary, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var def := npc.def
	var minute: float = ctx["minute"]
	var kind: String = choice["kind"]
	var action := {
		"kind": kind,
		"score": choice["score"],
		"target_npc": choice.get("target_npc", ""),
		"place": "",
		"target_pos": npc.position,
		"arrive_state": "IDLE",
		"activity": "parado",
		"duration": 20.0,
		"enter_home": false,
	}
	match kind:
		"sleep":
			action["place"] = def.home_id
			action["target_pos"] = Places.house_door(def.home_id)
			action["arrive_state"] = "RESTING"
			action["activity"] = "dormindo"
			action["enter_home"] = true
			if is_sleep_time(def, minute / 60.0):
				action["duration"] = clampf(minutes_until_hour(minute, def.wake_hour), 30.0, 720.0)
			else:
				action["duration"] = 90.0
		"rest":
			if rng.randf() < 0.5:
				action["place"] = "banco_praca"
				action["target_pos"] = _scatter(Places.poi_pos("banco_praca"), 0.6, rng)
				action["activity"] = "descansando no banco"
			else:
				action["place"] = def.home_id
				action["target_pos"] = Places.house_porch(def.home_id)
				action["activity"] = "relaxando na varanda"
			action["arrive_state"] = "RESTING"
			action["duration"] = rng.randf_range(30.0, 60.0)
		"work":
			if def.id == "pipa":
				# A carteira entrega cartas de porta em porta.
				var houses := Places.HOUSES.keys()
				houses.erase(def.home_id)
				var house: String = houses[rng.randi() % houses.size()]
				action["place"] = house
				action["target_pos"] = Places.house_door(house) + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
				action["activity"] = "entregando cartas"
				action["duration"] = rng.randf_range(8.0, 15.0)
				action["delivery_to"] = house
			else:
				var place := def.work_place
				if place == "home":
					action["place"] = def.home_id
					action["target_pos"] = Places.house_porch(def.home_id)
				else:
					action["place"] = place
					action["target_pos"] = _scatter(Places.poi_pos(place), Places.poi_radius(place) * 0.7, rng)
				action["activity"] = def.work_activity
				var until_end := (def.work_end_hour * 60.0) - minute
				action["duration"] = clampf(minf(until_end, rng.randf_range(60.0, 100.0)), 15.0, 120.0)
			action["arrive_state"] = "WORKING"
		"socialize":
			action["arrive_state"] = "SOCIALIZING"
			action["activity"] = "procurando companhia"
			action["duration"] = rng.randf_range(20.0, 35.0)
		"leisure":
			var hobby := _pick_hobby(def, minute, rng)
			var spot: Dictionary = Places.HOBBY_SPOTS.get(hobby, {"place": def.favorite_place, "text": "aproveitando o dia"})
			var place2: String = spot["place"]
			if place2 == "home":
				action["place"] = def.home_id
				action["target_pos"] = Places.house_porch(def.home_id)
			elif place2 == "random":
				place2 = Places.EXPLORE_SPOTS[rng.randi() % Places.EXPLORE_SPOTS.size()]
				action["place"] = place2
				action["target_pos"] = _scatter(Places.poi_pos(place2), Places.poi_radius(place2), rng)
			else:
				action["place"] = place2
				action["target_pos"] = _scatter(Places.poi_pos(place2), Places.poi_radius(place2) * 0.8, rng)
			action["hobby"] = hobby
			action["arrive_state"] = "LEISURE"
			action["activity"] = spot["text"]
			action["duration"] = rng.randf_range(40.0, 70.0)
		"explore":
			var options: Array = Places.EXPLORE_SPOTS.duplicate()
			var current := Places.nearest_place(npc.position)
			options.erase(current)
			var spot_id: String = options[rng.randi() % options.size()]
			action["place"] = spot_id
			action["target_pos"] = _scatter(Places.poi_pos(spot_id), Places.poi_radius(spot_id), rng)
			action["arrive_state"] = "EXPLORING"
			action["activity"] = "explorando " + Places.poi_label(spot_id)
			action["duration"] = rng.randf_range(25.0, 45.0)
		"gathering":
			action["place"] = "praca"
			action["target_pos"] = _scatter(Places.poi_pos("praca"), 4.5, rng)
			action["arrive_state"] = "SOCIALIZING"
			action["activity"] = "no encontro da praça"
			action["duration"] = maxf(10.0, GATHERING_END - minute)
		_:
			action["kind"] = "wander"
			var base := npc.position
			if base.length() > Places.ISLAND_RADIUS - 4.0:
				base = base * 0.85
			action["target_pos"] = _scatter(base, 6.0, rng)
			action["arrive_state"] = "IDLE"
			action["activity"] = "parado, pensando na vida"
			action["duration"] = rng.randf_range(8.0, 18.0)
	return action


static func _pick_hobby(def: NpcDefinition, minute: float, rng: RandomNumberGenerator) -> String:
	var options := []
	for h in def.hobbies:
		# Observar estrelas só faz sentido à noite.
		if h == "observar_estrelas" and minute > 5.0 * 60.0 and minute < 19.0 * 60.0:
			continue
		options.append(h)
	if options.is_empty():
		return "passear"
	return options[rng.randi() % options.size()]


static func _scatter(center: Vector3, radius: float, rng: RandomNumberGenerator) -> Vector3:
	var angle := rng.randf() * TAU
	var r := sqrt(rng.randf()) * radius
	var p := center + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
	var flat := Vector2(p.x, p.z)
	if flat.length() > Places.WALK_RADIUS - 2.0:
		flat = flat.normalized() * (Places.WALK_RADIUS - 2.0)
	return Vector3(flat.x, 0.0, flat.y)
