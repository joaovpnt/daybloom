extends TestCase
## Interações sociais reais entre moradores, relacionamentos e memórias.


func _awake(sim: Simulation) -> void:
	for id in sim.npc_order:
		var n: NpcState = sim.npcs[id]
		n.inside_home = false
		n.set_state("IDLE", "parado")
		n.partner_id = ""


func test_exige_proximidade() -> void:
	var sim := new_sim()
	_awake(sim)
	var res := sim.try_start_interaction("lila", "bento", 10.0)
	assert_false(res["ok"], "não deve interagir a 10 m de distância")
	assert_eq(res["reason"], "longe demais")
	assert_eq(sim.journal.entries.size(), 1, "nada registrado no diário")


func test_exige_disponibilidade() -> void:
	var sim := new_sim()
	_awake(sim)
	sim.npcs["bento"].set_state("RESTING", "dormindo")
	var res := sim.try_start_interaction("lila", "bento", 1.0)
	assert_false(res["ok"], "não interage com quem dorme")
	sim.npcs["bento"].set_state("IDLE", "parado")
	sim.npcs["bento"].partner_id = "pipa"
	assert_false(sim.try_start_interaction("lila", "bento", 1.0)["ok"], "não interage com quem já conversa")


func test_conversa_modifica_relacao_e_gera_memoria() -> void:
	var sim := new_sim()
	_awake(sim)
	var before := sim.relationships.affinity("lila", "bento")
	var before_b := sim.relationships.affinity("bento", "lila")
	var res := sim.try_start_interaction("lila", "bento", 1.5)
	assert_true(res["ok"], "interação deve começar")
	assert_eq(sim.npcs["lila"].state, "SOCIALIZING")
	assert_eq(sim.npcs["lila"].partner_id, "bento")
	# Antes de terminar, nada é registrado.
	assert_eq(sim.memories.list_for("lila").filter(func(m): return m["type"] == "npc_interaction").size(), 0)
	sim.set_time(1, sim.minute + 60.0)
	var outcomes := sim.update_interactions()
	assert_eq(outcomes.size(), 1, "a interação termina após a duração")
	var kind: String = outcomes[0]["kind"]
	var after := sim.relationships.affinity("lila", "bento")
	if kind == SocialRules.KIND_DISAGREEMENT:
		assert_lt(after, before, "desentendimento reduz afinidade")
	else:
		assert_gt(after, before, "interação positiva aumenta afinidade")
		assert_gt(sim.relationships.affinity("bento", "lila"), before_b, "a relação recíproca também muda")
	var mems := sim.memories.list_for("lila").filter(func(m): return m["type"] == "npc_interaction")
	assert_eq(mems.size(), 1, "memória da interação registrada")
	assert_true((mems[0]["participants"] as Array).has("bento"), "memória cita o participante")
	assert_eq(mems[0]["event_ref"], outcomes[0]["event_id"], "memória referencia o evento")
	assert_eq(sim.npcs["lila"].partner_id, "", "parceiro liberado")
	var rel: Dictionary = sim.relationships.get_rel("lila", "bento")
	assert_eq(int(rel["interactions"]), 1, "histórico de interações")
	assert_eq(int(rel["last_meeting"]["day"]), 1, "último encontro registrado")
	assert_eq((rel["history"] as Array).size(), 1, "evento no histórico da relação")


func test_cooldown_evita_repeticao() -> void:
	var sim := new_sim()
	_awake(sim)
	sim.try_start_interaction("marina", "pipa", 1.0)
	sim.set_time(1, sim.minute + 60.0)
	sim.update_interactions()
	var res := sim.try_start_interaction("marina", "pipa", 1.0)
	assert_false(res["ok"], "par em cooldown não conversa de novo logo em seguida")
	sim.set_time(1, sim.minute + 300.0)
	assert_true(sim.try_start_interaction("marina", "pipa", 1.0)["ok"], "após o cooldown podem conversar")


func test_tres_tipos_de_interacao() -> void:
	var sim := new_sim(99)
	_awake(sim)
	# Atividade compartilhada no jardim (hobby em comum: jardinagem)
	var lila: NpcState = sim.npcs["lila"]
	var celeste: NpcState = sim.npcs["celeste"]
	lila.position = Places.poi_pos("jardim")
	celeste.position = Places.poi_pos("jardim") + Vector3(1, 0, 0)
	lila.needs["diversao"] = 30.0
	var kinds := {}
	for i in range(40):
		kinds[SocialRules.choose_kind(lila, celeste, sim, "jardim", sim.rng)] = true
	assert_true(kinds.has(SocialRules.KIND_SHARED), "atividade compartilhada deve ocorrer no jardim")
	assert_true(kinds.has(SocialRules.KIND_CHAT), "conversa amistosa deve ocorrer")
	# Desentendimento: Ravena (pouco gentil, gostos opostos) e Marina cansadas e de mau humor.
	var ravena: NpcState = sim.npcs["ravena"]
	var marina: NpcState = sim.npcs["marina"]
	ravena.valence = -0.5
	marina.valence = -0.4
	ravena.needs["energia"] = 20.0
	var dis := 0
	for i in range(200):
		if SocialRules.choose_kind(ravena, marina, sim, "praca", sim.rng) == SocialRules.KIND_DISAGREEMENT:
			dis += 1
	assert_gt(dis, 0, "desentendimento possível em contexto tenso")
	# Gentis e de bom humor quase nunca brigam.
	var gentle := 0
	var tobias: NpcState = sim.npcs["tobias"]
	celeste.valence = 0.6
	tobias.valence = 0.6
	for i in range(200):
		if SocialRules.choose_kind(tobias, celeste, sim, "praca", sim.rng) == SocialRules.KIND_DISAGREEMENT:
			gentle += 1
	assert_lt(float(gentle), float(dis), "moradores gentis brigam menos")


func test_desentendimento_e_reconciliacao() -> void:
	var sim := new_sim()
	_awake(sim)
	var it := {"a": "ravena", "b": "tobias", "kind": SocialRules.KIND_DISAGREEMENT, "place": "praca", "started": sim.now_abs(), "duration": 10.0, "topic": "receitas"}
	var before := sim.relationships.affinity("ravena", "tobias")
	sim.apply_interaction_outcome(it)
	assert_lt(sim.relationships.affinity("ravena", "tobias"), before, "afinidade cai")
	assert_true(sim.relationships.get_rel("ravena", "tobias")["conflict_open"], "conflito aberto")
	assert_eq(sim.journal.entries[-1]["kind"], SocialRules.KIND_DISAGREEMENT, "diário registra o desentendimento")
	# Logo depois não há reconciliação (precisa esfriar a cabeça).
	var early := 0
	for i in range(50):
		if SocialRules.choose_kind(sim.npcs["ravena"], sim.npcs["tobias"], sim, "praca", sim.rng) == SocialRules.KIND_RECONCILIATION:
			early += 1
	assert_eq(early, 0, "sem reconciliação imediata")
	sim.set_time(1, sim.minute + 240.0)
	var kinds := {}
	for i in range(50):
		kinds[SocialRules.choose_kind(sim.npcs["ravena"], sim.npcs["tobias"], sim, "praca", sim.rng)] = true
	assert_true(kinds.has(SocialRules.KIND_RECONCILIATION), "reconciliação possível depois")
	var it2 := it.duplicate()
	it2["kind"] = SocialRules.KIND_RECONCILIATION
	var mid := sim.relationships.affinity("ravena", "tobias")
	sim.apply_interaction_outcome(it2)
	assert_gt(sim.relationships.affinity("ravena", "tobias"), mid, "reconciliação melhora a relação")
	assert_false(sim.relationships.get_rel("ravena", "tobias")["conflict_open"], "conflito resolvido")


func test_cancelamento_nao_registra() -> void:
	var sim := new_sim()
	_awake(sim)
	var entries := sim.journal.entries.size()
	sim.try_start_interaction("bento", "pipa", 1.0)
	sim.cancel_interaction("bento")
	sim.set_time(1, sim.minute + 90.0)
	assert_eq(sim.update_interactions().size(), 0, "interação cancelada não termina com resultado")
	assert_eq(sim.journal.entries.size(), entries, "nada novo no diário")
	assert_eq(sim.npcs["pipa"].partner_id, "", "parceiros liberados")


func test_memorias_sem_duplicacao_e_recuperacao() -> void:
	var mem := MemorySystem.new()
	var t := {"day": 2, "minute": 600.0}
	var r1 := mem.add_memory("lila", "gift_received", ["lila", "p"], "Recebeu uma Margarida.", 0.6, [], "evt_1", t, "gift|p|margarida|2")
	var r2 := mem.add_memory("lila", "gift_received", ["lila", "p"], "Recebeu uma Margarida.", 0.6, [], "evt_2", t, "gift|p|margarida|2")
	assert_true(r1["is_new"])
	assert_false(r2["is_new"], "memória equivalente não é duplicada")
	assert_eq(mem.list_for("lila").size(), 1)
	assert_eq(int(mem.list_for("lila")[0]["occurrences"]), 2, "ocorrências somadas")
	mem.add_memory("lila", "npc_interaction", ["lila", "bento"], "Conversou com Bento sobre música.", 0.3, [], "evt_3", t)
	mem.add_memory("lila", "npc_interaction", ["lila", "pipa"], "Conversou com Pipa sobre frutas.", 0.3, [], "evt_4", t)
	var found := mem.retrieve("lila", {"participants": ["bento"], "now_abs": 2000.0}, 1)
	assert_true((found[0]["participants"] as Array).has("bento"), "recupera por participante")
	var by_kw := mem.retrieve("lila", {"keywords": ["frutas"], "now_abs": 2000.0}, 1)
	assert_true(str(by_kw[0]["description"]).contains("frutas"), "recupera por palavra-chave")
	# Capacidade limitada
	for i in range(120):
		mem.add_memory("bento", "npc_interaction", ["bento", "x%d" % i], "Evento %d" % i, randf(), [], "e%d" % i, {"day": 1 + i / 10, "minute": 10.0})
	assert_eq(mem.list_for("bento").size(), MemorySystem.CAPACITY, "memórias limitadas à capacidade")


func test_encontro_comunitario() -> void:
	var sim := new_sim()
	_awake(sim)
	var entry := sim.conclude_gathering(["lila", "bento", "pipa"])
	assert_eq(entry["kind"], "community_event")
	assert_true(str(entry["text"]).contains("Lila, Bento e Pipa"), "texto cita os participantes reais")
	assert_eq(sim.memories.list_for("bento").filter(func(m): return m["type"] == "community_event" and m["key"].begins_with("gathering")).size(), 1)
	assert_true(sim.conclude_gathering(["lila"]).is_empty(), "uma pessoa sozinha não é encontro")
