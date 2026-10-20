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
	m.rim = 0.25
	m.rim_tint = 0.6
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


static func water() -> ShaderMaterial:
	if _cache.has("water"):
		return _cache["water"]
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, specular_toon;
uniform vec4 shallow : source_color = vec4(0.42, 0.85, 0.88, 1.0);
uniform vec4 deep : source_color = vec4(0.16, 0.52, 0.78, 1.0);
uniform float wave_strength = 0.05;
uniform float night = 0.0;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.35 + TIME * 1.2) * wave_strength + cos(world_pos.z * 0.3 + TIME) * wave_strength;
}
void fragment() {
	float d = clamp(length(world_pos.xz) / 70.0, 0.0, 1.0);
	vec3 col = mix(shallow.rgb, deep.rgb, d);
	float ripple = sin(world_pos.x * 1.7 + TIME * 2.0) * sin(world_pos.z * 1.3 - TIME * 1.6);
	col += vec3(smoothstep(0.85, 1.0, ripple)) * 0.25;
	col = mix(col, col * vec3(0.25, 0.3, 0.55), night);
	ALBEDO = col;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	_cache["water"] = m
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
