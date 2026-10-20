class_name MemorySystem
extends RefCounted
## Memórias individuais dos moradores, com deduplicação e recuperação por
## relevância e contexto.

const TYPES := ["gift_received", "important_conversation", "npc_interaction", "relationship_change", "community_event"]
const CAPACITY := 80

var memories: Dictionary = {}  # npc_id -> Array[Dictionary]
var _seq: int = 0


func list_for(npc_id: String) -> Array:
	if not memories.has(npc_id):
		memories[npc_id] = []
	return memories[npc_id]


## Registra uma memória. Se já houver uma memória equivalente (mesma chave de
## deduplicação), ela é reforçada em vez de duplicada.
func add_memory(npc_id: String, type: String, participants: Array, description: String, relevance: float, consequences: Array, event_ref: String, time: Dictionary, dedup_key: String = "") -> Dictionary:
	assert(type in TYPES, "tipo de memória inválido: %s" % type)
	var parts := participants.duplicate()
	parts.sort()
	var key := dedup_key if dedup_key != "" else "%s|%s|%d" % [type, ",".join(parts), int(time["day"])]
	var list := list_for(npc_id)
	for mem in list:
		if mem.get("key", "") == key:
			mem["occurrences"] = int(mem["occurrences"]) + 1
			mem["relevance"] = snappedf(minf(1.0, maxf(float(mem["relevance"]), relevance) + 0.05), 0.001)
			mem["description"] = description
			mem["day"] = int(time["day"])
			mem["minute"] = float(time["minute"])
			mem["event_ref"] = event_ref
			for c in consequences:
				if not (mem["consequences"] as Array).has(c):
					(mem["consequences"] as Array).append(c)
			return {"memory": mem, "is_new": false}
	_seq += 1
	var memory := {
		"id": "mem_%s_%d_%d" % [npc_id, int(time["day"]), _seq],
		"type": type,
		"participants": parts,
		"day": int(time["day"]),
		"minute": float(time["minute"]),
		"description": description.substr(0, 390),
		"relevance": snappedf(clampf(relevance, 0.0, 1.0), 0.001),
		"consequences": consequences.duplicate(),
		"event_ref": event_ref,
		"occurrences": 1,
		"key": key,
	}
	list.append(memory)
	_prune(npc_id, time)
	return {"memory": memory, "is_new": true}


func _score(mem: Dictionary, now_abs: float) -> float:
	var age_days := maxf(0.0, (now_abs - ((int(mem["day"]) - 1) * 1440.0 + float(mem["minute"]))) / 1440.0)
	return float(mem["relevance"]) * (1.0 / (1.0 + age_days * 0.25)) + minf(0.2, (int(mem["occurrences"]) - 1) * 0.03)


func _prune(npc_id: String, time: Dictionary) -> void:
	var list := list_for(npc_id)
	if list.size() <= CAPACITY:
		return
	var now_abs := (int(time["day"]) - 1) * 1440.0 + float(time["minute"])
	var scored := []
	for mem in list:
		scored.append([_score(mem, now_abs), mem])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var kept := []
	for i in range(CAPACITY):
		kept.append(scored[i][1])
	# Mantém a ordem cronológica original.
	memories[npc_id] = list.filter(func(m): return kept.has(m))


## Recupera as memórias mais relevantes para um contexto.
## context: {participants: Array, types: Array, keywords: Array, now_abs: float}
func retrieve(npc_id: String, context: Dictionary, limit: int = 5) -> Array:
	var now_abs: float = float(context.get("now_abs", 0.0))
	var wanted_parts: Array = context.get("participants", [])
	var wanted_types: Array = context.get("types", [])
	var keywords: Array = context.get("keywords", [])
	var scored := []
	for mem in list_for(npc_id):
		var score := _score(mem, now_abs)
		for p in wanted_parts:
			if (mem["participants"] as Array).has(p):
				score += 0.6
		if wanted_types.has(mem["type"]):
			score += 0.3
		var desc: String = str(mem["description"]).to_lower()
		for kw in keywords:
			if str(kw).length() >= 3 and desc.contains(str(kw).to_lower()):
				score += 0.25
		scored.append([score, mem])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	for i in range(min(limit, scored.size())):
		out.append(scored[i][1])
	return out


func to_array_for(npc_id: String) -> Array:
	return list_for(npc_id).duplicate(true)


func load_for(npc_id: String, list: Array) -> void:
	var out := []
	var seen := {}
	for raw in list:
		var mem: Dictionary = (raw as Dictionary).duplicate(true)
		if seen.has(mem["id"]):
			continue  # nunca duplicar ao carregar
		seen[mem["id"]] = true
		mem["day"] = int(mem["day"])
		mem["occurrences"] = int(mem.get("occurrences", 1))
		if not mem.has("key"):
			var parts: Array = mem["participants"]
			mem["key"] = "%s|%s|%d" % [mem["type"], ",".join(parts), int(mem["day"])]
		out.append(mem)
		var tail := str(mem["id"]).get_slice("_", str(mem["id"]).get_slice_count("_") - 1)
		if tail.is_valid_int():
			_seq = max(_seq, int(tail))
	memories[npc_id] = out
