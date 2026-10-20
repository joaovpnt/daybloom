extends TestCase
## Integração com a cena da ilha: carregamento, jogadora, interações e
## comportamento autônomo dos moradores com navegação real.

var world: World


func before_each() -> void:
	GameState.new_game("Ana", "Daybloom", 77)
	ApiClient.last_health = {"backend": false, "mongo": false, "ollama": false}
	world = load("res://scenes/world.tscn").instantiate()
	runner.add_child(world)
	var frames := 0
	while not world.is_ready and frames < 600:
		await tree().physics_frame
		frames += 1


func after_each() -> void:
	GameClock.minutes_per_second = 1.0
	GameClock.running = false
	if is_instance_valid(world):
		world.queue_free()
	await tree().process_frame
	GameState.end_session()
	tree().auto_accept_quit = true


func test_cena_principal_carrega() -> void:
	assert_true(world.is_ready, "a ilha ficou pronta")
	assert_eq(world.builder.house_nodes.size(), 9, "8 casas de moradores + casa da jogadora")
	assert_eq(world.director.actors.size(), 8, "8 moradores na cena")
	assert_eq(tree().get_nodes_in_group("npc_actor").size(), 8, "nenhum morador duplicado")
	assert_gt(world.resource_nodes.size(), 30, "recursos coletáveis espalhados")
	assert_gt(world.builder.nav_region.navigation_mesh.get_polygon_count(), 100, "navmesh gerado")
	assert_true(GameClock.running, "o relógio começou")
	var path := NavigationServer3D.map_get_path(world.get_world_3d().navigation_map, Places.house_door("casa_lila"), Places.poi_pos("praia_sul"), true)
	assert_gt(path.size(), 2, "há caminho navegável entre a casa da Lila e a praia")


func test_movimentacao_e_colisao() -> void:
	var start := world.player.global_position
	world.player.debug_input = Vector2(0, -1)
	await wait_frames(60)
	world.player.debug_input = Vector2.ZERO
	assert_gt(start.z - world.player.global_position.z, 2.5, "a jogadora andou para frente (W)")
	# Empurra a jogadora contra a casa da Lila: ela não pode atravessar.
	var house := Places.house_pos("casa_lila")
	var door := Places.house_door("casa_lila")
	world.player.global_position = door
	var dir := (house - door).normalized()
	world.player.debug_input = Vector2(dir.x, dir.z)
	await wait_frames(90)
	world.player.debug_input = Vector2.ZERO
	var flat := Vector2(world.player.global_position.x - house.x, world.player.global_position.z - house.z)
	assert_gt(flat.length(), 2.2, "a colisão impede atravessar a casa")


func test_interacao_e_coleta() -> void:
	var node: ResourceNode = null
	for n in world.resource_nodes.values():
		if n.is_available() and GameState.resources[n.resource_id]["kind"] == "shell":
			node = n
			break
	assert_true(node != null, "há uma concha disponível")
	world.player.global_position = node.global_position + Vector3(0.8, 0, 0)
	world.player.face_towards(node.global_position)
	await wait_frames(3)
	var item: String = GameState.resources[node.resource_id]["item_id"]
	var before := GameState.inventory.count(item)
	assert_true(world.player.try_interact(), "interação com E")
	assert_eq(GameState.inventory.count(item), before + 1, "item coletado no inventário")
	assert_false(node.visible, "recurso some da ilha")


func _awake_actor() -> NpcActor:
	for id in ["lila", "bento", "pipa", "marina", "celeste", "ravena", "tobias"]:
		var a: NpcActor = world.director.actors[id]
		if not a.npc.inside_home and not a.npc.is_sleeping():
			return a
	return null


func test_conversa_e_presente_na_cena() -> void:
	var actor := _awake_actor()
	assert_true(actor != null, "há um morador acordado")
	world.player.global_position = actor.global_position + Vector3(1.2, 0, 0)
	EventBus.dialogue_requested.emit(actor.npc.id)
	await wait_frames(5)
	assert_eq(world._modal, "dialogue", "painel de diálogo aberto")
	assert_eq(actor.phase, NpcActor.Phase.TALKING_PLAYER, "o morador para para conversar")
	var pos := actor.global_position
	await wait_frames(60)
	assert_lt(actor.global_position.distance_to(pos), 0.05, "o morador fica parado durante a conversa")
	assert_false(world.player.input_enabled, "a jogadora não anda enquanto digita")
	var liked: String = ""
	for item_id in ItemDB.ITEMS:
		if actor.npc.def.preference_for(item_id) > 0:
			liked = item_id
			break
	GameState.inventory.add(liked, 1)
	var before := GameState.sim.relationships.affinity(actor.npc.id, GameState.sim.player_id)
	var res := world.dialogue_panel.give_item(liked)
	assert_true(res["ok"], "presente entregue")
	assert_gt(GameState.sim.relationships.affinity(actor.npc.id, GameState.sim.player_id), before, "afinidade com a jogadora mudou")
	world.dialogue_panel.close_panel()
	await wait_frames(2)
	assert_eq(world._modal, "", "diálogo fechado")
	assert_true(world.player.input_enabled, "jogadora volta a andar")
	assert_true(actor.phase != NpcActor.Phase.TALKING_PLAYER, "o morador retoma a rotina")


func test_rotinas_autonomas() -> void:
	GameClock.minutes_per_second = 12.0
	var states := {}
	var cb := func(id, s, _a):
		if not states.has(id): states[id] = {}
		states[id][s] = true
	GameState.sim.npc_state_changed.connect(cb)
	var start_pos := {}
	for id in world.director.actors:
		start_pos[id] = world.director.actors[id].global_position
	await wait_frames(2400)
	GameState.sim.npc_state_changed.disconnect(cb)
	assert_gt(world.director.decisions_made, 16, "a IA tomou decisões sozinha")
	var moved := 0
	for id in world.director.actors:
		if world.director.actors[id].global_position.distance_to(start_pos[id]) > 4.0:
			moved += 1
	assert_gt(moved, 4, "a maioria dos moradores se deslocou pela ilha (%d)" % moved)
	var varied := 0
	for id in states:
		if (states[id] as Dictionary).size() >= 3:
			varied += 1
	assert_gt(varied, 4, "moradores alternaram entre vários estados")
	assert_lt(world.director.stuck_events, 6, "moradores não ficam presos (eventos: %d)" % world.director.stuck_events)


func test_interacao_social_real_entre_moradores() -> void:
	GameClock.minutes_per_second = 8.0
	var started := []
	var finished := []
	var on_start := func(a, b, k):
		var d: float = world.director.actors[a].global_position.distance_to(world.director.actors[b].global_position)
		started.append({"a": a, "b": b, "kind": k, "distance": d})
	var on_finish := func(a, b, k, o): finished.append(o)
	GameState.sim.interaction_started.connect(on_start)
	GameState.sim.interaction_finished.connect(on_finish)
	# Deixa dois moradores sociáveis com vontade de conversar.
	for id in ["lila", "bento", "pipa"]:
		GameState.sim.npcs[id].needs["social"] = 10.0
	var frames := 0
	while finished.is_empty() and frames < 4800:
		await tree().physics_frame
		frames += 1
	GameState.sim.interaction_started.disconnect(on_start)
	GameState.sim.interaction_finished.disconnect(on_finish)
	assert_gt(started.size(), 0, "moradores iniciaram uma interação social")
	assert_gt(finished.size(), 0, "a interação terminou com resultado")
	for s in started:
		assert_true(s["distance"] <= SocialRules.MEET_DISTANCE + 0.05, "interação só começa com proximidade real (%.2f m)" % s["distance"])
	if not finished.is_empty():
		var o: Dictionary = finished[0]
		var mems := GameState.sim.memories.list_for(o["a"]).filter(func(m): return m["event_ref"] == o["event_id"])
		assert_eq(mems.size(), 1, "a interação virou memória do participante")
		var rel: Dictionary = GameState.sim.relationships.get_rel(o["a"], o["b"])
		assert_gt(float(rel["interactions"]), 0.0, "relacionamento registrou o encontro")
