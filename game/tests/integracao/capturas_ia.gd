extends Node
## Capturas reais da 0.3 (Forward+), com backend, MongoDB e Ollama ligados.
## Uso: DAYBLOOM_API_URL=... godot --path game res://tests/integracao/capturas_ia.tscn -- <pasta>
var out := ""
var w: World


func shot(name: String) -> void:
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("ia_%s.png" % name))
	print("captura ", name)


func _wait_reply(panel: DialoguePanel, max_s: float = 60.0) -> void:
	var t := 0.0
	while panel.waiting_exchange != "" and t < max_s:
		await get_tree().create_timer(0.25).timeout
		t += 0.25


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = Vector2i(1600, 900)
	await ApiClient.check_health()
	GameState.new_game("Ana", "Daybloom", 2026)
	SaveManager.start_new_game_session()
	w = load("res://scenes/world.tscn").instantiate()
	add_child(w)
	while not w.is_ready:
		await get_tree().process_frame
	GameClock.running = false
	GameClock.minute = 10 * 60.0
	var sim := GameState.sim
	sim.set_time(1, 600.0)
	for id in sim.npc_order:
		var a: NpcActor = w.director.actors[id]
		if sim.npcs[id].inside_home:
			a._exit_home_visual()
		sim.npcs[id].set_state("IDLE", "parado")
	# Histórias reais antes das capturas.
	GameState.inventory.add("tulipa_coral", 2)
	GameState.inventory.add("margarida", 3)
	sim.give_gift("lila", "tulipa_coral", GameState.inventory)
	sim.complete_activity("lila", {"kind": "work"})
	sim.complete_activity("lila", {"kind": "work"})
	sim.give_gift("lila", "margarida", GameState.inventory)
	var map := w.get_world_3d().navigation_map
	var spot := NavigationServer3D.map_get_closest_point(map, Places.poi_pos("jardim") + Vector3(2, 0, 4))
	w.player.global_position = spot
	var lila: NpcActor = w.director.actors["lila"]
	lila.global_position = spot + Vector3(1.6, 0, -0.6)
	lila.phase = NpcActor.Phase.NEEDS_DECISION
	w.camera.set_zoom_immediate(0.8)
	w.camera.snap()
	for i in range(30):
		await get_tree().process_frame
	# 1) Conversa real com a Lila (Qwen).
	w._on_dialogue_requested("lila")
	var panel: DialoguePanel = w.dialogue_panel
	panel._append_player("Oi Lila! Você lembra do presente que eu te dei?")
	panel.respond_to("Oi Lila! Você lembra do presente que eu te dei?")
	await get_tree().create_timer(0.6).timeout
	await shot("01_pensando")
	await _wait_reply(panel)
	panel._append_player("Você viu a briga do Tobias com a Ravena?")
	panel.respond_to("Você viu a briga do Tobias com a Ravena?")
	await _wait_reply(panel)
	await shot("02_conversa_real")
	panel.close_panel()
	# 2) Iniciativa: Tobias vem agradecer.
	var tob: NpcActor = w.director.actors["tobias"]
	tob.global_position = NavigationServer3D.map_get_closest_point(map, spot + Vector3(-7, 0, 2))
	tob.phase = NpcActor.Phase.NEEDS_DECISION
	sim.npcs["tobias"].pending_initiatives["agradecer_presente"] = {"detail": "Pêssego", "event_ref": "evt_cap", "from": 0.0, "until": sim.now_abs() + 600.0}
	w.life.start_initiative("tobias", sim.initiative_candidate("tobias"))
	var t := 0.0
	while tob.phase != NpcActor.Phase.WAITING_PLAYER and t < 20.0:
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	await shot("03_iniciativa")
	w._on_dialogue_requested("tobias")
	await _wait_reply(w.dialogue_panel)
	await shot("04_iniciativa_dialogo")
	w.dialogue_panel.close_panel()
	# 3) Falas entre moradores.
	var pipa: NpcActor = w.director.actors["pipa"]
	var mar: NpcActor = w.director.actors["marina"]
	pipa.global_position = NavigationServer3D.map_get_closest_point(map, spot + Vector3(3, 0, 3))
	mar.global_position = NavigationServer3D.map_get_closest_point(map, spot + Vector3(4.2, 0, 3))
	sim.npcs["pipa"].position = pipa.global_position
	sim.npcs["marina"].position = mar.global_position
	for id in ["pipa", "marina"]:
		sim.cancel_interaction(id)
		sim.npcs[id].partner_id = ""
		sim.npcs[id].set_state("IDLE", "parado")
		(w.director.actors[id] as NpcActor).phase = NpcActor.Phase.NEEDS_DECISION
	sim._pair_cooldowns.clear()
	w.life._chat_cooldown = 0.0
	sim.try_start_interaction("pipa", "marina", 1.0)
	w.director.on_interaction_started("pipa", "marina")
	t = 0.0
	while not mar.speech.visible and t < 40.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	await shot("05_falas_entre_moradores")
	# 4) Painel F3 e Diário.
	w.hud.toggle_diagnostics()
	await get_tree().create_timer(2.5).timeout
	await shot("06_diagnostico_f3")
	w.hud.toggle_diagnostics()
	w.journal_panel.open()
	await shot("07_diario")
	w.journal_panel.show_tab(1)
	w.journal_panel.show_detail("lila")
	w.journal_panel.advanced_toggle.button_pressed = true
	await shot("08_diario_lila")
	get_tree().quit()
