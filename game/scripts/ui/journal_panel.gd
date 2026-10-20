class_name JournalPanel
extends PanelContainer
## "Diário da Ilha" (acontecimentos confirmados) e painel dos moradores
## (humor, atividade, relação com a jogadora e memórias).

signal closed()

var tabs: TabContainer
var journal_text: RichTextLabel
var residents_box: VBoxContainer
var detail_text: RichTextLabel


func _ready() -> void:
	theme = UiTheme.make()
	custom_minimum_size = Vector2(900, 620)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UiTheme.label("Diário da Ilha", 30))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	# Aba: acontecimentos
	var scroll := ScrollContainer.new()
	scroll.name = "Acontecimentos"
	tabs.add_child(scroll)
	journal_text = RichTextLabel.new()
	journal_text.bbcode_enabled = true
	journal_text.fit_content = true
	journal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_text.add_theme_font_size_override("normal_font_size", 18)
	journal_text.add_theme_font_size_override("bold_font_size", 18)
	scroll.add_child(journal_text)
	# Aba: moradores
	var h := HBoxContainer.new()
	h.name = "Moradores"
	h.add_theme_constant_override("separation", 14)
	tabs.add_child(h)
	var rs := ScrollContainer.new()
	rs.custom_minimum_size = Vector2(430, 0)
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(rs)
	residents_box = VBoxContainer.new()
	residents_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	residents_box.add_theme_constant_override("separation", 6)
	rs.add_child(residents_box)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(ds)
	detail_text = RichTextLabel.new()
	detail_text.bbcode_enabled = true
	detail_text.fit_content = true
	detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_text.add_theme_font_size_override("normal_font_size", 16)
	detail_text.add_theme_font_size_override("bold_font_size", 17)
	ds.add_child(detail_text)
	var close := UiTheme.button("Fechar (Esc)", UiTheme.CORAL)
	close.pressed.connect(close_panel)
	v.add_child(close)
	visible = false


func open() -> void:
	refresh()
	visible = true
	UiTheme.place(self, Control.PRESET_CENTER)


func close_panel() -> void:
	if visible:
		visible = false
		closed.emit()


func refresh() -> void:
	var sim := GameState.sim
	if sim == null:
		return
	var lines := []
	var entries: Array = sim.journal.to_array()
	entries.reverse()
	var last_day := -1
	for e in entries:
		if int(e["day"]) != last_day:
			last_day = int(e["day"])
			lines.append("\n[b][color=#7a9e5a]Dia %d[/color][/b]" % last_day)
		lines.append("[color=#a08060]%s[/color]  %s" % [GameClock.format_hm(float(e["minute"])), e["text"]])
	if entries.is_empty():
		lines.append("Nenhum acontecimento registrado ainda.")
	journal_text.text = "\n".join(lines).strip_edges()
	for c in residents_box.get_children():
		c.queue_free()
	for npc_id in sim.npc_order:
		var npc: NpcState = sim.npcs[npc_id]
		var rel: Dictionary = sim.relationships.get_rel(npc_id, sim.player_id)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(1, 1, 1), 14, Color(0.9, 0.82, 0.68), false))
		b.add_theme_stylebox_override("hover", UiTheme.panel_style(Color(0.96, 1, 0.94), 14, UiTheme.GREEN, false))
		b.add_theme_stylebox_override("pressed", UiTheme.panel_style(Color(0.96, 1, 0.94), 14, UiTheme.GREEN_DARK, false))
		b.add_theme_color_override("font_color", UiTheme.INK)
		b.add_theme_color_override("font_hover_color", UiTheme.INK)
		b.add_theme_font_size_override("font_size", 16)
		b.text = "%s (%s) — %s\n%s · %s" % [npc.display_name(), npc.def.species, _hearts(float(rel["affinity"])), npc.mood.capitalize(), npc.activity]
		b.pressed.connect(func(): show_detail(npc_id))
		residents_box.add_child(b)
	if detail_text.text == "":
		show_detail(sim.npc_order[0])


func _hearts(aff: float) -> String:
	var n := clampi(int((aff + 10.0) / 20.0), 0, 5)
	return "♥".repeat(n) + "♡".repeat(5 - n) + " " + RelationshipSystem.label_for(aff)


func show_detail(npc_id: String) -> void:
	var sim := GameState.sim
	var npc: NpcState = sim.npcs[npc_id]
	var rel: Dictionary = sim.relationships.get_rel(npc_id, sim.player_id)
	var t := []
	t.append("[b]%s[/b] — %s, %s" % [npc.display_name(), npc.def.species, npc.def.occupation])
	t.append("[i]%s[/i]" % npc.def.personality_summary)
	t.append("Humor: %s · Estado: %s" % [npc.mood, NpcState.STATE_LABELS.get(npc.state, npc.state)])
	t.append("Com você: afinidade %.0f · confiança %.0f (%s)" % [float(rel["affinity"]), float(rel["trust"]), RelationshipSystem.label_for(float(rel["affinity"]))])
	t.append("Objetivo: %s (%d%%)" % [npc.def.personal_goal, int(npc.goal_progress * 100.0)])
	t.append("Necessidades: energia %d · social %d · diversão %d · conforto %d" % [int(npc.need("energia")), int(npc.need("social")), int(npc.need("diversao")), int(npc.need("conforto"))])
	# Amizades entre moradores
	var friends := []
	for other_id in sim.npc_order:
		if other_id == npc_id:
			continue
		friends.append([sim.relationships.affinity(npc_id, other_id), other_id])
	friends.sort_custom(func(a, b): return a[0] > b[0])
	var fl := []
	for f in friends.slice(0, 3):
		fl.append("%s (%s)" % [sim.npcs[f[1]].display_name(), RelationshipSystem.label_for(f[0])])
	t.append("Mais próximos: " + ", ".join(fl))
	var worst: Array = friends[-1]
	if float(worst[0]) < -8.0:
		t.append("Em atrito com: %s" % sim.npcs[worst[1]].display_name())
	t.append("\n[b]Memórias importantes[/b]")
	var mems := sim.memories.retrieve(npc_id, {"now_abs": sim.now_abs()}, 6)
	for m in mems:
		var times := " (×%d)" % int(m["occurrences"]) if int(m["occurrences"]) > 1 else ""
		t.append("• Dia %d: %s%s" % [int(m["day"]), m["description"], times])
	if mems.is_empty():
		t.append("Nenhuma ainda.")
	detail_text.text = "\n".join(t)
