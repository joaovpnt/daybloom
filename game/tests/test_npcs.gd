extends TestCase
## Moradores: quantidade, identidade, personalidades e Utility AI.


func test_exatamente_oito_moradores() -> void:
	var defs := Simulation.load_definitions()
	assert_eq(defs.size(), 8, "devem existir exatamente 8 definições")
	var sim := new_sim()
	assert_eq(sim.npcs.size(), 8, "a simulação deve ter 8 moradores")


func test_ids_unicos_e_dados_completos() -> void:
	var ids := {}
	var names := {}
	var species := {}
	for def in Simulation.load_definitions():
		assert_false(ids.has(def.id), "ID duplicado: %s" % def.id)
		ids[def.id] = true
		names[def.display_name] = true
		species[def.species] = true
		for field in ["display_name", "species", "occupation", "home_id", "personal_goal", "favorite_place", "speech_style", "personality_summary"]:
			assert_true(str(def.get(field)) != "", "%s sem %s" % [def.id, field])
		assert_true(Places.HOUSES.has(def.home_id), "%s com casa inexistente" % def.id)
		assert_gt(def.likes.size(), 0, "%s sem gostos" % def.id)
		assert_gt(def.dislikes.size(), 0, "%s sem aversões" % def.id)
		assert_gt(def.hobbies.size(), 0, "%s sem hobbies" % def.id)
		for h in def.hobbies:
			assert_true(Places.HOBBY_SPOTS.has(h), "%s com hobby desconhecido %s" % [def.id, h])
	assert_eq(names.size(), 8, "nomes distintos")
	assert_eq(species.size(), 8, "espécies distintas")


func test_personalidades_distintas() -> void:
	var defs := Simulation.load_definitions()
	for i in range(defs.size()):
		for j in range(i + 1, defs.size()):
			var a: Dictionary = defs[i].traits()
			var b: Dictionary = defs[j].traits()
			var dist := 0.0
			for k in a:
				dist += absf(a[k] - b[k])
			assert_gt(dist, 0.35, "%s e %s têm personalidades parecidas demais" % [defs[i].id, defs[j].id])
	# Rotinas diferentes
	var wakes := {}
	for def in defs:
		wakes["%s-%s-%s" % [def.wake_hour, def.sleep_hour, def.work_start_hour]] = true
	assert_eq(wakes.size(), 8, "cada morador tem uma rotina própria")


func test_selecao_de_acao_valida() -> void:
	var sim := new_sim()
	for hour in [6.0, 9.0, 13.0, 18.0, 23.0]:
		sim.set_time(1, hour * 60.0)
		for npc_id in sim.npc_order:
			var npc: NpcState = sim.npcs[npc_id]
			var plan := UtilityBrain.choose_action(npc, sim, {"minute": sim.minute, "abs": sim.now_abs(), "day": 1}, sim.rng)
			assert_true(plan["kind"] in UtilityBrain.ACTIONS, "ação inválida %s" % plan["kind"])
			assert_true(plan["arrive_state"] in NpcState.STATES, "estado de chegada inválido")
			var p: Vector3 = plan["target_pos"]
			assert_lt(Vector2(p.x, p.z).length(), Places.WALK_RADIUS, "destino fora da ilha")
			assert_gt(float(plan["duration"]), 0.0, "duração positiva")


func test_rotina_depende_do_horario() -> void:
	var sim := new_sim()
	var lila: NpcState = sim.npcs["lila"]
	lila.needs = {"energia": 70.0, "social": 80.0, "diversao": 80.0, "conforto": 80.0}
	sim.set_time(1, 23.0 * 60.0)
	var plan := UtilityBrain.choose_action(lila, sim, {"minute": sim.minute, "abs": sim.now_abs(), "day": 1}, sim.rng)
	assert_eq(plan["kind"], "sleep", "Lila dorme às 23h")
	var tobias: NpcState = sim.npcs["tobias"]
	tobias.needs = {"energia": 90.0, "social": 90.0, "diversao": 90.0, "conforto": 90.0}
	sim.set_time(1, 7.0 * 60.0)
	var plan2 := UtilityBrain.choose_action(tobias, sim, {"minute": sim.minute, "abs": sim.now_abs(), "day": 1}, sim.rng)
	assert_eq(plan2["kind"], "work", "Tobias trabalha às 7h no quiosque")
	assert_eq(plan2["place"], "quiosque")
	# Otávio é noturno: às 8h está dormindo; às 23h está acordado.
	assert_true(UtilityBrain.is_sleep_time(sim.npcs["otavio"].def, 8.0), "Otávio dorme de manhã")
	assert_false(UtilityBrain.is_sleep_time(sim.npcs["otavio"].def, 23.0), "Otávio fica acordado à noite")


func test_necessidades_e_personalidade_influenciam() -> void:
	var sim := new_sim()
	sim.set_time(1, 16.0 * 60.0)
	var ctx := {"minute": sim.minute, "abs": sim.now_abs(), "day": 1}
	# Morador sociável com social baixo prefere socializar.
	var lila: NpcState = sim.npcs["lila"]
	lila.needs = {"energia": 80.0, "social": 5.0, "diversao": 80.0, "conforto": 80.0}
	var counts := {}
	for i in range(30):
		var k: String = UtilityBrain.choose_action(lila, sim, ctx, sim.rng)["kind"]
		counts[k] = counts.get(k, 0) + 1
	assert_gt(counts.get("socialize", 0), 20, "Lila solitária deve buscar companhia")
	# Morador cansado prefere dormir/descansar.
	var celeste: NpcState = sim.npcs["celeste"]
	celeste.needs = {"energia": 4.0, "social": 80.0, "diversao": 80.0, "conforto": 80.0}
	var k2: String = UtilityBrain.choose_action(celeste, sim, ctx, sim.rng)["kind"]
	assert_true(k2 in ["sleep", "rest"], "Celeste exausta deveria descansar (obteve %s)" % k2)
	# Curiosidade: Otávio explora mais que Tobias com as mesmas necessidades.
	var ot: NpcState = sim.npcs["otavio"]
	var tb: NpcState = sim.npcs["tobias"]
	var needs := {"energia": 90.0, "social": 95.0, "diversao": 60.0, "conforto": 95.0}
	ot.needs = needs.duplicate()
	tb.needs = needs.duplicate()
	var s_ot := 0.0
	var s_tb := 0.0
	for e in UtilityBrain.score_actions(ot, sim, ctx, sim.rng):
		if e["kind"] == "explore": s_ot = e["score"]
	for e in UtilityBrain.score_actions(tb, sim, ctx, sim.rng):
		if e["kind"] == "explore": s_tb = e["score"]
	assert_gt(s_ot, s_tb, "o curioso Otávio pontua exploração acima de Tobias")


func test_afinidade_alta_atrai_visitas() -> void:
	var sim := new_sim()
	sim.set_time(1, 15.0 * 60.0)
	for id in sim.npc_order:
		sim.relationships.get_rel("pipa", id)["affinity"] = 0.0 if id != "pipa" else 0.0
	sim.relationships.get_rel("pipa", "marina")["affinity"] = 90.0
	var hits := 0
	for i in range(60):
		if UtilityBrain.pick_social_target(sim.npcs["pipa"], sim, sim.rng) == "marina":
			hits += 1
	assert_gt(hits, 20, "Pipa deveria procurar Marina com mais frequência (%d/60)" % hits)


func test_necessidades_mudam_com_o_tempo() -> void:
	var sim := new_sim()
	var npc: NpcState = sim.npcs["marina"]
	npc.set_state("IDLE", "parado")
	var before := npc.need("energia")
	sim.tick(120.0)
	assert_lt(npc.need("energia"), before, "energia cai acordado")
	npc.set_state("RESTING", "dormindo")
	var mid := npc.need("energia")
	sim.tick(120.0)
	assert_gt(npc.need("energia"), mid, "energia sobe dormindo")
	npc.set_state("SOCIALIZING", "conversando")
	var soc := npc.need("social")
	sim.tick(30.0)
	assert_gt(npc.need("social"), soc, "socializar recupera o social")
