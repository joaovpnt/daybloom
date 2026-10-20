class_name Hud
extends CanvasLayer
## HUD enxuto: relógio, indicador de interação e avisos. Informações técnicas
## ficam no painel de diagnóstico (F3). Falhas de salvamento continuam visíveis
## como um aviso integrado ao visual.

var root: Control
var clock: ClockBadge
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_box: VBoxContainer
var save_pill: PanelContainer
var save_label: Label
var warning_pill: PanelContainer
var warning_label: Label
var hint_panel: PanelContainer
var fps_label: Label
var diag: DiagPanel
var _save_hide_timer := 0.0
var _hint_timer := 25.0


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	# Relógio
	clock = ClockBadge.new()
	clock.position = Vector2(22, 18)
	root.add_child(clock)
	# Avisos persistentes (salvamento indisponível) e status momentâneo
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-22, 18)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	warning_pill = _pill(Color("fde7e2"), UiTheme.DANGER)
	warning_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.DANGER, true)
	warning_pill.add_child(warning_label)
	warning_pill.visible = false
	warning_pill.tooltip_text = "Pressione F3 para ver detalhes"
	right.add_child(warning_pill)
	save_pill = _pill(Color(UiTheme.SURFACE, 0.95), UiTheme.LINE)
	save_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true)
	save_pill.add_child(save_label)
	save_pill.visible = false
	right.add_child(save_pill)
	fps_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(fps_label)
	# Indicador de interação
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.95), 999, UiTheme.LINE, 2, true, 8))
	prompt_panel.visible = false
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_panel)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	prompt_panel.add_child(ph)
	ph.add_child(UiTheme.keycap("E"))
	prompt_label = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK, true)
	ph.add_child(prompt_label)
	# Notificações
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.position.y = 20
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	# Dica de controles (some sozinha; F1 mostra de novo)
	hint_panel = PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.9), 16, UiTheme.LINE, 2, false, 8))
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_panel)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 14)
	hint_panel.add_child(hh)
	for pair in [["WASD", "andar"], ["Shift", "correr"], ["E", "interagir"], ["I", "inventário"], ["J", "diário"], ["F5", "salvar"], ["Esc", "pausa"]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.add_child(UiTheme.keycap(pair[0]))
		item.add_child(UiTheme.label(pair[1], UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true))
		hh.add_child(item)
	diag = DiagPanel.new()
	root.add_child(diag)
	EventBus.interaction_prompt_changed.connect(_on_prompt)
	EventBus.toast_requested.connect(show_toast)
	EventBus.save_status_changed.connect(_on_save_status)
	EventBus.backend_status_changed.connect(_on_backend_status)
	EventBus.journal_entry_added.connect(_on_journal)
	root.resized.connect(_layout)
	_layout.call_deferred()
	if not ApiClient.last_health.is_empty():
		_on_backend_status(ApiClient.last_health)


func _pill(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(bg, 999, border, 2, false, 6))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


func _layout() -> void:
	var vs := root.size
	prompt_panel.reset_size()
	prompt_panel.position = Vector2((vs.x - prompt_panel.size.x) * 0.5, vs.y - prompt_panel.size.y - 84)
	hint_panel.reset_size()
	hint_panel.position = Vector2(22, vs.y - hint_panel.size.y - 18)


func _process(delta: float) -> void:
	if _save_hide_timer > 0.0:
		_save_hide_timer -= delta
		if _save_hide_timer <= 0.0:
			save_pill.visible = false
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 3.0:
			hint_panel.modulate.a = clampf(_hint_timer / 3.0, 0.0, 1.0)
		if _hint_timer <= 0.0:
			hint_panel.visible = false
	fps_label.visible = Settings.show_fps
	if Settings.show_fps:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func show_hints() -> void:
	hint_panel.visible = true
	hint_panel.modulate.a = 1.0
	_hint_timer = 10.0


func toggle_diagnostics() -> void:
	diag.toggle()


func _on_prompt(text: String) -> void:
	var clean := text.trim_prefix("[E] ")
	prompt_panel.visible = clean != ""
	prompt_label.text = clean
	_layout()


func _on_save_status(status: Dictionary) -> void:
	var state: String = status.get("state", "")
	var msg: String = status.get("message", "")
	save_pill.visible = true
	match state:
		"saving", "loading":
			save_label.text = "● " + msg
			save_label.add_theme_color_override("font_color", UiTheme.INK_SOFT)
			_save_hide_timer = 0.0
		"saved", "loaded":
			save_label.text = "✓ Partida salva" if state == "saved" else "✓ Partida carregada"
			save_label.tooltip_text = msg
			save_label.add_theme_color_override("font_color", UiTheme.GREEN_DARK)
			_save_hide_timer = 3.5
		"error":
			# Erros de salvamento não somem sozinhos: a jogadora precisa saber.
			save_label.text = "⚠ " + msg
			save_label.add_theme_color_override("font_color", UiTheme.DANGER)
			_save_hide_timer = 12.0
	diag.last_save_status = status


func _on_backend_status(status: Dictionary) -> void:
	diag.last_health = status
	if not status.get("backend", false):
		warning_label.text = "⚠ Salvamento indisponível — backend desligado"
		warning_pill.visible = true
	elif not status.get("mongo", false):
		warning_label.text = "⚠ Salvamento indisponível — MongoDB fora do ar"
		warning_pill.visible = true
	else:
		warning_pill.visible = false


func _on_journal(entry: Dictionary) -> void:
	if entry.get("kind", "") in ["shared_activity", "disagreement", "reconciliation", "community_event", "relationship_change", "gift_received"]:
		show_toast(str(entry["text"]), entry.get("kind", ""))


func show_toast(text: String, kind: String = "") -> void:
	var panel := PanelContainer.new()
	var color: Color = UiTheme.KIND_COLORS.get(kind, UiTheme.LINE_STRONG)
	var sb := UiTheme.box(Color(UiTheme.SURFACE, 0.97), 16, UiTheme.LINE, 2, true, 8)
	sb.border_width_left = 6
	sb.border_color = UiTheme.LINE
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(6, 22)
	h.add_child(dot)
	var l := UiTheme.label(text, UiTheme.SIZE_SMALL + 1, UiTheme.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(520.0, 9.5 * text.length() + 30.0), 0)
	h.add_child(l)
	toast_box.add_child(panel)
	while toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)
