extends TestCase
## Versão 0.3 na cena da ilha: iniciativas, convites, falas entre moradores,
## diálogo que não trava (com cancelamento), fallback sem Ollama e emoções.

var world: World
var _server: TCPServer
var _peers: Array = []
var _saved_url := ""
var _saved_health: Dictionary = {}


func before_each() -> void:
	_saved_url = ApiClient.base_url
	_saved_health = ApiClient.last_health
	GameState.new_game("Ana", "Daybloom", 88)
	ApiClient.last_health = {"backend": false, "mongo": false, "ollama": false}
	world = load("res://scenes/world.tscn").instantiate()
	runner.add_child(world)
	var frames := 0
	while not world.is_ready and frames < 600:
		await tree().physics_frame
		frames += 1
	GameClock.running = false
	GameClock.minute = 600.0
	GameState.sim.set_time(GameClock.day, 600.0)


func after_each() -> void:
	ApiClient.base_url = _saved_url
	ApiClient.last_health = _saved_health
	if _server:
		_server.stop()
		_server = null
	_peers.clear()
	if is_instance_valid(world):
		world.queue_free()
	await tree().process_frame
	GameState.end_session()
	tree().auto_accept_quit = true


func _awake_actor_near_player(npc_id: String, dist := 8.0) -> NpcActor:
	var actor: NpcActor = world.director.actors[npc_id]
	var npc: NpcState = actor.npc
	if npc.inside_home:
		actor._exit_home_visual()
	npc.set_state("IDLE", "parado")
	npc.partner_id = ""
	actor.phase = NpcActor.Phase.NEEDS_DECISION
	var map := world.get_world_3d().navigation_map
	actor.global_position = NavigationServer3D.map_get_closest_point(map, world.player.global_position + Vector3(dist, 0, 0))
	npc.position = actor.global_position
	return actor


func test_morador_procura_a_jogadora_e_pode_ser_ignorado() -> void:
	var sim := GameState.sim
	var actor := _awake_actor_near_player("tobias")
	sim.npcs["tobias"].pending_initiatives["agradecer_presente"] = {"detail": "Pêssego", "event_ref": "evt_x", "from": 0.0, "until": sim.now_abs() + 500.0}
	world.life._grace = 0.0
	world.life.start_initiative("tobias", sim.initiative_candidate("tobias"))
	assert_eq(world.life.active_initiative_npc, "tobias", "Tobias tomou a iniciativa")
	var frames := 0
	while actor.phase != NpcActor.Phase.WAITING_PLAYER and frames < 900:
		await tree().physics_frame
		frames += 1
	assert_eq(actor.phase, NpcActor.Phase.WAITING_PLAYER, "chegou perto e espera")
	assert_lt(actor.global_position.distance_to(world.player.global_position), 2.6, "parou perto da jogadora")
	assert_true(world.player.input_enabled, "a jogadora continua livre para andar")
	# A jogadora vai embora: ele desiste.
	world.player.global_position += Vector3(0, 0, 25)
	for i in range(10):
		await tree().physics_frame
	assert_eq(world.life.active_initiative_npc, "", "desistiu quando a jogadora se afastou")
	assert_false(actor.is_waiting_for_player())
	assert_false(sim.npcs["tobias"].cooldown_ready("initiative", sim.now_abs()), "cooldown aplicado")


func test_aceitar_iniciativa_abre_dialogo_com_a_fala_do_morador() -> void:
	var sim := GameState.sim
	var actor := _awake_actor_near_player("lila", 1.8)
	sim.npcs["lila"].pending_initiatives["agradecer_presente"] = {"detail": "Margarida", "event_ref": "evt_y", "from": 0.0, "until": sim.now_abs() + 500.0}
	world.life.start_initiative("lila", sim.initiative_candidate("lila"))
	var frames := 0
	while actor.phase != NpcActor.Phase.WAITING_PLAYER and frames < 300:
		await tree().physics_frame
		frames += 1
	world._on_dialogue_requested("lila")
	await wait_frames(2)
	assert_true(world.dialogue_panel.visible, "diálogo aberto")
	assert_true(world.dialogue_panel.log_text.get_parsed_text().contains("agradecer"), "Lila abre com o agradecimento")
	assert_false(sim.npcs["lila"].pending_initiatives.has("agradecer_presente"), "iniciativa consumida")
	world.dialogue_panel.close_panel()


func test_convite_aceito_vira_atividade_real() -> void:
	var sim := GameState.sim
	var actor := _awake_actor_near_player("bento", 4.0)
	assert_true(sim.apply_ai_action("bento", "convidar_atividade", {"lugar": "coreto"})["applied"])
	var map := world.get_world_3d().navigation_map
	var spot := NavigationServer3D.map_get_closest_point(map, Places.poi_pos("coreto") + Vector3(0, 0, 3.2))
	actor.global_position = spot + Vector3(0.8, 0, 0)
	world.player.global_position = spot
	world.life._update_invitations()
	await wait_frames(2)
	world.life._update_invitations()
	assert_true(sim.npcs["bento"].invitation.is_empty(), "convite concluído")
	assert_eq(sim.journal.entries[-1]["kind"], "invitation", "Diário registra")


func test_falas_entre_moradores_quando_a_jogadora_esta_perto() -> void:
	var sim := GameState.sim
	var a := _awake_actor_near_player("pipa", 3.0)
	var b := _awake_actor_near_player("marina", 4.0)
	sim.npcs["pipa"].position = a.global_position
	sim.npcs["marina"].position = b.global_position
	var res := sim.try_start_interaction("pipa", "marina", 1.0)
	if not res["ok"]:
		sim._pair_cooldowns.clear()
		res = sim.try_start_interaction("pipa", "marina", 1.0)
	assert_true(res["ok"], "conversa válida")
	await wait_frames(3)
	assert_true(a.speech.visible, "a fala aparece acima da Pipa")
	assert_gt(world.life.chats_shown, 0)


func test_dialogo_nao_trava_e_pode_ser_cancelado() -> void:
	# Um "backend" que aceita a conexão e nunca responde (IA muito lenta).
	_server = TCPServer.new()
	var port := 0
	for p in range(18760, 18790):
		if _server.listen(p, "127.0.0.1") == OK:
			port = p
			break
	assert_gt(port, 0, "servidor de teste ativo")
	ApiClient.base_url = "http://127.0.0.1:%d" % port
	ApiClient.last_health = {"backend": true, "mongo": true, "ollama": true}
	var actor := _awake_actor_near_player("celeste", 1.5)
	world._on_dialogue_requested("celeste")
	await wait_frames(2)
	var panel: DialoguePanel = world.dialogue_panel
	panel._append_player("Como você está hoje?")
	panel.respond_to("Como você está hoje?")
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while frames < 45:
		if _server.is_connection_available():
			_peers.append(_server.take_connection())
		await tree().process_frame
		frames += 1
	assert_eq(frames, 45, "o jogo continua rodando enquanto a IA pensa")
	assert_true(panel.waiting_exchange != "", "ainda esperando a resposta")
	assert_true(panel.typing.visible and panel.cancel_button.visible, "indicador e botão de cancelar visíveis")
	assert_false(panel.input.editable, "não envia outra mensagem por cima")
	var lines_before := panel.history.size()
	panel.cancel_request()
	assert_eq(panel.waiting_exchange, "", "cancelado na hora")
	assert_eq(panel.history.size(), lines_before + 1, "resposta clássica imediata")
	assert_true(panel.thinking_label.text.contains("cancelado"), "aviso amigável")
	assert_true(panel.input.editable, "pode continuar conversando")
	assert_lt(Time.get_ticks_msec() - t0, 15000, "nada esperou o timeout")
	panel.close_panel()


func test_cenario_e_sem_ollama_usa_dialogos_classicos() -> void:
	ApiClient.last_health = {"backend": false, "mongo": false, "ollama": false}
	var actor := _awake_actor_near_player("marina", 1.5)
	world._on_dialogue_requested("marina")
	await wait_frames(2)
	var panel: DialoguePanel = world.dialogue_panel
	panel._append_player("Tudo bem?")
	await panel.respond_to("Tudo bem?")
	assert_eq(panel.last_source, "fallback", "resposta dos diálogos clássicos")
	assert_eq(panel.mode_chip.text, "diálogo clássico", "indicador discreto do modo")
	assert_eq(panel.thinking_label.text, "", "sem mensagem de erro quando a IA está simplesmente desligada")
	assert_true(GameState.sim.npcs["marina"].partner_id == GameState.sim.player_id, "o jogo segue normal")
	panel.close_panel()


func test_emocoes_validadas_movem_o_rosto() -> void:
	var actor := _awake_actor_near_player("lila", 1.5)
	world._on_dialogue_requested("lila")
	await wait_frames(2)
	var panel: DialoguePanel = world.dialogue_panel
	panel._apply_validated({"emotion": "alegre", "memory_ids": [], "action": null}, "oi")
	await wait_frames(2)
	assert_eq(actor.visual.expression, "happy", "alegria → rosto feliz")
	assert_true(panel.emotion_chip_holder.get_child_count() > 0, "feedback emocional no painel")
	var chip_text := ""
	for c in panel.mood_holder.get_children():
		if not c.is_queued_for_deletion():
			chip_text += str((c.get_child(0) as Label).text) if c.get_child_count() > 0 and c.get_child(0) is Label else ""
	assert_true(chip_text.contains("Alegre"), "o chip de humor mostra a reação (sem contradição): %s" % chip_text)
	panel._apply_validated({"emotion": "triste", "memory_ids": [], "action": null}, "oi")
	await wait_frames(2)
	assert_eq(actor.visual.expression, "sad", "tristeza → rosto triste")
	panel._apply_validated({"emotion": "surpresa", "memory_ids": [], "action": "acao_falsa", "action_params": {}}, "oi")
	await wait_frames(2)
	assert_eq(actor.visual.expression, "surprised", "surpresa → reação surpresa")
	panel.close_panel()
