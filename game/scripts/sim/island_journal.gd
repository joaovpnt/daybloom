class_name IslandJournal
extends RefCounted
## "Diário da Ilha": somente acontecimentos confirmados pela simulação.

const LIMIT := 200

var entries: Array = []


func add(event_id: String, kind: String, participants: Array, text: String, time: Dictionary) -> Dictionary:
	for e in entries:
		if e["event_id"] == event_id:
			return e
	var entry := {
		"event_id": event_id,
		"day": int(time["day"]),
		"minute": snappedf(float(time["minute"]), 0.01),
		"kind": kind,
		"participants": participants.duplicate(),
		"text": text,
	}
	entries.append(entry)
	while entries.size() > LIMIT:
		entries.pop_front()
	return entry


func recent(count: int) -> Array:
	return entries.slice(max(0, entries.size() - count))


func to_array() -> Array:
	return entries.duplicate(true)


func load_from(list: Array) -> void:
	entries = []
	var seen := {}
	for raw in list:
		var e: Dictionary = (raw as Dictionary).duplicate(true)
		if seen.has(e["event_id"]):
			continue
		seen[e["event_id"]] = true
		e["day"] = int(e["day"])
		entries.append(e)
