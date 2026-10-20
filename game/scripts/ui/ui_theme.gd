class_name UiTheme
extends RefCounted
## Tema visual aconchegante do Daybloom (cores creme, madeira e verde).

const CREAM := Color(1.0, 0.973, 0.91)
const CREAM_DARK := Color(0.96, 0.91, 0.8)
const INK := Color(0.33, 0.24, 0.17)
const INK_SOFT := Color(0.52, 0.42, 0.33)
const GREEN := Color(0.44, 0.72, 0.42)
const GREEN_DARK := Color(0.32, 0.58, 0.32)
const CORAL := Color(0.94, 0.52, 0.45)
const SKY := Color(0.55, 0.78, 0.92)
const GOLD := Color(0.98, 0.78, 0.35)

static var _theme: Theme


static func panel_style(bg: Color = CREAM, radius: int = 22, border: Color = Color(0.86, 0.76, 0.6), shadow: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	if shadow:
		sb.shadow_color = Color(0.25, 0.16, 0.08, 0.22)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 5)
	return sb


static func button_style(bg: Color, radius: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.border_color = bg.darkened(0.18)
	sb.border_width_bottom = 4
	return sb


static func make() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(1, 1, 0.9))
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.6))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "Button", button_style(GREEN))
	t.set_stylebox("hover", "Button", button_style(GREEN.lightened(0.1)))
	t.set_stylebox("pressed", "Button", button_style(GREEN_DARK))
	t.set_stylebox("focus", "Button", button_style(GREEN.lightened(0.15)))
	t.set_stylebox("disabled", "Button", button_style(Color(0.7, 0.68, 0.62)))
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	var le := StyleBoxFlat.new()
	le.bg_color = Color(1, 1, 1)
	le.set_corner_radius_all(14)
	le.border_color = Color(0.86, 0.76, 0.6)
	le.set_border_width_all(2)
	le.content_margin_left = 14
	le.content_margin_right = 14
	le.content_margin_top = 8
	le.content_margin_bottom = 8
	t.set_stylebox("normal", "LineEdit", le)
	var le_focus := le.duplicate()
	le_focus.border_color = GREEN
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT.lightened(0.3))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_stylebox("panel", "TabContainer", panel_style(CREAM, 18, Color(0.86, 0.76, 0.6), false))
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", INK_SOFT)
	t.set_color("font_hovered_color", "TabContainer", INK)
	var tab_sel := button_style(CREAM, 14)
	tab_sel.border_width_bottom = 0
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", button_style(CREAM_DARK, 14))
	t.set_stylebox("tab_hovered", "TabContainer", button_style(CREAM_DARK.lightened(0.3), 14))
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(0.86, 0.76, 0.6, 0.6)
	scroll.set_corner_radius_all(6)
	t.set_stylebox("grabber", "VScrollBar", scroll)
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.04)
	track.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_color("font_color", "CheckBox", INK)
	_theme = t
	return t


static func label(text: String, size: int = 20, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, color: Color = GREEN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if color != GREEN:
		b.add_theme_stylebox_override("normal", button_style(color))
		b.add_theme_stylebox_override("hover", button_style(color.lightened(0.1)))
		b.add_theme_stylebox_override("pressed", button_style(color.darkened(0.12)))
		b.add_theme_stylebox_override("focus", button_style(color.lightened(0.15)))
	return b


## Ícone circular colorido de item.
static func item_icon(item_id: String, size: float = 44.0) -> Control:
	var icon := ItemIcon.new()
	icon.item_id = item_id
	icon.custom_minimum_size = Vector2(size, size)
	return icon
