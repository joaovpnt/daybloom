class_name IslandTerrain
extends RefCounted
## Terreno da ilha: núcleo plano e caminhável, pequenas elevações (mirante e
## bosque), transição suave para a praia, fundo do lago e da água rasa.
## A mesma função de altura é usada pela malha, pela colisão e pelo mapa lógico.

const MOUNDS := [
	{"pos": Vector2(-21, -31), "radius": 8.5, "height": 0.9},
	{"pos": Vector2(27, -30), "radius": 6.5, "height": 0.55},
	{"pos": Vector2(-36, -6), "radius": 5.0, "height": 0.4},
]
const POND_CENTER := Vector2(21, 18)
const POND_RADIUS := 5.5

const GRASS_A := Color(0.47, 0.72, 0.36)
const GRASS_B := Color(0.40, 0.66, 0.33)
const GRASS_C := Color(0.56, 0.76, 0.38)
const SAND := Color(0.95, 0.86, 0.64)
const SAND_WET := Color(0.84, 0.74, 0.55)
const POND_BED := Color(0.42, 0.55, 0.42)

static var _noise: FastNoiseLite


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 2026
		_noise.frequency = 0.045
		_noise.fractal_octaves = 3
	return _noise


static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var r := p.length()
	var h := 0.0
	for m in MOUNDS:
		var d: float = p.distance_to(m["pos"]) / float(m["radius"])
		if d < 1.0:
			h += float(m["height"]) * (0.5 + 0.5 * cos(d * PI))
	# Praia: começa em 41 m, desce suavemente até a água
	if r > 41.0:
		h -= 0.08 * _smooth((r - 41.0) / 3.0)
	if r > 44.0:
		h -= 0.42 * _smooth((r - 44.0) / 5.5)
	if r > 49.5:
		h -= 1.2 * _smooth((r - 49.5) / 4.0)
	# Fundo do lago
	var dp := p.distance_to(POND_CENTER)
	if dp < POND_RADIUS + 0.6:
		h -= 0.55 * _smooth((POND_RADIUS + 0.6 - dp) / 1.6)
	return h


static func color_at(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var r := p.length()
	var n := _n().get_noise_2d(x, z)
	var c := GRASS_A.lerp(GRASS_B, clampf(n * 0.9 + 0.35, 0.0, 1.0))
	c = c.lerp(GRASS_C, clampf(_n().get_noise_2d(x * 2.3 + 40.0, z * 2.3) * 0.8, 0.0, 0.6))
	var sand_t := _smooth((r - 40.5 + n * 1.2) / 2.0)
	c = c.lerp(SAND, sand_t)
	c = c.lerp(SAND_WET, _smooth((r - 46.5) / 2.5))
	var dp := p.distance_to(POND_CENTER)
	if dp < POND_RADIUS + 1.4:
		c = c.lerp(SAND, _smooth((POND_RADIUS + 1.4 - dp) / 0.8))
		if dp < POND_RADIUS:
			c = c.lerp(POND_BED, _smooth((POND_RADIUS - dp) / 1.0))
	return c


## Malha em anéis concêntricos com cores por vértice.
static func build_mesh(max_r: float = 56.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 160
	var radii: Array = [0.0]
	var r := 0.6
	while r < max_r:
		radii.append(r)
		r += 0.9 if r < 40.0 else 0.7
	radii.append(max_r)
	var grid := []
	for ri in range(radii.size()):
		var ring := []
		var count := 1 if ri == 0 else segs
		for s in range(count):
			var a := TAU * s / segs + (0.5 * TAU / segs if ri % 2 == 1 else 0.0)
			var rr: float = radii[ri]
			var x := cos(a) * rr
			var z := sin(a) * rr
			ring.append(Vector3(x, height(x, z), z))
		grid.append(ring)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for ri in range(grid.size() - 1):
		var inner: Array = grid[ri]
		var outer: Array = grid[ri + 1]
		for s in range(segs):
			var o0: Vector3 = outer[s]
			var o1: Vector3 = outer[(s + 1) % segs]
			if inner.size() == 1:
				_tri(st, inner[0], o0, o1)
			else:
				var i0: Vector3 = inner[s]
				var i1: Vector3 = inner[(s + 1) % segs]
				_tri(st, i0, o0, o1)
				_tri(st, i0, o1, i1)
	st.generate_normals()
	var mesh := st.commit()
	return mesh


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_color(color_at(v.x, v.z, v.y))
		st.add_vertex(v)


static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m
