class_name LifeEngine
extends RefCounted
## Motor da vida dos moradores: decide (Utility AI, situações sociais e
## eventos), executa os planos de todos os oito (NpcRunner) em todos os andares
## e detecta encontros espontâneos. Não depende de cenas: o diretor do mundo
## só liga/desliga corpos físicos para quem está no andar carregado.

signal npc_floor_left(npc_id: String, floor_id: String, via: String)
signal npc_floor_arrived(npc_id: String, floor_id: String, via: String)
signal social_started(a_id: String, b_id: String, kind: String)

const DECISIONS_PER_UPDATE := 2
const ENCOUNTER_INTERVAL := 2.0
const MEET_PHYSICAL := 2.6
const MEET_LOGICAL := 3.4

var sim: Simulation
var runners: Dictionary = {}
var rng := RandomNumberGenerator.new()
var decisions_made: int = 0
var interactions_started: int = 0
var stuck_events: int = 0
var stuck_log: Array = []
## Andar com corpos físicos (o que está na tela).
var physical_floor: String = ""
var _queue := 0
var _encounter_minutes := 0.0
var _last_now := -1.0
var _gathering_done_day := 0


func setup(p_sim: Simulation) -> void:
	sim = p_sim
	rng.randomize()
	runners.clear()
	for npc_id in sim.npc_order:
		runners[npc_id] = NpcRunner.new(sim.npcs[npc_id], self)
		var npc: NpcState = sim.npcs[npc_id]
		# Quem estava dormindo no save continua na cama até a IA decidir.
		if npc.is_sleeping():
			var bed := UtilityBrain.free_object(sim, npc.home_floor(), "dormir", true, npc.id)
			if not bed.is_empty():
				var plan := UtilityBrain._base("sleep", {})
				UtilityBrain._use_object(plan, bed, "dormir", rng)
				plan["place"] = npc.home_place()
				plan["arrive_state"] = "RESTING"
				plan["activity"] = "dormindo"
				plan["duration"] = 20.0
				npc.floor_id = npc.home_floor()
				npc.position = plan["target_pos"]
				var r: NpcRunner = runners[npc_id]
				r.start(plan, sim.now_abs())
				r.legs = []
				r._arrive(sim.now_abs())
	sim.engine = self


func runner(npc_id: String) -> NpcRunner:
	return runners.get(npc_id)


func npc_left_floor(npc_id: String, floor_id: String, via: String) -> void:
	npc_floor_left.emit(npc_id, floor_id, via)


func npc_arrived_floor(npc_id: String, prev_floor: String, floor_id: String, via: String) -> void:
	npc_floor_arrived.emit(npc_id, floor_id, via)


## Avança a simulação de vida. `now` em minutos absolutos de jogo.
func update(now: float) -> void:
	if sim == null:
		return
	var dt := 0.0 if _last_now < 0.0 else maxf(0.0, now - _last_now)
	_last_now = now
	for npc_id in sim.npc_order:
		var r: NpcRunner = runners[npc_id]
		sim.npcs[npc_id].clock_now = now
		r.update(now)
	var ids: Array = sim.npc_order
	var decided := 0
	var scanned := 0
	while scanned < ids.size() and decided < DECISIONS_PER_UPDATE:
		var npc_id: String = ids[_queue % ids.size()]
		_queue += 1
		scanned += 1
		var r2: NpcRunner = runners[npc_id]
		if r2.phase == NpcRunner.Phase.DECIDE and sim.npcs[npc_id].partner_id == "":
			_decide(r2, now)
			decided += 1
	_encounter_minutes += dt
	if _encounter_minutes >= ENCOUNTER_INTERVAL:
		_encounter_minutes = 0.0
		check_encounters()
	_check_gathering()


func _decide(r: NpcRunner, now: float) -> void:
	var npc := r.npc
	var plan: Dictionary = sim.plan_override(npc.id, now)
	if plan.is_empty():
		var ctx := {"minute": fmod(now, 1440.0), "abs": now, "day": sim.day}
		plan = UtilityBrain.choose_action(npc, sim, ctx, rng)
	decisions_made += 1
	r.start(plan, now)


## Força um plano agora (situações, eventos, convites).
func assign(npc_id: String, plan: Dictionary) -> void:
	var r: NpcRunner = runners[npc_id]
	if r.phase in [NpcRunner.Phase.TRAVEL, NpcRunner.Phase.PERFORM]:
		var old := r.plan
		if str(old.get("object_uid", "")) != "":
			sim.building.release(old["object_uid"], npc_id)
	r.hold = {}
	r.start(plan, sim.now_abs())


func try_social(a_id: String, b_id: String) -> bool:
	if not sim.npcs.has(b_id):
		return false
	var a: NpcState = sim.npcs[a_id]
	var b: NpcState = sim.npcs[b_id]
	if a.floor_id != b.floor_id or a.in_transit or b.in_transit:
		return false
	var dist := NpcRunner._flat(a.position, b.position)
	var limit := MEET_PHYSICAL if a.floor_id == physical_floor else MEET_LOGICAL
	if dist > limit + 0.8:
		return false
	var res := sim.try_start_interaction(a_id, b_id, minf(dist, SocialRules.MEET_DISTANCE))
	if not res["ok"]:
		return false
	runners[a_id].begin_social()
	runners[b_id].begin_social()
	interactions_started += 1
	social_started.emit(a_id, b_id, res["kind"])
	return true


## Encontros espontâneos entre moradores no mesmo andar e na mesma zona.
func check_encounters() -> void:
	var ids: Array = sim.npc_order
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: NpcState = sim.npcs[ids[i]]
			var b: NpcState = sim.npcs[ids[j]]
			if a.floor_id != b.floor_id or not a.is_available() or not b.is_available():
				continue
			if a.state in ["WORKING", "RESTING"] or b.state in ["WORKING", "RESTING"]:
				continue
			if BuildingLayout.zone_of(a.floor_id, a.position) != BuildingLayout.zone_of(b.floor_id, b.position):
				continue
			var limit := MEET_PHYSICAL if a.floor_id == physical_floor else MEET_LOGICAL
			var dist := NpcRunner._flat(a.position, b.position)
			if dist > limit:
				continue
			var ra: NpcRunner = runners[a.id]
			var rb: NpcRunner = runners[b.id]
			if ra.phase == NpcRunner.Phase.HOLD or rb.phase == NpcRunner.Phase.HOLD:
				continue
			var chance := 0.15 + (a.trait_value("sociabilidade") + b.trait_value("sociabilidade")) * 0.2
			if rng.randf() > chance:
				continue
			try_social(a.id, b.id)


func on_arrived(npc: NpcState, plan: Dictionary, now: float) -> void:
	sim.on_npc_arrived(npc.id, plan, now)


func on_finished(npc: NpcState, plan: Dictionary, completed: bool, now: float) -> void:
	sim.complete_activity(npc.id, plan, completed)


## Encontro do entardecer na convivência: só conta quem estava lá de verdade.
func _check_gathering() -> void:
	var minute := sim.minute
	if minute < UtilityBrain.GATHERING_END or minute > UtilityBrain.GATHERING_END + 30.0:
		return
	if _gathering_done_day == sim.day:
		return
	_gathering_done_day = sim.day
	var attendees := []
	var center := Places.poi_pos("convivencia")
	for npc_id in sim.npc_order:
		var npc: NpcState = sim.npcs[npc_id]
		if npc.floor_id != "terreo" or npc.is_sleeping() or npc.in_transit:
			continue
		if NpcRunner._flat(npc.position, center) <= 6.0:
			attendees.append(npc_id)
	sim.conclude_gathering(attendees)


## Posições exatas (para salvar) — quem está no elevador vai para o destino.
func settle_for_save() -> void:
	for npc_id in sim.npc_order:
		var r: NpcRunner = runners[npc_id]
		var npc: NpcState = sim.npcs[npc_id]
		if npc.in_transit:
			var leg := r.current_leg()
			if not leg.is_empty() and leg.has("to") and leg["type"] != "walk":
				npc.floor_id = str(leg["to"])
				npc.position = BuildingLayout.ELEVATOR_CALL
			npc.in_transit = false
