class_name LifeCoordinator
extends Node
## Vida social "visível" dos moradores (0.3), por cima da simulação:
##  - iniciativas: um morador procura a jogadora (com cooldowns e prioridade);
##  - convites: o morador espera a jogadora no lugar combinado;
##  - falas curtas entre moradores quando a jogadora está por perto;
##  - reações a etapas de objetivos e pedidos de plano ao modelo (baixa prioridade).
## Nada aqui decide acontecimentos: tudo passa pelas regras do Simulation.

signal initiative_ready(npc_id: String, cand: Dictionary)

const CHECK_INTERVAL := 3.0
const INITIATIVE_RADIUS := 22.0
const GIVE_UP_DISTANCE := 15.0
const WAIT_SECONDS := 40.0
const CHAT_RADIUS := 12.0
const CHAT_LINE_COOLDOWN := 20.0
const STARTUP_GRACE := 25.0

var sim: Simulation
var director: NpcDirector
var player: Node3D
var enabled := true
var blocked := false  # interface modal aberta
var active_initiative_npc: String = ""
var initiatives_started := 0
var chats_shown := 0
var _timer := 0.0
var _wait := 0.0
var _chat_cooldown := 0.0
var _grace := STARTUP_GRACE
var _invite_sent: Dictionary = {}
var _plan_day: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(p_sim: Simulation, p_director: NpcDirector, p_player: Node3D) -> void:
	sim = p_sim
	director = p_director
	player = p_player
	_rng.randomize()
	sim.interaction_started.connect(_on_interaction_started)
	sim.goal_changed.connect(_on_goal_changed)


func _physics_process(delta: float) -> void:
	if sim == null or player == null or not enabled:
		return
	_grace -= delta
	_chat_cooldown -= delta
	_update_active_initiative(delta)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	_update_invitations()
	if not blocked and _grace <= 0.0 and active_initiative_npc == "":
		_try_initiative()


# --- iniciativas ------------------------------------------------------------------

func _try_initiative() -> void:
	var best_id := ""
	var best: Dictionary = {}
	var best_score := -INF
	var priority := {"agradecer_presente": 5.0, "pedir_ajuda": 4.0, "contar_novidade": 3.5, "convidar": 3.0, "pergunta": 2.0}
	for npc_id in sim.npc_order:
		var actor: NpcActor = director.get_actor(npc_id)
		if actor == null or not actor.visible or not actor._nav_ready:
			continue
		if not (actor.phase in [NpcActor.Phase.NEEDS_DECISION, NpcActor.Phase.PERFORMING, NpcActor.Phase.MOVING]):
			continue
		var npc: NpcState = sim.npcs[npc_id]
		if npc.state in ["WORKING", "RESTING"] or actor.action.get("kind", "") in ["sleep", "gathering", "invite"]:
			continue
		var dist := actor.global_position.distance_to(player.global_position)
		if dist > INITIATIVE_RADIUS:
			continue
		var cand := sim.initiative_candidate(npc_id)
		if cand.is_empty():
			continue
		var score: float = priority.get(cand["reason"], 1.0) - dist * 0.05 + npc.trait_value("sociabilidade") * 0.5
		if score > best_score:
			best_score = score
			best = cand
			best_id = npc_id
	if best_id != "":
		start_initiative(best_id, best)


func start_initiative(npc_id: String, cand: Dictionary) -> void:
	var actor: NpcActor = director.get_actor(npc_id)
	if actor == null:
		return
	active_initiative_npc = npc_id
	_wait = 0.0
	initiatives_started += 1
	actor.approach_player(player, cand)


func _update_active_initiative(delta: float) -> void:
	if active_initiative_npc == "":
		return
	var actor: NpcActor = director.get_actor(active_initiative_npc)
	if actor == null or not actor.is_waiting_for_player():
		active_initiative_npc = ""
		return
	if actor.phase == NpcActor.Phase.WAITING_PLAYER:
		if _wait == 0.0:
			EventBus.toast_requested.emit("%s quer falar com você · [E] conversar" % sim.npcs[active_initiative_npc].display_name())
			initiative_ready.emit(active_initiative_npc, actor.initiative)
		_wait += delta
		var far := actor.global_position.distance_to(player.global_position) > GIVE_UP_DISTANCE
		if _wait > WAIT_SECONDS or far:
			ignore_initiative()


## A jogadora ignorou ou se afastou: o morador desiste, sem bloquear nada.
func ignore_initiative() -> void:
	if active_initiative_npc == "":
		return
	var actor: NpcActor = director.get_actor(active_initiative_npc)
	if actor:
		sim.mark_initiative(active_initiative_npc, actor.initiative, "ignored")
		actor.cancel_initiative()
	active_initiative_npc = ""


## Chamado quando a jogadora aceita conversar com quem a procurou.
func take_initiative(npc_id: String) -> Dictionary:
	var actor: NpcActor = director.get_actor(npc_id)
	if actor == null or actor.initiative.is_empty():
		return {}
	var cand := actor.initiative.duplicate()
	sim.mark_initiative(npc_id, cand, "accepted")
	actor.initiative = {}
	actor.emote.set_persistent("")
	if active_initiative_npc == npc_id:
		active_initiative_npc = ""
	match str(cand.get("reason", "")):
		"pedir_ajuda":
			var items: Array = cand.get("items", [])
			if not items.is_empty():
				sim.apply_ai_action(npc_id, "pedir_item", {"item_id": items[0]})
		"convidar":
			if sim.npcs[npc_id].invitation.is_empty():
				sim.start_invitation(npc_id, str(cand.get("place", "praca")))
	return cand


# --- convites ---------------------------------------------------------------------

func _update_invitations() -> void:
	for npc_id in sim.npc_order:
		var npc: NpcState = sim.npcs[npc_id]
		var actor: NpcActor = director.get_actor(npc_id)
		if npc.invitation.is_empty():
			_invite_sent.erase(npc_id)
			continue
		var place: String = npc.invitation["place"]
		if not _invite_sent.has(npc_id) and actor.phase in [NpcActor.Phase.NEEDS_DECISION, NpcActor.Phase.PERFORMING] and npc.partner_id == "":
			_invite_sent[npc_id] = true
			actor.go_to_invite(place)
		var spot := Places.poi_pos(place)
		var player_there := player.global_position.distance_to(spot) <= Places.poi_radius(place) + 3.5
		var npc_there := actor.global_position.distance_to(spot) <= Places.poi_radius(place) + 4.0
		if player_there and npc_there:
			var res := sim.complete_invitation(npc_id)
			if not res.is_empty():
				EventBus.npc_reaction.emit(npc_id, "invite_done")
				EventBus.toast_requested.emit(res["text"])
				actor.say("Que bom que você veio!", 3.5)


# --- falas entre moradores ---------------------------------------------------

func _on_interaction_started(a_id: String, b_id: String, kind: String) -> void:
	if _chat_cooldown > 0.0 or player == null:
		return
	var aa: NpcActor = director.get_actor(a_id)
	var ab: NpcActor = director.get_actor(b_id)
	if aa == null or ab == null or not aa.visible:
		return
	if aa.global_position.distance_to(player.global_position) > CHAT_RADIUS:
		return
	_chat_cooldown = CHAT_LINE_COOLDOWN
	chats_shown += 1
	var it: Dictionary = sim.active_interactions.get(SocialRules.pair_key(a_id, b_id), {})
	var topic := str(it.get("topic", "a ilha"))
	var place := str(it.get("place", "praca"))
	var lines: Array = FallbackDialogue.npc_chat_lines(sim.npcs[a_id], sim.npcs[b_id], kind, topic, _rng)
	if ApiClient.last_health.get("ollama", false):
		var body := {"request_id": "chat_%s_%s_%d" % [a_id, b_id, Time.get_ticks_msec()], "context": ContextBuilder.build_npc_chat(sim, a_id, b_id, kind, topic, place)}
		var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_POST, "/api/v1/ai/npc-chat", body, 30.0)
		if res["ok"] and res["data"].get("source", "") == "ollama":
			lines = [str(res["data"]["line_a"]), str(res["data"]["line_b"])]
	# A conversa pode ter acabado enquanto o modelo respondia.
	if not sim.active_interactions.has(SocialRules.pair_key(a_id, b_id)) or not is_instance_valid(aa):
		return
	aa.say(lines[0], 4.0)
	await get_tree().create_timer(2.6).timeout
	if is_instance_valid(ab) and sim.active_interactions.has(SocialRules.pair_key(a_id, b_id)):
		ab.say(lines[1], 4.0)


# --- objetivos ---------------------------------------------------------------------

func _on_goal_changed(npc_id: String, info: Dictionary) -> void:
	if info.get("completed", false):
		EventBus.npc_reaction.emit(npc_id, "goal_completed")
	elif info.get("step_done", false):
		EventBus.npc_reaction.emit(npc_id, "goal_step")
	if info.get("step_done", false) and not info.get("completed", false):
		request_plan(npc_id)


## Pede ao modelo (baixa prioridade, no máximo uma vez por dia por morador)
## que escolha entre opções VÁLIDAS para a próxima etapa. O simulador aplica.
func request_plan(npc_id: String) -> void:
	if _plan_day.get(npc_id, -1) == sim.day:
		return
	_plan_day[npc_id] = sim.day
	var options := plan_options(npc_id)
	if options.is_empty():
		return
	var chosen: String = options[0]["id"]
	var motive := ""
	if ApiClient.last_health.get("ollama", false):
		var npc: NpcState = sim.npcs[npc_id]
		var body := {"request_id": "plano_%s_%d" % [npc_id, sim.day], "npc_id": npc_id, "options": options,
			"context": ContextBuilder.build(npc, sim, sim.goal_context(npc_id).get("current_step", ""))}
		var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_POST, "/api/v1/ai/plan", body, 70.0)
		if res["ok"] and res["data"].get("source", "") == "ollama":
			chosen = str(res["data"]["option"])
			motive = str(res["data"].get("motive", ""))
	apply_plan(npc_id, chosen, motive)


func plan_options(npc_id: String) -> Array:
	var npc: NpcState = sim.npcs[npc_id]
	var step := GoalLibrary.step_at(npc.def.personal_goal_id, int(npc.goal_state.get("step", 0)))
	match str(step.get("type", "")):
		"receber_item":
			return [{"id": "pedir_jogadora", "label": "pedir ajuda para %s" % sim.player_name}, {"id": "esperar", "label": "esperar com calma"}]
		"atividade_compartilhada":
			return [{"id": "convidar_jogadora", "label": "convidar %s" % sim.player_name}, {"id": "esperar_amigo", "label": "esperar encontrar um amigo"}]
		"":
			return []
	return [{"id": "continuar", "label": "continuar no próprio ritmo"}, {"id": "dedicar", "label": "se dedicar mais"}]


func apply_plan(npc_id: String, option: String, motive: String) -> void:
	var npc: NpcState = sim.npcs[npc_id]
	match option:
		"pedir_jogadora":
			npc.cooldowns.erase("ask_help")
		"convidar_jogadora":
			npc.cooldowns.erase("invite")
	if motive != "":
		npc.goal_state["plan_note"] = motive.substr(0, 160)
