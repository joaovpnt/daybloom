class_name UiTheme
extends RefCounted
## Design system do Daybloom 0.2 — "papel de carta aconchegante".
##
## Tokens: paleta creme/folha/coral, tipografia Nunito (texto) e Fredoka
## (títulos e logo), raios de 14/22 px, espaçamentos de 4/8/12/16/24 px e
## animações curtas (0,18 s) para abrir painéis.

# --- Paleta -------------------------------------------------------------------
const CREAM := Color("fff7ea")
const SURFACE := Color("fffdf8")
const SURFACE_ALT := Color("f6eddd")
const LINE := Color("e8d8c0")
const LINE_STRONG := Color("d6c0a0")
const INK := Color("4a3a2c")
const INK_SOFT := Color("8a7562")
const INK_FAINT := Color("b8a58f")
const GREEN := Color("6dbe7a")
const GREEN_DARK := Color("4e9e5d")
const CORAL := Color("f08a78")
const CORAL_DARK := Color("d96e5c")
const SKY := Color("7fb8e6")
const GOLD := Color("f6c25b")
const LILAC := Color("b49be0")
const DANGER := Color("d9574a")
const SHADOW := Color(0.29, 0.2, 0.12, 0.18)

# --- Espaçamento e forma -------------------------------------------------------
const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 16
const SPACE_XL := 24
const RADIUS_S := 14
const RADIUS_L := 22

# --- Tipografia ------------------------------------------------------------
const SIZE_SMALL := 15
const SIZE_BODY := 18
const SIZE_TITLE := 26
const SIZE_DISPLAY := 40

## Cores por tipo de acontecimento (Diário da Ilha).
const KIND_COLORS := {
	"friendly_chat": Color("7fb8e6"),
	"shared_activity": Color("6dbe7a"),
	"disagreement": Color("e07b62"),
	"reconciliation": Color("e58fb0"),
	"gift_received": Color("f6c25b"),
	"community_event": Color("b49be0"),
	"important_conversation": Color("8fc7b8"),
	"relationship_change": Color("f0a35c"),
	"new_friendship": Color("e58fb0"),
	"trust_change": Color("8fc7b8"),
	"goal_started": Color("f6c25b"),
	"goal_milestone": Color("e3a93b"),
	"goal_completed": Color("d98f1f"),
	"promise": Color("7f9be6"),
	"invitation": Color("6dbe7a"),
}
const KIND_LABELS := {
	"friendly_chat": "Conversa",
	"shared_activity": "Atividade",
	"disagreement": "Desentendimento",
	"reconciliation": "Reconciliação",
	"gift_received": "Presente",
	"community_event": "Comunidade",
	"important_conversation": "Conversa",
	"relationship_change": "Amizade",
	"new_friendship": "Nova amizade",
	"trust_change": "Confiança",
	"goal_started": "Objetivo",
	"goal_milestone": "Objetivo",
	"goal_completed": "Objetivo",
	"promise": "Promessa",
	"invitation": "Convite",
}

static var _theme: Theme
static var _fonts: Dictionary = {}
static var _textures: Dictionary = {}


# --- Fontes ---------------------------------------------------------------

static func _font(file: String, weight: int) -> Font:
	var key := "%s|%d" % [file, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base: FontFile = load("res://assets/fonts/%s" % file)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[key] = fv
	return fv


static func font_regular() -> Font:
	return _font("Nunito.ttf", 550)


static func font_bold() -> Font:
	return _font("Nunito.ttf", 800)


static func font_display() -> Font:
	return _font("Fredoka.ttf", 600)


# --- Recursos de imagem ------------------------------------------------------

static func portrait(npc_id: String) -> Texture2D:
	return _texture("res://assets/ui/portraits/%s.png" % npc_id)


static func item_texture(item_id: String) -> Texture2D:
	return _texture("res://assets/ui/icons/%s.png" % item_id)


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


# --- Caixas de estilo --------------------------------------------------------

static func box(bg: Color = SURFACE, radius: int = RADIUS_L, border: Color = LINE, border_w: int = 2, shadow: bool = true, pad: int = SPACE_L) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 14
		sb.shadow_offset = Vector2(0, 6)
	return sb


## Compatibilidade com a versão 0.1.
static func panel_style(bg: Color = SURFACE, radius: int = RADIUS_L, border: Color = LINE, shadow: bool = true) -> StyleBoxFlat:
	return box(bg, radius, border, 2, shadow)


static func button_box(bg: Color, radius: int = 999, border_bottom: int = 4, pad_h: int = 22, pad_v: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.border_color = bg.darkened(0.16)
	sb.border_width_bottom = border_bottom
	sb.anti_aliasing = true
	return sb


static func button_style(bg: Color, radius: int = 999) -> StyleBoxFlat:
	return button_box(bg, radius)


static func make() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font_regular()
	t.default_font_size = SIZE_BODY
	t.set_color("font_color", "Label", INK)
	_style_button(t, "Button", GREEN, Color.WHITE)
	t.set_font("font", "Button", font_bold())
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("panel", "Panel", box())
	var le := box(Color.WHITE, RADIUS_S, LINE, 2, false, 10)
	t.set_stylebox("normal", "LineEdit", le)
	var le_focus := box(Color.WHITE, RADIUS_S, GREEN, 2, false, 10)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_FAINT)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(GREEN, 0.35))
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("bold_font", "RichTextLabel", font_bold())
	t.set_font("normal_font", "RichTextLabel", font_regular())
	t.set_stylebox("panel", "TabContainer", box(SURFACE, RADIUS_S, LINE, 0, false, 0))
	var empty := StyleBoxEmpty.new()
	for s in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]:
		t.set_stylebox(s, "TabContainer", empty)
	t.set_constant("side_margin", "TabContainer", 0)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(LINE_STRONG, 0.9)
	grab.set_corner_radius_all(6)
	grab.content_margin_left = 4
	grab.content_margin_right = 4
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab_h := grab.duplicate()
	grab_h.bg_color = INK_FAINT
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_h)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_h)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.04)
	track.set_corner_radius_all(6)
	track.content_margin_left = 4
	track.content_margin_right = 4
	t.set_stylebox("scroll", "VScrollBar", track)
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = SURFACE_ALT
	pb_bg.set_corner_radius_all(999)
	pb_bg.content_margin_top = 5
	pb_bg.content_margin_bottom = 5
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = GREEN
	pb_fill.set_corner_radius_all(999)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_hover_pressed_color", "CheckButton", INK)
	t.set_color("font_focus_color", "CheckButton", INK)
	t.set_stylebox("focus", "CheckButton", box(Color(0, 0, 0, 0), RADIUS_S, GREEN, 2, false, 4))
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(s, "CheckButton", box(Color(0, 0, 0, 0), RADIUS_S, Color(0, 0, 0, 0), 0, false, 4))
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_hover_color", "OptionButton", INK)
	t.set_color("font_pressed_color", "OptionButton", INK)
	t.set_color("font_focus_color", "OptionButton", INK)
	for s in ["normal", "hover", "pressed", "focus"]:
		var ob := box(Color.WHITE if s != "hover" else Color("fbf4e6"), RADIUS_S, GREEN if s == "focus" else LINE, 2, false, 8)
		t.set_stylebox(s, "OptionButton", ob)
	var tip := box(INK, 10, INK, 0, true, 8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", CREAM)
	_theme = t
	return t


static func _style_button(t: Theme, type: String, color: Color, text: Color) -> void:
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, text)
	t.set_color("font_pressed_color", type, text)
	t.set_color("font_focus_color", type, text)
	t.set_color("font_disabled_color", type, Color(text, 0.6))
	t.set_stylebox("normal", type, button_box(color))
	t.set_stylebox("hover", type, button_box(color.lightened(0.08)))
	var pressed := button_box(color.darkened(0.08), 999, 1)
	pressed.content_margin_top += 3
	t.set_stylebox("pressed", type, pressed)
	var focus := button_box(color.lightened(0.08))
	focus.border_color = INK
	focus.set_border_width_all(3)
	t.set_stylebox("focus", type, focus)
	t.set_stylebox("disabled", type, button_box(Color("cfc6b8")))


# --- Componentes ---------------------------------------------------------------

static func label(text: String, size: int = SIZE_BODY, color: Color = INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	return l


static func title(text: String, size: int = SIZE_TITLE) -> Label:
	var l := label(text, size, INK)
	l.add_theme_font_override("font", font_display())
	return l


## Botão. Variantes: primary (verde), secondary (creme), danger (coral), ghost.
static func button(text: String, color: Variant = GREEN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c: Color = GREEN
	if color is Color:
		c = color
	elif color is String:
		match color:
			"secondary":
				return secondary_button(text)
			"danger":
				c = CORAL
			"sky":
				c = SKY
			"gold":
				c = GOLD.darkened(0.08)
	if c != GREEN:
		b.add_theme_stylebox_override("normal", button_box(c))
		b.add_theme_stylebox_override("hover", button_box(c.lightened(0.08)))
		var pr := button_box(c.darkened(0.08), 999, 1)
		pr.content_margin_top += 3
		b.add_theme_stylebox_override("pressed", pr)
		var fc := button_box(c.lightened(0.08))
		fc.border_color = INK
		fc.set_border_width_all(3)
		b.add_theme_stylebox_override("focus", fc)
	return b


static func secondary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(s, INK)
	var n := button_box(SURFACE_ALT)
	n.border_color = LINE_STRONG
	b.add_theme_stylebox_override("normal", n)
	var h := button_box(Color("f1e4cd"))
	h.border_color = LINE_STRONG
	b.add_theme_stylebox_override("hover", h)
	var p := button_box(Color("eadbc1"), 999, 1)
	p.content_margin_top += 3
	b.add_theme_stylebox_override("pressed", p)
	var f := button_box(Color("f1e4cd"))
	f.border_color = INK
	f.set_border_width_all(3)
	b.add_theme_stylebox_override("focus", f)
	return b


## Pílula/etiqueta (humor, tipo de item, estado).
static func chip(text: String, color: Color = SKY, text_color: Color = INK) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.28)
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	var l := label(text, SIZE_SMALL, text_color, true)
	pc.add_child(l)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


## Tecla (ex.: "E") para o indicador de interação.
static func keycap(key: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := button_box(INK, 8, 3, 9, 2)
	sb.border_color = Color("2e241b")
	pc.add_theme_stylebox_override("panel", sb)
	var l := label(key, SIZE_SMALL, CREAM, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc


## Corações de afinidade (0 a 5).
static func hearts_text(affinity: float) -> String:
	var n := clampi(int(round((affinity + 10.0) / 18.0)), 0, 5)
	return "♥".repeat(n) + "♡".repeat(5 - n)


static func hearts_label(affinity: float, size: int = SIZE_BODY) -> Label:
	var l := label(hearts_text(affinity), size, CORAL)
	return l


static func mood_color(mood: String) -> Color:
	if mood == "radiante" or mood == "alegre":
		return GREEN
	if mood == "triste" or mood.begins_with("chatead"):
		return SKY
	if mood.begins_with("cansad") or mood == "dormindo":
		return LILAC
	if mood.begins_with("solit") or mood.begins_with("entediad"):
		return GOLD
	return Color("c9b79d")


## Retrato circular com moldura.
static func portrait_rect(npc_id: String, size: float = 96.0) -> Control:
	var frame := PortraitFrame.new()
	frame.npc_id = npc_id
	frame.custom_minimum_size = Vector2(size, size)
	return frame


## Ícone de item (renderizado no Blender, com reserva desenhada).
static func item_icon(item_id: String, size: float = 44.0) -> Control:
	var tex := item_texture(item_id)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(size, size)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var icon := ItemIcon.new()
	icon.item_id = item_id
	icon.custom_minimum_size = Vector2(size, size)
	return icon


static func separator() -> Control:
	var c := ColorRect.new()
	c.color = LINE
	c.custom_minimum_size = Vector2(0, 2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Ancora um controle levando em conta o tamanho mínimo (evita deslocamentos).
static func place(c: Control, preset: int, margin: int = 0) -> void:
	c.reset_size()
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER else Control.GROW_DIRECTION_BEGIN


## Animação curta de entrada (escala + opacidade).
static func pop_in(c: Control, from_scale: float = 0.96) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * from_scale
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.16)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2)
