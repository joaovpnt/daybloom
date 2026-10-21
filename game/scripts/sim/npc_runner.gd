class_name NpcRunner
extends RefCounted
## Executa o plano de um morador, esteja ele no andar carregado (com corpo
## físico, NpcActor) ou em outro andar (representação lógica). O plano vira uma
## rota: andar até o elevador/escada, viajar entre andares e andar até o
## destino; depois o morador executa a atividade pelo tempo planejado.
##
## Quando o andar é carregado, o ator assume os trechos a pé no mesmo ponto em
## que a simulação lógica parou (sem teleporte visível nem duplicação).

enum Phase { DECIDE, TRAVEL, PERFORM, SOCIAL, HOLD }

## Velocidade lógica (metros por minuto de jogo), igual à do ator físico.
const WALK_M_PER_MIN := 2.6
const ARRIVE_DISTANCE := 0.8

var npc: NpcState
var engine
var phase: Phase = Phase.DECIDE
var plan: Dictionary = {}
var legs: Array = []
var leg_i: int = 0
var leg_from: Vector3 = Vector3.ZERO
var leg_start: float = 0.0
var leg_end: float = 0.0
var perform_end: float = 0.0
## Ator físico (NpcActor) quando o andar do morador está carregado.
var actor = null
var actor_walking: bool = false
var hold: Dictionary = {}
var _replanned := false


func _init(p_npc: NpcState, p_engine) -> void:
	npc = p_npc
	engine = p_engine


static func route(from_floor: String, from_pos: Vector3, to_floor: String, to_pos: Vector3, energy: float = 60.0) -> Array:
	if from_floor == to_floor or to_floor == "":
		return [{"type": "walk", "floor": from_floor, "to": to_pos}]
	var diff := absi(BuildingLayout.level_of(to_floor) - BuildingLayout.level_of(from_floor))
	if diff == 1 and energy > 45.0:
		return [
			{"type": "walk", "floor": from_floor, "to": BuildingLayout.STAIRS_CALL},
			{"type": "stairs", "from": from_floor, "to": to_floor, "minutes": BuildingLayout.stairs_minutes(from_floor, to_floor)},
			{"type": "walk", "floor": to_floor, "to": to_pos},
		]
	return [
		{"type": "walk", "floor": from_floor, "to": BuildingLayout.ELEVATOR_CALL},
		{"type": "lift", "from": from_floor, "to": to_floor, "minutes": BuildingLayout.elevator_minutes(from_floor, to_floor)},
		{"type": "walk", "floor": to_floor, "to": to_pos},
	]


func is_traveling() -> bool:
	return phase == Phase.TRAVEL


func current_leg() -> Dictionary:
	return legs[leg_i] if phase == Phase.TRAVEL and leg_i < legs.size() else {}


## Começa um plano novo.
func start(p: Dictionary, now: float) -> void:
	plan = p
	npc.current_action = p
	npc.action_log.append(p.get("kind", ""))
	if npc.action_log.size() > 12:
		npc.action_log.pop_front()
	if str(p.get("object_uid", "")) != "":
		engine.sim.building.reserve(p["object_uid"], npc.id)
	npc.action_rates = {}
	npc.action_activity = ""
	npc.comfort_target = 45.0
	_replanned = false
	legs = route(npc.floor_id, npc.position, str(p.get("floor", npc.floor_id)), p.get("target_pos", npc.position), npc.need("energia"))
	leg_i = 0
	phase = Phase.TRAVEL
	engine.sim.set_npc_state(npc.id, "WALKING", _travel_text())
	if actor:
		actor.stand_up()
	_begin_leg(now)


func _travel_text() -> String:
	var target_npc := str(plan.get("target_npc", ""))
	if target_npc != "" and engine.sim.npcs.has(target_npc):
		return "indo ver " + engine.sim.npcs[target_npc].display_name()
	var kind := str(plan.get("kind", ""))
	if kind == "sleep":
		return "indo dormir"
	var place := str(plan.get("place", ""))
	if place == npc.home_place():
		return "indo para casa" if not npc.is_home() else "andando pela casa"
	if place != "":
		var label := Places.poi_label(place)
		return "indo para " + ("o " if Simulation._prep(label) == "o" else "a ") + label
	return "andando"


func _begin_leg(now: float) -> void:
	if leg_i >= legs.size():
		_arrive(now)
		return
	var leg: Dictionary = legs[leg_i]
	leg_start = now
	match leg["type"]:
		"walk":
			# Socializar: o alvo pode ter mudado de andar no caminho.
			if leg_i == legs.size() - 1 and str(plan.get("target_npc", "")) != "" and not _replanned:
				var other: NpcState = engine.sim.npcs.get(plan["target_npc"])
				if other and (other.floor_id != npc.floor_id or other.in_transit):
					_replanned = true
					if other.in_transit or not other.is_available():
						finish(false, now)
						return
					legs = route(npc.floor_id, npc.position, other.floor_id, other.position, npc.need("energia"))
					leg_i = 0
					_begin_leg(now)
					return
				if other:
					leg["to"] = other.position
			leg_from = npc.position
			var dist := _flat(npc.position, leg["to"])
			if actor:
				actor_walking = true
				actor.walk_to(leg["to"])
				leg_end = now + maxf(3.0, dist / WALK_M_PER_MIN * 4.0 + 4.0)
			else:
				actor_walking = false
				leg_end = now + maxf(0.2, dist / WALK_M_PER_MIN)
		"lift", "stairs":
			npc.in_transit = true
			leg_end = now + float(leg["minutes"])
			engine.npc_left_floor(npc.id, str(leg["from"]), str(leg["type"]))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func update(now: float) -> void:
	match phase:
		Phase.TRAVEL:
			_update_travel(now)
		Phase.PERFORM:
			if now >= perform_end:
				finish(true, now)
			elif should_interrupt(now):
				finish(false, now)
		Phase.SOCIAL:
			if npc.partner_id == "":
				phase = Phase.DECIDE
				engine.sim.set_npc_state(npc.id, "IDLE", "parado")
		Phase.HOLD:
			if now >= float(hold.get("until", INF)):
				release_hold()


func _update_travel(now: float) -> void:
	if leg_i >= legs.size():
		_arrive(now)
		return
	var leg: Dictionary = legs[leg_i]
	if leg["type"] == "walk":
		if actor and actor_walking:
			if actor.has_arrived() or _flat(npc.position, leg["to"]) <= ARRIVE_DISTANCE:
				actor_walking = false
				leg_i += 1
				_begin_leg(now)
			elif now > leg_end:
				# O corpo físico não chegou a tempo: segue a rota (sem travar a simulação).
				actor_walking = false
				engine.stuck_events += 1
				engine.stuck_log.append({"npc": npc.id, "floor": npc.floor_id, "pos": npc.position, "target": leg["to"], "kind": plan.get("kind", "")})
				if _flat(npc.position, leg["to"]) < 3.0:
					leg_i += 1
					_begin_leg(now)
				else:
					finish(false, now)
			return
		var span := maxf(0.001, leg_end - leg_start)
		var t := clampf((now - leg_start) / span, 0.0, 1.0)
		npc.position = leg_from.lerp(leg["to"], t)
		if t >= 1.0:
			npc.position = leg["to"]
			leg_i += 1
			_begin_leg(now)
	else:
		if now >= leg_end:
			var prev := npc.floor_id
			npc.floor_id = str(leg["to"])
			npc.in_transit = false
			var arrival: Vector3 = BuildingLayout.STAIRS_CALL if leg["type"] == "stairs" else BuildingLayout.ELEVATOR_CALL
			npc.position = arrival + Vector3(0.4, 0, engine.rng.randf_range(-0.5, 0.5))
			leg_i += 1
			engine.npc_arrived_floor(npc.id, prev, npc.floor_id, str(leg["type"]))
			_begin_leg(now)


func _arrive(now: float) -> void:
	var kind := str(plan.get("kind", ""))
	if kind == "socialize":
		var other_id := str(plan.get("target_npc", ""))
		if engine.try_social(npc.id, other_id):
			return
		finish(false, now)
		return
	var seat = plan.get("seat_pos")
	if seat != null:
		npc.position = Vector3(seat.x, 0.0, seat.z)
	if plan.get("face_pos") != null:
		var f: Vector3 = plan["face_pos"]
		var d := f - npc.position
		if Vector2(d.x, d.z).length() > 0.05:
			npc.rotation_y = atan2(d.x, d.z)
	if seat != null and plan.has("seat_rot"):
		npc.rotation_y = float(plan["seat_rot"])
	engine.sim.set_npc_state(npc.id, str(plan.get("arrive_state", "IDLE")), str(plan.get("activity", "parado")))
	perform_end = now + float(plan.get("duration", 20.0))
	var act := ActionLibrary.get_action(str(plan.get("action_id", "")))
	npc.action_rates = (act.get("rates", {}) as Dictionary).duplicate()
	npc.action_activity = str(act.get("activity", ""))
	npc.comfort_target = float(plan.get("comfort", 45.0))
	phase = Phase.PERFORM
	if actor:
		actor.perform(plan)
	engine.on_arrived(npc, plan, now)


## Interrompe atividades quando surge algo mais urgente.
func should_interrupt(now: float) -> bool:
	var kind := str(plan.get("kind", ""))
	if kind in ["sleep", "situation", "event"]:
		return false
	var hour := fmod(now, 1440.0) / 60.0
	if UtilityBrain.is_sleep_time(npc.def, hour) and kind != "gathering":
		return true
	if npc.need("energia") < 6.0:
		return true
	if npc.need("banheiro") < 8.0 and kind != "toilet":
		return true
	if kind == "shower" or kind == "toilet":
		return false
	return false


## Encerra o plano (concluído ou não) e libera objeto e pose.
func finish(completed: bool, now: float) -> void:
	var p := plan
	plan = {}
	legs = []
	leg_i = 0
	actor_walking = false
	if str(p.get("object_uid", "")) != "":
		engine.sim.building.release(p["object_uid"], npc.id)
	npc.action_rates = {}
	npc.action_activity = ""
	npc.comfort_target = 45.0
	npc.current_action = {}
	if actor:
		actor.stand_up()
	phase = Phase.DECIDE
	if npc.partner_id == "":
		engine.sim.set_npc_state(npc.id, "IDLE", "parado")
	engine.on_finished(npc, p, completed, now)


## Interação social começou (o plano atual fica suspenso).
func begin_social() -> void:
	if str(plan.get("object_uid", "")) != "":
		engine.sim.building.release(plan["object_uid"], npc.id)
	plan = {}
	legs = []
	actor_walking = false
	npc.current_action = {}
	npc.action_rates = {}
	if actor:
		actor.stand_up()
		actor.stop()
	phase = Phase.SOCIAL


## Segura o morador sob controle externo (iniciativa, visita da jogadora...).
func set_hold(reason: String, minutes: float, now: float) -> void:
	if phase == Phase.TRAVEL or phase == Phase.PERFORM:
		if str(plan.get("object_uid", "")) != "":
			engine.sim.building.release(plan["object_uid"], npc.id)
		plan = {}
		legs = []
		npc.current_action = {}
		npc.action_rates = {}
	actor_walking = false
	hold = {"reason": reason, "until": now + minutes}
	phase = Phase.HOLD


func release_hold() -> void:
	hold = {}
	if phase == Phase.HOLD:
		phase = Phase.DECIDE
		if npc.partner_id == "":
			engine.sim.set_npc_state(npc.id, "IDLE", "parado")


func is_holding(reason: String = "") -> bool:
	return phase == Phase.HOLD and (reason == "" or hold.get("reason", "") == reason)


func attach_actor(a, now: float) -> void:
	actor = a
	actor_walking = false
	var leg := current_leg()
	if not leg.is_empty() and leg["type"] == "walk" and str(leg["floor"]) == npc.floor_id:
		actor_walking = true
		actor.walk_to(leg["to"])
		var dist := _flat(npc.position, leg["to"])
		leg_end = now + maxf(3.0, dist / WALK_M_PER_MIN * 4.0 + 4.0)
	elif phase == Phase.PERFORM:
		actor.perform(plan)


func detach_actor(now: float) -> void:
	if actor == null:
		return
	var leg := current_leg()
	if actor_walking and not leg.is_empty() and leg["type"] == "walk":
		leg_from = npc.position
		leg_start = now
		leg_end = now + maxf(0.2, _flat(npc.position, leg["to"]) / WALK_M_PER_MIN)
	actor_walking = false
	actor = null
