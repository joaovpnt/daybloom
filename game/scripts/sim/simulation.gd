class_name Simulation
extends RefCounted
## Núcleo da simulação social do Daybloom. Não depende de cenas: guarda o
## estado dos oito moradores, relacionamentos, memórias e o Diário da Ilha, e
## aplica as consequências de cada acontecimento confirmado.

signal journal_added(entry: Dictionary)
signal relationship_changed(owner_id: String, other_id: String, relationship: Dictionary)
signal memory_added(npc_id: String, memory: Dictionary)
signal npc_state_changed(npc_id: String, state: String, activity: String)
signal interaction_started(a_id: String, b_id: String, kind: String)
signal interaction_finished(a_id: String, b_id: String, kind: String, outcome: Dictionary)

const NPC_COUNT := 8
const NPC_IDS := ["lila", "tobias", "marina", "otavio", "pipa", "bento", "ravena", "celeste"]

## Relações iniciais marcantes (afinidade de A por B; a recíproca é parecida).
const SEED_RELATIONS := {
	"lila+bento": 38.0, "lila+celeste": 34.0, "tobias+celeste": 30.0, "ravena+tobias": -14.0,
	"pipa+marina": 30.0, "otavio+celeste": 24.0, "otavio+ravena": 18.0, "marina+bento": 16.0,
	"pipa+lila": 22.0, "bento+tobias": 12.0, "ravena+lila": -4.0, "pipa+otavio": 6.0,
}

var npcs: Dictionary = {}
var npc_order: Array = []
var relationships := RelationshipSystem.new()
var memories := MemorySystem.new()
var journal := IslandJournal.new()
var rng := RandomNumberGenerator.new()

var day: int = 1
var minute: float = 480.0
var event_seq: int = 0
var player_id: String = "jogadora_1"
var player_name: String = "Jogadora"
var island_name: String = "Daybloom"
## Interações em andamento: pair_key -> {a, b, kind, place, started, duration, topic}
var active_interactions: Dictionary = {}
var _pair_cooldowns: Dictionary = {}


static func load_definitions() -> Array:
	var defs := []
	for npc_id in NPC_IDS:
		var def: NpcDefinition = load("res://data/npcs/%s.tres" % npc_id)
		assert(def != null, "definição ausente: %s" % npc_id)
		defs.append(def)
	return defs


func setup_new(defs: Array, p_player_id: String, p_player_name: String, seed_value: int = 0) -> void:
	assert(defs.size() == NPC_COUNT, "o Daybloom 0.1 tem exatamente oito moradores")
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	player_id = p_player_id
	player_name = p_player_name
	npcs.clear()
	npc_order.clear()
	relationships = RelationshipSystem.new()
	memories = MemorySystem.new()
	journal = IslandJournal.new()
	active_interactions.clear()
	_pair_cooldowns.clear()
	event_seq = 0
	for def in defs:
		var npc := NpcState.new(def)
		var h := absi(hash(def.id))
		npc.needs = {
			"energia": 72.0 + float(h % 23),
			"social": 40.0 + float((h / 7) % 40),
			"diversao": 45.0 + float((h / 13) % 35),
			"conforto": 55.0 + float((h / 17) % 35),
		}
		npc.position = Places.house_door(def.home_id) + Vector3(float(h % 5) * 0.3 - 0.6, 0, 0.5)
		npcs[def.id] = npc
		npc_order.append(def.id)
	for a_id in npc_order:
		for b_id in npc_order:
			if a_id == b_id:
				continue
			var base := float((absi(hash(a_id + b_id)) % 13))
			var key := "%s+%s" % [a_id, b_id]
			var rev := "%s+%s" % [b_id, a_id]
			if SEED_RELATIONS.has(key):
				base = SEED_RELATIONS[key]
			elif SEED_RELATIONS.has(rev):
				base = float(SEED_RELATIONS[rev]) * 0.85
			var rel := relationships.ensure(a_id, b_id, base, 25.0 + base * 0.4)
			if base < -8.0:
				rel["conflict_open"] = true
				rel["conflict_since"] = -600.0
		relationships.ensure(a_id, player_id, 0.0, 10.0)
	# Estado inicial coerente com o horário.
	for npc_id in npc_order:
		var npc: NpcState = npcs[npc_id]
		if UtilityBrain.is_sleep_time(npc.def, minute / 60.0):
			npc.set_state("RESTING", "dormindo")
			npc.inside_home = true
		npc.update_emotion()
	var evt := next_event_id()
	var entry := journal.add(evt, "community_event", [], "%s chegou à ilha %s. Os oito moradores estão curiosos para conhecer a nova vizinha!" % [player_name, island_name], time_dict())
	journal_added.emit(entry)
	for npc_id in npc_order:
		_remember(npc_id, "community_event", [npc_id, player_id], "%s chegou para morar na ilha." % player_name, 0.7, ["nova_moradora"], evt, "chegada_jogadora")


# --- tempo ---------------------------------------------------------------

func set_time(p_day: int, p_minute: float) -> void:
	day = p_day
	minute = p_minute


func now_abs() -> float:
	return (day - 1) * 1440.0 + minute


func time_dict() -> Dictionary:
	return {"day": day, "minute": snappedf(minute, 0.01)}


func next_event_id() -> String:
	event_seq += 1
	return "evt_%06d" % event_seq


# --- necessidades e emoções ---------------------------------------------

func tick(minutes: float) -> void:
	for npc_id in npc_order:
		tick_npc(npcs[npc_id], minutes)


func tick_npc(npc: NpcState, minutes: float) -> void:
	var t_energy := npc.trait_value("energia")
	var t_soc := npc.trait_value("sociabilidade")
	var t_cur := npc.trait_value("curiosidade")
	var d_energy := -0.055 * (1.2 - t_energy * 0.4)
	var d_social := -0.07 * (0.5 + t_soc)
	var d_fun := -0.055 * (0.6 + t_energy * 0.6 + t_cur * 0.2)
	var d_comfort := -0.035
	match npc.state:
		"RESTING":
			if npc.is_sleeping():
				d_energy = 0.2
				d_comfort = 0.05
				d_social *= 0.2
				d_fun *= 0.2
			else:
				d_energy = 0.05
				d_comfort = 0.35
		"WORKING":
			d_energy -= 0.03
			d_fun -= 0.01
		"SOCIALIZING":
			d_social = 0.55
			d_fun = 0.18
		"LEISURE":
			d_fun = 0.45
			d_comfort = 0.05
		"EXPLORING":
			d_fun = 0.25 + t_cur * 0.2
			d_energy -= 0.02
		"WALKING":
			d_energy -= 0.01
		"IDLE":
			d_comfort = 0.02
	npc.add_need("energia", d_energy * minutes)
	npc.add_need("social", d_social * minutes)
	npc.add_need("diversao", d_fun * minutes)
	npc.add_need("conforto", d_comfort * minutes)
	npc.mood_modifier *= exp(-minutes / 240.0)
	npc.update_emotion()


func set_npc_state(npc_id: String, state: String, activity: String) -> void:
	var npc: NpcState = npcs[npc_id]
	if npc.set_state(state, activity):
		npc.update_emotion()
		npc_state_changed.emit(npc_id, state, activity)


# --- interações sociais entre moradores ----------------------------------

func pair_cooldown_ready(a_id: String, b_id: String) -> bool:
	return now_abs() >= float(_pair_cooldowns.get(SocialRules.pair_key(a_id, b_id), -INF))


func is_in_interaction(npc_id: String) -> bool:
	for key in active_interactions:
		var it: Dictionary = active_interactions[key]
		if it["a"] == npc_id or it["b"] == npc_id:
			return true
	return false


## Inicia uma interação real entre dois moradores, se as condições forem
## cumpridas (proximidade, disponibilidade, cooldown).
func try_start_interaction(a_id: String, b_id: String, distance: float) -> Dictionary:
	var a: NpcState = npcs[a_id]
	var b: NpcState = npcs[b_id]
	var check := SocialRules.can_interact(a, b, self, distance)
	if not check["ok"]:
		return {"ok": false, "reason": check["reason"]}
	var place := Places.nearest_place((a.position + b.position) * 0.5)
	var kind := SocialRules.choose_kind(a, b, self, place, rng)
	var duration := rng.randf_range(18.0, 32.0)
	if kind == SocialRules.KIND_SHARED:
		duration += 15.0
	elif kind == SocialRules.KIND_DISAGREEMENT:
		duration = rng.randf_range(8.0, 14.0)
	var topic := SocialRules.conversation_topic(a, b, rng)
	var info := {"a": a_id, "b": b_id, "kind": kind, "place": place, "started": now_abs(), "duration": duration, "topic": topic}
	active_interactions[SocialRules.pair_key(a_id, b_id)] = info
	a.partner_id = b_id
	b.partner_id = a_id
	set_npc_state(a_id, "SOCIALIZING", _activity_text(kind, b, place))
	set_npc_state(b_id, "SOCIALIZING", _activity_text(kind, a, place))
	interaction_started.emit(a_id, b_id, kind)
	return {"ok": true, "kind": kind, "duration": duration, "place": place}


func _activity_text(kind: String, other: NpcState, place: String) -> String:
	match kind:
		SocialRules.KIND_SHARED:
			return "se divertindo com " + other.display_name()
		SocialRules.KIND_DISAGREEMENT:
			return "discutindo com " + other.display_name()
		SocialRules.KIND_RECONCILIATION:
			return "fazendo as pazes com " + other.display_name()
	return "conversando com " + other.display_name()


## Cancela uma interação sem registrar consequências (ex.: a jogadora chamou
## um dos moradores). Nada é registrado se a interação não se completou.
func cancel_interaction(npc_id: String) -> void:
	for key in active_interactions.keys():
		var it: Dictionary = active_interactions[key]
		if it["a"] == npc_id or it["b"] == npc_id:
			active_interactions.erase(key)
			for pid in [it["a"], it["b"]]:
				var n: NpcState = npcs[pid]
				if n.partner_id != player_id:
					n.partner_id = ""
			return


## Verifica se interações chegaram ao fim e aplica os resultados.
func update_interactions() -> Array:
	var finished := []
	for key in active_interactions.keys():
		var it: Dictionary = active_interactions[key]
		if now_abs() - float(it["started"]) >= float(it["duration"]):
			finished.append(finish_interaction(key))
	return finished


func finish_interaction(key: String) -> Dictionary:
	var it: Dictionary = active_interactions[key]
	active_interactions.erase(key)
	var a: NpcState = npcs[it["a"]]
	var b: NpcState = npcs[it["b"]]
	a.partner_id = ""
	b.partner_id = ""
	var outcome := apply_interaction_outcome(it)
	interaction_finished.emit(a.id, b.id, it["kind"], outcome)
	return outcome


func apply_interaction_outcome(it: Dictionary) -> Dictionary:
	var a: NpcState = npcs[it["a"]]
	var b: NpcState = npcs[it["b"]]
	var kind: String = it["kind"]
	var place: String = it["place"]
	var place_label := Places.poi_label(place)
	var time := time_dict()
	var evt := next_event_id()
	var na := a.display_name()
	var nb := b.display_name()
	var outcome := {"kind": kind, "event_id": evt, "place": place, "a": a.id, "b": b.id}
	var d_aff_a := 0.0
	var d_aff_b := 0.0
	var d_trust := 0.0
	var text := ""
	var relevance := 0.3
	var mem_a := ""
	var mem_b := ""
	var key := SocialRules.pair_key(a.id, b.id)
	var journal_it := true
	match kind:
		SocialRules.KIND_CHAT:
			d_aff_a = 1.5 + a.trait_value("sociabilidade") * 2.0
			d_aff_b = 1.5 + b.trait_value("sociabilidade") * 2.0
			d_trust = 1.0
			if str(it["topic"]).contains(place_label) or place_label.contains(str(it["topic"]).trim_prefix("o ").trim_prefix("a ")):
				text = "%s e %s conversaram sobre %s." % [na, nb, it["topic"]]
			else:
				text = "%s e %s conversaram sobre %s perto d%s %s." % [na, nb, it["topic"], _prep(place_label), place_label]
			mem_a = "Conversou com %s sobre %s." % [nb, it["topic"]]
			mem_b = "Conversou com %s sobre %s." % [na, it["topic"]]
			# Conversas comuns entram no diário no máximo a cada 6 horas por dupla.
			journal_it = now_abs() >= float(_pair_cooldowns.get("journal:" + key, -INF))
			if journal_it:
				_pair_cooldowns["journal:" + key] = now_abs() + 360.0
			a.add_need("social", 6.0)
			b.add_need("social", 6.0)
		SocialRules.KIND_SHARED:
			var what: String = Places.SHARED_ACTIVITIES.get(place, "passaram um tempo juntos")
			d_aff_a = 4.0 + a.trait_value("sociabilidade") * 2.0
			d_aff_b = 4.0 + b.trait_value("sociabilidade") * 2.0
			d_trust = 3.0
			relevance = 0.5
			text = "%s e %s %s." % [na, nb, what]
			mem_a = "%s com %s." % [what.capitalize(), nb]
			mem_b = "%s com %s." % [what.capitalize(), na]
			a.add_need("diversao", 20.0)
			b.add_need("diversao", 20.0)
			a.mood_modifier += 0.15
			b.mood_modifier += 0.15
		SocialRules.KIND_DISAGREEMENT:
			var reason := SocialRules.disagreement_reason(a, b, rng)
			d_aff_a = -4.0 - (1.0 - a.trait_value("gentileza")) * 4.0
			d_aff_b = -4.0 - (1.0 - b.trait_value("gentileza")) * 4.0
			d_trust = -4.0
			relevance = 0.65
			text = "%s e %s tiveram um pequeno desentendimento: %s." % [na, nb, reason]
			mem_a = "Desentendeu-se com %s: %s." % [nb, reason]
			mem_b = "Desentendeu-se com %s: %s." % [na, reason]
			a.mood_modifier -= 0.3
			b.mood_modifier -= 0.3
			for pair in [[a, b], [b, a]]:
				var rel: Dictionary = relationships.get_rel(pair[0].id, pair[1].id)
				rel["conflict_open"] = true
				rel["conflict_since"] = now_abs()
				pair[0].set_cooldown("conflict:" + pair[1].id, now_abs(), SocialRules.DISAGREEMENT_COOLDOWN)
		SocialRules.KIND_RECONCILIATION:
			d_aff_a = 6.0 + a.trait_value("gentileza") * 3.0
			d_aff_b = 6.0 + b.trait_value("gentileza") * 3.0
			d_trust = 4.0
			relevance = 0.7
			text = "%s e %s fizeram as pazes perto d%s %s." % [na, nb, _prep(place_label), place_label]
			mem_a = "Fez as pazes com %s." % nb
			mem_b = "Fez as pazes com %s." % na
			a.mood_modifier += 0.25
			b.mood_modifier += 0.25
			for pair in [[a, b], [b, a]]:
				var rel2: Dictionary = relationships.get_rel(pair[0].id, pair[1].id)
				rel2["conflict_open"] = false
	var change_a := relationships.apply_event(a.id, b.id, kind, d_aff_a, d_trust, evt, time)
	var change_b := relationships.apply_event(b.id, a.id, kind, d_aff_b, d_trust, evt, time)
	relationship_changed.emit(a.id, b.id, relationships.get_rel(a.id, b.id))
	relationship_changed.emit(b.id, a.id, relationships.get_rel(b.id, a.id))
	var consequences := ["afinidade %+.1f" % d_aff_a, "confiança %+.1f" % d_trust]
	var dedup_a := "npc_interaction|%s|%s|%d" % [b.id, kind, day]
	var dedup_b := "npc_interaction|%s|%s|%d" % [a.id, kind, day]
	_remember(a.id, "npc_interaction", [a.id, b.id], mem_a, relevance, consequences, evt, dedup_a)
	_remember(b.id, "npc_interaction", [a.id, b.id], mem_b, relevance, ["afinidade %+.1f" % d_aff_b, "confiança %+.1f" % d_trust], evt, dedup_b)
	_relationship_change_memory(a, b, change_a, evt)
	_relationship_change_memory(b, a, change_b, evt)
	var cd := SocialRules.PAIR_CHAT_COOLDOWN + (60.0 if kind == SocialRules.KIND_SHARED else 0.0)
	_pair_cooldowns[key] = now_abs() + cd
	a.set_cooldown("visit:" + b.id, now_abs(), cd + 60.0)
	b.set_cooldown("visit:" + a.id, now_abs(), cd + 60.0)
	a.update_emotion()
	b.update_emotion()
	outcome["text"] = text
	outcome["affinity_a"] = d_aff_a
	outcome["affinity_b"] = d_aff_b
	outcome["journaled"] = journal_it
	if journal_it:
		var entry := journal.add(evt, kind, [a.id, b.id], text, time)
		journal_added.emit(entry)
	return outcome


func _relationship_change_memory(owner: NpcState, other: NpcState, change: Dictionary, evt: String) -> void:
	if not change["changed"]:
		return
	var label: String = change["new_label"]
	var desc := "Sente que agora %s e %s são %s." % [owner.display_name(), other.display_name() if other else player_name, label]
	_remember(owner.id, "relationship_change", [owner.id, other.id], desc, 0.75, ["relação: %s → %s" % [change["old_label"], label]], evt, "rel|%s|%s" % [other.id, label])


func _relationship_change_memory_player(owner: NpcState, change: Dictionary, evt: String) -> void:
	if not change["changed"]:
		return
	var label: String = change["new_label"]
	var desc := "Sente que agora %s e %s são %s." % [owner.display_name(), player_name, label]
	_remember(owner.id, "relationship_change", [owner.id, player_id], desc, 0.8, ["relação: %s → %s" % [change["old_label"], label]], evt, "rel|%s|%s" % [player_id, label])
	var entry := journal.add(evt + "_rel", "relationship_change", [owner.id, player_id], "%s e %s agora são %s." % [owner.display_name(), player_name, label], time_dict())
	journal_added.emit(entry)


func _remember(npc_id: String, type: String, participants: Array, description: String, relevance: float, consequences: Array, evt: String, dedup_key: String = "") -> Dictionary:
	var result := memories.add_memory(npc_id, type, participants, description, relevance, consequences, evt, time_dict(), dedup_key)
	memory_added.emit(npc_id, result["memory"])
	return result


static func _prep(label: String) -> String:
	# "perto da praça", "perto do lago"
	var feminine := ["praça", "estante", "doca", "fogueira", "praia", "casa", "varanda"]
	for f in feminine:
		if label.begins_with(f) or label.contains("casa"):
			return "a"
	if label.begins_with("píer") or label.begins_with("lago") or label.begins_with("coreto") or label.begins_with("mirante") or label.begins_with("pomar") or label.begins_with("bosque") or label.begins_with("quiosque") or label.begins_with("mural") or label.begins_with("banco"):
		return "o"
	return "a"


# --- encontro comunitário -------------------------------------------------

func conclude_gathering(attendees: Array) -> Dictionary:
	if attendees.size() < 2:
		return {}
	var evt := next_event_id()
	var names := []
	for npc_id in attendees:
		names.append(npcs[npc_id].display_name())
	var who: String = ", ".join(names.slice(0, names.size() - 1)) + " e " + names[-1]
	var text := "%s se reuniram na praça ao entardecer para jogar conversa fora." % who
	for npc_id in attendees:
		var npc: NpcState = npcs[npc_id]
		npc.add_need("social", 10.0)
		npc.mood_modifier += 0.1
		_remember(npc_id, "community_event", attendees, "Participou do encontro na praça com %s." % who, 0.55, ["encontro comunitário"], evt, "gathering|%d" % day)
		for other_id in attendees:
			if other_id != npc_id:
				relationships.apply_event(npc_id, other_id, "community_event", 1.0, 0.5, evt, time_dict(), false)
	var entry := journal.add(evt, "community_event", attendees, text, time_dict())
	journal_added.emit(entry)
	return entry


# --- objetivos pessoais ---------------------------------------------------

func complete_activity(npc_id: String, action: Dictionary) -> void:
	var npc: NpcState = npcs[npc_id]
	var kind: String = action.get("kind", "")
	var gain := 0.0
	if kind == "work":
		gain = 0.0625 if npc.id == "pipa" else 0.04
	elif kind == "leisure" and npc.def.hobbies.size() > 0 and action.get("hobby", "") == npc.def.hobbies[0]:
		gain = 0.03
	if gain <= 0.0 or npc.goal_progress >= 1.0:
		return
	var before := npc.goal_progress
	npc.goal_progress = minf(1.0, npc.goal_progress + gain)
	for milestone in [0.5, 1.0]:
		if before < milestone and npc.goal_progress >= milestone:
			var evt := next_event_id()
			var text := ""
			if milestone >= 1.0:
				text = "%s alcançou seu objetivo: %s!" % [npc.display_name(), npc.def.personal_goal.to_lower()]
			else:
				text = "%s está na metade do caminho para %s." % [npc.display_name(), npc.def.personal_goal.to_lower()]
			_remember(npc_id, "community_event", [npc_id], text, 0.8, ["objetivo pessoal %d%%" % int(milestone * 100)], evt, "goal|%s" % str(milestone))
			var entry := journal.add(evt, "community_event", [npc_id], text, time_dict())
			journal_added.emit(entry)


# --- jogadora ---------------------------------------------------------------

## Primeira conversa do dia com a jogadora fortalece a relação.
func register_player_talk(npc_id: String) -> Dictionary:
	var npc: NpcState = npcs[npc_id]
	var rel: Dictionary = relationships.get_rel(npc_id, player_id)
	var first_ever := int(rel["interactions"]) == 0
	if int(rel.get("talk_day", 0)) == day:
		return {"first_today": false, "first_ever": false}
	rel["talk_day"] = day
	var evt := next_event_id()
	var gain := 2.0 + npc.trait_value("sociabilidade") * 2.0
	var change := relationships.apply_event(npc_id, player_id, "conversation", gain, 1.5, evt, time_dict())
	npc.add_need("social", 8.0)
	if first_ever:
		_remember(npc_id, "important_conversation", [npc_id, player_id], "Conheceu %s e conversaram pela primeira vez." % player_name, 0.75, ["primeiro encontro"], evt, "first_talk|" + player_id)
		var entry := journal.add(evt, "important_conversation", [npc_id, player_id], "%s conversou com %s pela primeira vez." % [player_name, npc.display_name()], time_dict())
		journal_added.emit(entry)
	else:
		_remember(npc_id, "important_conversation", [npc_id, player_id], "Bateu papo com %s." % player_name, 0.35, [], evt, "talk|%s|%d" % [player_id, day])
	_relationship_change_memory_player(npc, change, evt)
	relationship_changed.emit(npc_id, player_id, rel)
	return {"first_today": true, "first_ever": first_ever, "affinity_delta": gain}


## Aplica uma ação sugerida pelo modelo de linguagem, somente se for válida.
func apply_suggested_action(npc_id: String, action: String, player_message: String) -> Dictionary:
	if not npcs.has(npc_id):
		return {"applied": false, "reason": "morador inexistente"}
	var npc: NpcState = npcs[npc_id]
	match action:
		"sorrir":
			if npc.mood_modifier < 0.4:
				npc.mood_modifier = minf(npc.mood_modifier + 0.08, 0.4)
				npc.update_emotion()
				return {"applied": true}
		"ficar_triste":
			npc.mood_modifier = maxf(npc.mood_modifier - 0.08, -0.4)
			npc.update_emotion()
			return {"applied": true}
		"lembrar_conversa":
			if not npc.cooldown_ready("llm_memory", now_abs()):
				return {"applied": false, "reason": "já lembrou de uma conversa hoje"}
			var clean := player_message.strip_edges().replace("\n", " ")
			if clean.length() < 8:
				return {"applied": false, "reason": "mensagem curta demais"}
			npc.set_cooldown("llm_memory", now_abs(), 720.0)
			var evt := next_event_id()
			_remember(npc_id, "important_conversation", [npc_id, player_id], "%s contou: \"%s\"" % [player_name, clean.substr(0, 140)], 0.65, ["conversa marcante"], evt, "llm|%s|%d" % [player_id, day])
			return {"applied": true}
	return {"applied": false, "reason": "ação desconhecida ou sem efeito"}


## Entrega de presente: valida o inventário, calcula a reação pelas
## preferências do morador e registra consequências reais.
func give_gift(npc_id: String, item_id: String, inventory: Inventory) -> Dictionary:
	if not npcs.has(npc_id):
		return {"ok": false, "reason": "morador inexistente"}
	if not ItemDB.exists(item_id) or not inventory.has(item_id, 1):
		return {"ok": false, "reason": "item não está no inventário"}
	var npc: NpcState = npcs[npc_id]
	if npc.is_sleeping():
		return {"ok": false, "reason": "%s está dormindo" % npc.display_name()}
	inventory.remove(item_id, 1)
	var pref := npc.def.preference_for(item_id)
	var rel: Dictionary = relationships.get_rel(npc_id, player_id)
	if int(rel.get("gift_day", 0)) != day:
		rel["gift_day"] = day
		rel["gifts_today"] = 0
	rel["gifts_today"] = int(rel["gifts_today"]) + 1
	var factor := 1.0
	if int(rel["gifts_today"]) == 2:
		factor = 0.5
	elif int(rel["gifts_today"]) > 2:
		factor = 0.0
	var d_aff := 0.0
	var d_trust := 0.0
	var reaction := ""
	var relevance := 0.55
	if pref > 0:
		d_aff = 8.0
		d_trust = 3.0
		reaction = "adorou"
		relevance = 0.8
		npc.mood_modifier += 0.25
	elif pref < 0:
		d_aff = -3.0
		d_trust = -1.0
		reaction = "não gostou"
		relevance = 0.6
		npc.mood_modifier -= 0.15
	else:
		d_aff = 3.0
		d_trust = 1.0
		reaction = "gostou"
		npc.mood_modifier += 0.1
	d_aff *= factor if d_aff > 0.0 else 1.0
	d_trust *= factor if d_trust > 0.0 else 1.0
	var evt := next_event_id()
	var change := relationships.apply_event(npc_id, player_id, "gift", d_aff, d_trust, evt, time_dict())
	var item_text := ItemDB.with_article(item_id)
	var desc := "Recebeu %s de %s e %s." % [item_text, player_name, reaction]
	_remember(npc_id, "gift_received", [npc_id, player_id], desc, relevance, ["afinidade %+.1f" % d_aff], evt, "gift|%s|%s|%d" % [player_id, item_id, day])
	_relationship_change_memory_player(npc, change, evt)
	var journal_text := "%s deu %s para %s, que %s do presente." % [player_name, item_text, npc.display_name(), reaction]
	var entry := journal.add(evt, "gift_received", [player_id, npc_id], journal_text, time_dict())
	journal_added.emit(entry)
	relationship_changed.emit(npc_id, player_id, rel)
	npc.update_emotion()
	return {
		"ok": true,
		"reaction": reaction,
		"preference": pref,
		"affinity_delta": d_aff,
		"trust_delta": d_trust,
		"gifts_today": int(rel["gifts_today"]),
		"event_id": evt,
	}


# --- persistência -----------------------------------------------------------

func npcs_to_array() -> Array:
	var out := []
	for npc_id in npc_order:
		var npc: NpcState = npcs[npc_id]
		out.append(npc.to_dict(relationships.to_dict_for(npc_id), memories.to_array_for(npc_id)))
	return out


func load_from_snapshot(snapshot: Dictionary, defs: Array) -> void:
	npcs.clear()
	npc_order.clear()
	relationships = RelationshipSystem.new()
	memories = MemorySystem.new()
	journal = IslandJournal.new()
	active_interactions.clear()
	_pair_cooldowns.clear()
	player_id = str(snapshot["player_id"])
	player_name = str(snapshot["player"].get("name", "Jogadora"))
	var world: Dictionary = snapshot["world"]
	island_name = str(world.get("island_name", "Daybloom"))
	day = int(world["day"])
	minute = float(world["minute"])
	event_seq = int(world.get("event_seq", 0))
	var pc: Dictionary = world.get("pair_cooldowns", {})
	for key in pc:
		_pair_cooldowns[str(key)] = float(pc[key])
	var by_id := {}
	for def in defs:
		by_id[def.id] = def
	for data in snapshot["npcs"]:
		var npc_id := str(data["id"])
		assert(by_id.has(npc_id), "morador desconhecido no save: %s" % npc_id)
		if npcs.has(npc_id):
			continue  # nunca duplicar
		var npc := NpcState.new(by_id[npc_id])
		npc.apply_dict(data)
		npcs[npc_id] = npc
		npc_order.append(npc_id)
		relationships.load_for(npc_id, data.get("relationships", {}))
		memories.load_for(npc_id, data.get("memories", []))
	# Garante relações com todos (compatibilidade com saves antigos).
	for a_id in npc_order:
		for b_id in npc_order:
			if a_id != b_id:
				relationships.ensure(a_id, b_id)
		relationships.ensure(a_id, player_id, 0.0, 10.0)
	journal.load_from(snapshot.get("journal", []))
	rng.seed = int(Time.get_unix_time_from_system()) ^ event_seq


func pair_cooldowns_to_dict() -> Dictionary:
	var out := {}
	for key in _pair_cooldowns:
		if float(_pair_cooldowns[key]) > now_abs():
			out[key] = snappedf(float(_pair_cooldowns[key]), 0.01)
	return out
