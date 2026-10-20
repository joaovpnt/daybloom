class_name InventoryPanel
extends PanelContainer
## Inventário: grade de itens à esquerda e detalhes do item selecionado à
## direita. No modo presente, o botão principal entrega o item escolhido.

signal item_chosen(item_id: String)
signal closed()

const COLUMNS := 5
const SLOT := 92

var grid: GridContainer
var title: Label
var hint: Label
var detail_icon_holder: CenterContainer
var detail_name: Label
var detail_kind_holder: HBoxContainer
var detail_desc: Label
var detail_count: Label
var primary_button: Button
var gift_mode := false
var selected: String = ""
var _slot_buttons: Dictionary = {}


func _ready() -> void:
	theme = UiTheme.make()
	custom_minimum_size = Vector2(860, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiTheme.SPACE_M)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	title = UiTheme.title("Inventário")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	hint = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(hint)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiTheme.SPACE_L)
	v.add_child(body)
	var grid_bg := PanelContainer.new()
	grid_bg.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE_ALT, 18, UiTheme.LINE, 0, false, 10))
	body.add_child(grid_bg)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid_bg.add_child(grid)
	# Detalhes
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(300, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", UiTheme.SPACE_S)
	body.add_child(detail)
	detail_icon_holder = CenterContainer.new()
	detail_icon_holder.custom_minimum_size = Vector2(0, 150)
	detail.add_child(detail_icon_holder)
	detail_name = UiTheme.title("", 24)
	detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(detail_name)
	detail_kind_holder = HBoxContainer.new()
	detail_kind_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	detail.add_child(detail_kind_holder)
	detail_desc = UiTheme.label("", UiTheme.SIZE_BODY, UiTheme.INK_SOFT)
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_desc.custom_minimum_size = Vector2(280, 54)
	detail.add_child(detail_desc)
	detail_count = UiTheme.label("", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true)
	detail_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(detail_count)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiTheme.SPACE_S)
	detail.add_child(buttons)
	primary_button = UiTheme.button("Dar presente", "gold")
	primary_button.pressed.connect(_on_primary)
	buttons.add_child(primary_button)
	var close := UiTheme.secondary_button("Fechar  ·  Esc")
	close.pressed.connect(close_panel)
	buttons.add_child(close)
	EventBus.inventory_changed.connect(refresh)
	visible = false


func open(for_gift: bool = false) -> void:
	gift_mode = for_gift
	title.text = "Escolha um presente" if for_gift else "Inventário"
	selected = ""
	refresh()
	visible = true
	await get_tree().process_frame
	UiTheme.place(self, Control.PRESET_CENTER)
	UiTheme.pop_in(self)
	if not _slot_buttons.is_empty():
		(_slot_buttons.values()[0] as Button).grab_focus()


func close_panel() -> void:
	if visible:
		visible = false
		closed.emit()


func refresh() -> void:
	for c in grid.get_children():
		c.queue_free()
	_slot_buttons.clear()
	var items := GameState.inventory.items()
	hint.text = "%d / %d espaços" % [items.size(), Inventory.MAX_SLOTS]
	if selected == "" or GameState.inventory.count(selected) == 0:
		selected = items[0]["item_id"] if not items.is_empty() else ""
	for i in range(Inventory.MAX_SLOTS):
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.focus_mode = Control.FOCUS_ALL
		if i < items.size():
			var item_id: String = items[i]["item_id"]
			var is_sel := item_id == selected
			b.add_theme_stylebox_override("normal", UiTheme.box(Color.WHITE, 16, UiTheme.GREEN if is_sel else UiTheme.LINE, 3 if is_sel else 2, false, 4))
			b.add_theme_stylebox_override("hover", UiTheme.box(Color("fbfff8"), 16, UiTheme.GREEN, 3, false, 4))
			b.add_theme_stylebox_override("pressed", UiTheme.box(Color("eef9ee"), 16, UiTheme.GREEN_DARK, 3, false, 4))
			b.add_theme_stylebox_override("focus", UiTheme.box(Color(0, 0, 0, 0), 16, UiTheme.INK, 2, false, 4))
			b.tooltip_text = ItemDB.display_name(item_id)
			var icon := UiTheme.item_icon(item_id, 68)
			icon.set_anchors_preset(Control.PRESET_CENTER)
			icon.position = Vector2((SLOT - 68) / 2.0, (SLOT - 68) / 2.0 - 4)
			b.add_child(icon)
			var count := UiTheme.label("×%d" % int(items[i]["count"]), 13, UiTheme.INK, true)
			count.position = Vector2(SLOT - 34, SLOT - 24)
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(count)
			b.pressed.connect(func(): _select(item_id))
			b.gui_input.connect(func(ev): _on_slot_input(ev, item_id))
			_slot_buttons[item_id] = b
		else:
			b.disabled = true
			b.add_theme_stylebox_override("disabled", UiTheme.box(Color(1, 1, 1, 0.45), 16, Color(UiTheme.LINE, 0.6), 2, false, 4))
		grid.add_child(b)
	_update_detail()


func _on_slot_input(ev: InputEvent, item_id: String) -> void:
	if ev is InputEventMouseButton and ev.double_click and gift_mode:
		_select(item_id)
		_on_primary()


func _select(item_id: String) -> void:
	selected = item_id
	refresh()
	if _slot_buttons.has(item_id):
		(_slot_buttons[item_id] as Button).grab_focus()


func _update_detail() -> void:
	for c in detail_icon_holder.get_children():
		c.queue_free()
	for c in detail_kind_holder.get_children():
		c.queue_free()
	primary_button.visible = gift_mode
	primary_button.disabled = selected == ""
	if selected == "":
		detail_name.text = "Inventário vazio"
		detail_desc.text = "Colete flores, conchas, frutas, galhos e pedras pela ilha."
		detail_count.text = ""
		return
	var item := ItemDB.get_item(selected)
	detail_icon_holder.add_child(UiTheme.item_icon(selected, 140))
	detail_name.text = ItemDB.display_name(selected)
	var kind: String = item.get("kind", "")
	var kind_color: Color = {"flor": UiTheme.CORAL, "fruta": UiTheme.GOLD, "praia": UiTheme.SKY, "material": Color("b39a7c")}.get(kind, UiTheme.LINE_STRONG)
	detail_kind_holder.add_child(UiTheme.chip(kind.capitalize(), kind_color))
	detail_desc.text = item.get("description", "")
	detail_count.text = "Você tem %d" % GameState.inventory.count(selected)


func _on_primary() -> void:
	if gift_mode and selected != "":
		item_chosen.emit(selected)
