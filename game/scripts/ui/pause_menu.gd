class_name PauseMenu
extends Control
## Menu de pausa: pausa o relógio e a simulação; dá acesso a salvar,
## configurações e voltar ao menu principal.

signal resume_requested()
signal save_requested()
signal quit_to_menu_requested()

var status_label: Label
var settings_panel: SettingsPanel
var _panel: PanelContainer


func _ready() -> void:
	theme = UiTheme.make()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.18, 0.12, 0.42)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(440, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.SPACE_M)
	_panel.add_child(v)
	var title := UiTheme.title("Pausa", UiTheme.SIZE_DISPLAY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiTheme.label("A ilha espera por você.", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var b1 := UiTheme.button("Continuar jogando")
	b1.pressed.connect(func(): resume_requested.emit())
	v.add_child(b1)
	var b2 := UiTheme.button("Salvar partida", "sky")
	b2.pressed.connect(func(): save_requested.emit())
	v.add_child(b2)
	var b3 := UiTheme.secondary_button("Configurações")
	b3.pressed.connect(_open_settings)
	v.add_child(b3)
	var b4 := UiTheme.button("Salvar e voltar ao menu", "danger")
	b4.pressed.connect(func(): quit_to_menu_requested.emit())
	v.add_child(b4)
	status_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size = Vector2(400, 0)
	v.add_child(status_label)
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	settings_panel.closed.connect(func(): _panel.visible = true)
	EventBus.save_status_changed.connect(func(s): status_label.text = s.get("message", ""))
	visible = false
	visibility_changed.connect(_on_visibility)


func _on_visibility() -> void:
	if visible:
		_panel.visible = true
		settings_panel.visible = false
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		UiTheme.place(_panel, Control.PRESET_CENTER)
		await get_tree().process_frame
		UiTheme.place(_panel, Control.PRESET_CENTER)
		UiTheme.pop_in(_panel)


func _open_settings() -> void:
	_panel.visible = false
	settings_panel.open()


## Esc dentro da pausa: fecha as configurações antes de despausar.
func handle_escape() -> bool:
	if settings_panel.visible:
		settings_panel.close_panel()
		return true
	return false
