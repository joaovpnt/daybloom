extends TestCase
## Versão 0.2 na cena da ilha: navegação no mapa novo, oclusão da câmera,
## reações visuais ligadas às emoções e save da 0.1 aberto no mapa novo.

var world: World


func _load_world() -> void:
	ApiClient.last_health = {"backend": false, "mongo": false, "ollama": false}
	world = load("res://scenes/world.tscn").instantiate()
	runner.add_child(world)
	var frames := 0
	while not world.is_ready and frames < 600:
		await tree().physics_frame
		frames += 1


func after_each() -> void:
	GameClock.running = false
	if is_instance_valid(world):
		world.queue_free()
	await tree().process_frame
	GameState.end_session()
	tree().auto_accept_quit = true


func test_todos_os_lugares_sao_alcancaveis() -> void:
	GameState.new_game("Ana", "Daybloom", 11)
	await _load_world()
	var map := world.get_world_3d().navigation_map
	var start := Places.house_door("casa_jogadora")
	var targets := {}
	for id in Places.POIS:
		targets[id] = Places.poi_pos(id)
	for id in Places.HOUSES:
		targets[id] = Places.house_door(id)
	for id in targets:
		var goal: Vector3 = targets[id]
		var path := NavigationServer3D.map_get_path(map, start, goal, true)
		assert_gt(path.size(), 1, "existe caminho até %s" % id)
		if path.size() > 1:
			var end := path[path.size() - 1]
			var tolerance := maxf(2.5, Places.poi_radius(id) + 1.5)
			assert_lt(Vector2(end.x - goal.x, end.z - goal.z).length(), tolerance, "o caminho chega perto de %s" % id)


func test_camera_deixa_casa_transparente() -> void:
	GameState.new_game("Ana", "Daybloom", 12)
	await _load_world()
	var house: Node3D = world.builder.house_nodes["casa_lila"]
	# Coloca a jogadora atrás da casa (do lado oposto à câmera).
	var behind := Places.house_pos("casa_lila") + Vector3(0, 0, -5.6)
	world.player.global_position = NavigationServer3D.map_get_closest_point(world.get_world_3d().navigation_map, behind)
	world.camera.snap()
	var mats_before := {}
	for mi in house.find_children("*", "MeshInstance3D", true, false):
		mats_before[mi] = (mi as MeshInstance3D).get_active_material(0)
	var frames := 0
	while not world.camera.is_faded(house) and frames < 120:
		await tree().process_frame
		frames += 1
	assert_true(world.camera.is_faded(house), "a casa entre a câmera e a jogadora fica transparente")
	for mi in mats_before:
		assert_true((mi as MeshInstance3D).get_active_material(0) == mats_before[mi], "material compartilhado não foi alterado")
	# Afasta a jogadora: a casa volta ao normal.
	world.player.global_position = Places.poi_pos("praca") + Vector3(0, 0, 8)
	world.camera.snap()
	frames = 0
	while world.camera.is_faded(house) and frames < 240:
		await tree().process_frame
		frames += 1
	assert_false(world.camera.is_faded(house), "a casa volta a ficar opaca")
	for gi in house.find_children("*", "GeometryInstance3D", true, false):
		assert_lt((gi as GeometryInstance3D).transparency, 0.01, "transparência restaurada")


func test_presente_dispara_reacao_visual() -> void:
	GameState.new_game("Ana", "Daybloom", 13)
	await _load_world()
	var actor: NpcActor = null
	for id in GameState.sim.npc_order:
		var a: NpcActor = world.director.actors[id]
		if a.visible and not a.npc.is_sleeping():
			actor = a
			break
	if not assert_true(actor != null, "há um morador acordado"):
		return
	EventBus.npc_reaction.emit(actor.npc.id, "gift_loved")
	await wait_frames(2)
	assert_true(actor.visual.is_reacting(), "o morador reage com animação")
	assert_eq(String(actor.visual.anim.current_animation), "happy", "animação de alegria")
	assert_eq(actor.visual.expression, "happy", "rosto feliz")
	EventBus.npc_reaction.emit(actor.npc.id, "gift_disliked")
	await wait_frames(2)
	assert_eq(actor.visual.expression, "sad", "presente ruim deixa o rosto triste")


func test_save_0_1_abre_no_mapa_novo() -> void:
	var f := FileAccess.open("res://tests/fixtures/save_v0_1.json", FileAccess.READ)
	var res := GameState.apply_snapshot(JSON.parse_string(f.get_as_text()))
	assert_true(res["ok"], "save 0.1 aplicado")
	await _load_world()
	assert_true(world.is_ready, "a ilha abre com o save antigo")
	var map := world.get_world_3d().navigation_map
	var p := world.player.global_position
	assert_lt(p.distance_to(NavigationServer3D.map_get_closest_point(map, p)), 1.0, "jogadora em área caminhável")
	await wait_frames(30)
	for id in world.director.actors:
		var a: NpcActor = world.director.actors[id]
		if a.visible:
			var q := a.global_position
			assert_lt(q.distance_to(NavigationServer3D.map_get_closest_point(map, q)), 1.5, "%s em área caminhável" % id)
