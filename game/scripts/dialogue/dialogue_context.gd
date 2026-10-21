class_name DialogueContext
extends RefCounted
## Compatibilidade com a 0.2: o contexto agora é montado pelo ContextBuilder.


static func build(npc: NpcState, sim: Simulation, message: String, history: Array = []) -> Dictionary:
	return ContextBuilder.build(npc, sim, message, history)
