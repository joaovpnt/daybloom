class_name MemorySystem
extends RefCounted
## Memórias individuais dos moradores (0.3).
##
## Cada memória guarda o FATO (o que aconteceu, segundo quem lembra), uma
## possível INTERPRETAÇÃO subjetiva (opinião), a ORIGEM do conhecimento
## (participou, viu, ouviu de alguém ou a jogadora contou) e a VALIDADE.
## Categorias: recente (conversas e detalhes passageiros), episódica
## (presentes, discussões, promessas, atividades), social (o que sabe sobre os
## outros) e longo prazo (experiências marcantes, promovidas automaticamente).
## Memórias equivalentes são consolidadas pela chave de deduplicação.

const TYPES := [
	"gift_received", "important_conversation", "npc_interaction", "relationship_change", "community_event",
	"observation", "rumor", "promise", "goal_progress", "player_conversation",
]
const CATEGORIES := ["recente", "episodica", "social", "longo_prazo"]
const ORIGINS := ["participacao", "observacao", "comunicacao", "jogadora"]
const CATEGORY_FOR_TYPE := {
	"gift_received": "episodica",
	"important_conversation": "episodica",
	"npc_interaction": "social",
	"relationship_change": "social",
	"community_event": "episodica",
	"observation": "social",
	"rumor": "social",
	"promise": "episodica",
	"goal_progress": "episodica",
	"player_conversation": "recente",
}
const CAPACITY := 100
const RECENT_DAYS := 2  # memórias "recentes" deixam de valer depois disso
const LONG_TERM_IMPORTANCE := 0.75
const LONG_TERM_OCCURRENCES := 3

## Palavras da conversa que apontam para tipos de memória.
const KEYWORD_TYPES := {
	"presente": ["gift_received"], "presentes": ["gift_received"], "deu": ["gift_received"],
	"ganhou": ["gift_received"], "dei": ["gift_received"], "entreguei": ["gift_received"],
	"briga": ["npc_interaction", "rumor", "observation"], "brigada": ["npc_interaction", "rumor", "observation"],
	"brigado": ["npc_interaction", "rumor", "observation"], "brigaram": ["npc_interaction", "rumor", "observation"],
	"discutiu": ["npc_interaction", "rumor", "observation"], "discussao": ["npc_interaction", "rumor", "observation"],
	"desentendimento": ["npc_interaction", "rumor", "observation"], "pazes": ["npc_interaction"],
	"promessa": ["promise"], "prometi": ["promise"], "prometeu": ["promise"],
	"objetivo": ["goal_progress"], "sonho": ["goal_progress"], "projeto": ["goal_progress"],
	"encontro": ["community_event"], "reuniao": ["community_event"],
}

var memories: Dictionary = {}  # npc_id -> Array[Dictionary]
var _seq: int = 0


func list_for(npc_id: String) -> Array:
	if not memories.has(npc_id):
		memories[npc_id] = []
	return memories[npc_id]


## Registra uma memória. Se já houver uma equivalente (mesma chave), ela é
## reforçada em vez de duplicada. `extra` aceita: category, origin, fact,
## interpretation, validity, source_id.
func add_memory(npc_id: String, type: String, participants: Array, description: String, relevance: float, consequences: Array, event_ref: String, time: Dictionary, dedup_key: String = "", extra: Dictionary = {}) -> Dictionary:
	assert(type in TYPES, "tipo de memória inválido: %s" % type)
	var parts := participants.duplicate()
	parts.sort()
	var key := dedup_key if dedup_key != "" else "%s|%s|%d" % [type, ",".join(parts), int(time["day"])]
	var fact: String = str(extra.get("fact", description)).substr(0, 390)
	var list := list_for(npc_id)
	for mem in list:
		if mem.get("key", "") == key:
			mem["occurrences"] = int(mem["occurrences"]) + 1
			var imp := snappedf(minf(1.0, maxf(float(mem["relevance"]), relevance) + 0.05), 0.001)
			mem["relevance"] = imp
			mem["importance"] = imp
			mem["description"] = fact
			mem["fact"] = fact
			if extra.has("interpretation") and str(extra["interpretation"]) != "":
				mem["interpretation"] = str(extra["interpretation"]).substr(0, 190)
			if extra.has("public"):
				mem["public_fact"] = str(extra["public"]).substr(0, 390)
			mem["day"] = int(time["day"])
			mem["minute"] = float(time["minute"])
			mem["event_ref"] = event_ref
			mem["validity"] = "consolidada"
			for c in consequences:
				if not (mem["consequences"] as Array).has(c):
					(mem["consequences"] as Array).append(c)
			_maybe_promote(mem)
			return {"memory": mem, "is_new": false}
	_seq += 1
	var memory := {
		"id": "mem_%s_%d_%d" % [npc_id, int(time["day"]), _seq],
		"type": type,
		"category": str(extra.get("category", CATEGORY_FOR_TYPE.get(type, "episodica"))),
		"participants": parts,
		"day": int(time["day"]),
		"minute": float(time["minute"]),
		"description": fact,
		"fact": fact,
		"relevance": snappedf(clampf(relevance, 0.0, 1.0), 0.001),
		"importance": snappedf(clampf(relevance, 0.0, 1.0), 0.001),
		"origin": str(extra.get("origin", "participacao")),
		"validity": str(extra.get("validity", "valida")),
		"consequences": consequences.duplicate(),
		"event_ref": event_ref,
		"occurrences": 1,
		"key": key,
	}
	if extra.has("interpretation") and str(extra["interpretation"]) != "":
		memory["interpretation"] = str(extra["interpretation"]).substr(0, 190)
	if extra.has("source_id"):
		memory["source_id"] = str(extra["source_id"])
	# Versão do fato que pode ser contada a outros (terceira pessoa).
	if extra.has("public"):
		memory["public_fact"] = str(extra["public"]).substr(0, 390)
	assert(memory["category"] in CATEGORIES, "categoria inválida")
	assert(memory["origin"] in ORIGINS, "origem inválida")
	_maybe_promote(memory)
	list.append(memory)
	_prune(npc_id, time)
	return {"memory": memory, "is_new": true}


func _maybe_promote(mem: Dictionary) -> void:
	if mem["category"] in ["recente"] or mem["type"] == "rumor":
		return
	if float(mem["relevance"]) >= LONG_TERM_IMPORTANCE or int(mem["occurrences"]) >= LONG_TERM_OCCURRENCES:
		mem["category"] = "longo_prazo"


## O morador já sabe de um acontecimento (por qualquer origem)?
func knows_event(npc_id: String, event_ref: String) -> bool:
	if event_ref == "":
		return false
	for mem in list_for(npc_id):
		if mem.get("event_ref", "") == event_ref:
			return true
	return false


func get_memory(npc_id: String, memory_id: String) -> Dictionary:
	for mem in list_for(npc_id):
		if mem["id"] == memory_id:
			return mem
	return {}


## Marca memórias como lembradas (reforça um pouco a importância).
func recall(npc_id: String, memory_ids: Array) -> int:
	var n := 0
	for mem in list_for(npc_id):
		if memory_ids.has(mem["id"]):
			mem["relevance"] = snappedf(minf(1.0, float(mem["relevance"]) + 0.02), 0.001)
			mem["importance"] = mem["relevance"]
			n += 1
	return n


## Memórias recentes expiram depois de alguns dias (continuam no save como
## desatualizadas até serem descartadas pela poda).
func expire(now_day: int) -> void:
	for list in memories.values():
		for mem in list:
			if mem.get("category", "") == "recente" and now_day - int(mem["day"]) >= RECENT_DAYS:
				mem["validity"] = "desatualizada"


func _score(mem: Dictionary, now_abs: float) -> float:
	var age_days := maxf(0.0, (now_abs - ((int(mem["day"]) - 1) * 1440.0 + float(mem["minute"]))) / 1440.0)
	var decay := 0.25 if mem.get("category", "") != "longo_prazo" else 0.06
	var s := float(mem["relevance"]) * (1.0 / (1.0 + age_days * decay)) + minf(0.2, (int(mem["occurrences"]) - 1) * 0.03)
	if mem.get("validity", "valida") == "desatualizada":
		s *= 0.3
	return s


func _prune(npc_id: String, time: Dictionary) -> void:
	var list := list_for(npc_id)
	if list.size() <= CAPACITY:
		return
	var now_abs := (int(time["day"]) - 1) * 1440.0 + float(time["minute"])
	var scored := []
	for mem in list:
		var s := _score(mem, now_abs)
		if mem.get("category", "") == "longo_prazo":
			s += 0.5
		scored.append([s, mem])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var kept := []
	for i in range(CAPACITY):
		kept.append(scored[i][1])
	memories[npc_id] = list.filter(func(m): return kept.has(m))


## Recupera as memórias mais relevantes para um contexto, combinando filtros,
## relevância, recência e palavras-chave.
## context: {participants, types, categories, keywords, exclude_types,
##           include_outdated, now_abs}
func retrieve(npc_id: String, context: Dictionary, limit: int = 5) -> Array:
	var now_abs: float = float(context.get("now_abs", 0.0))
	var wanted_parts: Array = context.get("participants", [])
	var wanted_types: Array = context.get("types", []).duplicate()
	var wanted_cats: Array = context.get("categories", [])
	var exclude_types: Array = context.get("exclude_types", [])
	var keywords: Array = context.get("keywords", [])
	var include_outdated: bool = context.get("include_outdated", false)
	var type_boost := {}
	for kw in keywords:
		for t in KEYWORD_TYPES.get(_fold(str(kw)), []):
			type_boost[t] = true
	var scored := []
	for mem in list_for(npc_id):
		if exclude_types.has(mem["type"]):
			continue
		if not include_outdated and mem.get("validity", "valida") == "desatualizada":
			continue
		if not wanted_cats.is_empty() and not wanted_cats.has(mem.get("category", "")):
			continue
		var score := _score(mem, now_abs)
		for p in wanted_parts:
			if (mem["participants"] as Array).has(p):
				score += 0.6
		if wanted_types.has(mem["type"]):
			score += 0.3
		if type_boost.has(mem["type"]):
			score += 0.5
		var desc := _fold(str(mem.get("fact", mem["description"])))
		for kw in keywords:
			var k := _fold(str(kw))
			if k.length() >= 3 and desc.contains(k):
				score += 0.45
		scored.append([score, mem])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	for i in range(min(limit, scored.size())):
		out.append(scored[i][1])
	return out


## Acontecimentos que o morador conhece (participou, viu ou ouviu falar),
## mais recentes primeiro.
func known_events(npc_id: String, max_age_days: int, now_day: int, limit: int = 6) -> Array:
	var out := []
	var list := list_for(npc_id).duplicate()
	list.reverse()
	for mem in list:
		if not (mem["type"] in ["npc_interaction", "observation", "rumor", "community_event", "goal_progress"]):
			continue
		if now_day - int(mem["day"]) > max_age_days:
			continue
		out.append(mem)
		if out.size() >= limit:
			break
	return out


func count_for(npc_id: String) -> int:
	return list_for(npc_id).size()


static func _fold(text: String) -> String:
	var t := text.to_lower()
	var from := "áàâãäéèêëíìîïóòôõöúùûüç"
	var to := "aaaaaeeeeiiiiooooouuuuc"
	for i in range(from.length()):
		t = t.replace(from[i], to[i])
	return t


func to_array_for(npc_id: String) -> Array:
	return list_for(npc_id).duplicate(true)


## Carrega memórias de um save (inclusive da 0.1/0.2, completando os campos
## novos) sem nunca duplicar.
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
		# Migração 0.2 -> 0.3: campos opcionais.
		if not mem.has("category") or not (mem["category"] in CATEGORIES):
			mem["category"] = CATEGORY_FOR_TYPE.get(mem["type"], "episodica")
		if not mem.has("origin") or not (mem["origin"] in ORIGINS):
			mem["origin"] = "participacao"
		if not mem.has("fact"):
			mem["fact"] = mem["description"]
		if not mem.has("validity"):
			mem["validity"] = "valida"
		if not mem.has("importance"):
			mem["importance"] = mem["relevance"]
		_maybe_promote(mem)
		out.append(mem)
		var tail := str(mem["id"]).get_slice("_", str(mem["id"]).get_slice_count("_") - 1)
		if tail.is_valid_int():
			_seq = max(_seq, int(tail))
	memories[npc_id] = out
