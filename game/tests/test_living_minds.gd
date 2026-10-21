extends TestCase
## Versão 0.3 — Living Minds: contexto, memória, conhecimento limitado,
## rumores, objetivos, ações autorizadas, evolução de personalidade e os
## cenários de regressão A a F (sem depender do Ollama).

var rng := RandomNumberGenerator.new()


func before_each() -> void:
	rng.seed = 77


func after_each() -> void:
	GameState.end_session()


func _awake(sim: Simulation) -> void:
	for id in sim.npc_order:
		var n: NpcState = sim.npcs[id]
		n.inside_home = false
		n.set_state("IDLE", "parado")
	sim.set_time(1, 600.0)


func _place(sim: Simulation, id: String, poi: String, offset := Vector3.ZERO) -> void:
	sim.npcs[id].position = Places.poi_pos(poi) + offset


func _roundtrip_sim(sim_snapshot: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(sim_snapshot))


# --- 19. inicialização dos oito moradores ------------------------------------

func test_oito_moradores_com_perfis_e_objetivos() -> void:
	var sim := new_sim()
	assert_eq(sim.npc_order.size(), 8, "exatamente oito moradores")
	var styles := {}
	for id in sim.npc_order:
		var d: NpcDefinition = sim.npcs[id].def
		assert_true(d.vocabulary.size() >= 3, "%s tem vocabulário" % id)
		assert_true(d.temperament != "" and d.friendship_style != "" and d.social_limits != "", "%s tem perfil profundo" % id)
		assert_true(d.favorite_topics.size() >= 2 and d.disliked_topics.size() >= 1, "%s tem assuntos" % id)
		assert_true(GoalLibrary.has_goal(d.personal_goal_id), "%s tem objetivo em etapas" % id)
		for step in GoalLibrary.steps(d.personal_goal_id):
			assert_true(step["type"] in GoalLibrary.STEP_TYPES, "etapa válida em %s" % id)
		styles[d.speech_style] = true
	assert_eq(styles.size(), 8, "cada morador fala de um jeito")


# --- 1 e 3. contexto e recuperação de memórias ------------------------------------

func test_contexto_contextualizado_e_recuperacao() -> void:
	var sim := new_sim()
	_awake(sim)
	var inv := Inventory.new()
	inv.add("tulipa_coral", 1)
	sim.give_gift("lila", "tulipa_coral", inv)
	for i in range(12):
		sim.memories.add_memory("lila", "npc_interaction", ["lila", "bento"], "Conversou com Bento sobre música %d." % i, 0.4, [], "x%d" % i, sim.time_dict(), "k%d" % i)
	var ctx := ContextBuilder.build(sim.npcs["lila"], sim, "Você lembra do presente que eu te dei? E a Ravena?")
	var mems: Array = ctx["memories"]
	assert_true(mems.size() <= ContextBuilder.MAX_MEMORIES, "memórias limitadas")
	assert_true(str(mems[0]["fact"]).contains("Tulipa"), "o presente é a memória mais relevante: %s" % mems[0]["fact"])
	assert_eq(mems[0]["ref"], "m1", "referência curta para o modelo")
	assert_eq(mems[0]["origin"], "participacao")
	assert_true(mems[0].has("interpretation"), "opinião separada do fato")
	var related: Array = ctx["related_npcs"]
	assert_eq(related.size(), 1, "Ravena detectada na mensagem")
	assert_eq(related[0]["id"], "ravena")
	assert_true((ctx["allowed"]["actions"] as Array).has("registrar_promessa"), "permissões calculadas pelo simulador")
	assert_true(ctx["goal"]["title"] != "", "objetivo ativo no contexto")
	assert_true(ctx["npc"].has("vocabulary") and ctx["npc"].has("temperament"), "perfil conversacional")
	assert_false(ctx.has("recent_facts"), "nada do Diário global")


# --- B / 5. conhecimento limitado e ausência de memórias fictícias ------------

func test_cenario_b_conhecimento_limitado() -> void:
	var sim := new_sim()
	_awake(sim)
	# Tobias e Ravena discutem no mirante; Lila está longe, no jardim; Otávio está perto.
	_place(sim, "tobias", "mirante")
	_place(sim, "ravena", "mirante", Vector3(1, 0, 0))
	_place(sim, "otavio", "mirante", Vector3(4, 0, 2))
	_place(sim, "lila", "jardim")
	_place(sim, "pipa", "praia_sul")
	var it := {"a": "tobias", "b": "ravena", "kind": SocialRules.KIND_DISAGREEMENT, "place": "mirante", "started": sim.now_abs(), "duration": 10.0, "topic": "pintura"}
	var out := sim.apply_interaction_outcome(it)
	assert_true((out["observers"] as Array).has("otavio"), "Otávio, que estava perto, viu")
	assert_false((out["observers"] as Array).has("lila"), "Lila, longe, não viu")
	assert_true(sim.memories.knows_event("otavio", out["event_id"]), "Otávio sabe")
	assert_false(sim.memories.knows_event("lila", out["event_id"]), "Lila não sabe")
	var ctx := ContextBuilder.build(sim.npcs["lila"], sim, "Você viu a briga do Tobias com a Ravena?")
	for e in ctx["known_events"]:
		assert_false(str(e["fact"]).contains("discut"), "o contexto da Lila não contém a briga")
	for m in ctx["memories"]:
		assert_false(str(m["fact"]).contains("Desentendeu"), "nem nas memórias")
	var reply: String = FallbackDialogue.respond(sim.npcs["lila"], sim, "Você viu a briga do Tobias com a Ravena?", rng)["text"]
	assert_true(reply.contains("Não vi nem ouvi"), "Lila admite que não sabe: %s" % reply)
	var reply_o: String = FallbackDialogue.respond(sim.npcs["otavio"], sim, "Você viu a briga do Tobias com a Ravena?", rng)["text"]
	assert_true(reply_o.begins_with("Eu vi"), "Otávio viu: %s" % reply_o)
	# Pergunta sobre briga inexistente com a própria Lila.
	var reply2: String = FallbackDialogue.respond(sim.npcs["lila"], sim, "Você ainda está brigada com a Ravena?", rng)["text"]
	assert_true(reply2.contains("não tivemos briga"), "não inventa briga: %s" % reply2)


# --- 6. fatos e rumores ----------------------------------------------------------------

func test_rumores_separados_de_fatos() -> void:
	var sim := new_sim()
	_awake(sim)
	_place(sim, "tobias", "mirante")
	_place(sim, "ravena", "mirante", Vector3(1, 0, 0))
	_place(sim, "pipa", "mirante", Vector3(3, 0, 1))
	_place(sim, "lila", "jardim")
	var out := sim.apply_interaction_outcome({"a": "tobias", "b": "ravena", "kind": SocialRules.KIND_DISAGREEMENT, "place": "mirante", "started": sim.now_abs(), "duration": 10.0, "topic": "pintura"})
	assert_true(sim.memories.knows_event("pipa", out["event_id"]), "Pipa viu")
	var shared := sim.share_news("pipa", "lila")
	assert_true(shared.size() >= 1, "Pipa conta a novidade para Lila")
	var rumor: Dictionary = {}
	for m in sim.memories.list_for("lila"):
		if m["type"] == "rumor":
			rumor = m
	assert_false(rumor.is_empty(), "Lila guardou um rumor")
	assert_eq(rumor["origin"], "comunicacao", "origem: comunicação")
	assert_eq(rumor["source_id"], "pipa", "fonte identificada")
	assert_true(str(rumor["fact"]).begins_with("Ouviu de Pipa"), "o fato registra que foi ouvido")
	var ctx := ContextBuilder.build(sim.npcs["lila"], sim, "Tem alguma novidade?")
	var found := false
	for e in ctx["known_events"] + ctx["memories"]:
		if e.get("is_rumor", false):
			found = true
			assert_eq(e["source"], "Pipa", "fonte do rumor no contexto")
	assert_true(found, "o contexto marca rumores como rumores")
	# Rumor de rumor fica com validade duvidosa.
	sim.share_news("lila", "celeste")
	for m in sim.memories.list_for("celeste"):
		if m["type"] == "rumor":
			assert_eq(m["validity"], "duvidosa", "boato de segunda mão é duvidoso")
	var news: String = FallbackDialogue.respond(sim.npcs["lila"], sim, "Alguma novidade?", rng)["text"]
	assert_true(news.contains("me contou"), "nos diálogos clássicos o rumor é dito como rumor: %s" % news)


# --- 7. objetivos que evoluem por ações reais ---------------------------------------

func test_objetivo_da_lila_evolui_por_acoes_reais() -> void:
	var sim := new_sim()
	_awake(sim)
	var lila: NpcState = sim.npcs["lila"]
	assert_eq(int(lila.goal_state["step"]), 0)
	sim.complete_activity("lila", {"kind": "leisure", "hobby": "passear"})
	assert_eq(int(lila.goal_state["counts"].get("canteiros", 0)), 0, "atividade errada não conta")
	sim.complete_activity("lila", {"kind": "work"})
	sim.complete_activity("lila", {"kind": "work"})
	assert_eq(int(lila.goal_state["step"]), 1, "etapa 1 concluída por trabalho real")
	var inv := Inventory.new()
	inv.add("concha", 1)
	inv.add("margarida", 2)
	inv.add("girassol", 1)
	sim.give_gift("lila", "concha", inv)
	assert_eq(int(lila.goal_state["step"]), 1, "concha não serve para flores")
	assert_true(sim.goal_help_items("lila").has("margarida"), "Lila sabe do que precisa")
	sim.give_gift("lila", "margarida", inv)
	sim.give_gift("lila", "margarida", inv)
	sim.give_gift("lila", "girassol", inv)
	assert_eq(int(lila.goal_state["step"]), 2, "flores recebidas de verdade")
	_place(sim, "lila", "jardim")
	_place(sim, "bento", "jardim", Vector3(1, 0, 0))
	sim.apply_interaction_outcome({"a": "lila", "b": "bento", "kind": SocialRules.KIND_SHARED, "place": "jardim", "started": sim.now_abs(), "duration": 30.0, "topic": "flores"})
	assert_eq(int(lila.goal_state["step"]), 3, "atividade compartilhada no jardim")
	sim.complete_activity("lila", {"kind": "leisure", "hobby": "jardinagem"})
	sim.complete_activity("lila", {"kind": "leisure", "hobby": "jardinagem"})
	assert_true(int(lila.goal_state["completed_day"]) > 0, "objetivo concluído")
	assert_eq(lila.goal_progress, 1.0)
	var kinds := []
	for e in sim.journal.entries:
		kinds.append(e["kind"])
	for k in ["goal_started", "goal_milestone", "goal_completed"]:
		assert_true(kinds.has(k), "Diário registra %s" % k)
	var long_term := false
	for m in sim.memories.list_for("lila"):
		if m["type"] == "goal_progress" and m["category"] == "longo_prazo":
			long_term = true
	assert_true(long_term, "conclusão vira memória de longo prazo")
	assert_true(sim.npcs["bento"].goal_state["counts"].is_empty() or int(sim.npcs["bento"].goal_state["step"]) == 0, "o objetivo do Bento não avança com a etapa da Lila")


# --- 8 / F. ações proibidas ou impossíveis ------------------------------------------

func test_cenario_f_acoes_impossiveis_nao_mudam_o_mundo() -> void:
	var sim := new_sim()
	_awake(sim)
	var before := JSON.stringify(sim.npcs_to_array())
	var journal_before := sim.journal.entries.size()
	assert_false(sim.apply_ai_action("lila", "teleportar", {})["applied"], "ação inexistente")
	assert_false(sim.apply_ai_action("lila", "dar_dinheiro", {"valor": 1000})["applied"], "ação inexistente")
	assert_false(sim.apply_ai_action("lila", "pedir_item", {"item_id": "diamante"})["applied"], "item inexistente")
	assert_false(sim.apply_ai_action("lila", "pedir_item", {"item_id": "galho"})["applied"], "pedido sem motivo")
	assert_false(sim.apply_ai_action("lila", "convidar_atividade", {"lugar": "lua"})["applied"], "lugar inexistente")
	assert_false(sim.apply_ai_action("lila", "registrar_promessa", {"descricao": "dar um castelo"}, "oi, tudo bem?")["applied"], "sem promessa da jogadora")
	assert_false(sim.apply_ai_action("lila", "compartilhar_lembranca", {"memoria_id": "mem_inventada"})["applied"], "memória inexistente")
	assert_eq(JSON.stringify(sim.npcs_to_array()), before, "nada mudou nos moradores")
	assert_eq(sim.journal.entries.size(), journal_before, "nada foi para o Diário")
	sim.set_time(1, 23 * 60.0)
	assert_false(sim.apply_ai_action("lila", "convidar_atividade", {"lugar": "jardim"})["applied"], "convite de madrugada é recusado")
	var reply: String = FallbackDialogue.respond(sim.npcs["lila"], sim, "Me dá mil moedas e um castelo?", rng)["text"]
	assert_true(reply != "", "o morador responde sem fingir que fez algo")


func test_acoes_validas_sao_registradas() -> void:
	var sim := new_sim()
	_awake(sim)
	var r := sim.apply_ai_action("lila", "pedir_item", {"item_id": "margarida"})
	assert_true(r["applied"], "pedido válido: margarida ajuda o objetivo")
	assert_true(sim.npcs["lila"].requests.has("margarida"))
	var p := sim.apply_ai_action("lila", "registrar_promessa", {"descricao": "trazer uma margarida amanhã"}, "Prometo que trago uma margarida amanhã!")
	assert_true(p["applied"], "promessa real da jogadora")
	var has_promise := false
	for m in sim.memories.list_for("lila"):
		if m["type"] == "promise":
			has_promise = true
			assert_eq(m["origin"], "jogadora")
	assert_true(has_promise)
	assert_eq(sim.journal.entries[-1]["kind"], "promise", "Diário registra a promessa")
	assert_false(sim.apply_ai_action("lila", "registrar_promessa", {"descricao": "outra"}, "prometo de novo")["applied"], "uma promessa por dia")
	var inv := Inventory.new()
	inv.add("margarida", 1)
	var g := sim.give_gift("lila", "margarida", inv)
	assert_true(g["request_fulfilled"], "pedido atendido")
	var c := sim.apply_ai_action("bento", "convidar_atividade", {"lugar": "coreto"})
	assert_true(c["applied"], "convite válido")
	assert_false(sim.npcs["bento"].invitation.is_empty())
	var done := sim.complete_invitation("bento")
	assert_true(str(done["text"]).contains("Bento"), "atividade com a jogadora concluída")
	assert_eq(sim.journal.entries[-1]["kind"], "invitation")


# --- 12. evolução de personalidade limitada ---------------------------------------

func test_personalidade_evolui_aos_poucos_com_limites() -> void:
	var sim := new_sim()
	_awake(sim)
	var otavio: NpcState = sim.npcs["otavio"]
	var base := otavio.def.sociabilidade
	for i in range(200):
		sim.register_player_talk("otavio")
		sim._positive_experience(otavio)
	assert_lt(otavio.trait_value("sociabilidade") - base, 0.031, "no máximo 0,03 por dia")
	assert_gt(otavio.trait_value("sociabilidade"), base, "tímido ganha confiança com boas experiências")
	for d in range(2, 40):
		sim.set_time(d, 600.0)
		sim.on_new_day()
		for i in range(20):
			sim._positive_experience(otavio)
	assert_lt(otavio.trait_value("sociabilidade") - base, 0.1501, "nunca mais que 0,15 do original")
	var lila: NpcState = sim.npcs["lila"]
	var lila_base := lila.trait_value("sociabilidade")
	sim._positive_experience(lila)
	assert_eq(lila.trait_value("sociabilidade"), lila_base, "quem já é sociável não muda por isso")


func test_preferencia_aprendida_com_presentes() -> void:
	var sim := new_sim()
	_awake(sim)
	sim.relationships.get_rel("tobias", sim.player_id)["affinity"] = 30.0
	var inv := Inventory.new()
	inv.add("campanula", 3)
	assert_eq(sim.npcs["tobias"].preference_for("campanula"), 0, "indiferente no começo")
	sim.give_gift("tobias", "campanula", inv)
	sim.set_time(2, 600.0)
	var g := sim.give_gift("tobias", "campanula", inv)
	assert_true(g["learned_like"], "passou a gostar")
	assert_eq(sim.npcs["tobias"].preference_for("campanula"), 1)


# --- 4 / 14 / A. persistência e cenário A -----------------------------------------

func test_cenario_a_presente_lembrado_apos_salvar_e_carregar() -> void:
	GameState.new_game("Ana", "Daybloom", 31)
	var sim := GameState.sim
	_awake(sim)
	GameClock.reset(1, 600.0)
	GameState.inventory.add("tulipa_coral", 1)
	var res := sim.give_gift("lila", "tulipa_coral", GameState.inventory)
	assert_true(res["ok"])
	sim.apply_ai_action("lila", "pedir_item", {"item_id": "margarida"})
	sim.complete_activity("lila", {"kind": "work"})
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameState.build_snapshot()))
	GameState.end_session()
	GameState.new_game("Outra", "Outra", 2)
	assert_true(GameState.apply_snapshot(snap)["ok"], "save carregado")
	sim = GameState.sim
	var lila: NpcState = sim.npcs["lila"]
	var gift_mem: Dictionary = {}
	for m in sim.memories.list_for("lila"):
		if m["type"] == "gift_received":
			gift_mem = m
	assert_false(gift_mem.is_empty(), "memória do presente sobreviveu")
	for key in ["category", "origin", "fact", "interpretation", "validity", "public_fact"]:
		assert_true(gift_mem.has(key), "campo %s persistido" % key)
	assert_true(lila.requests.has("margarida"), "pedido persistido")
	assert_eq(int(lila.goal_state["counts"].get("canteiros", 0)), 1, "progresso da etapa persistido")
	var reply: String = FallbackDialogue.respond(lila, sim, "Lembra do presente que eu te dei?", rng)["text"]
	assert_true(reply.contains("Tulipa"), "Lila lembra do presente: %s" % reply)
	var ctx := ContextBuilder.build(lila, sim, "Lembra do presente que eu te dei?")
	assert_true(str(ctx["memories"][0]["fact"]).contains("Tulipa"), "e o contexto do modelo também")


func test_save_antigo_ganha_campos_novos() -> void:
	var f := FileAccess.open("res://tests/fixtures/save_v0_1.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	assert_true(GameState.apply_snapshot(data)["ok"], "save 0.1 carrega na 0.3")
	var sim := GameState.sim
	for id in sim.npc_order:
		for m in sim.memories.list_for(id):
			assert_true(m["category"] in MemorySystem.CATEGORIES, "categoria preenchida")
			assert_eq(m["origin"], "participacao", "origem padrão")
			assert_true(m.has("fact"), "fato preenchido")
		assert_true(int(sim.npcs[id].goal_state["step"]) >= 0, "etapa derivada")
	var snap := GameState.build_snapshot()
	assert_eq(str(snap["game_version"]), GameState.GAME_VERSION)


# --- C / 15. interação social persistida e relações consistentes ----------------

func test_cenario_c_interacao_social_persistida() -> void:
	GameState.new_game("Ana", "Daybloom", 41)
	var sim := GameState.sim
	_awake(sim)
	_place(sim, "lila", "jardim")
	_place(sim, "bento", "jardim", Vector3(1, 0, 0))
	_place(sim, "celeste", "jardim", Vector3(5, 0, 2))
	var aff_before := sim.relationships.affinity("lila", "bento")
	var cel_before := sim.relationships.affinity("celeste", "lila")
	var start := sim.try_start_interaction("lila", "bento", 1.0)
	assert_true(start["ok"], "interação válida")
	sim.set_time(1, 600.0 + float(start["duration"]) + 1.0)
	var outs := sim.update_interactions()
	assert_eq(outs.size(), 1, "interação concluída pelas regras")
	var out: Dictionary = outs[0]
	assert_gt(sim.relationships.affinity("lila", "bento"), aff_before - 20.0, "relação atualizada")
	assert_eq(sim.relationships.affinity("celeste", "lila"), cel_before, "quem só observou não muda a relação")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameState.build_snapshot()))
	var aff_after := sim.relationships.affinity("lila", "bento")
	GameState.end_session()
	assert_true(GameState.apply_snapshot(snap)["ok"])
	sim = GameState.sim
	assert_eq(snappedf(sim.relationships.affinity("lila", "bento"), 0.01), snappedf(aff_after, 0.01), "afinidade persistida")
	assert_true(sim.memories.knows_event("lila", out["event_id"]) and sim.memories.knows_event("bento", out["event_id"]), "memórias persistidas")
	if (out["observers"] as Array).has("celeste"):
		assert_true(sim.memories.knows_event("celeste", out["event_id"]), "observação persistida")


# --- D. personalidades distintas -------------------------------------------------

func test_cenario_d_mesma_pergunta_respostas_diferentes() -> void:
	var sim := new_sim()
	_awake(sim)
	var q := "Você gosta de dias de chuva?"
	var a: String = FallbackDialogue.respond(sim.npcs["lila"], sim, q, rng)["text"]
	var b: String = FallbackDialogue.respond(sim.npcs["ravena"], sim, q, rng)["text"]
	assert_true(a != b, "respostas diferentes: %s | %s" % [a, b])
	var ca := ContextBuilder.build(sim.npcs["lila"], sim, q)
	var cb := ContextBuilder.build(sim.npcs["ravena"], sim, q)
	assert_true(ca["npc"]["speech_style"] != cb["npc"]["speech_style"], "estilos de fala diferentes")
	assert_true(ca["npc"]["vocabulary"] != cb["npc"]["vocabulary"], "vocabulários diferentes")


# --- 18. iniciativas -----------------------------------------------------------------

func test_iniciativas_com_prioridade_e_cooldown() -> void:
	var sim := new_sim()
	_awake(sim)
	assert_true(sim.initiative_candidate("tobias").is_empty() or sim.initiative_candidate("tobias")["reason"] in ["pedir_ajuda", "pergunta"], "sem motivo forte no início")
	var inv := Inventory.new()
	inv.add("pessego", 1)
	sim.give_gift("tobias", "pessego", inv)
	assert_true(sim.initiative_candidate("tobias").get("reason", "") != "agradecer_presente", "não agradece no mesmo instante")
	sim.set_time(1, 600.0 + 200.0)
	var cand := sim.initiative_candidate("tobias")
	assert_eq(cand.get("reason", ""), "agradecer_presente", "agradecer vem primeiro (depois de um tempo)")
	sim.mark_initiative("tobias", cand, "accepted")
	assert_true(sim.initiative_candidate("tobias").is_empty(), "cooldown individual")
	assert_true(sim.initiative_candidate("lila").is_empty(), "cooldown global evita interrupções seguidas")
	assert_true(sim.initiative_candidate("pipa").is_empty(), "Pipa também espera o cooldown global")
	sim.set_time(1, 600.0 + 200.0 + Simulation.INITIATIVE_GLOBAL_COOLDOWN + 1.0)
	var pipa := sim.initiative_candidate("pipa")
	assert_eq(pipa.get("reason", ""), "pergunta", "depois do cooldown, a curiosa Pipa vem fazer uma pergunta")
	sim.mark_initiative("pipa", pipa, "ignored")
	var ignored := false
	for m in sim.memories.list_for("pipa"):
		if str(m["fact"]).contains("seguiu o caminho"):
			ignored = true
	assert_true(ignored, "ignorar é permitido e lembrado sem drama")


# --- memória: consolidação, promoção e expiração ------------------------------

func test_memoria_consolida_promove_e_expira() -> void:
	var sim := new_sim()
	for i in range(3):
		sim.memories.add_memory("pipa", "npc_interaction", ["pipa", "marina"], "Conversou com Marina.", 0.4, [], "e%d" % i, sim.time_dict(), "mesma")
	var list := sim.memories.list_for("pipa").filter(func(m): return m["key"] == "mesma")
	assert_eq(list.size(), 1, "consolidada")
	assert_eq(list[0]["category"], "longo_prazo", "repetida vira longo prazo")
	assert_eq(list[0]["validity"], "consolidada")
	sim.memories.add_memory("pipa", "player_conversation", ["pipa", sim.player_id], "Ana disse: «oi»", 0.3, [], "c", sim.time_dict(), "conv")
	sim.set_time(4, 600.0)
	sim.on_new_day()
	var recent := sim.memories.list_for("pipa").filter(func(m): return m["key"] == "conv")
	assert_eq(recent[0]["validity"], "desatualizada", "memória recente expira")
	var got := sim.memories.retrieve("pipa", {"keywords": ["oi"], "now_abs": sim.now_abs()}, 10)
	assert_false(got.has(recent[0]), "memórias desatualizadas não entram no contexto")
