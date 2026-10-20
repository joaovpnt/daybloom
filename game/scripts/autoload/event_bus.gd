extends Node
## Barramento global de eventos. Sistemas emitem; interfaces e outros sistemas
## escutam. Nenhum estado é guardado aqui.

signal journal_entry_added(entry: Dictionary)
signal inventory_changed()
signal relationship_changed(owner_id: String, other_id: String, relationship: Dictionary)
signal memory_added(npc_id: String, memory: Dictionary)
signal npc_state_changed(npc_id: String, state: String, activity: String)
signal social_interaction_started(a_id: String, b_id: String, kind: String)
signal social_interaction_finished(a_id: String, b_id: String, kind: String, outcome: Dictionary)
signal save_status_changed(status: Dictionary)
signal toast_requested(text: String)
signal interaction_prompt_changed(text: String)
signal dialogue_requested(npc_id: String)
signal ui_modal_changed(open: bool)
signal backend_status_changed(status: Dictionary)
signal npc_reaction(npc_id: String, kind: String)
signal settings_changed()
