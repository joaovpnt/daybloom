class_name Hud
extends CanvasLayer
## HUD: relógio, estado do salvamento, indicador de interação, avisos e atalhos.

var root: Control
var clock_label: Label
var period_label: Label
var save_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_box: VBoxContainer
var backend_label: Label


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	# Relógio
	var clock := PanelContainer.new()
	clock.position = Vector2(24, 20)
	clock.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.CREAM, 26))
	root.add_child(clock)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	clock.add_child(cv)
	clock_label = UiTheme.label("Dia 1 · 08:00", 30)
	cv.add_child(clock_label)
	period_label = UiTheme.label("manhã", 18, UiTheme.INK_SOFT)
	cv.add_child(period_label)
	# Estado do salvamento
	var save_panel := PanelContainer.new()
	save_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(1, 0.98, 0.93, 0.92), 18))
	save_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	save_panel.position = Vector2(-24, 20)
	save_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(save_panel)
	var sv := VBoxContainer.new()
	save_panel.add_child(sv)
	save_label = UiTheme.label("Ainda não salvo (F5 para salvar)", 16, UiTheme.INK_SOFT)
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sv.add_child(save_label)
	backend_label = UiTheme.label("", 14, UiTheme.INK_SOFT)
	backend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sv.add_child(backend_label)
	# Indicador de interação
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.CREAM, 30))
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_panel.position.y = -110
	prompt_panel.visible = false
	root.add_child(prompt_panel)
	prompt_label = UiTheme.label("", 22)
	prompt_panel.add_child(prompt_label)
	# Avisos
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.position.y = 24
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	# Atalhos
	var hints := UiTheme.label("WASD mover · Shift correr · E interagir · I inventário · J Diário da Ilha · F5 salvar · Esc pausa", 15, Color(1, 1, 1, 0.95))
	hints.add_theme_color_override("font_outline_color", Color(0.2, 0.15, 0.1, 0.7))
	hints.add_theme_constant_override("outline_size", 6)
	hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hints.position = Vector2(24, -36)
	root.add_child(hints)

	EventBus.interaction_prompt_changed.connect(_on_prompt)
	EventBus.toast_requested.connect(show_toast)
	EventBus.save_status_changed.connect(_on_save_status)
	EventBus.backend_status_changed.connect(_on_backend_status)
	EventBus.journal_entry_added.connect(_on_journal)
	if not ApiClient.last_health.is_empty():
		_on_backend_status(ApiClient.last_health)


func _process(_delta: float) -> void:
	clock_label.text = "Dia %d · %s" % [GameClock.day, GameClock.format_hm(GameClock.minute)]
	period_label.text = GameClock.period().capitalize() + ("  ·  pausado" if get_tree().paused else "")


func _on_prompt(text: String) -> void:
	prompt_panel.visible = text != ""
	prompt_label.text = text


func _on_save_status(status: Dictionary) -> void:
	save_label.text = status.get("message", "")
	match status.get("state", ""):
		"error":
			save_label.add_theme_color_override("font_color", Color(0.8, 0.25, 0.2))
		"saved", "loaded":
			save_label.add_theme_color_override("font_color", UiTheme.GREEN_DARK)
		_:
			save_label.add_theme_color_override("font_color", UiTheme.INK_SOFT)


func _on_backend_status(status: Dictionary) -> void:
	var mongo := "MongoDB conectado" if status.get("mongo", false) else "MongoDB indisponível"
	var ia := "IA de diálogo: Qwen" if status.get("ollama", false) else "IA de diálogo: diálogos clássicos"
	backend_label.text = "%s · %s" % [mongo, ia]


func _on_journal(entry: Dictionary) -> void:
	if entry.get("kind", "") in ["shared_activity", "disagreement", "reconciliation", "community_event", "relationship_change"]:
		show_toast("Diário da Ilha: " + str(entry["text"]))


func show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(1, 0.98, 0.93, 0.95), 20))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(560.0, 14.0 * text.length() + 40.0), 0)
	panel.add_child(l)
	toast_box.add_child(panel)
	while toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := panel.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)
