class_name SettingsPanel
extends PanelContainer
## Configurações de vídeo e interface. Usado no menu principal e na pausa.
## As mudanças são aplicadas na hora e salvas em user://settings.cfg.

signal closed()

var _rows: VBoxContainer
var renderer_label: Label


func _ready() -> void:
	theme = UiTheme.make()
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.SPACE_M)
	add_child(v)
	v.add_child(UiTheme.title("Configurações"))
	renderer_label = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	renderer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(renderer_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", UiTheme.SPACE_S)
	v.add_child(_rows)
	_section("Vídeo")
	_toggle("Tela cheia", "fullscreen")
	_toggle("Sincronia vertical (VSync)", "vsync")
	_option("Suavização (MSAA)", "msaa", [["Desligada", 0], ["2×", 2], ["4×", 4]])
	_option("Sombras", "shadows", [["Desligadas", 0], ["Médias", 1], ["Altas", 2]])
	_toggle("Oclusão ambiente (SSAO)", "ssao")
	_toggle("Brilho suave (glow)", "glow")
	_option("Resolução 3D", "render_scale", [["75%", 0.75], ["85%", 0.85], ["100%", 1.0]])
	_section("Interface")
	_option("Tamanho da interface", "ui_scale", [["Pequeno", 0.9], ["Normal", 1.0], ["Grande", 1.15]])
	_toggle("Mostrar FPS", "show_fps")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var back := UiTheme.button("Pronto")
	back.pressed.connect(close_panel)
	row.add_child(back)
	visible = false


func open() -> void:
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	var active := RenderingServer.get_current_rendering_method()
	renderer_label.text = "Renderizador: %s%s" % [_renderer_name(active), "" if active == method else " (projeto pede %s; o driver atual não suporta)" % _renderer_name(method)]
	visible = true
	await get_tree().process_frame
	UiTheme.place(self, Control.PRESET_CENTER)
	UiTheme.pop_in(self)


static func _renderer_name(m: String) -> String:
	match m:
		"forward_plus":
			return "Forward+"
		"mobile":
			return "Mobile"
		"gl_compatibility":
			return "Compatibilidade (OpenGL)"
	return m


func close_panel() -> void:
	if visible:
		visible = false
		Settings.save_settings()
		closed.emit()


func _section(text: String) -> void:
	var l := UiTheme.label(text.to_upper(), 13, UiTheme.INK_FAINT, true)
	_rows.add_child(l)


func _row(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.SPACE_M)
	var l := UiTheme.label(text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	_rows.add_child(h)
	return h


func _toggle(text: String, prop: String) -> void:
	var h := _row(text)
	var c := CheckButton.new()
	c.name = prop
	c.button_pressed = bool(Settings.get(prop))
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		c.add_theme_stylebox_override(st, empty)
	c.add_theme_stylebox_override("focus", UiTheme.box(Color(0, 0, 0, 0), 999, UiTheme.INK, 2, false, 0))
	c.toggled.connect(func(on: bool):
		Settings.set(prop, on)
		Settings.apply())
	h.add_child(c)


func _option(text: String, prop: String, choices: Array) -> void:
	var h := _row(text)
	var o := OptionButton.new()
	o.name = prop
	o.custom_minimum_size = Vector2(150, 0)
	var current = Settings.get(prop)
	for i in range(choices.size()):
		o.add_item(str(choices[i][0]), i)
		if is_equal_approx(float(choices[i][1]), float(current)):
			o.select(i)
	o.item_selected.connect(func(idx: int):
		var val = choices[idx][1]
		Settings.set(prop, int(val) if typeof(Settings.get(prop)) == TYPE_INT else float(val))
		Settings.apply())
	h.add_child(o)
