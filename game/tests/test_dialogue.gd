extends TestCase
## Diálogos: fallback contextualizado, contexto do modelo, validação de ações
## sugeridas e tratamento de backend/Ollama indisponível ou lento.


func test_fallback_responde_em_portugues_e_por_intencao() -> void:
	var sim := new_sim()
	var rng := RandomNumberGenerator.new()
	var lila: NpcState = sim.npcs["lila"]
	var r1 := FallbackDialogue.respond(lila, sim, "Do que você gosta?", rng)
	assert_eq(r1["intent"], "likes")
	assert_true(r1["text"].contains("flores"), "Lila fala das flores: %s" % r1["text"])
	var r2 := FallbackDialogue.respond(lila, sim, "Qual é o seu sonho?", rng)
	assert_true(r2["text"].contains("jardim"), "objetivo pessoal citado")
	var r3 := FallbackDialogue.respond(lila, sim, "tchau!", rng)
	assert_eq(r3["intent"], "bye")
	var r4 := FallbackDialogue.respond(lila, sim, "asdfgh", rng)
	assert_eq(r4["intent"], "unknown")
	assert_gt(r4["text"].length(), 5)


func test_fallback_usa_relacoes_e_memorias_reais() -> void:
	var sim := new_sim()
	var rng := RandomNumberGenerator.new()
	var ravena: NpcState = sim.npcs["ravena"]
	var opinion := FallbackDialogue.respond(ravena, sim, "O que acha do Tobias?", rng)
	assert_eq(opinion["intent"], "other_npc")
	assert_true(opinion["text"].contains("desentendimento") or opinion["text"].contains("não nos damos"), "Ravena e Tobias estão em atrito: %s" % opinion["text"])
	var inv := Inventory.new()
	inv.add("concha", 1)
	ravena.set_state("IDLE", "parado")
	sim.give_gift("ravena", "concha", inv)
	var mem := FallbackDialogue.respond(ravena, sim, "Você lembra de mim?", rng)
	assert_true(mem["text"].contains("Concha") or mem["text"].contains("concha"), "lembra do presente real: %s" % mem["text"])


func test_vozes_diferentes() -> void:
	var sim := new_sim()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var greetings := {}
	for id in sim.npc_order:
		greetings[FallbackDialogue.greeting(sim.npcs[id], sim, rng)] = true
	assert_eq(greetings.size(), 8, "cada morador cumprimenta do seu jeito")


func test_contexto_do_modelo_limitado() -> void:
	var sim := new_sim()
	for i in range(30):
		sim.memories.add_memory("bento", "important_conversation", ["bento", sim.player_id], "Conversa %d sobre música" % i, 0.5, [], "e%d" % i, {"day": 1, "minute": float(i)}, "k%d" % i)
	var ctx := DialogueContext.build(sim.npcs["bento"], sim, "Vamos falar de música?")
	assert_true((ctx["memories"] as Array).size() <= ContextBuilder.MAX_MEMORIES, "memórias limitadas")
	assert_true((ctx["known_events"] as Array).size() <= ContextBuilder.MAX_EVENTS, "acontecimentos limitados")
	assert_false(ctx.has("recent_facts"), "o Diário global não é enviado ao modelo (0.3)")
	for key in ["npc", "emotion", "relationship", "time", "memories", "known_events", "goal", "allowed", "location"]:
		assert_true(ctx.has(key), "contexto contém %s" % key)
	assert_eq(ctx["npc"]["name"], "Bento")


func test_acoes_sugeridas_sao_validadas() -> void:
	var sim := new_sim()
	assert_false(sim.apply_suggested_action("bento", "dar_1000_moedas", "oi")["applied"], "ação desconhecida é ignorada")
	assert_false(sim.apply_suggested_action("ninguem", "sorrir", "oi")["applied"], "morador inexistente")
	var r1 := sim.apply_suggested_action("bento", "lembrar_conversa", "Hoje é meu aniversário e estou muito feliz!")
	assert_true(r1["applied"], "primeira memória de conversa aceita")
	var r2 := sim.apply_suggested_action("bento", "lembrar_conversa", "Outra coisa importante para lembrar")
	assert_false(r2["applied"], "limite de uma memória de conversa por período")
	var aff := sim.relationships.affinity("bento", sim.player_id)
	sim.apply_suggested_action("bento", "sorrir", "oi")
	assert_eq(sim.relationships.affinity("bento", sim.player_id), aff, "o modelo não altera relacionamentos")


func test_backend_desligado_nao_trava() -> void:
	var old := ApiClient.base_url
	ApiClient.base_url = "http://127.0.0.1:9"  # porta fechada
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_GET, "/health", null, 3.0)
	ApiClient.base_url = old
	assert_false(res["ok"], "sem backend a requisição falha")
	assert_lt(Time.get_ticks_msec() - t0, 5000, "falha rápido, sem congelar")


func test_timeout_do_modelo() -> void:
	# Servidor que aceita a conexão mas nunca responde (simula modelo travado).
	var server := TCPServer.new()
	var port := 0
	for p in range(18765, 18800):
		if server.listen(p, "127.0.0.1") == OK:
			port = p
			break
	assert_gt(port, 0, "servidor de teste iniciado")
	var old := ApiClient.base_url
	ApiClient.base_url = "http://127.0.0.1:%d" % port
	var frames := [0]
	var counter := func(): frames[0] += 1
	tree().process_frame.connect(counter)
	var t0 := Time.get_ticks_msec()
	var res: Dictionary = await ApiClient.request_json(HTTPClient.METHOD_POST, "/api/v1/dialogue", {"x": 1}, 1.0)
	tree().process_frame.disconnect(counter)
	ApiClient.base_url = old
	server.stop()
	assert_false(res["ok"], "timeout vira falha controlada")
	assert_eq(res["error"], "tempo de resposta esgotado")
	assert_lt(Time.get_ticks_msec() - t0, 4000, "respeita o timeout")
	assert_gt(frames[0], 10, "o jogo continuou rodando frames enquanto esperava")


func test_painel_de_dialogo_usa_fallback_sem_ollama() -> void:
	GameState.new_game("Ana", "Daybloom", 11)
	ApiClient.last_health = {"backend": false, "mongo": false, "ollama": false}
	var panel := DialoguePanel.new()
	runner.add_child(panel)
	var npc: NpcState = GameState.sim.npcs["tobias"]
	npc.set_state("IDLE", "parado")
	npc.inside_home = false
	panel.open("tobias")
	assert_true(panel.log_text.get_parsed_text().contains("Tobias"), "saudação exibida")
	assert_gt(GameState.sim.relationships.affinity("tobias", GameState.sim.player_id), 0.0, "primeira conversa do dia aumenta a afinidade")
	await panel.respond_to("Como vai?")
	assert_true(panel.log_text.get_parsed_text().contains("Ana: ") == false, "respond_to não duplica a fala da jogadora")
	assert_eq(panel.last_source, "fallback")
	assert_gt(panel.history.size(), 1, "histórico de conversa mantido")
	panel.queue_free()
	GameState.end_session()
