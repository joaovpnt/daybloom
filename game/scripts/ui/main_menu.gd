extends Control
## Menu principal: a ilha em 3D ao fundo, logo, cartão com Continuar, Nova
## partida, Configurações e Sair, e indicadores discretos dos serviços locais.

var status_label: Label
var continue_button: Button
var new_button: Button
var settings_button: Button
var save_info: Label
var new_panel: PanelContainer
var name_input: LineEdit
var island_input: LineEdit
var overwrite_label: Label
var settings_panel: SettingsPanel
var diorama: Control
var menu_column: VBoxContainer
var chips_row: HBoxContainer
var _save_exists := false
var _busy := false


func _ready() -> void:
	theme = UiTheme.make()
	get_tree().paused = false
	_build_background()
	# Véu suave à esquerda para dar leitura ao cartão.
	var veil := TextureRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.texture = _veil_texture()
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(veil)
	menu_column = VBoxContainer.new()
	menu_column.add_theme_constant_override("separation", UiTheme.SPACE_L)
	menu_column.custom_minimum_size = Vector2(440, 0)
	add_child(menu_column)
	var logo := Label.new()
	logo.text = "Daybloom"
	logo.add_theme_font_override("font", UiTheme.font_display())
	logo.add_theme_font_size_override("font_size", 92)
	logo.add_theme_color_override("font_color", Color.WHITE)
	logo.add_theme_color_override("font_outline_color", UiTheme.GREEN_DARK)
	logo.add_theme_constant_override("outline_size", 24)
	logo.add_theme_color_override("font_shadow_color", Color(0.2, 0.3, 0.15, 0.35))
	logo.add_theme_constant_override("shadow_offset_y", 6)
	menu_column.add_child(logo)
	var tagline := UiTheme.label("uma ilha onde cada vizinho tem sua própria vida", 20, UiTheme.INK, true)
	tagline.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	tagline.add_theme_constant_override("outline_size", 8)
	menu_column.add_child(tagline)
	var card := PanelContainer.new()
	menu_column.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.SPACE_M)
	card.add_child(v)
	continue_button = UiTheme.button("Continuar")
	continue_button.disabled = true
	continue_button.pressed.connect(_on_continue)
	v.add_child(continue_button)
	save_info = UiTheme.label("Procurando partida salva...", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(save_info)
	new_button = UiTheme.button("Nova partida", "sky")
	new_button.pressed.connect(_on_new_pressed)
	v.add_child(new_button)
	settings_button = UiTheme.secondary_button("Configurações")
	settings_button.pressed.connect(_open_settings)
	v.add_child(settings_button)
	var quit := UiTheme.secondary_button("Sair")
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)
	chips_row = HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 6)
	menu_column.add_child(chips_row)
	status_label = UiTheme.label("Verificando backend local...", UiTheme.SIZE_SMALL, UiTheme.INK)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(440, 0)
	status_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	status_label.add_theme_constant_override("outline_size", 6)
	menu_column.add_child(status_label)
	var retry := Button.new()
	retry.text = "Verificar novamente"
	retry.flat = true
	retry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	retry.add_theme_color_override("font_color", UiTheme.GREEN_DARK)
	retry.add_theme_color_override("font_hover_color", UiTheme.INK)
	retry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	retry.pressed.connect(refresh_status)
	menu_column.add_child(retry)
	_build_new_panel()
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	settings_panel.closed.connect(func():
		menu_column.visible = true
		settings_button.grab_focus())
	var version := UiTheme.label("versão %s" % GameState.GAME_VERSION, 14, UiTheme.INK, true)
	version.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	version.add_theme_constant_override("outline_size", 6)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -24
	version.offset_bottom = -16
	add_child(version)
	get_viewport().size_changed.connect(_layout)
	await get_tree().process_frame
	_layout()
	new_button.grab_focus()
	refresh_status()


func _build_background() -> void:
	# Fundo 3D (a ilha de verdade). Em modo headless usa o fundo desenhado.
	if DisplayServer.get_name() == "headless":
		diorama = MenuBackground.new()
	else:
		diorama = MenuDiorama.new()
	diorama.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(diorama)


static func _veil_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.97, 0.9, 0.72))
	g.set_color(1, Color(1.0, 0.97, 0.9, 0.0))
	g.add_point(0.34, Color(1.0, 0.97, 0.9, 0.32))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	return t


func _layout() -> void:
	var vs := get_viewport_rect().size
	var margin := clampf(vs.x * 0.06, 32.0, 140.0)
	menu_column.reset_size()
	menu_column.position = Vector2(margin, maxf(24.0, (vs.y - menu_column.size.y) * 0.5))
	if new_panel.visible:
		UiTheme.place(new_panel, Control.PRESET_CENTER)


func _build_new_panel() -> void:
	new_panel = PanelContainer.new()
	new_panel.custom_minimum_size = Vector2(520, 0)
	new_panel.visible = false
	add_child(new_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.SPACE_S)
	new_panel.add_child(v)
	v.add_child(UiTheme.title("Nova partida", 32))
	v.add_child(UiTheme.label("Seu nome", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true))
	name_input = LineEdit.new()
	name_input.max_length = 20
	name_input.placeholder_text = "Como os moradores vão te chamar?"
	v.add_child(name_input)
	v.add_child(UiTheme.label("Nome da ilha", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true))
	island_input = LineEdit.new()
	island_input.max_length = 24
	island_input.text = "Daybloom"
	v.add_child(island_input)
	overwrite_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DANGER)
	overwrite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overwrite_label.custom_minimum_size = Vector2(470, 0)
	v.add_child(overwrite_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_S)
	v.add_child(row)
	var start := UiTheme.button("Começar")
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_start_new)
	row.add_child(start)
	var cancel := UiTheme.secondary_button("Voltar")
	cancel.pressed.connect(func():
		new_panel.visible = false
		menu_column.visible = true
		new_button.grab_focus())
	row.add_child(cancel)
	name_input.text_submitted.connect(func(_t): island_input.grab_focus())
	island_input.text_submitted.connect(func(_t): _on_start_new())


func _open_settings() -> void:
	menu_column.visible = false
	settings_panel.open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if settings_panel.visible:
			settings_panel.close_panel()
		elif new_panel.visible:
			new_panel.visible = false
			menu_column.visible = true
		get_viewport().set_input_as_handled()


func _set_chips(items: Array) -> void:
	for c in chips_row.get_children():
		c.queue_free()
	for it in items:
		chips_row.add_child(UiTheme.chip(it[0], it[1]))


func refresh_status() -> void:
	status_label.text = "Verificando backend local..."
	var health: Dictionary = await ApiClient.check_health()
	var chips := []
	var msg := ""
	if not health["backend"]:
		chips.append(["Backend desligado", UiTheme.CORAL])
		msg = "Inicie scripts\\iniciar_backend.bat para salvar e continuar partidas."
	elif not health["mongo"]:
		chips.append(["MongoDB inacessível", UiTheme.CORAL])
		msg = "O backend está ativo, mas o MongoDB não responde. Salvar não funcionará."
	else:
		chips.append(["Saves no MongoDB", UiTheme.GREEN])
	chips.append(["IA local (Qwen)" if health["ollama"] else "Diálogos clássicos", UiTheme.LILAC if health["ollama"] else UiTheme.LINE_STRONG])
	_set_chips(chips)
	status_label.text = msg
	status_label.visible = msg != ""
	if health["backend"] and health["mongo"]:
		var info: Dictionary = await SaveManager.check_save_exists()
		_save_exists = info.get("exists", false)
		if not info["ok"]:
			save_info.text = "Não foi possível ler o save: %s" % info["error"]
		elif _save_exists:
			save_info.text = "%s · ilha %s · dia %d" % [info.get("player_name", ""), info.get("island_name", ""), int(info.get("day", 1))]
		else:
			save_info.text = "Nenhuma partida salva ainda."
	else:
		_save_exists = false
		save_info.text = "Partidas salvas ficam no MongoDB (indisponível agora)."
	continue_button.disabled = not _save_exists
	if _save_exists:
		continue_button.grab_focus()
	_layout()


func _on_new_pressed() -> void:
	menu_column.visible = false
	new_panel.visible = true
	UiTheme.place(new_panel, Control.PRESET_CENTER)
	UiTheme.pop_in(new_panel)
	overwrite_label.text = "Atenção: começar uma nova partida substituirá a partida salva atual no primeiro salvamento." if _save_exists else ""
	overwrite_label.visible = _save_exists
	name_input.grab_focus()


func _on_start_new() -> void:
	if _busy:
		return
	_busy = true
	GameState.new_game(name_input.text, island_input.text)
	SaveManager.start_new_game_session()
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_continue() -> void:
	if _busy:
		return
	_busy = true
	continue_button.disabled = true
	save_info.text = "Carregando..."
	var result: Dictionary = await SaveManager.load_game()
	if result["ok"]:
		get_tree().change_scene_to_file("res://scenes/world.tscn")
	else:
		save_info.text = "Falha ao carregar: %s" % result["error"]
		continue_button.disabled = false
		_busy = false
