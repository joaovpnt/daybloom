class_name PortraitFrame
extends Control
## Retrato circular do personagem (renderizado no Blender) com moldura.

const MASK_SHADER := """
shader_type canvas_item;
uniform vec4 bg : source_color = vec4(1.0, 0.95, 0.86, 1.0);
uniform vec4 ring : source_color = vec4(0.84, 0.75, 0.6, 1.0);
uniform float ring_width = 0.045;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p);
	vec4 tex = texture(TEXTURE, UV * 0.78 + vec2(0.11, 0.02));
	vec4 col = mix(bg, vec4(tex.rgb, 1.0), tex.a);
	float edge = smoothstep(0.5, 0.49, d);
	float r = smoothstep(0.5 - ring_width - 0.01, 0.5 - ring_width, d);
	col = mix(col, ring, r);
	COLOR = vec4(col.rgb, col.a * edge);
}
"""

static var _shader: Shader

var npc_id: String = "":
	set(value):
		npc_id = value
		_refresh()
var bg_color: Color = Color("fff1dc")
var _rect: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = MASK_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("bg", bg_color)
	_rect.material = m
	add_child(_rect)
	_refresh()


func _refresh() -> void:
	if _rect == null:
		return
	_rect.texture = UiTheme.portrait(npc_id)
	(_rect.material as ShaderMaterial).set_shader_parameter("bg", bg_color)
