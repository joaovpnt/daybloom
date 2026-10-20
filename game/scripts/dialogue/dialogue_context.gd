class_name DialogueContext
extends RefCounted
## Monta o contexto limitado e estruturado enviado ao modelo de linguagem.


static func build(npc: NpcState, sim: Simulation, message: String) -> Dictionary:
	var rel: Dictionary = sim.relationships.get_rel(npc.id, sim.player_id)
	var keywords := FallbackDialogue.normalize(message).split(" ", false)
	var mems := sim.memories.retrieve(npc.id, {
		"participants": [sim.player_id],
		"keywords": Array(keywords),
		"now_abs": sim.now_abs(),
	}, 5)
	var memory_lines := []
	for m in mems:
		memory_lines.append("Dia %d: %s" % [int(m["day"]), m["description"]])
	var facts := []
	for e in sim.journal.recent(6):
		facts.append("Dia %d às %s: %s" % [int(e["day"]), GameClock.format_hm(float(e["minute"])), e["text"]])
	return {
		"island_name": sim.island_name,
		"player_name": sim.player_name,
		"npc": {
			"id": npc.id,
			"name": npc.display_name(),
			"species": npc.def.species,
			"occupation": npc.def.occupation,
			"personality_summary": npc.def.personality_summary,
			"traits": npc.traits,
			"speech_style": npc.def.speech_style,
			"catchphrase": npc.def.catchphrase,
			"likes": Array(npc.def.likes).map(func(t): return SocialRules._tag_label(t)),
			"dislikes": Array(npc.def.dislikes).map(func(t): return SocialRules._tag_label(t)),
			"hobbies": Array(npc.def.hobbies),
			"personal_goal": npc.def.personal_goal,
			"current_activity": npc.activity,
		},
		"emotion": {"mood": npc.mood, "valence": snappedf(npc.valence, 0.01)},
		"relationship": {
			"affinity": snappedf(float(rel["affinity"]), 0.1),
			"trust": snappedf(float(rel["trust"]), 0.1),
			"label": RelationshipSystem.label_for(float(rel["affinity"])),
			"interactions": int(rel["interactions"]),
		},
		"time": {"day": sim.day, "label": GameClock.format_hm(sim.minute), "period": GameClock.period_for(sim.minute)},
		"memories": memory_lines,
		"recent_facts": facts,
	}
