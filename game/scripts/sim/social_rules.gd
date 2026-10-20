class_name SocialRules
extends RefCounted
## Regras das interações sociais entre moradores: decide o tipo de interação
## a partir do contexto e calcula as consequências.

const KIND_CHAT := "friendly_chat"
const KIND_SHARED := "shared_activity"
const KIND_DISAGREEMENT := "disagreement"
const KIND_RECONCILIATION := "reconciliation"

const PAIR_CHAT_COOLDOWN := 90.0          # minutos entre interações do mesmo par
const DISAGREEMENT_COOLDOWN := 2880.0     # 2 dias entre desentendimentos do mesmo par
const RECONCILE_MIN_DELAY := 120.0        # tempo mínimo para "esfriar a cabeça"
const MEET_DISTANCE := 2.6


static func pair_key(a_id: String, b_id: String) -> String:
	return "%s+%s" % [a_id, b_id] if a_id < b_id else "%s+%s" % [b_id, a_id]


## Verifica as condições reais para iniciar uma interação.
static func can_interact(a: NpcState, b: NpcState, sim, distance: float) -> Dictionary:
	if a.id == b.id:
		return {"ok": false, "reason": "mesmo morador"}
	if distance > MEET_DISTANCE:
		return {"ok": false, "reason": "longe demais"}
	if not a.is_available() or not b.is_available():
		return {"ok": false, "reason": "indisponível"}
	if not sim.pair_cooldown_ready(a.id, b.id):
		return {"ok": false, "reason": "conversaram há pouco"}
	return {"ok": true, "reason": ""}


static func shared_hobbies(a: NpcState, b: NpcState) -> Array:
	var out := []
	for h in a.def.hobbies:
		if b.def.hobbies.has(h):
			out.append(h)
	return out


## Decide o tipo de interação conforme personalidades, humor, histórico e lugar.
static func choose_kind(a: NpcState, b: NpcState, sim, place_id: String, rng: RandomNumberGenerator) -> String:
	var now: float = sim.now_abs()
	var rel_ab: Dictionary = sim.relationships.get_rel(a.id, b.id)
	var rel_ba: Dictionary = sim.relationships.get_rel(b.id, a.id)
	var conflict := bool(rel_ab.get("conflict_open", false)) or bool(rel_ba.get("conflict_open", false))
	var kindness := (a.trait_value("gentileza") + b.trait_value("gentileza")) * 0.5

	if conflict:
		var since := maxf(float(rel_ab.get("conflict_since", 0.0)), float(rel_ba.get("conflict_since", 0.0)))
		if now - since >= RECONCILE_MIN_DELAY and rng.randf() < 0.35 + kindness * 0.6:
			return KIND_RECONCILIATION
		return KIND_CHAT

	# Chance de desentendimento: pouca gentileza, mau humor, cansaço e gostos opostos.
	var chance := 0.015 + (1.0 - kindness) * 0.12
	if a.valence < 0.0 or b.valence < 0.0:
		chance += 0.08
	if a.need("energia") < 30.0 or b.need("energia") < 30.0:
		chance += 0.05
	if _tastes_clash(a, b):
		chance += 0.05
	chance *= 1.0 - kindness * 0.6
	var avg_aff := (float(rel_ab["affinity"]) + float(rel_ba["affinity"])) * 0.5
	if avg_aff > 50.0:
		chance *= 0.4
	if not sim.npcs[a.id].cooldown_ready("conflict:" + b.id, now):
		chance = 0.0
	if rng.randf() < chance:
		return KIND_DISAGREEMENT

	# Atividade compartilhada: hobby em comum ou lugar propício, com vontade de se divertir.
	var shared := shared_hobbies(a, b)
	var place_ok := Places.SHARED_ACTIVITIES.has(place_id)
	if place_ok and (a.need("diversao") < 75.0 or b.need("diversao") < 75.0):
		var p := 0.22 + (0.28 if not shared.is_empty() else 0.0) + clampf(avg_aff / 200.0, 0.0, 0.25)
		if rng.randf() < p:
			return KIND_SHARED
	return KIND_CHAT


static func _tastes_clash(a: NpcState, b: NpcState) -> bool:
	for h in a.def.hobbies:
		var topic: String = Places.HOBBY_SPOTS.get(h, {}).get("topic", "")
		for d in b.def.dislikes:
			if topic.contains(d):
				return true
	for like in a.def.likes:
		if b.def.dislikes.has(like):
			return true
	for like in b.def.likes:
		if a.def.dislikes.has(like):
			return true
	return false


static func conversation_topic(a: NpcState, b: NpcState, rng: RandomNumberGenerator) -> String:
	var shared := shared_hobbies(a, b)
	if not shared.is_empty():
		return Places.HOBBY_SPOTS[shared[rng.randi() % shared.size()]]["topic"]
	var pool := []
	for h in a.def.hobbies + b.def.hobbies:
		pool.append(Places.HOBBY_SPOTS.get(h, {}).get("topic", "o tempo"))
	pool.append("o clima da ilha")
	return pool[rng.randi() % pool.size()]


static func disagreement_reason(a: NpcState, b: NpcState, rng: RandomNumberGenerator) -> String:
	var reasons := []
	for like in a.def.likes:
		if b.def.dislikes.has(like):
			reasons.append("%s defendeu seu gosto por %s, que %s detesta" % [a.display_name(), _tag_label(like), b.display_name()])
	for like in b.def.likes:
		if a.def.dislikes.has(like):
			reasons.append("%s criticou o gosto de %s por %s" % [a.display_name(), b.display_name(), _tag_label(like)])
	if a.need("energia") < 30.0 or b.need("energia") < 30.0:
		reasons.append("o cansaço deixou a conversa tensa")
	reasons.append("discordaram sobre qual é o lugar mais bonito da ilha")
	reasons.append("um comentário atravessado sobre %s gerou mal-estar" % conversation_topic(a, b, rng))
	return reasons[rng.randi() % reasons.size()]


static func _tag_label(tag: String) -> String:
	if ItemDB.exists(tag):
		return ItemDB.display_name(tag).to_lower()
	var labels := {
		"flor": "flores", "flor_branca": "flores brancas", "flor_vermelha": "flores vermelhas",
		"flor_azul": "flores azuis", "flor_amarela": "flores amarelas", "fruta": "frutas",
		"doce": "doces", "azedo": "coisas azedas", "comida": "comida", "praia": "coisas da praia",
		"concha": "conchas", "raro": "coisas raras", "material": "materiais", "madeira": "madeira",
		"pedra": "pedras",
	}
	return labels.get(tag, tag)
