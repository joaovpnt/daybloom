extends TestCase
## Snapshot canônico, restauração completa e ausência de duplicação.

const TEST_DIR := "user://saves_teste"


func before_each() -> void:
	GameState.new_game("Ana", "Ilha Teste", 21)
	GameClock.reset(2, 615.0)
	GameState.sim.set_time(2, 615.0)


func after_each() -> void:
	GameState.end_session()


func _play_a_bit() -> void:
	var sim := GameState.sim
	for id in sim.npc_order:
		sim.npcs[id].inside_home = false
		sim.npcs[id].set_state("IDLE", "parado")
	GameState.inventory.add("margarida", 3)
	GameState.inventory.add("concha", 2)
	GameState.collect_resource("flor_02")
	sim.give_gift("lila", "margarida", GameState.inventory)
	sim.try_start_interaction("ravena", "tobias", 1.0)
	sim.set_time(2, 700.0)
	sim.update_interactions()
	sim.try_start_interaction("lila", "bento", 1.0)
	sim.set_time(2, 760.0)
	sim.update_interactions()
	sim.register_player_talk("bento")
	sim.npcs["pipa"].goal_progress = 0.3
	sim.npcs["marina"].needs["energia"] = 33.0
	GameClock.reset(2, 760.0)


func _roundtrip(snapshot: Variant) -> Variant:
	# Passa pelo mesmo formato de transporte usado com o backend (JSON).
	return JSON.parse_string(JSON.stringify(snapshot))


func test_snapshot_canonico_completo() -> void:
	_play_a_bit()
	var snap := GameState.build_snapshot()
	for key in ["schema_version", "player_id", "island_id", "save_slot_id", "world", "player", "npcs", "journal"]:
		assert_true(snap.has(key), "snapshot contém %s" % key)
	assert_eq(snap["schema_version"], 1)
	assert_eq((snap["npcs"] as Array).size(), 8, "oito moradores no save")
	var npc: Dictionary = snap["npcs"][0]
	for key in ["needs", "personality", "emotion", "state", "relationships", "memories", "personal_goal", "position"]:
		assert_true(npc.has(key), "morador contém %s" % key)
	assert_eq((npc["relationships"] as Dictionary).size(), 8, "relações com 7 moradores + jogadora")
	assert_eq(snap["world"]["day"], 2)
	assert_gt((snap["world"]["resources"] as Array).size(), 30, "estado dos recursos salvo")


func test_restaura_partida_sem_perdas() -> void:
	_play_a_bit()
	var snap := GameState.build_snapshot()
	var aff_lila := GameState.sim.relationships.affinity("lila", GameState.sim.player_id)
	var aff_rt := GameState.sim.relationships.affinity("ravena", "tobias")
	var mem_count := GameState.sim.memories.list_for("lila").size()
	var journal_count := GameState.sim.journal.entries.size()
	var inv := GameState.inventory.to_array()
	# Bagunça o estado atual para garantir que o carregamento substitui tudo.
	GameState.new_game("Outra", "Outra ilha", 5)
	var res := GameState.apply_snapshot(_roundtrip(snap))
	assert_true(res["ok"], "snapshot aplicado")
	var sim := GameState.sim
	assert_eq(sim.player_name, "Ana")
	assert_eq(sim.island_name, "Ilha Teste")
	assert_eq(GameClock.day, 2)
	assert_eq(int(GameClock.minute), 760)
	assert_eq(GameState.inventory.to_array(), inv, "inventário preservado")
	assert_lt(absf(sim.relationships.affinity("lila", sim.player_id) - aff_lila), 0.011, "relação com a jogadora preservada")
	assert_lt(absf(sim.relationships.affinity("ravena", "tobias") - aff_rt), 0.011, "relação entre moradores preservada")
	assert_eq(sim.memories.list_for("lila").size(), mem_count, "memórias preservadas")
	assert_eq(sim.journal.entries.size(), journal_count, "diário preservado")
	assert_eq(snappedf(sim.npcs["pipa"].goal_progress, 0.001), 0.3, "objetivo preservado")
	assert_eq(snappedf(sim.npcs["marina"].need("energia"), 0.001), 33.0, "necessidades preservadas")
	assert_false(GameState.resources["flor_02"]["available"], "recurso coletado continua coletado")
	assert_eq(sim.npcs.size(), 8)


func test_salvar_carregar_salvar_nao_duplica() -> void:
	_play_a_bit()
	var first := GameState.build_snapshot()
	GameState.apply_snapshot(_roundtrip(first))
	var second := GameState.build_snapshot()
	GameState.apply_snapshot(_roundtrip(second))
	var third := GameState.build_snapshot()
	assert_eq((third["journal"] as Array).size(), (first["journal"] as Array).size(), "diário sem duplicação")
	assert_eq((third["player"]["inventory"] as Array), (first["player"]["inventory"] as Array), "inventário sem duplicação")
	for i in range(8):
		assert_eq((third["npcs"][i]["memories"] as Array).size(), (first["npcs"][i]["memories"] as Array).size(), "memórias sem duplicação")
		assert_eq(JSON.stringify(_roundtrip(third["npcs"][i]["relationships"]), "", true), JSON.stringify(_roundtrip(first["npcs"][i]["relationships"]), "", true), "relações idênticas")
	assert_eq(third["world"]["event_seq"], first["world"]["event_seq"], "sequência de eventos estável")
	# Novos eventos após carregar não colidem com IDs antigos.
	var evt := GameState.sim.next_event_id()
	for e in third["journal"]:
		assert_true(e["event_id"] != evt, "ID de evento novo não repete um antigo")


func test_backend_local_com_revisao() -> void:
	var backend := LocalFileSaveBackend.new(TEST_DIR)
	backend.delete_save("slot_teste")
	_play_a_bit()
	GameState.save_slot_id = "slot_teste"
	var snap := GameState.build_snapshot()
	var r1: Dictionary = await backend.write_save("slot_teste", snap, 0, false)
	assert_true(r1["ok"], "primeira gravação")
	assert_eq(r1["revision"], 1)
	var r_conflict: Dictionary = await backend.write_save("slot_teste", snap, 0, false)
	assert_false(r_conflict["ok"], "não sobrescreve sem revisão")
	assert_true(r_conflict["conflict"])
	var r2: Dictionary = await backend.write_save("slot_teste", snap, 1, false)
	assert_eq(r2["revision"], 2)
	var loaded: Dictionary = await backend.load_save("slot_teste")
	assert_true(loaded["found"])
	assert_eq(loaded["revision"], 2)
	assert_eq(JSON.stringify(loaded["snapshot"], "", true), JSON.stringify(_roundtrip(snap), "", true), "conteúdo idêntico")
	backend.delete_save("slot_teste")


func test_save_manager_com_backend_local() -> void:
	var backend := LocalFileSaveBackend.new(TEST_DIR)
	backend.delete_save("slot1")
	var old: SaveBackend = SaveManager.backend
	SaveManager.use_backend(backend)
	SaveManager.start_new_game_session()
	_play_a_bit()
	GameState.save_slot_id = "slot1"
	var r: Dictionary = await SaveManager.save_game()
	assert_true(r["ok"], "SaveManager salva")
	assert_eq(SaveManager.last_status["state"], "saved")
	GameState.inventory.add("galho", 4)
	var loaded: Dictionary = await SaveManager.load_game("slot1")
	assert_true(loaded["ok"], "SaveManager carrega")
	assert_eq(GameState.inventory.count("galho"), 0, "estado volta ao que foi salvo")
	var r2: Dictionary = await SaveManager.save_game()
	assert_eq(r2["revision"], 2, "revisão incrementa")
	backend.delete_save("slot1")
	SaveManager.use_backend(old)


func test_falha_de_salvamento_e_relatada() -> void:
	var old: SaveBackend = SaveManager.backend
	var old_url := ApiClient.base_url
	ApiClient.base_url = "http://127.0.0.1:9"
	SaveManager.use_backend(ApiSaveBackend.new())
	var r: Dictionary = await SaveManager.save_game()
	assert_false(r["ok"], "sem backend não há sucesso")
	assert_eq(SaveManager.last_status["state"], "error")
	assert_true(str(SaveManager.last_status["message"]).contains("NÃO foi salvo"), "mensagem deixa claro que não salvou")
	ApiClient.base_url = old_url
	SaveManager.use_backend(old)


func test_rejeita_save_de_versao_futura() -> void:
	var snap := GameState.build_snapshot()
	snap["schema_version"] = 99
	var res := GameState.apply_snapshot(snap)
	assert_false(res["ok"], "save de versão futura é recusado")


func test_exporta_fixture_para_o_backend() -> void:
	_play_a_bit()
	var snap := GameState.build_snapshot()
	var dir := ProjectSettings.globalize_path("res://").path_join("../backend/tests/fixtures")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("snapshot_godot.json"), FileAccess.WRITE)
	assert_true(f != null, "fixture gravada para validação cruzada no backend")
	if f:
		f.store_string(JSON.stringify(snap, "  "))
		f.close()
