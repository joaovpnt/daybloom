class_name DiagPanel
extends PanelContainer
## Painel de diagnóstico (F3): backend, MongoDB, Ollama, salvamento e desempenho.

var text: RichTextLabel
var last_health: Dictionary = {}
var last_save_status: Dictionary = {}
var _timer := 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.INK, 0.88), 16, UiTheme.INK, 0, true, 12))
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-420, 120)
	custom_minimum_size = Vector2(400, 0)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.add_theme_color_override("default_color", UiTheme.CREAM)
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("bold_font_size", 14)
	text.custom_minimum_size = Vector2(376, 0)
	add_child(text)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func toggle() -> void:
	visible = not visible
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_refresh()


func _yes(v: bool) -> String:
	return "[color=#9be59f]ok[/color]" if v else "[color=#ff9f8f]indisponível[/color]"


func _refresh() -> void:
	var lines := ["[b]Diagnóstico[/b]  (F3 para fechar)"]
	lines.append("Backend: %s  ·  MongoDB: %s  ·  Ollama: %s" % [_yes(last_health.get("backend", false)), _yes(last_health.get("mongo", false)), _yes(last_health.get("ollama", false))])
	if str(last_health.get("error", "")) != "":
		lines.append("Detalhe: %s" % str(last_health.get("error", "")))
	lines.append("Salvamento: %s (revisão %d)" % [str(last_save_status.get("message", "—")), SaveManager.revision])
	lines.append("Desempenho: %d FPS · %d objetos desenhados" % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	lines.append("Chamadas de desenho: %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if GameState.sim:
		var states := {}
		for id in GameState.sim.npc_order:
			var s: String = GameState.sim.npcs[id].state
			states[s] = states.get(s, 0) + 1
		lines.append("Moradores: %s" % str(states))
		lines.append("Interações em andamento: %d" % GameState.sim.active_interactions.size())
	text.text = "\n".join(lines)
