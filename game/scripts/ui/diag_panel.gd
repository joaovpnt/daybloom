class_name DiagPanel
extends PanelContainer
## Painel de diagnóstico (F3): backend, MongoDB, Ollama, fila de IA, latência,
## erros recentes, memórias por morador, salvamento e desempenho. Nunca fica
## visível sem a jogadora pedir.

var text: RichTextLabel
var last_health: Dictionary = {}
var last_save_status: Dictionary = {}
var ai: Dictionary = {}
var _timer := 0.0
var _ai_timer := 0.0
var _fetching := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.INK, 0.9), 16, UiTheme.INK, 0, true, 12))
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -484
	offset_right = -24
	offset_top = 112
	custom_minimum_size = Vector2(460, 0)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.add_theme_color_override("default_color", UiTheme.CREAM)
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_font_size_override("bold_font_size", 14)
	text.custom_minimum_size = Vector2(436, 0)
	add_child(text)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func toggle() -> void:
	visible = not visible
	_ai_timer = 0.0
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	_ai_timer -= delta
	if _ai_timer <= 0.0 and not _fetching:
		_ai_timer = 2.0
		_fetch_ai()
	if _timer <= 0.0:
		_timer = 0.5
		_refresh()


func _fetch_ai() -> void:
	_fetching = true
	ai = await ApiClient.ai_status()
	_fetching = false


func _yes(v: bool) -> String:
	return "[color=#9be59f]ok[/color]" if v else "[color=#ff9f8f]indisponível[/color]"


func _refresh() -> void:
	var lines := ["[b]Diagnóstico[/b]  (F3 para fechar)"]
	lines.append("Backend: %s  ·  MongoDB: %s  ·  Ollama: %s" % [_yes(last_health.get("backend", false)), _yes(last_health.get("mongo", false)), _yes(last_health.get("ollama_reachable", false))])
	if str(last_health.get("error", "")) != "":
		lines.append("Detalhe: %s" % str(last_health.get("error", "")))
	var model := str(ai.get("modelo", last_health.get("ollama_model", "?")))
	var installed: bool = ai.get("modelo_instalado", last_health.get("ollama", false))
	lines.append("Modelo: %s (%s)  ·  Modo de diálogo: %s" % [model, "instalado" if installed else "[color=#ff9f8f]não instalado[/color]", "IA local" if ApiClient.last_health.get("ollama", false) else "diálogos clássicos"])
	if not ai.is_empty():
		var m: Dictionary = ai.get("metricas", {})
		var fila: Array = ai.get("fila", [])
		var ativos: Array = ai.get("em_andamento", [])
		var ativo := "nenhuma"
		if not ativos.is_empty():
			ativo = "%s (%s, %.1f s)" % [ativos[0]["tipo"], ativos[0]["morador"], float(ativos[0]["tempo_ms"]) / 1000.0]
		lines.append("Fila de IA: %d  ·  Em andamento: %s" % [fila.size(), ativo])
		var lat = m.get("ultima_latencia_ms")
		var tok = m.get("ultimos_tokens")
		lines.append("Última latência: %s  ·  média: %s  ·  tokens: %s" % [
			("%.1f s" % (float(lat) / 1000.0)) if lat != null else "—",
			("%.1f s" % (float(m.get("latencia_media_ms")) / 1000.0)) if m.get("latencia_media_ms") != null else "—",
			("%d → %d" % [int(tok["entrada"]), int(tok["saida"])]) if tok is Dictionary else "—"])
		lines.append("Pedidos: %d concluídos · %d falhas · %d cancelados · %d obsoletos · %d repetidos" % [
			int(m.get("concluidas", 0)), int(m.get("falhas", 0)), int(m.get("canceladas", 0)), int(m.get("obsoletas", 0)), int(m.get("deduplicadas", 0))])
		var errs: Array = ai.get("erros_recentes", [])
		if not errs.is_empty():
			var parts := []
			for e in errs.slice(max(0, errs.size() - 3)):
				parts.append("%s: %s" % [e.get("tipo", ""), e.get("motivo", "")])
			lines.append("[color=#ffcf9f]Erros recentes: %s[/color]" % ", ".join(parts))
	lines.append("Salvamento: %s (revisão %d)" % [str(last_save_status.get("message", "—")), SaveManager.revision])
	lines.append("Desempenho: %d FPS · %d objetos · %d chamadas de desenho" % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	if GameState.sim:
		var sim := GameState.sim
		var states := {}
		var mem_parts := []
		for id in sim.npc_order:
			var s: String = sim.npcs[id].state
			states[s] = states.get(s, 0) + 1
			mem_parts.append("%s %d" % [sim.npcs[id].display_name().trim_prefix("Dona ").substr(0, 7), sim.memories.count_for(id)])
		lines.append("Moradores: %s" % str(states))
		lines.append("Memórias: %s" % " · ".join(mem_parts))
		lines.append("Interações em andamento: %d" % sim.active_interactions.size())
	text.text = "\n".join(lines)
