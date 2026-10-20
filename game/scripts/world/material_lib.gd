class_name MaterialLib
extends RefCounted
## Materiais estilizados (toon) reaproveitados em toda a ilha.

static var _cache: Dictionary = {}


static func toon(color: Color, roughness: float = 0.9, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), roughness, emission]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.5
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_cache[key] = m
	return m


## Material de janela que acende à noite (o DayNight ajusta a emissão).
static func window_glass() -> StandardMaterial3D:
	if _cache.has("window"):
		return _cache["window"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.75, 0.9)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.82, 0.45)
	m.emission_energy_multiplier = 0.0
	m.roughness = 0.2
	_cache["window"] = m
	return m


const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.40, 0.82, 0.86, 1.0);
uniform vec4 deep : source_color = vec4(0.14, 0.48, 0.74, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform vec2 center = vec2(0.0, 0.0);
uniform float shore_radius = 48.6;
uniform float deep_radius = 75.0;
uniform float foam_width = 0.9;
uniform float wave_strength = 0.045;
uniform float night = 0.0;
uniform bool pond = false;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (!pond) {
		VERTEX.y += sin(world_pos.x * 0.32 + TIME * 1.1) * wave_strength + cos(world_pos.z * 0.27 + TIME * 0.9) * wave_strength;
	}
}

void fragment() {
	float r = length(world_pos.xz - center);
	float d = pond ? clamp(1.0 - r / shore_radius, 0.0, 1.0) : clamp((r - shore_radius) / (deep_radius - shore_radius), 0.0, 1.0);
	vec3 col = mix(shallow.rgb, deep.rgb, pond ? d * 0.6 : d);
	float ripple = vnoise(world_pos.xz * 0.9 + vec2(TIME * 0.25, TIME * 0.18)) * vnoise(world_pos.xz * 1.7 - vec2(TIME * 0.2, 0.0));
	col += vec3(smoothstep(0.42, 0.62, ripple)) * 0.12;
	float edge = pond ? (shore_radius - r) : (r - shore_radius);
	float foam_noise = vnoise(world_pos.xz * 2.2 + vec2(TIME * 0.6, 0.0));
	float foam = (1.0 - smoothstep(0.0, foam_width + foam_noise * 0.5, edge)) * step(-0.4, edge);
	foam *= 0.6 + 0.4 * sin(TIME * 1.6 + r * 2.0);
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 1.0) * 0.85);
	col = mix(col, col * vec3(0.22, 0.28, 0.5), night);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
"""


static func _water_material(key: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var shader := Shader.new()
	shader.code = WATER_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	_cache[key] = m
	return m


static func water() -> ShaderMaterial:
	return _water_material("water")


static func pond_water() -> ShaderMaterial:
	var created := not _cache.has("pond_water")
	var m := _water_material("pond_water")
	if created:
		var c: Vector2 = Places.POIS["lago"]["pos"]
		m.set_shader_parameter("pond", true)
		m.set_shader_parameter("center", c)
		m.set_shader_parameter("shore_radius", float(Places.POIS["lago"]["radius"]) + 0.4)
		m.set_shader_parameter("foam_width", 0.35)
		m.set_shader_parameter("shallow", Color(0.45, 0.78, 0.74))
		m.set_shader_parameter("deep", Color(0.22, 0.50, 0.58))
	return m


static func mesh(m: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func sphere(r: float, h: float = -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if h > 0.0 else r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cylinder(top: float, bottom: float, height: float, segments: int = 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 20
	c.rings = 6
	return c
