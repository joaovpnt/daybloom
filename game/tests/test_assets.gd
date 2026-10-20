extends TestCase
## Versão 0.2: modelos exportados do Blender, animações, materiais, interface
## em várias resoluções e compatibilidade com saves da versão 0.1.

const CHARACTER_ANIMS := ["idle", "walk", "talk", "happy", "sad", "surprised"]
const PLAYER_ANIMS := ["idle", "walk", "run", "interact", "talk"]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]


func after_each() -> void:
	GameState.end_session()


func _mesh_stats(root: Node) -> Dictionary:
	var verts := 0
	var surfaces := 0
	var missing_mat := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in range(m.get_surface_count()):
			surfaces += 1
			verts += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if (mi as MeshInstance3D).get_active_material(s) == null:
				missing_mat += 1
	return {"verts": verts, "surfaces": surfaces, "missing_mat": missing_mat}


func test_todos_os_modelos_glb_carregam() -> void:
	var count := 0
	for folder in ["buildings", "characters", "environment", "props"]:
		var dir := DirAccess.open(ModelLib.ROOT + folder)
		assert_true(dir != null, "pasta de modelos %s existe" % folder)
		if dir == null:
			continue
		for f in dir.get_files():
			if not f.ends_with(".glb"):
				continue
			count += 1
			var rel := "%s/%s" % [folder, f.get_basename()]
			var node := ModelLib.instance(rel)
			if not assert_true(node != null, "modelo %s instancia" % rel):
				continue
			var st := _mesh_stats(node)
			assert_gt(st["verts"], 20, "%s tem geometria" % rel)
			assert_eq(st["missing_mat"], 0, "%s: toda superfície tem material" % rel)
			node.free()
	assert_gt(count, 70, "biblioteca completa de modelos (%d)" % count)


func test_casas_personalizadas_preservam_ids() -> void:
	assert_eq(Places.HOUSES.size(), 9, "9 casas")
	for house_id in Places.HOUSES:
		assert_true(ModelLib.exists("buildings/%s" % house_id), "modelo próprio para %s" % house_id)
	# IDs persistentes da versão 0.1 continuam existindo.
	for id in ["casa_jogadora", "casa_lila", "casa_tobias", "casa_otavio", "casa_pipa", "casa_marina", "casa_bento", "casa_ravena", "casa_celeste"]:
		assert_true(Places.HOUSES.has(id), "id %s preservado" % id)


func test_personagens_tem_animacoes_e_expressoes() -> void:
	var sim := new_sim()
	for npc_id in sim.npc_order:
		var vis := CharacterVisual.new()
		runner.add_child(vis)
		vis.setup("characters/villager_%s" % npc_id)
		for a in CHARACTER_ANIMS:
			assert_true(vis.has_animation(a), "%s tem animação %s" % [npc_id, a])
		for parts in CharacterVisual.EXPRESSIONS.values():
			for p in parts:
				assert_true(vis.parts.has(p), "%s tem a malha de expressão %s" % [npc_id, p])
		vis.queue_free()
	var pv := CharacterVisual.new()
	runner.add_child(pv)
	pv.setup("characters/player")
	for a in PLAYER_ANIMS:
		assert_true(pv.has_animation(a), "jogadora tem animação %s" % a)
	pv.queue_free()
	await wait_frames(1)


func test_animacoes_unicas_voltam_ao_loop() -> void:
	var vis := CharacterVisual.new()
	runner.add_child(vis)
	vis.setup("characters/villager_pipa")
	vis.play("walk")
	assert_eq(vis.current_anim, "walk", "anda em loop")
	vis.play_once("happy")
	assert_true(vis.is_reacting(), "reação de alegria em andamento")
	vis.play("idle")
	assert_eq(String(vis.anim.current_animation), "happy", "loop não interrompe a reação")
	var frames := 0
	while vis.is_reacting() and frames < 400:
		await tree().process_frame
		frames += 1
	assert_false(vis.is_reacting(), "a reação termina")
	vis.flash_expression("sad", 0.2)
	assert_true(vis.parts["Eyes_Sad"].visible, "expressão triste visível")
	vis.queue_free()


func test_materiais_compartilhados_entre_instancias() -> void:
	var a := ModelLib.instance("environment/tree_round_a")
	var b := ModelLib.instance("environment/tree_round_a")
	var ma: Material = (a.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0)
	var mb: Material = (b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0)
	assert_true(ma == mb, "instâncias do mesmo modelo reutilizam o material (sem cópias)")
	a.free()
	b.free()


func test_save_da_versao_0_1_carrega() -> void:
	var f := FileAccess.open("res://tests/fixtures/save_v0_1.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	assert_eq(str(data["game_version"]), "0.1.0", "fixture é um save real da 0.1")
	var res := GameState.apply_snapshot(data)
	assert_true(res["ok"], "save 0.1 aplicado: %s" % str(res.get("error", "")))
	assert_eq(GameState.sim.npcs.size(), 8, "8 moradores restaurados")
	for npc in data["npcs"]:
		assert_true(GameState.sim.npcs.has(str(npc["id"])), "morador %s preservado" % npc["id"])
	assert_eq(GameState.sim.player_name, str(data["player"]["name"]), "nome da jogadora preservado")
	assert_eq(GameState.inventory.items().size(), (data["player"]["inventory"] as Array).size(), "inventário preservado")
	# Salvar de novo na 0.2 mantém os IDs e acrescenta apenas campos opcionais.
	var snap := GameState.build_snapshot()
	assert_eq(int(snap["schema_version"]), SaveMigrator.CURRENT, "schema atual")
	assert_eq(str(snap["save_slot_id"]), str(data["save_slot_id"]), "slot preservado")
	assert_eq(str(snap["island_id"]), str(data["island_id"]), "ilha preservada")


func test_interface_cabe_em_todas_as_resolucoes() -> void:
	GameState.new_game("Ana", "Daybloom", 5)
	for res in RESOLUTIONS:
		var host := Control.new()
		host.size = Vector2(res)
		runner.add_child(host)
		var inv := InventoryPanel.new()
		var jour := JournalPanel.new()
		var dlg := DialoguePanel.new()
		var sett := SettingsPanel.new()
		for p in [inv, jour, dlg, sett]:
			host.add_child(p)
		await wait_frames(1)
		inv.open(false)
		jour.open()
		dlg.open(GameState.sim.npc_order[0])
		sett.open()
		await wait_frames(3)
		var bounds := Rect2(Vector2.ZERO, Vector2(res))
		for p in [inv, jour, dlg, sett]:
			var r: Rect2 = (p as Control).get_rect()
			assert_true(bounds.encloses(r), "%s cabe em %dx%d (%s)" % [p.get_class() if p.get_script() == null else (p.get_script() as Script).get_global_name(), res.x, res.y, str(r)])
		host.queue_free()
		await wait_frames(1)
	assert_eq(Settings.effective_ui_scale(1080.0), Settings.ui_scale, "sem escala extra em 1080p")
	assert_gt(Settings.effective_ui_scale(1440.0), Settings.ui_scale * 1.3, "interface cresce em 1440p")
