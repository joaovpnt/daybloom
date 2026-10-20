class_name PauseMenu
extends Control
## Menu de pausa: pausa o relógio e a simulação.

signal resume_requested()
signal save_requested()
signal quit_to_menu_requested()

var status_label: Label
var _panel: PanelContainer


func _ready() -> void:
	theme = UiTheme.make()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.15, 0.1, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	add_child(panel)
	_panel = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := UiTheme.label("Pausa", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var b1 := UiTheme.button("Continuar jogando")
	b1.pressed.connect(func(): resume_requested.emit())
	v.add_child(b1)
	var b2 := UiTheme.button("Salvar partida", UiTheme.SKY.darkened(0.15))
	b2.pressed.connect(func(): save_requested.emit())
	v.add_child(b2)
	var b3 := UiTheme.button("Salvar e voltar ao menu", UiTheme.CORAL)
	b3.pressed.connect(func(): quit_to_menu_requested.emit())
	v.add_child(b3)
	status_label = UiTheme.label("", 15, UiTheme.INK_SOFT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(380, 0)
	v.add_child(status_label)
	EventBus.save_status_changed.connect(func(s): status_label.text = s.get("message", ""))
	visible = false
	visibility_changed.connect(func(): if visible: UiTheme.place(_panel, Control.PRESET_CENTER))
