class_name EmoteBubble
extends Node3D
## Balão de emoção acima do personagem (coração, nota, exclamação...).
## Pode ser persistente (estado atual) ou temporário (reação).

const STYLES := {
	"chat": {"text": "…", "color": Color(0.38, 0.32, 0.42)},
	"love": {"text": "♥", "color": Color(0.93, 0.36, 0.5)},
	"music": {"text": "♪", "color": Color(0.36, 0.55, 0.85)},
	"angry": {"text": "!", "color": Color(0.88, 0.3, 0.26)},
	"surprise": {"text": "!", "color": Color(0.95, 0.62, 0.2)},
	"sad": {"text": "~", "color": Color(0.45, 0.55, 0.8)},
	"sleep": {"text": "z", "color": Color(0.5, 0.55, 0.8)},
	"done": {"text": "✓", "color": Color(0.35, 0.68, 0.4)},
	"question": {"text": "?", "color": Color(0.55, 0.45, 0.75)},
}

static var _bubble_tex: Texture2D

var sprite: Sprite3D
var label: Label3D
var _persistent: String = ""
var _temp_timer := 0.0
var _pop := 0.0


static func bubble_texture() -> Texture2D:
	if _bubble_tex:
		return _bubble_tex
	var size := 96
	var img := Image.create(size, size + 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size / 2.0, size / 2.0)
	for y in range(size + 20):
		for x in range(size):
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var a := 0.0
			if d < 44.0:
				a = 1.0
			elif d < 46.0:
				a = 46.0 - d
			# rabinho do balão
			var t := Vector2(x - size / 2.0, y - (size - 6))
			if y > size - 14 and y < size + 16 and absf(t.x) < (size + 16 - y) * 0.45:
				a = 1.0
			if a > 0.0:
				var edge := d > 40.0 and d < 46.0 and y < size - 8
				img.set_pixel(x, y, Color(0.86, 0.76, 0.62, a) if edge else Color(1, 0.99, 0.96, a))
	_bubble_tex = ImageTexture.create_from_image(img)
	return _bubble_tex


func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.texture = bubble_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.0065
	sprite.no_depth_test = false
	sprite.visibility_range_end = 30.0
	add_child(sprite)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.0065
	label.outline_size = 0
	label.position = Vector3(0, 0.07, 0.01)
	label.render_priority = 1
	label.visibility_range_end = 30.0
	add_child(label)
	visible = false


func set_persistent(style: String) -> void:
	_persistent = style
	if _temp_timer <= 0.0:
		_show(style)


func flash(style: String, seconds: float = 2.0) -> void:
	_temp_timer = seconds
	_pop = 0.25
	_show(style)


func current() -> String:
	return label.text if visible else ""


func _show(style: String) -> void:
	if style == "" or not STYLES.has(style):
		visible = false
		return
	var st: Dictionary = STYLES[style]
	label.text = st["text"]
	label.modulate = st["color"]
	visible = true


func _process(delta: float) -> void:
	if _temp_timer > 0.0:
		_temp_timer -= delta
		if _temp_timer <= 0.0:
			_show(_persistent)
	if _pop > 0.0:
		_pop -= delta
		scale = Vector3.ONE * (1.0 + sin(clampf(_pop / 0.25, 0.0, 1.0) * PI) * 0.35)
	else:
		scale = Vector3.ONE
	position.y = position.y if not visible else position.y
