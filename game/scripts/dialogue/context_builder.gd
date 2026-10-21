class_name ContextBuilder
extends RefCounted
## Monta o contexto enviado ao modelo de linguagem (0.3).
##
## Princípios:
##  - só o que é relevante para esta conversa (nada de banco de dados inteiro);
##  - só o que ESTE morador sabe: memórias próprias (participou, viu, ouviu
##    dizer ou a jogadora contou) — o Diário da Ilha não é enviado;
##  - fatos, opiniões e rumores separados;
##  - permissões calculadas pelo simulador (ações, itens, lugares).

const MAX_MEMORIES := 6
const MAX_EVENTS := 5
const MAX_RELATED := 3


## Detecta moradores citados numa mensagem (por nome ou apelido).
static func mentioned_npcs(sim: Simulation, text: String, exclude: String = "") -> Array:
	var folded := " " + MemorySystem._fold(text) + " "
	for p in [",", ".", "!", "?", ";", ":", "\"", "'"]:
		folded = folded.replace(p, " ")
	var out := []
	for npc_id in sim.npc_order:
		if npc_id == exclude:
			continue
		var npc: NpcState = sim.npcs[npc_id]
		var names: Array = Array(npc.def.aliases) if npc.def.aliases.size() > 0 else [npc_id]
		for alias in names:
			if folded.contains(" " + MemorySystem._fold(str(alias)) + " "):
				out.append(npc_id)
				break
	return out


static func _needs_text(npc: NpcState) -> Array:
	var out := []
	var art := npc.def.article()
	if npc.need("energia") < 30.0:
		out.append("cansad%s (energia %d)" % [art, int(npc.need("energia"))])
	if npc.need("social") < 30.0:
		out.append("com vontade de companhia")
	if npc.need("diversao") < 30.0:
		out.append("um pouco entediad%s" % art)
	if npc.need("conforto") < 30.0:
		out.append("precisando descansar")
	return out


static func _opinion(sim: Simulation, owner_id: String, other_id: String) -> String:
	var rel: Dictionary = sim.relationships.get_rel(owner_id, other_id)
	var aff := float(rel["affinity"])
	var other := sim.npcs[other_id] as NpcState
	if bool(rel.get("conflict_open", false)):
		return "vocês tiveram um desentendimento e ainda não fizeram as pazes"
	if aff >= 55.0:
		return "gosta muito de %s" % other.display_name()
	if aff >= 30.0:
		return "considera %s um(a) amigo(a)" % other.display_name()
	if aff < -8.0:
		return "não se dá muito bem com %s" % other.display_name()
	return ""


static func _fact_of(mem: Dictionary) -> String:
	return str(mem.get("fact", mem.get("description", "")))


## Contexto completo para conversa com a jogadora.
static func build(npc: NpcState, sim: Simulation, message: String, history: Array = []) -> Dictionary:
	var rel: Dictionary = sim.relationships.get_rel(npc.id, sim.player_id)
	var related_ids := mentioned_npcs(sim, message, npc.id)
	for turn in history.slice(max(0, history.size() - 2)):
		for rid in mentioned_npcs(sim, str(turn.get("text", "")), npc.id):
			if not related_ids.has(rid):
				related_ids.append(rid)
	var keywords: Array = Array(FallbackDialogue.normalize(message).split(" ", false))
	var wanted_parts: Array = [sim.player_id] + related_ids
	var mems := sim.memories.retrieve(npc.id, {
		"participants": wanted_parts,
		"keywords": keywords,
		"now_abs": sim.now_abs(),
	}, MAX_MEMORIES)
	var memory_out := []
	var used_ids := {}
	for i in range(mems.size()):
		var m: Dictionary = mems[i]
		used_ids[m["id"]] = true
		var entry := {
			"ref": "m%d" % (i + 1),
			"id": m["id"],
			"category": m.get("category", "episodica"),
			"origin": m.get("origin", "participacao"),
			"fact": _fact_of(m),
			"day": int(m["day"]),
		}
		if str(m.get("interpretation", "")) != "":
			entry["interpretation"] = m["interpretation"]
		if m["type"] == "rumor":
			entry["is_rumor"] = true
			if sim.npcs.has(str(m.get("source_id", ""))):
				entry["source"] = sim.npcs[str(m["source_id"])].display_name()
		memory_out.append(entry)
	# Acontecimentos que o morador conhece (participou, viu ou ouviu falar).
	var events := []
	for m in sim.memories.known_events(npc.id, 2, sim.day, 12):
		if used_ids.has(m["id"]):
			continue
		var is_rumor: bool = m["type"] == "rumor"
		var source := ""
		if is_rumor and sim.npcs.has(str(m.get("source_id", ""))):
			source = sim.npcs[str(m["source_id"])].display_name()
		events.append({
			"fact": str(m.get("public_fact", _fact_of(m))) if is_rumor else _fact_of(m),
			"origin": m.get("origin", "participacao"),
			"day": int(m["day"]),
			"is_rumor": is_rumor,
			"source": source,
		})
		if events.size() >= MAX_EVENTS:
			break
	var related := []
	for rid in related_ids.slice(0, MAX_RELATED):
		var other: NpcState = sim.npcs[rid]
		var r: Dictionary = sim.relationships.get_rel(npc.id, rid)
		var facts := []
		for m in sim.memories.retrieve(npc.id, {"participants": [rid], "now_abs": sim.now_abs()}, 6):
			if (m["participants"] as Array).has(rid):
				var f := _fact_of(m)
				if m["type"] == "rumor":
					f = "(rumor) " + f
				facts.append(f)
			if facts.size() >= 2:
				break
		related.append({
			"id": rid,
			"name": other.display_name(),
			"relation_label": RelationshipSystem.label_for(float(r["affinity"])),
			"affinity": snappedf(float(r["affinity"]), 0.1),
			"opinion": _opinion(sim, npc.id, rid),
			"known_facts": facts,
		})
	var def := npc.def
	return {
		"island_name": sim.island_name,
		"player_name": sim.player_name,
		"npc": {
			"id": npc.id,
			"name": npc.display_name(),
			"species": def.species,
			"occupation": def.occupation,
			"pronoun": def.pronoun,
			"personality_summary": def.personality_summary,
			"traits": npc.traits.duplicate(),
			"speech_style": def.speech_style,
			"vocabulary": Array(def.vocabulary),
			"catchphrase": def.catchphrase,
			"temperament": def.temperament,
			"values": Array(def.values),
			"favorite_topics": Array(def.favorite_topics),
			"disliked_topics": Array(def.disliked_topics),
			"long_term_goals": Array(def.long_term_goals),
			"social_limits": def.social_limits,
			"characteristic_reactions": def.characteristic_reactions,
			"friendship_style": def.friendship_style,
			"likes": _pref_labels(npc, true),
			"dislikes": Array(def.dislikes).map(func(t): return SocialRules._tag_label(t)),
			"current_activity": npc.activity,
		},
		"emotion": {"mood": npc.mood, "valence": snappedf(npc.valence, 0.01)},
		"needs": _needs_text(npc),
		"time": {"day": sim.day, "label": GameClock.format_hm(sim.minute), "period": GameClock.period_for(sim.minute)},
		"location": Places.poi_label(Places.nearest_place(npc.position)),
		"relationship": {
			"affinity": snappedf(float(rel["affinity"]), 0.1),
			"trust": snappedf(float(rel["trust"]), 0.1),
			"label": RelationshipSystem.label_for(float(rel["affinity"])),
			"interactions": int(rel["interactions"]),
		},
		"related_npcs": related,
		"goal": sim.goal_context(npc.id),
		"memories": memory_out,
		"known_events": events,
		"allowed": sim.allowed_ai_actions(npc.id),
	}


static func _pref_labels(npc: NpcState, likes: bool) -> Array:
	var out: Array = Array(npc.def.likes).map(func(t): return SocialRules._tag_label(t))
	for item_id in npc.learned_likes:
		out.append(ItemDB.display_name(item_id))
	return out


## Contexto curto para falas entre dois moradores (só o que o jogo decidiu).
static func build_npc_chat(sim: Simulation, a_id: String, b_id: String, kind: String, topic: String, place: String) -> Dictionary:
	var a: NpcState = sim.npcs[a_id]
	var b: NpcState = sim.npcs[b_id]
	var info := func(n: NpcState) -> Dictionary:
		return {"id": n.id, "name": n.display_name(), "personality_summary": n.def.personality_summary,
			"speech_style": n.def.speech_style, "mood": n.mood}
	return {
		"a": info.call(a),
		"b": info.call(b),
		"kind": kind,
		"topic": topic,
		"place": Places.poi_label(place),
		"relation_label": RelationshipSystem.label_for(sim.relationships.affinity(a_id, b_id)),
	}
