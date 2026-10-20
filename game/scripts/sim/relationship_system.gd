class_name RelationshipSystem
extends RefCounted
## Relacionamentos direcionais: cada morador tem sua própria visão de cada um
## dos outros sete moradores e da jogadora.

const HISTORY_LIMIT := 20

var data: Dictionary = {}  # owner_id -> {other_id -> relationship}


static func new_relationship(affinity: float = 0.0, trust: float = 20.0) -> Dictionary:
	return {
		"affinity": affinity,
		"trust": trust,
		"interactions": 0,
		"last_meeting": null,
		"history": [],
		"conflict_open": false,
		"conflict_since": 0.0,
		"gift_day": 0,
		"gifts_today": 0,
		"talk_day": 0,
	}


static func label_for(affinity: float) -> String:
	if affinity < -30.0:
		return "rivais"
	if affinity < -8.0:
		return "em atrito"
	if affinity < 10.0:
		return "conhecidos"
	if affinity < 30.0:
		return "colegas"
	if affinity < 55.0:
		return "amigos"
	if affinity < 80.0:
		return "bons amigos"
	return "melhores amigos"


func ensure(owner_id: String, other_id: String, affinity: float = 0.0, trust: float = 20.0) -> Dictionary:
	if not data.has(owner_id):
		data[owner_id] = {}
	if not data[owner_id].has(other_id):
		data[owner_id][other_id] = new_relationship(affinity, trust)
	return data[owner_id][other_id]


func get_rel(owner_id: String, other_id: String) -> Dictionary:
	return ensure(owner_id, other_id)


func affinity(owner_id: String, other_id: String) -> float:
	return float(get_rel(owner_id, other_id)["affinity"])


func trust(owner_id: String, other_id: String) -> float:
	return float(get_rel(owner_id, other_id)["trust"])


## Aplica um acontecimento à relação de owner com other. Retorna informações
## sobre a mudança de rótulo (usada para criar memórias de mudança de relação).
func apply_event(owner_id: String, other_id: String, kind: String, d_aff: float, d_trust: float, event_id: String, time: Dictionary, counts_as_meeting: bool = true) -> Dictionary:
	var rel := get_rel(owner_id, other_id)
	var old_aff: float = rel["affinity"]
	var old_label := label_for(old_aff)
	rel["affinity"] = clampf(old_aff + d_aff, -100.0, 100.0)
	rel["trust"] = clampf(float(rel["trust"]) + d_trust, 0.0, 100.0)
	if counts_as_meeting:
		rel["interactions"] = int(rel["interactions"]) + 1
		rel["last_meeting"] = {"day": int(time["day"]), "minute": float(time["minute"])}
	var history: Array = rel["history"]
	history.append({
		"event_id": event_id,
		"kind": kind,
		"day": int(time["day"]),
		"minute": float(time["minute"]),
		"affinity_delta": snappedf(d_aff, 0.01),
		"trust_delta": snappedf(d_trust, 0.01),
	})
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
	var new_label := label_for(float(rel["affinity"]))
	return {"old_label": old_label, "new_label": new_label, "changed": old_label != new_label, "improved": float(rel["affinity"]) > old_aff}


func to_dict_for(owner_id: String) -> Dictionary:
	var out := {}
	var rels: Dictionary = data.get(owner_id, {})
	for other in rels:
		var r: Dictionary = rels[other].duplicate(true)
		r["affinity"] = snappedf(float(r["affinity"]), 0.01)
		r["trust"] = snappedf(float(r["trust"]), 0.01)
		out[other] = r
	return out


func load_for(owner_id: String, rels: Dictionary) -> void:
	data[owner_id] = {}
	for other in rels:
		var r := new_relationship()
		var saved: Dictionary = rels[other]
		for key in saved:
			r[key] = saved[key]
		r["affinity"] = clampf(float(r["affinity"]), -100.0, 100.0)
		r["trust"] = clampf(float(r["trust"]), 0.0, 100.0)
		for key in ["interactions", "gift_day", "gifts_today", "talk_day"]:
			r[key] = int(r.get(key, 0))
		r["conflict_open"] = bool(r.get("conflict_open", false))
		r["conflict_since"] = float(r.get("conflict_since", 0.0))
		if r["last_meeting"] is Dictionary:
			r["last_meeting"] = {"day": int(r["last_meeting"]["day"]), "minute": float(r["last_meeting"]["minute"])}
		var hist := []
		for h in r["history"]:
			var e: Dictionary = (h as Dictionary).duplicate()
			e["day"] = int(e["day"])
			hist.append(e)
		r["history"] = hist
		data[owner_id][str(other)] = r
