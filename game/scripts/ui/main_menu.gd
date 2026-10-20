extends Control
## Menu principal: nova partida, continuar e estado dos serviços locais.

var status_label: Label
var continue_button: Button
var new_button: Button
var save_info: Label
var new_panel: PanelContainer
var name_input: LineEdit
var island_input: LineEdit
var overwrite_label: Label
var _save_exists := false
var _busy := false


func _ready() -> void:
	theme = UiTheme.make()
	get_tree().paused = false
	var bg := MenuBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 14)
	center.custom_minimum_size = Vector2(460, 0)
	add_child(center)
	var title := UiTheme.label("Daybloom", 96, Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.45, 0.62, 0.36))
	title.add_theme_constant_override("outline_size", 22)
	center.add_child(title)
	var subtitle := UiTheme.label("uma ilha onde cada vizinho tem sua própria vida", 22, Color(0.33, 0.24, 0.17))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(subtitle)
	var card := PanelContainer.new()
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	continue_button = UiTheme.button("Continuar")
	continue_button.disabled = true
	continue_button.pressed.connect(_on_continue)
	v.add_child(continue_button)
	save_info = UiTheme.label("Procurando partida salva...", 15, UiTheme.INK_SOFT)
	save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(save_info)
	new_button = UiTheme.button("Nova partida", UiTheme.SKY.darkened(0.15))
	new_button.pressed.connect(_on_new_pressed)
	v.add_child(new_button)
	var quit := UiTheme.button("Sair", UiTheme.CORAL)
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)
	status_label = UiTheme.label("Verificando backend local...", 15, UiTheme.INK_SOFT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(420, 0)
	v.add_child(status_label)
	var retry := UiTheme.button("Verificar novamente", UiTheme.INK_SOFT)
	retry.pressed.connect(refresh_status)
	v.add_child(retry)
	_build_new_panel()
	var version := UiTheme.label("versão %s" % GameState.GAME_VERSION, 14, UiTheme.INK_SOFT)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-130, -34)
	add_child(version)
	await get_tree().process_frame
	UiTheme.place(center, Control.PRESET_CENTER)
	refresh_status()


func _build_new_panel() -> void:
	new_panel = PanelContainer.new()
	new_panel.custom_minimum_size = Vector2(520, 0)
	new_panel.visible = false
	add_child(new_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	new_panel.add_child(v)
	v.add_child(UiTheme.label("Nova partida", 30))
	v.add_child(UiTheme.label("Seu nome", 17, UiTheme.INK_SOFT))
	name_input = LineEdit.new()
	name_input.max_length = 20
	name_input.placeholder_text = "Como os moradores vão te chamar?"
	v.add_child(name_input)
	v.add_child(UiTheme.label("Nome da ilha", 17, UiTheme.INK_SOFT))
	island_input = LineEdit.new()
	island_input.max_length = 24
	island_input.text = "Daybloom"
	v.add_child(island_input)
	overwrite_label = UiTheme.label("", 15, Color(0.75, 0.3, 0.2))
	overwrite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overwrite_label.custom_minimum_size = Vector2(470, 0)
	v.add_child(overwrite_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var start := UiTheme.button("Começar")
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_start_new)
	row.add_child(start)
	var cancel := UiTheme.button("Voltar", UiTheme.CORAL)
	cancel.pressed.connect(func(): new_panel.visible = false)
	row.add_child(cancel)


func refresh_status() -> void:
	status_label.text = "Verificando backend local..."
	var health: Dictionary = await ApiClient.check_health()
	var parts := []
	if not health["backend"]:
		parts.append("Backend local desligado — inicie com scripts\\iniciar_backend.bat para salvar no MongoDB.")
	elif not health["mongo"]:
		parts.append("Backend ativo, mas o MongoDB está inacessível. Salvar não funcionará.")
	else:
		parts.append("MongoDB conectado.")
	parts.append("Conversas: %s" % ("IA local (Qwen via Ollama)" if health["ollama"] else "diálogos clássicos (Ollama indisponível)"))
	status_label.text = "\n".join(parts)
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


func _on_new_pressed() -> void:
	new_panel.visible = true
	UiTheme.place(new_panel, Control.PRESET_CENTER)
	overwrite_label.text = "Atenção: começar uma nova partida substituirá a partida salva atual no primeiro salvamento." if _save_exists else ""
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
