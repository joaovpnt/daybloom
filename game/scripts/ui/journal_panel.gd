class_name JournalPanel
extends PanelContainer
## Diário da Ilha: acontecimentos confirmados (cartões por dia, com cor por
## tipo) e moradores (cartões com retrato e corações; detalhe com objetivo,
## amizades e memórias). A seção "Avançado" mostra necessidades e estado da IA.

signal closed()

const TAB_EVENTS := 0
const TAB_RESIDENTS := 1

var tabs: TabContainer          # mantido por compatibilidade (abas ocultas)
var segment: HBoxContainer
var events_box: VBoxContainer
var residents_box: VBoxContainer
var detail_box: VBoxContainer
var detail_text: RichTextLabel  # memórias e amizades (texto rico)
var advanced_toggle: CheckButton
var advanced_text: RichTextLabel
var filter_holder: HBoxContainer
var selected_npc: String = ""
var _filter: String = ""
var _seg_buttons: Array = []


func _ready() -> void:
	theme = UiTheme.make()
	custom_minimum_size = Vector2(980, 640)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.SPACE_M)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTheme.SPACE_L)
	v.add_child(top)
	var t := UiTheme.title("Diário da Ilha", 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	segment = HBoxContainer.new()
	segment.add_theme_constant_override("separation", 0)
	top.add_child(segment)
	for i in range(2):
		var b := Button.new()
		b.text = ["Acontecimentos", "Moradores"][i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): show_tab(i))
		segment.add_child(b)
		_seg_buttons.append(b)
	var close := UiTheme.secondary_button("Fechar  ·  Esc")
	close.pressed.connect(close_panel)
	top.add_child(close)
	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	# --- Acontecimentos
	var ev := VBoxContainer.new()
	ev.name = "Acontecimentos"
	ev.add_theme_constant_override("separation", UiTheme.SPACE_S)
	tabs.add_child(ev)
	filter_holder = HBoxContainer.new()
	filter_holder.add_theme_constant_override("separation", 6)
	ev.add_child(filter_holder)
	var es := ScrollContainer.new()
	es.size_flags_vertical = Control.SIZE_EXPAND_FILL
	es.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ev.add_child(es)
	events_box = VBoxContainer.new()
	events_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events_box.add_theme_constant_override("separation", 6)
	es.add_child(events_box)
	# --- Moradores
	var h := HBoxContainer.new()
	h.name = "Moradores"
	h.add_theme_constant_override("separation", UiTheme.SPACE_L)
	tabs.add_child(h)
	var rs := ScrollContainer.new()
	rs.custom_minimum_size = Vector2(360, 0)
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(rs)
	residents_box = VBoxContainer.new()
	residents_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	residents_box.add_theme_constant_override("separation", 6)
	rs.add_child(residents_box)
	var dpanel := PanelContainer.new()
	dpanel.add_theme_stylebox_override("panel", UiTheme.box(Color.WHITE, 18, UiTheme.LINE, 2, false, 16))
	dpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(dpanel)
	var ds := ScrollContainer.new()
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dpanel.add_child(ds)
	detail_box = VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", UiTheme.SPACE_S)
	ds.add_child(detail_box)
	detail_text = _rich(16)
	advanced_toggle = CheckButton.new()
	advanced_toggle.text = "Avançado (necessidades e estado da IA)"
	advanced_toggle.toggled.connect(func(_on): _refresh_advanced())
	advanced_text = _rich(15)
	show_tab(TAB_EVENTS)
	visible = false


func _rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", UiTheme.INK)
	return r


func show_tab(i: int) -> void:
	tabs.current_tab = i
	for k in range(_seg_buttons.size()):
		var b: Button = _seg_buttons[k]
		var on := k == i
		b.button_pressed = on
		var radius := [999, 0, 0, 999] if k == 0 else [0, 999, 999, 0]
		var bg := UiTheme.GREEN if on else UiTheme.SURFACE_ALT
		var sb := UiTheme.button_box(bg, 999, 0 if not on else 3, 18, 8)
		sb.corner_radius_top_left = radius[0]
		sb.corner_radius_top_right = radius[1]
		sb.corner_radius_bottom_right = radius[2]
		sb.corner_radius_bottom_left = radius[3]
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, sb)
		var fc := Color.WHITE if on else UiTheme.INK_SOFT
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, fc)


func open() -> void:
	refresh()
	visible = true
	await get_tree().process_frame
	UiTheme.place(self, Control.PRESET_CENTER)
	UiTheme.pop_in(self)
	(_seg_buttons[tabs.current_tab] as Button).grab_focus()


func close_panel() -> void:
	if visible:
		visible = false
		closed.emit()


func refresh() -> void:
	var sim := GameState.sim
	if sim == null:
		return
	_build_filters()
	_build_events()
	_build_residents()
	if selected_npc == "" or not sim.npcs.has(selected_npc):
		selected_npc = sim.npc_order[0]
	show_detail(selected_npc)


# --- Acontecimentos ----------------------------------------------------------

func _build_filters() -> void:
	for c in filter_holder.get_children():
		c.queue_free()
	var kinds := {"": "Todos"}
	for e in GameState.sim.journal.entries:
		var k: String = e.get("kind", "")
		kinds[k] = UiTheme.KIND_LABELS.get(k, "Outros")
	var seen_labels := {}
	for k in kinds:
		var lbl: String = kinds[k]
		if seen_labels.has(lbl):
			continue
		seen_labels[lbl] = true
		var b := Button.new()
		b.text = lbl
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var col: Color = UiTheme.KIND_COLORS.get(k, UiTheme.LINE_STRONG) if k != "" else UiTheme.INK_SOFT
		var on: bool = _label_of(_filter) == lbl
		var sb := UiTheme.box(col if on else Color.WHITE, 999, col, 2, false, 0)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_font_size_override("font_size", 14)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color.WHITE if on else UiTheme.INK)
		b.pressed.connect(func():
			_filter = k
			_build_filters()
			_build_events())
		filter_holder.add_child(b)


func _label_of(kind: String) -> String:
	return "Todos" if kind == "" else UiTheme.KIND_LABELS.get(kind, "Outros")


func _build_events() -> void:
	for c in events_box.get_children():
		c.queue_free()
	var sim := GameState.sim
	var entries: Array = sim.journal.to_array()
	entries.reverse()
	var last_day := -1
	var shown := 0
	for e in entries:
		if _filter != "" and _label_of(e.get("kind", "")) != _label_of(_filter):
			continue
		if int(e["day"]) != last_day:
			last_day = int(e["day"])
			var dl := UiTheme.label("Dia %d" % last_day, UiTheme.SIZE_SMALL, UiTheme.GREEN_DARK, true)
			if shown > 0:
				dl.custom_minimum_size = Vector2(0, 30)
				dl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			events_box.add_child(dl)
		events_box.add_child(_event_card(e))
		shown += 1
	if shown == 0:
		var empty := UiTheme.label("Nenhum acontecimento registrado ainda. Os moradores vivem suas vidas — volte daqui a pouco!", UiTheme.SIZE_BODY, UiTheme.INK_SOFT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		events_box.add_child(empty)


func _event_card(e: Dictionary) -> Control:
	var kind: String = e.get("kind", "")
	var col: Color = UiTheme.KIND_COLORS.get(kind, UiTheme.LINE_STRONG)
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color.WHITE, 14, UiTheme.LINE, 0, false, 10)
	sb.border_width_left = 6
	sb.border_color = col
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UiTheme.SPACE_M)
	card.add_child(h)
	var faces := HBoxContainer.new()
	faces.add_theme_constant_override("separation", -10)
	h.add_child(faces)
	var parts: Array = e.get("participants", [])
	for pid in parts.slice(0, 2):
		if GameState.sim.npcs.has(pid):
			var pf := PortraitFrame.new()
			pf.custom_minimum_size = Vector2(40, 40)
			pf.npc_id = pid
			faces.add_child(pf)
	if faces.get_child_count() == 0:
		faces.custom_minimum_size = Vector2(40, 0)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 0)
	h.add_child(text_col)
	var meta := UiTheme.label("%s · %s" % [GameClock.format_hm(float(e["minute"])), UiTheme.KIND_LABELS.get(kind, "Acontecimento")], 13, col.darkened(0.25), true)
	text_col.add_child(meta)
	var body := UiTheme.label(str(e["text"]), 16)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(body)
	return card


# --- Moradores -----------------------------------------------------------------

func _build_residents() -> void:
	for c in residents_box.get_children():
		c.queue_free()
	var sim := GameState.sim
	for npc_id in sim.npc_order:
		residents_box.add_child(_resident_card(npc_id))


func _resident_card(npc_id: String) -> Control:
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var rel: Dictionary = sim.relationships.get_rel(npc_id, sim.player_id)
	var on := npc_id == selected_npc
	var b := Button.new()
	b.name = npc_id
	b.custom_minimum_size = Vector2(0, 74)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UiTheme.box(Color("f2fbef") if on else Color.WHITE, 16, UiTheme.GREEN if on else UiTheme.LINE, 3 if on else 2, false, 6))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color("f7fdf4"), 16, UiTheme.GREEN, 2, false, 6))
	b.add_theme_stylebox_override("pressed", UiTheme.box(Color("eef9ee"), 16, UiTheme.GREEN_DARK, 3, false, 6))
	b.add_theme_stylebox_override("focus", UiTheme.box(Color(0, 0, 0, 0), 16, UiTheme.INK, 2, false, 6))
	b.pressed.connect(func(): show_detail(npc_id))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", UiTheme.SPACE_M)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var pf := PortraitFrame.new()
	pf.custom_minimum_size = Vector2(56, 56)
	pf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pf.npc_id = npc_id
	h.add_child(pf)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_row)
	var nl := UiTheme.label(npc.display_name(), 18, UiTheme.INK, true)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nl)
	var hl := UiTheme.hearts_label(float(rel["affinity"]), 15)
	name_row.add_child(hl)
	var act := UiTheme.label("%s · %s" % [npc.mood.capitalize(), npc.activity], 14, UiTheme.INK_SOFT)
	act.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	act.clip_text = true
	col.add_child(act)
	for n in [h, col, name_row, nl, hl, act, pf]:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func show_detail(npc_id: String) -> void:
	var sim := GameState.sim
	if not sim.npcs.has(npc_id):
		return
	var changed := npc_id != selected_npc
	selected_npc = npc_id
	if changed:
		_build_residents()
	for c in detail_box.get_children():
		detail_box.remove_child(c)
		if c != detail_text and c != advanced_toggle and c != advanced_text:
			c.queue_free()
	var npc: NpcState = sim.npcs[npc_id]
	var rel: Dictionary = sim.relationships.get_rel(npc_id, sim.player_id)
	# Cabeçalho
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.SPACE_L)
	detail_box.add_child(head)
	var pf := PortraitFrame.new()
	pf.custom_minimum_size = Vector2(104, 104)
	pf.npc_id = npc_id
	head.add_child(pf)
	var hc := VBoxContainer.new()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hc)
	hc.add_child(UiTheme.title(npc.display_name(), 28))
	hc.add_child(UiTheme.label("%s · %s" % [npc.def.species.capitalize(), npc.def.occupation], UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	hc.add_child(chips)
	chips.add_child(UiTheme.chip(npc.mood.capitalize(), UiTheme.mood_color(npc.mood)))
	chips.add_child(UiTheme.chip(RelationshipSystem.label_for(float(rel["affinity"])).capitalize(), UiTheme.CORAL))
	chips.add_child(UiTheme.hearts_label(float(rel["affinity"]), 18))
	var summary := UiTheme.label(npc.def.personality_summary, UiTheme.SIZE_SMALL, UiTheme.INK_SOFT)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(summary)
	detail_box.add_child(UiTheme.label("Agora: %s" % npc.activity, 16))
	# Objetivo
	detail_box.add_child(UiTheme.label("OBJETIVO PESSOAL", 13, UiTheme.INK_FAINT, true))
	var goal := UiTheme.label(npc.def.personal_goal, 16)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(goal)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.value = npc.goal_progress * 100.0
	bar.add_theme_stylebox_override("background", UiTheme.box(UiTheme.SURFACE_ALT, 999, UiTheme.LINE, 0, false, 0))
	bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD, 999, UiTheme.GOLD, 0, false, 0))
	bar.tooltip_text = "%d%%" % int(npc.goal_progress * 100.0)
	detail_box.add_child(bar)
	# Amizades e memórias (texto rico)
	var t := []
	var friends := []
	for other_id in sim.npc_order:
		if other_id != npc_id:
			friends.append([sim.relationships.affinity(npc_id, other_id), other_id])
	friends.sort_custom(func(a, b): return a[0] > b[0])
	var fl := []
	for f in friends.slice(0, 3):
		fl.append("%s [color=#8a7562](%s)[/color]" % [sim.npcs[f[1]].display_name(), RelationshipSystem.label_for(f[0])])
	t.append("[b]Mais próximos:[/b] " + ", ".join(fl))
	var worst: Array = friends[-1]
	if float(worst[0]) < -8.0:
		t.append("[b]Em atrito com:[/b] %s" % sim.npcs[worst[1]].display_name())
	t.append("\n[b]Memórias importantes[/b]")
	var mems := sim.memories.retrieve(npc_id, {"now_abs": sim.now_abs()}, 6)
	for m in mems:
		var times := " (×%d)" % int(m["occurrences"]) if int(m["occurrences"]) > 1 else ""
		t.append("[color=#b8a58f]Dia %d[/color]  %s%s" % [int(m["day"]), m["description"], times])
	if mems.is_empty():
		t.append("[color=#8a7562]Nenhuma ainda.[/color]")
	detail_text.text = "\n".join(t)
	detail_box.add_child(detail_text)
	detail_box.add_child(advanced_toggle)
	detail_box.add_child(advanced_text)
	_refresh_advanced()


func _refresh_advanced() -> void:
	advanced_text.visible = advanced_toggle.button_pressed
	if not advanced_text.visible or selected_npc == "":
		return
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[selected_npc]
	var rel: Dictionary = sim.relationships.get_rel(selected_npc, sim.player_id)
	var lines := []
	lines.append("Estado: %s" % NpcState.STATE_LABELS.get(npc.state, npc.state))
	lines.append("Afinidade %.0f · confiança %.0f" % [float(rel["affinity"]), float(rel["trust"])])
	lines.append("Necessidades: energia %d · social %d · diversão %d · conforto %d" % [int(npc.need("energia")), int(npc.need("social")), int(npc.need("diversao")), int(npc.need("conforto"))])
	advanced_text.text = "[color=#8a7562]%s[/color]" % "\n".join(lines)
