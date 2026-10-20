class_name World
extends Node3D
## Cena principal da ilha: constrói o mundo, cria jogadora e moradores, conecta
## a interface e coordena salvar/pausar.

signal world_ready()

var builder: IslandBuilder
var day_night: DayNight
var director: NpcDirector
var player: Player
var camera: CameraRig
var hud: Hud
var inventory_panel: InventoryPanel
var journal_panel: JournalPanel
var dialogue_panel: DialoguePanel
var pause_menu: PauseMenu
var loading: Control
var resource_nodes: Dictionary = {}
var is_ready: bool = false
var _modal: String = ""
var _health_timer := 0.0
var _quit_after_failed_save := false
var _closing := false


func _ready() -> void:
	if not GameState.session_active:
		# Execução direta da cena (ex.: pelo editor): inicia uma partida nova.
		GameState.new_game("Jogadora", "Daybloom")
		SaveManager.start_new_game_session()
	get_tree().auto_accept_quit = false
	GameState.world_node = self
	_build_ui()
	builder = IslandBuilder.new()
	builder.build(self)
	day_night = DayNight.new()
	day_night.name = "DiaNoite"
	add_child(day_night)
	day_night.setup(builder.lamps, builder.fire_lights)
	_spawn_resources()
	director = NpcDirector.new()
	director.name = "Diretor"
	add_child(director)
	var npc_root := Node3D.new()
	npc_root.name = "Moradores"
	add_child(npc_root)
	director.setup(GameState.sim, npc_root)
	player = Player.new()
	player.name = "Jogadora"
	add_child(player)
	player.global_position = GameState.player_position
	player.rotation.y = GameState.player_rotation
	camera = CameraRig.new()
	camera.target = player
	add_child(camera)
	camera.snap()
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	GameClock.day_started.connect(_on_day_started)
	# Gera o navmesh em uma thread para não travar a tela.
	builder.nav_region.bake_finished.connect(_on_nav_baked, CONNECT_ONE_SHOT)
	builder.nav_region.bake_navigation_mesh(true)
	ApiClient.check_health()


func _on_nav_baked() -> void:
	# Aguarda o servidor de navegação sincronizar o mapa com o navmesh novo.
	var map := get_world_3d().navigation_map
	var probe_a := Places.house_door("casa_jogadora")
	var probe_b := Places.poi_pos("banco_praca")
	for i in range(240):
		await get_tree().physics_frame
		if NavigationServer3D.map_get_path(map, probe_a, probe_b, true).size() > 1:
			break
	director.on_navigation_ready()
	var p := NavigationServer3D.map_get_closest_point(map, player.global_position)
	if p.distance_to(player.global_position) > 1.0:
		player.global_position = p
	loading.visible = false
	GameClock.running = true
	is_ready = true
	world_ready.emit()
	EventBus.toast_requested.emit("Bem-vinda à ilha %s, %s!" % [GameState.sim.island_name, GameState.sim.player_name])


func _spawn_resources() -> void:
	var root := Node3D.new()
	root.name = "Recursos"
	add_child(root)
	for spec in IslandLayout.generate()["resources"]:
		var node := ResourceNode.new()
		root.add_child(node)
		node.position = Places.pos3(spec["pos"])
		node.setup(spec["id"])
		resource_nodes[spec["id"]] = node


func _on_day_started(_day: int) -> void:
	for node in resource_nodes.values():
		node.refresh()
	# Salvamento automático a cada manhã.
	if SaveManager.backend != null and is_ready:
		SaveManager.save_game()


func _build_ui() -> void:
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	inventory_panel = InventoryPanel.new()
	hud.root.add_child(inventory_panel)
	inventory_panel.closed.connect(_on_inventory_closed)
	inventory_panel.item_chosen.connect(_on_gift_item_chosen)
	journal_panel = JournalPanel.new()
	hud.root.add_child(journal_panel)
	journal_panel.closed.connect(func(): _set_modal(""))
	dialogue_panel = DialoguePanel.new()
	hud.root.add_child(dialogue_panel)
	dialogue_panel.closed.connect(_on_dialogue_closed)
	dialogue_panel.gift_requested.connect(_on_gift_requested)
	pause_menu = PauseMenu.new()
	hud.root.add_child(pause_menu)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.save_requested.connect(func(): SaveManager.save_game())
	pause_menu.quit_to_menu_requested.connect(_quit_to_menu)
	loading = ColorRect.new()
	(loading as ColorRect).color = UiTheme.CREAM
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := UiTheme.label("Preparando a ilha...", 34)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	loading.add_child(l)
	hud.root.add_child(loading)


func _set_modal(name_: String) -> void:
	_modal = name_
	if player:
		player.input_enabled = _modal == ""
		if _modal != "":
			EventBus.interaction_prompt_changed.emit("")
	EventBus.ui_modal_changed.emit(_modal != "")


func _process(delta: float) -> void:
	_health_timer -= delta
	if _health_timer <= 0.0:
		_health_timer = 60.0
		if is_ready:
			ApiClient.check_health()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE:
		_on_escape()
		get_viewport().set_input_as_handled()
		return
	if not is_ready or get_tree().paused:
		return
	if _modal == "dialogue":
		return  # o campo de texto recebe as teclas
	match key:
		KEY_E:
			if _modal == "":
				player.try_interact()
		KEY_I:
			if _modal == "":
				inventory_panel.open(false)
				_set_modal("inventory")
			elif _modal == "inventory":
				inventory_panel.close_panel()
		KEY_J:
			if _modal == "":
				journal_panel.open()
				_set_modal("journal")
			elif _modal == "journal":
				journal_panel.close_panel()
		KEY_F5:
			SaveManager.save_game()


func _on_escape() -> void:
	match _modal:
		"inventory", "gift":
			inventory_panel.close_panel()
		"journal":
			journal_panel.close_panel()
		"dialogue":
			dialogue_panel.close_panel()
		_:
			if get_tree().paused:
				_resume()
			else:
				_pause()


func _pause() -> void:
	get_tree().paused = true
	pause_menu.visible = true
	_quit_after_failed_save = false


func _resume() -> void:
	pause_menu.visible = false
	get_tree().paused = false


# --- diálogo e presentes ---------------------------------------------------

func _on_dialogue_requested(npc_id: String) -> void:
	if _modal != "":
		return
	var npc: NpcState = GameState.sim.npcs[npc_id]
	if npc.is_sleeping() or npc.inside_home:
		EventBus.toast_requested.emit("%s está dormindo. Melhor não acordar..." % npc.display_name())
		return
	var actor := director.get_actor(npc_id)
	actor.begin_player_talk(player)
	player.face_towards(actor.global_position)
	dialogue_panel.open(npc_id)
	_set_modal("dialogue")


func _on_dialogue_closed() -> void:
	var actor := director.get_actor(dialogue_panel.npc_id)
	if actor:
		actor.end_player_talk()
	_set_modal("")


func _on_gift_requested() -> void:
	dialogue_panel.visible = false
	inventory_panel.open(true)
	_modal = "gift"


func _on_gift_item_chosen(item_id: String) -> void:
	inventory_panel.visible = false
	dialogue_panel.visible = true
	_modal = "dialogue"
	dialogue_panel.give_item(item_id)


func _on_inventory_closed() -> void:
	if _modal == "gift":
		dialogue_panel.visible = true
		_modal = "dialogue"
	else:
		_set_modal("")


# --- salvar e sair -----------------------------------------------------------

func sync_to_state() -> void:
	if director:
		director.sync_positions()
	if player:
		GameState.player_position = player.global_position
		GameState.player_rotation = player.rotation.y


func _quit_to_menu() -> void:
	if _quit_after_failed_save:
		_go_to_menu()
		return
	var result: Dictionary = await SaveManager.save_game()
	if result["ok"]:
		_go_to_menu()
	else:
		_quit_after_failed_save = true
		pause_menu.status_label.text += "\nClique novamente em \"Salvar e voltar ao menu\" para sair SEM salvar."


func _go_to_menu() -> void:
	get_tree().paused = false
	GameState.end_session()
	get_tree().auto_accept_quit = true
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _quit_after_failed_save or not is_ready:
			get_tree().quit()
		elif not _closing:
			_closing = true
			_save_and_quit()


func _save_and_quit() -> void:
	if is_ready and GameState.session_active:
		EventBus.toast_requested.emit("Salvando antes de fechar...")
		var result: Dictionary = await SaveManager.save_game()
		if not result["ok"]:
			# Não fecha escondendo a falha: avisa e deixa a jogadora decidir.
			_closing = false
			_pause()
			_quit_after_failed_save = true
			pause_menu.status_label.text += "\nFeche a janela novamente para sair SEM salvar."
			return
	get_tree().quit()
