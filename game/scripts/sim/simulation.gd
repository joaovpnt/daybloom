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
signal goal_changed(npc_id: String, info: Dictionary)

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
	var interp_a := _interpretation(a, b, kind)
	var interp_b := _interpretation(b, a, kind)
	_remember(a.id, "npc_interaction", [a.id, b.id], mem_a, relevance, consequences, evt, dedup_a, {"public": text, "interpretation": interp_a})
	_remember(b.id, "npc_interaction", [a.id, b.id], mem_b, relevance, ["afinidade %+.1f" % d_aff_b, "confiança %+.1f" % d_trust], evt, dedup_b, {"public": text, "interpretation": interp_b})
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
	# 0.3: quem estava perto viu; quem conversou troca novidades que conhece.
	outcome["observers"] = _observe(evt, kind, [a.id, b.id], (a.position + b.position) * 0.5, text, place_label)
	outcome["shared"] = []
	if kind in [SocialRules.KIND_CHAT, SocialRules.KIND_SHARED, SocialRules.KIND_RECONCILIATION]:
		outcome["shared"] += share_news(a.id, b.id)
		outcome["shared"] += share_news(b.id, a.id)
	if kind == SocialRules.KIND_SHARED:
		goal_event(a.id, "atividade_compartilhada", {"place": place, "with": b.id})
		goal_event(b.id, "atividade_compartilhada", {"place": place, "with": a.id})
	for n in [a, b]:
		match kind:
			SocialRules.KIND_DISAGREEMENT:
				evolve_trait(n, "gentileza", -0.004)
			SocialRules.KIND_RECONCILIATION:
				evolve_trait(n, "gentileza", 0.003)
				_positive_experience(n)
			_:
				_positive_experience(n)
	_check_new_friendship(a, b, change_a, evt)
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
	var rel_kind := "new_friendship" if change["improved"] and label in ["amigos", "bons amigos", "melhores amigos"] else "relationship_change"
	var entry := journal.add(evt + "_rel", rel_kind, [owner.id, player_id], "%s e %s agora são %s." % [owner.display_name(), player_name, label], time_dict())
	journal_added.emit(entry)


func _remember(npc_id: String, type: String, participants: Array, description: String, relevance: float, consequences: Array, evt: String, dedup_key: String = "", extra: Dictionary = {}) -> Dictionary:
	var result := memories.add_memory(npc_id, type, participants, description, relevance, consequences, evt, time_dict(), dedup_key, extra)
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
	var kind: String = action.get("kind", "")
	if kind == "work":
		goal_event(npc_id, "trabalho", {})
	elif kind == "leisure" and action.get("hobby", "") != "":
		goal_event(npc_id, "hobby", {"hobby": action.get("hobby", "")})


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
	var trust_before := float(rel["trust"])
	var change := relationships.apply_event(npc_id, player_id, "conversation", gain, 1.5, evt, time_dict())
	npc.add_need("social", 8.0)
	if first_ever:
		_remember(npc_id, "important_conversation", [npc_id, player_id], "Conheceu %s e conversaram pela primeira vez." % player_name, 0.75, ["primeiro encontro"], evt, "first_talk|" + player_id)
		var entry := journal.add(evt, "important_conversation", [npc_id, player_id], "%s conversou com %s pela primeira vez." % [player_name, npc.display_name()], time_dict())
		journal_added.emit(entry)
	else:
		_remember(npc_id, "important_conversation", [npc_id, player_id], "Bateu papo com %s." % player_name, 0.35, [], evt, "talk|%s|%d" % [player_id, day])
	_relationship_change_memory_player(npc, change, evt)
	_check_trust_milestone(npc, trust_before, evt)
	relationship_changed.emit(npc_id, player_id, rel)
	_positive_experience(npc)
	var goal := goal_event(npc_id, "conversar_jogadora", {})
	return {"first_today": true, "first_ever": first_ever, "affinity_delta": gain, "goal": goal}


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
	var pref := npc.preference_for(item_id)
	var trust_before := float(relationships.get_rel(npc_id, player_id)["trust"])
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
	var journal_text := "%s deu %s para %s, que %s do presente." % [player_name, item_text, npc.display_name(), reaction]
	var interp: String = {"adorou": "Foi um presente muito especial.", "gostou": "Foi gentil da parte dela.", "não gostou": "Não era bem o meu gosto."}.get(reaction, "")
	_remember(npc_id, "gift_received", [npc_id, player_id], desc, relevance, ["afinidade %+.1f" % d_aff], evt, "gift|%s|%s|%d" % [player_id, item_id, day], {"public": journal_text, "interpretation": interp})
	_relationship_change_memory_player(npc, change, evt)
	var entry := journal.add(evt, "gift_received", [player_id, npc_id], journal_text, time_dict())
	journal_added.emit(entry)
	var extra := _after_gift(npc, item_id, pref, evt, journal_text)
	_check_trust_milestone(npc, trust_before, evt)
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
		"request_fulfilled": extra.get("request_fulfilled", false),
		"learned_like": extra.get("learned_like", false),
		"goal": extra.get("goal", {}),
	}



# --- 0.3: conhecimento, objetivos, personalidade e iniciativa ---------------

const OBSERVE_RADIUS := 14.0
const NEWS_MAX_AGE_DAYS := 2
const MAX_DRIFT := 0.15
const DAILY_DRIFT := 0.03
const INITIATIVE_NPC_COOLDOWN := 480.0
const INITIATIVE_GLOBAL_COOLDOWN := 180.0
const INVITE_DURATION := 150.0
const PROMISE_MARKERS := ["prometo", "prometi", "vou trazer", "vou te trazer", "juro", "pode deixar", "vou te dar", "eu trago", "trago amanha", "trago depois"]
const AI_ACTIONS := ["pedir_item", "convidar_atividade", "registrar_promessa", "compartilhar_lembranca"]


## Opinião subjetiva de quem viveu a interação (separada do fato).
func _interpretation(owner: NpcState, other: NpcState, kind: String) -> String:
	var aff := relationships.affinity(owner.id, other.id)
	match kind:
		SocialRules.KIND_CHAT:
			if aff >= 30.0:
				return "Adora conversar com %s." % other.display_name()
			if aff < -8.0:
				return "Ainda acha %s meio difícil." % other.display_name()
			return "Gostou da conversa."
		SocialRules.KIND_SHARED:
			return "Achou o tempo com %s muito divertido." % other.display_name()
		SocialRules.KIND_DISAGREEMENT:
			if owner.trait_value("gentileza") >= 0.6:
				return "Ficou chateada, mas quer resolver as coisas com %s." % other.display_name()
			return "Acha que %s passou do ponto." % other.display_name()
		SocialRules.KIND_RECONCILIATION:
			return "Sente alívio por terem feito as pazes."
	return ""


func _observation_fact(kind: String, names: Array, place_label: String) -> String:
	var who := " e ".join(names)
	var verb: String = {
		SocialRules.KIND_CHAT: "conversando",
		SocialRules.KIND_SHARED: "se divertindo juntos",
		SocialRules.KIND_DISAGREEMENT: "discutindo",
		SocialRules.KIND_RECONCILIATION: "fazendo as pazes",
	}.get(kind, "juntos")
	return "Viu %s %s perto d%s %s." % [who, verb, _prep(place_label), place_label]


## Moradores acordados e por perto testemunham o acontecimento (conhecimento
## por observação). Quem não estava lá não fica sabendo automaticamente.
func _observe(evt: String, kind: String, participants: Array, center: Vector3, public_text: String, place_label: String, fact: String = "") -> Array:
	var names := []
	for pid in participants:
		names.append(npcs[pid].display_name() if npcs.has(pid) else player_name)
	if fact == "":
		fact = _observation_fact(kind, names, place_label)
	var observers := []
	for npc_id in npc_order:
		if participants.has(npc_id):
			continue
		var npc: NpcState = npcs[npc_id]
		if npc.is_sleeping() or npc.inside_home:
			continue
		if npc.position.distance_to(center) > OBSERVE_RADIUS:
			continue
		if memories.knows_event(npc_id, evt):
			continue
		var imp := 0.5 if kind == SocialRules.KIND_DISAGREEMENT else 0.35
		_remember(npc_id, "observation", participants, fact, imp, [], evt, "obs|" + evt, {"origin": "observacao", "public": public_text})
		observers.append(npc_id)
	return observers


## Quem conta repassa até 1 ou 2 novidades que realmente conhece; quem ouve
## guarda como RUMOR (origem: comunicação), com a fonte identificada.
func share_news(teller_id: String, listener_id: String) -> Array:
	var teller: NpcState = npcs[teller_id]
	var max_items := 2 if teller.trait_value("sociabilidade") >= 0.7 and teller.trait_value("curiosidade") >= 0.8 else 1
	var candidates := []
	for mem in memories.list_for(teller_id):
		if day - int(mem["day"]) > NEWS_MAX_AGE_DAYS:
			continue
		if not mem.has("public_fact") or str(mem.get("event_ref", "")) == "":
			continue
		if not (mem["type"] in ["npc_interaction", "observation", "rumor", "community_event", "gift_received", "goal_progress"]):
			continue
		if float(mem["relevance"]) < 0.3 or (mem["participants"] as Array).has(listener_id):
			continue
		if memories.knows_event(listener_id, str(mem["event_ref"])):
			continue
		candidates.append(mem)
	candidates.sort_custom(func(x, y): return float(x["relevance"]) > float(y["relevance"]))
	var shared := []
	for mem in candidates.slice(0, max_items):
		var parts: Array = (mem["participants"] as Array).duplicate()
		if not parts.has(teller_id):
			parts.append(teller_id)
		var fact := "Ouviu de %s: %s" % [teller.display_name(), str(mem["public_fact"])]
		_remember(listener_id, "rumor", parts, fact, minf(0.6, float(mem["relevance"]) * 0.7), [], str(mem["event_ref"]), "rumor|" + str(mem["event_ref"]), {
			"origin": "comunicacao",
			"public": str(mem["public_fact"]),
			"source_id": teller_id,
			"validity": "duvidosa" if mem["type"] == "rumor" else "valida",
		})
		shared.append({"teller": teller_id, "listener": listener_id, "event_ref": mem["event_ref"]})
	return shared


## Objetivos: só avançam com acontecimentos reais aceitos pela etapa atual.
func goal_event(npc_id: String, event_type: String, params: Dictionary) -> Dictionary:
	if not npcs.has(npc_id):
		return {}
	var npc: NpcState = npcs[npc_id]
	var gid := npc.def.personal_goal_id
	var steps := GoalLibrary.steps(gid)
	var st := npc.goal_state
	var idx := int(st.get("step", 0))
	if steps.is_empty() or idx >= steps.size():
		return {}
	var step: Dictionary = steps[idx]
	if not GoalLibrary.matches(step, event_type, params):
		return {}
	var info := {"advanced": true, "step_done": false, "completed": false, "step_label": step["label"]}
	var goal_text := npc.def.personal_goal.to_lower()
	if int(st.get("started_day", 0)) == 0:
		st["started_day"] = day
		var evt0 := next_event_id()
		var txt0 := "%s começou a trabalhar no seu objetivo: %s." % [npc.display_name(), goal_text]
		_remember(npc_id, "goal_progress", [npc_id], "Começou a trabalhar no objetivo: %s." % goal_text, 0.6, [], evt0, "goal_start|" + gid, {"public": txt0})
		journal_added.emit(journal.add(evt0, "goal_started", [npc_id], txt0, time_dict()))
		info["started"] = true
	var counts: Dictionary = st["counts"]
	counts[step["id"]] = int(counts.get(step["id"], 0)) + 1
	var need := int(step.get("count", 1))
	if int(counts[step["id"]]) >= need:
		idx += 1
		st["step"] = idx
		info["step_done"] = true
		var evt := next_event_id()
		if idx >= steps.size():
			st["completed_day"] = day
			npc.goal_progress = 1.0
			info["completed"] = true
			var txt := "%s alcançou seu objetivo: %s!" % [npc.display_name(), goal_text]
			_remember(npc_id, "goal_progress", [npc_id], "Realizou o objetivo: %s." % goal_text, 0.95, ["objetivo concluído"], evt, "goal_done|" + gid, {"public": txt, "interpretation": "Um dos dias mais felizes na ilha.", "category": "longo_prazo"})
			journal_added.emit(journal.add(evt, "goal_completed", [npc_id], txt, time_dict()))
			npc.mood_modifier = minf(npc.mood_modifier + 0.4, 0.8)
			evolve_trait(npc, "coragem", 0.03)
		else:
			var txt2 := "%s concluiu uma etapa do objetivo: %s." % [npc.display_name(), step["label"]]
			_remember(npc_id, "goal_progress", [npc_id], "Concluiu a etapa: %s." % step["label"], 0.6, [], evt, "goal_step|%s|%d" % [gid, idx], {"public": txt2})
			journal_added.emit(journal.add(evt, "goal_milestone", [npc_id], txt2, time_dict()))
			npc.mood_modifier = minf(npc.mood_modifier + 0.12, 0.8)
	if not info["completed"]:
		var cur: Dictionary = GoalLibrary.step_at(gid, idx)
		var partial := 0.0 if cur.is_empty() else float(counts.get(cur["id"], 0)) / float(cur.get("count", 1))
		npc.goal_progress = clampf((float(idx) + partial) / float(steps.size()), 0.0, 0.99)
	npc.update_emotion()
	goal_changed.emit(npc_id, info)
	return info


func goal_context(npc_id: String) -> Dictionary:
	var npc: NpcState = npcs[npc_id]
	var gid := npc.def.personal_goal_id
	var idx := int(npc.goal_state.get("step", 0))
	var step := GoalLibrary.step_at(gid, idx)
	var needs := []
	for item_id in GoalLibrary.items_for(step):
		needs.append(ItemDB.display_name(item_id))
	return {
		"title": npc.def.personal_goal,
		"motivation": GoalLibrary.GOALS.get(gid, {}).get("motivation", ""),
		"current_step": step.get("label", ""),
		"progress_pct": int(npc.goal_progress * 100.0),
		"completed": step.is_empty() and int(npc.goal_state.get("completed_day", 0)) > 0,
		"needs": needs,
		"plan_note": npc.goal_state.get("plan_note", ""),
	}


func goal_help_items(npc_id: String) -> Array:
	var npc: NpcState = npcs[npc_id]
	return GoalLibrary.items_for(GoalLibrary.step_at(npc.def.personal_goal_id, int(npc.goal_state.get("step", 0))))


## Evolução gradual e limitada da personalidade (no máximo ±0,15 do traço
## original e 0,03 por dia por traço).
func evolve_trait(npc: NpcState, trait_key: String, delta: float) -> float:
	var base := float(npc.def.traits().get(trait_key, 0.5))
	var used := float(npc.drift_today.get(trait_key, 0.0))
	var allowed := maxf(0.0, DAILY_DRIFT - used)
	var d := clampf(delta, -allowed, allowed)
	var cur := npc.trait_value(trait_key)
	var new_value := clampf(cur + d, maxf(0.0, base - MAX_DRIFT), minf(1.0, base + MAX_DRIFT))
	var applied := new_value - cur
	if absf(applied) > 0.0:
		npc.traits[trait_key] = snappedf(new_value, 0.0001)
		npc.drift_today[trait_key] = used + absf(applied)
	return applied


func _positive_experience(npc: NpcState) -> void:
	# Moradores tímidos ganham confiança aos poucos com boas experiências.
	if npc.def.sociabilidade < 0.5:
		evolve_trait(npc, "sociabilidade", 0.004)
		evolve_trait(npc, "coragem", 0.002)


func _check_new_friendship(a: NpcState, b: NpcState, change: Dictionary, evt: String) -> void:
	if not (change["changed"] and change["improved"] and change["new_label"] == "amigos"):
		return
	var key := "friend:" + SocialRules.pair_key(a.id, b.id)
	if _pair_cooldowns.has(key):
		return
	_pair_cooldowns[key] = now_abs() + 9999999.0
	journal_added.emit(journal.add(evt + "_amizade", "new_friendship", [a.id, b.id], "%s e %s ficaram amigos." % [a.display_name(), b.display_name()], time_dict()))


func _check_trust_milestone(npc: NpcState, before: float, evt: String) -> void:
	var rel: Dictionary = relationships.get_rel(npc.id, player_id)
	var after := float(rel["trust"])
	var marks: Array = rel.get("trust_marks", [])
	for t in [50.0, 75.0]:
		var key := "up%d" % int(t)
		if before < t and after >= t and not marks.has(key):
			marks.append(key)
			journal_added.emit(journal.add(evt + "_" + key, "trust_change", [npc.id, player_id], "%s passou a confiar mais em %s." % [npc.display_name(), player_name], time_dict()))
	if before >= 30.0 and after < 30.0 and not marks.has("down30_%d" % day):
		marks.append("down30_%d" % day)
		journal_added.emit(journal.add(evt + "_down", "trust_change", [npc.id, player_id], "%s está com a confiança em %s abalada." % [npc.display_name(), player_name], time_dict()))
	rel["trust_marks"] = marks


func _after_gift(npc: NpcState, item_id: String, pref: int, evt: String, journal_text: String) -> Dictionary:
	var res := {}
	npc.gift_counts[item_id] = int(npc.gift_counts.get(item_id, 0)) + 1
	var item_name := ItemDB.display_name(item_id)
	if npc.requests.has(item_id) and float(npc.requests[item_id]) >= now_abs():
		npc.requests.erase(item_id)
		relationships.apply_event(npc.id, player_id, "request_fulfilled", 3.0, 3.0, evt + "_pedido", time_dict(), false)
		_remember(npc.id, "gift_received", [npc.id, player_id], "%s trouxe %s, como eu tinha pedido." % [player_name, item_name.to_lower()], 0.7, ["pedido atendido"], evt, "pedido|%s|%d" % [item_id, day], {"interpretation": "%s cumpre o que eu peço." % player_name})
		res["request_fulfilled"] = true
	var aff := relationships.affinity(npc.id, player_id)
	if pref == 0 and int(npc.gift_counts[item_id]) >= 2 and aff >= 15.0 and npc.learned_likes.size() < 3 and not npc.learned_likes.has(item_id):
		npc.learned_likes.append(item_id)
		_remember(npc.id, "gift_received", [npc.id, player_id], "Passou a gostar de %s por causa dos presentes de %s." % [item_name.to_lower(), player_name], 0.8, ["nova preferência"], evt, "gosto|" + item_id, {"category": "longo_prazo", "interpretation": "Agora %s me lembra uma amizade." % item_name.to_lower()})
		res["learned_like"] = true
	res["goal"] = goal_event(npc.id, "receber_item", {"item_id": item_id})
	if pref >= 0:
		npc.pending_initiatives["agradecer_presente"] = {"detail": item_name, "event_ref": evt, "from": now_abs() + 120.0, "until": now_abs() + 1440.0}
		_positive_experience(npc)
	_observe(evt, "gift", [npc.id], npc.position, journal_text, "", "Viu %s dar %s para %s." % [player_name, ItemDB.with_article(item_id).to_lower(), npc.display_name()])
	return res


## Emoção validada vinda do modelo: efeito pequeno e limitado no humor.
func apply_ai_emotion(npc_id: String, emotion: String) -> void:
	if not npcs.has(npc_id):
		return
	var npc: NpcState = npcs[npc_id]
	var d: float = {"alegre": 0.05, "animada": 0.06, "triste": -0.05, "irritada": -0.04, "envergonhada": -0.01}.get(emotion, 0.0)
	if d != 0.0:
		npc.mood_modifier = clampf(npc.mood_modifier + d, -0.4, 0.4)
		npc.update_emotion()


## Ações sugeridas pela IA: o simulador confere permissão e pré-condições e só
## então executa. Nada acontece no mundo sem passar por aqui.
func apply_ai_action(npc_id: String, action: String, params: Dictionary, player_message: String = "") -> Dictionary:
	if not npcs.has(npc_id):
		return {"applied": false, "reason": "morador inexistente"}
	if not (action in AI_ACTIONS):
		return {"applied": false, "reason": "ação não existe no jogo"}
	var npc: NpcState = npcs[npc_id]
	match action:
		"pedir_item":
			var item_id := str(params.get("item_id", ""))
			if not ItemDB.exists(item_id):
				return {"applied": false, "reason": "item inexistente"}
			if not (goal_help_items(npc_id).has(item_id) or npc.preference_for(item_id) > 0):
				return {"applied": false, "reason": "pedido sem motivo"}
			if npc.requests.has(item_id) and float(npc.requests[item_id]) >= now_abs():
				return {"applied": false, "reason": "já pediu este item"}
			npc.requests[item_id] = now_abs() + 2880.0
			_remember(npc_id, "important_conversation", [npc_id, player_id], "Pediu %s para %s." % [ItemDB.with_article(item_id).to_lower(), player_name], 0.4, [], next_event_id(), "pede|%s|%d" % [item_id, day], {"category": "recente"})
			return {"applied": true, "effect": "%s pediu: %s" % [npc.display_name(), ItemDB.display_name(item_id)]}
		"convidar_atividade":
			var place := str(params.get("lugar", ""))
			if not Places.SHARED_ACTIVITIES.has(place):
				return {"applied": false, "reason": "lugar sem atividade"}
			var hour := minute / 60.0
			if hour < 7.0 or hour > 19.5:
				return {"applied": false, "reason": "fora do horário"}
			if not npc.invitation.is_empty():
				return {"applied": false, "reason": "já há um convite"}
			if npc.is_sleeping() or npc.inside_home:
				return {"applied": false, "reason": "morador indisponível"}
			start_invitation(npc_id, place)
			return {"applied": true, "effect": "%s te convidou para %s" % [npc.display_name(), Places.poi_label(place)]}
		"registrar_promessa":
			var desc := str(params.get("descricao", "")).strip_edges().substr(0, 120)
			var folded := MemorySystem._fold(player_message)
			var promised := false
			for marker in PROMISE_MARKERS:
				if folded.contains(marker):
					promised = true
					break
			if not promised or desc.length() < 4:
				return {"applied": false, "reason": "a jogadora não prometeu nada"}
			if not npc.cooldown_ready("promise", now_abs()):
				return {"applied": false, "reason": "promessa já registrada hoje"}
			npc.set_cooldown("promise", now_abs(), 1440.0)
			var evt := next_event_id()
			var text := "%s prometeu a %s: %s." % [player_name, npc.display_name(), desc.trim_suffix(".")]
			_remember(npc_id, "promise", [npc_id, player_id], "%s prometeu: %s." % [player_name, desc.trim_suffix(".")], 0.7, [], evt, "promessa|%d" % day, {"origin": "jogadora", "public": text})
			journal_added.emit(journal.add(evt, "promise", [player_id, npc_id], text, time_dict()))
			return {"applied": true, "effect": "Promessa anotada"}
		"compartilhar_lembranca":
			var mid := str(params.get("memoria_id", ""))
			if memories.get_memory(npc_id, mid).is_empty():
				return {"applied": false, "reason": "lembrança inexistente"}
			memories.recall(npc_id, [mid])
			return {"applied": true, "effect": ""}
	return {"applied": false, "reason": "ação desconhecida"}


## Ações que podem ser sugeridas agora (enviadas ao modelo como permissões).
func allowed_ai_actions(npc_id: String) -> Dictionary:
	var npc: NpcState = npcs[npc_id]
	var actions := ["registrar_promessa", "compartilhar_lembranca"]
	var items := goal_help_items(npc_id)
	for item_id in ItemDB.ITEMS:
		if npc.preference_for(item_id) > 0 and not items.has(item_id):
			items.append(item_id)
	if not items.is_empty():
		actions.append("pedir_item")
	var places := []
	var hour := minute / 60.0
	if npc.invitation.is_empty() and hour >= 7.0 and hour <= 19.5:
		for place in [npc.def.favorite_place, npc.def.work_place, "praca", "praia_sul", "doca"]:
			if Places.SHARED_ACTIVITIES.has(place) and not places.has(place):
				places.append(place)
		if not places.is_empty():
			actions.append("convidar_atividade")
	return {"actions": actions, "items": items, "places": places}


## Motivo para o morador procurar a jogadora por iniciativa própria.
func initiative_candidate(npc_id: String) -> Dictionary:
	var npc: NpcState = npcs[npc_id]
	var now := now_abs()
	if npc.is_sleeping() or npc.inside_home or npc.partner_id != "" or not npc.invitation.is_empty():
		return {}
	if not npc.cooldown_ready("initiative", now) or now < float(_pair_cooldowns.get("initiative_global", -INF)):
		return {}
	var thanks: Dictionary = npc.pending_initiatives.get("agradecer_presente", {})
	if not thanks.is_empty() and now >= float(thanks["from"]) and now <= float(thanks["until"]):
		return {"reason": "agradecer_presente", "detail": thanks["detail"], "event_ref": thanks["event_ref"]}
	var aff := relationships.affinity(npc_id, player_id)
	var help_items := goal_help_items(npc_id)
	if not help_items.is_empty() and npc.cooldown_ready("ask_help", now) and aff >= 0.0:
		var names := []
		for it in help_items.slice(0, 3):
			names.append(ItemDB.display_name(it))
		var ctx := goal_context(npc_id)
		return {"reason": "pedir_ajuda", "detail": "%s; precisa de: %s" % [ctx["current_step"], ", ".join(names)], "items": help_items}
	var list := memories.list_for(npc_id).duplicate()
	list.reverse()
	for mem in list:
		if day - int(mem["day"]) > 1:
			break
		if not mem.has("public_fact") or float(mem["relevance"]) < 0.5:
			continue
		if npc.told_player.has(str(mem["event_ref"])) or (mem["participants"] as Array).has(player_id):
			continue
		if mem["type"] in ["gift_received", "important_conversation", "player_conversation", "promise"]:
			continue
		var detail := str(mem["public_fact"])
		if mem["type"] == "rumor":
			detail = "(rumor, ouviu de %s) %s" % [npcs[mem["source_id"]].display_name() if npcs.has(mem.get("source_id", "")) else "alguém", detail]
		return {"reason": "contar_novidade", "detail": detail, "event_ref": mem["event_ref"], "is_rumor": mem["type"] == "rumor"}
	var hour := minute / 60.0
	if aff >= 25.0 and hour >= 8.0 and hour <= 18.5 and npc.cooldown_ready("invite", now):
		var place := npc.def.favorite_place if Places.SHARED_ACTIVITIES.has(npc.def.favorite_place) else "praca"
		return {"reason": "convidar", "detail": Places.poi_label(place), "place": place}
	var rel: Dictionary = relationships.get_rel(npc_id, player_id)
	if int(rel["interactions"]) <= 2 and npc.trait_value("curiosidade") >= 0.6 and npc.cooldown_ready("question", now):
		return {"reason": "pergunta", "detail": "quer conhecer melhor %s" % player_name}
	return {}


func mark_initiative(npc_id: String, cand: Dictionary, outcome: String) -> void:
	var npc: NpcState = npcs[npc_id]
	var now := now_abs()
	npc.set_cooldown("initiative", now, INITIATIVE_NPC_COOLDOWN)
	_pair_cooldowns["initiative_global"] = now + INITIATIVE_GLOBAL_COOLDOWN
	match str(cand.get("reason", "")):
		"agradecer_presente":
			npc.pending_initiatives.erase("agradecer_presente")
		"pedir_ajuda":
			npc.set_cooldown("ask_help", now, 1440.0)
		"convidar":
			npc.set_cooldown("invite", now, 1440.0)
		"pergunta":
			npc.set_cooldown("question", now, 2880.0)
		"contar_novidade":
			if outcome == "accepted":
				npc.told_player.append(str(cand.get("event_ref", "")))
				while npc.told_player.size() > 40:
					npc.told_player.pop_front()
	if outcome == "ignored":
		_remember(npc_id, "player_conversation", [npc_id, player_id], "Tentou falar com %s, mas ela seguiu o caminho." % player_name, 0.2, [], next_event_id(), "ignorou|%d" % day)


func start_invitation(npc_id: String, place: String) -> void:
	var npc: NpcState = npcs[npc_id]
	npc.invitation = {"place": place, "until": now_abs() + INVITE_DURATION, "started": now_abs()}
	npc.set_cooldown("invite", now_abs(), 1440.0)
	_remember(npc_id, "important_conversation", [npc_id, player_id], "Convidou %s para ir ao %s." % [player_name, Places.poi_label(place)], 0.45, [], next_event_id(), "convite|%d" % day, {"category": "recente"})


## A jogadora apareceu no lugar do convite: atividade compartilhada real.
func complete_invitation(npc_id: String) -> Dictionary:
	var npc: NpcState = npcs[npc_id]
	if npc.invitation.is_empty():
		return {}
	var place: String = npc.invitation["place"]
	npc.invitation = {}
	var what: String = Places.SHARED_ACTIVITIES.get(place, "passaram um tempo juntos")
	var evt := next_event_id()
	var text := "%s e %s %s." % [player_name, npc.display_name(), what]
	var trust_before := float(relationships.get_rel(npc_id, player_id)["trust"])
	var change := relationships.apply_event(npc_id, player_id, "invitation", 5.0, 3.0, evt, time_dict())
	_remember(npc_id, "npc_interaction", [npc_id, player_id], "%s com %s." % [what.capitalize(), player_name], 0.7, ["convite aceito"], evt, "convite_ok|%d" % day, {"public": text, "interpretation": "%s aceitou o meu convite!" % player_name})
	journal_added.emit(journal.add(evt, "invitation", [player_id, npc_id], text, time_dict()))
	_relationship_change_memory_player(npc, change, evt)
	_check_trust_milestone(npc, trust_before, evt)
	npc.add_need("social", 15.0)
	npc.add_need("diversao", 15.0)
	npc.mood_modifier = minf(npc.mood_modifier + 0.2, 0.8)
	npc.update_emotion()
	_positive_experience(npc)
	var goal := goal_event(npc_id, "atividade_compartilhada", {"place": place, "with": player_id})
	return {"text": text, "event_id": evt, "goal": goal}


func expire_invitations() -> Array:
	var expired := []
	for npc_id in npc_order:
		var npc: NpcState = npcs[npc_id]
		if npc.invitation.is_empty() or now_abs() <= float(npc.invitation["until"]):
			continue
		var place: String = npc.invitation["place"]
		npc.invitation = {}
		npc.mood_modifier = maxf(npc.mood_modifier - 0.05, -0.4)
		_remember(npc_id, "player_conversation", [npc_id, player_id], "Esperou %s no %s, mas ela não apareceu." % [player_name, Places.poi_label(place)], 0.3, [], next_event_id(), "convite_perdido|%d" % day)
		expired.append(npc_id)
	return expired


func on_new_day() -> void:
	memories.expire(day)
	for npc_id in npc_order:
		var npc: NpcState = npcs[npc_id]
		npc.drift_today.clear()
		for item_id in npc.requests.keys():
			if float(npc.requests[item_id]) < now_abs():
				npc.requests.erase(item_id)
		var thanks: Dictionary = npc.pending_initiatives.get("agradecer_presente", {})
		if not thanks.is_empty() and float(thanks["until"]) < now_abs():
			npc.pending_initiatives.erase("agradecer_presente")


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
