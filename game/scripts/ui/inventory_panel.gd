class_name InventoryPanel
extends PanelContainer
## Inventário em grade. No modo presente, um clique escolhe o item a entregar.

signal item_chosen(item_id: String)
signal closed()

var grid: GridContainer
var title: Label
var hint: Label
var gift_mode := false


func _ready() -> void:
	theme = UiTheme.make()
	custom_minimum_size = Vector2(620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	title = UiTheme.label("Inventário", 30)
	v.add_child(title)
	hint = UiTheme.label("", 16, UiTheme.INK_SOFT)
	v.add_child(hint)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var close := UiTheme.button("Fechar (Esc)", UiTheme.CORAL)
	close.pressed.connect(close_panel)
	v.add_child(close)
	EventBus.inventory_changed.connect(refresh)
	visible = false


func open(for_gift: bool = false) -> void:
	gift_mode = for_gift
	title.text = "Escolha um presente" if for_gift else "Inventário"
	refresh()
	visible = true
	await get_tree().process_frame
	UiTheme.place(self, Control.PRESET_CENTER)


func close_panel() -> void:
	if visible:
		visible = false
		closed.emit()


func refresh() -> void:
	for c in grid.get_children():
		c.queue_free()
	var items := GameState.inventory.items()
	hint.text = "%d de %d espaços usados. Colete flores, conchas, frutas, galhos e pedras pela ilha." % [items.size(), Inventory.MAX_SLOTS]
	if gift_mode:
		hint.text = "Clique em um item para entregá-lo."
	for slot in items:
		var item_id: String = slot["item_id"]
		var b := Button.new()
		b.custom_minimum_size = Vector2(108, 108)
		b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(1, 1, 1), 18, Color(0.9, 0.82, 0.68), false))
		b.add_theme_stylebox_override("hover", UiTheme.panel_style(Color(0.95, 1, 0.93), 18, UiTheme.GREEN, false))
		b.add_theme_stylebox_override("pressed", UiTheme.panel_style(Color(0.9, 0.97, 0.88), 18, UiTheme.GREEN_DARK, false))
		b.tooltip_text = "%s\n%s" % [ItemDB.display_name(item_id), ItemDB.get_item(item_id).get("description", "")]
		var bv := VBoxContainer.new()
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(bv)
		var icon := UiTheme.item_icon(item_id, 46)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(icon)
		var name_l := UiTheme.label("%s ×%d" % [ItemDB.display_name(item_id), int(slot["count"])], 13)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(name_l)
		b.pressed.connect(func(): _on_item(item_id))
		grid.add_child(b)
	if items.is_empty():
		grid.add_child(UiTheme.label("Seu inventário está vazio.", 18, UiTheme.INK_SOFT))


func _on_item(item_id: String) -> void:
	if gift_mode:
		item_chosen.emit(item_id)
