class_name IslandBuilder
extends RefCounted
## Constrói a ilha 3D (terreno, praia, lago, caminhos, casas, praça, jardim,
## árvores e decoração) com arte provisória original. Toda geometria sólida é
## filha da NavigationRegion3D, para que o navmesh seja gerado a partir dela.

const GRASS := Color(0.55, 0.8, 0.42)
const GRASS_DARK := Color(0.42, 0.68, 0.35)
const SAND := Color(0.97, 0.88, 0.66)
const PATH := Color(0.86, 0.74, 0.55)
const STONE := Color(0.88, 0.85, 0.8)
const WOOD := Color(0.62, 0.43, 0.28)
const WOOD_LIGHT := Color(0.8, 0.62, 0.42)

const HOUSE_STYLES := {
	"casa_jogadora": {"wall": Color(0.99, 0.93, 0.8), "roof": Color(0.95, 0.5, 0.42)},
	"casa_lila": {"wall": Color(0.99, 0.9, 0.93), "roof": Color(0.74, 0.58, 0.9)},
	"casa_tobias": {"wall": Color(0.96, 0.86, 0.68), "roof": Color(0.66, 0.38, 0.25)},
	"casa_otavio": {"wall": Color(0.82, 0.84, 0.9), "roof": Color(0.25, 0.32, 0.55)},
	"casa_pipa": {"wall": Color(1.0, 0.92, 0.72), "roof": Color(0.95, 0.55, 0.2)},
	"casa_marina": {"wall": Color(0.85, 0.95, 0.96), "roof": Color(0.22, 0.62, 0.68)},
	"casa_bento": {"wall": Color(0.9, 0.97, 0.82), "roof": Color(0.35, 0.6, 0.3)},
	"casa_ravena": {"wall": Color(0.95, 0.88, 0.84), "roof": Color(0.6, 0.25, 0.4)},
	"casa_celeste": {"wall": Color(0.98, 0.95, 0.98), "roof": Color(0.82, 0.62, 0.85)},
}

var root: Node3D
var nav_region: NavigationRegion3D
var static_root: Node3D
var decor_root: Node3D
var lamps: Array = []
var fire_lights: Array = []
var house_nodes: Dictionary = {}


func build(parent: Node3D) -> void:
	root = parent
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	nav_region.navigation_mesh = _make_navmesh()
	root.add_child(nav_region)
	static_root = Node3D.new()
	static_root.name = "Solidos"
	nav_region.add_child(static_root)
	decor_root = Node3D.new()
	decor_root.name = "Decoracao"
	root.add_child(decor_root)
	_build_ground()
	_build_boundary()
	_build_paths()
	_build_plaza()
	_build_pond()
	_build_garden()
	for house_id in Places.HOUSES:
		_build_house(house_id)
	_build_pois()
	_build_trees()
	_build_ground_decor()


func _make_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.region_min_size = 4.0
	# Ignora telhados e topos de objetos: só o nível do chão vira caminho.
	nm.filter_baking_aabb = AABB(Vector3(-56, -1.5, -56), Vector3(112, 3.0, 112))
	return nm


func _static_box(size: Vector3, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	body.rotation.y = rot_y
	static_root.add_child(body)
	return body


func _static_cylinder(radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	body.position = pos
	static_root.add_child(body)
	return body


func _build_ground() -> void:
	# Oceano
	var ocean := PlaneMesh.new()
	ocean.size = Vector2(420, 420)
	ocean.subdivide_width = 80
	ocean.subdivide_depth = 80
	var ocean_mi := MaterialLib.mesh(ocean, MaterialLib.water(), Vector3(0, -0.45, 0), decor_root)
	ocean_mi.name = "Oceano"
	ocean_mi.add_to_group("water")
	# Areia
	var sand := MaterialLib.mesh(MaterialLib.cylinder(Places.BEACH_RADIUS, Places.BEACH_RADIUS + 3.0, 1.0, 72), MaterialLib.toon(SAND), Vector3(0, -0.58, 0), decor_root)
	sand.name = "Praia"
	_static_cylinder(Places.BEACH_RADIUS, 1.0, Vector3(0, -0.58, 0))
	# Grama (levemente acima da areia)
	var grass := MaterialLib.mesh(MaterialLib.cylinder(Places.ISLAND_RADIUS, Places.ISLAND_RADIUS + 0.6, 1.0, 72), MaterialLib.toon(GRASS), Vector3(0, -0.5, 0), decor_root)
	grass.name = "Grama"
	_static_cylinder(Places.ISLAND_RADIUS, 1.0, Vector3(0, -0.5, 0))
	# Manchas de grama mais escura para dar textura
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(26):
		var r := sqrt(rng.randf()) * (Places.ISLAND_RADIUS - 6.0)
		var a := rng.randf() * TAU
		var patch := MaterialLib.mesh(MaterialLib.cylinder(rng.randf_range(2.0, 5.0), rng.randf_range(2.0, 5.0), 0.02, 18), MaterialLib.toon(GRASS_DARK), Vector3(cos(a) * r, 0.005, sin(a) * r), decor_root)
		patch.scale = Vector3(1.0, 1.0, rng.randf_range(0.6, 1.0))


func _build_boundary() -> void:
	# Limite invisível na beira da água.
	var count := 64
	for i in range(count):
		var a := TAU * i / count
		var pos := Vector3(cos(a), 0, sin(a)) * (Places.WALK_RADIUS + 0.8)
		var body := _static_box(Vector3(5.0, 3.0, 1.0), pos + Vector3(0, 1.0, 0), 0.0)
		body.look_at_from_position(body.position, Vector3(0, body.position.y, 0), Vector3.UP)


func _build_paths() -> void:
	var mat := MaterialLib.toon(PATH)
	for seg in IslandLayout.paths():
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var length := a.distance_to(b)
		var mid := (a + b) * 0.5
		var mi := MaterialLib.mesh(MaterialLib.box(Vector3(2.2, 0.03, length)), mat, Vector3(mid.x, 0.012, mid.y), decor_root)
		mi.rotation.y = atan2(b.x - a.x, b.y - a.y)
		# Pedrinhas nas bordas
		var stones := int(length / 2.5)
		for i in range(stones):
			var t := (i + 0.5) / stones
			var p := a.lerp(b, t)
			var side := Vector2(b.y - a.y, -(b.x - a.x)).normalized() * (1.25 if i % 2 == 0 else -1.25)
			MaterialLib.mesh(MaterialLib.sphere(0.13, 0.12), MaterialLib.toon(STONE), Vector3(p.x + side.x, 0.03, p.y + side.y), decor_root)


func _build_plaza() -> void:
	MaterialLib.mesh(MaterialLib.cylinder(7.2, 7.2, 0.06, 48), MaterialLib.toon(STONE), Vector3(0, 0.02, 0), decor_root)
	MaterialLib.mesh(MaterialLib.cylinder(5.4, 5.4, 0.065, 48), MaterialLib.toon(Color(0.93, 0.89, 0.82)), Vector3(0, 0.022, 0), decor_root)
	# Fonte central
	MaterialLib.mesh(MaterialLib.cylinder(1.7, 1.8, 0.6, 32), MaterialLib.toon(Color(0.8, 0.78, 0.75)), Vector3(0, 0.3, 0), decor_root)
	var water := MaterialLib.mesh(MaterialLib.cylinder(1.5, 1.5, 0.05, 32), MaterialLib.water(), Vector3(0, 0.58, 0), decor_root)
	water.add_to_group("water")
	MaterialLib.mesh(MaterialLib.cylinder(0.25, 0.32, 1.3, 16), MaterialLib.toon(Color(0.82, 0.8, 0.77)), Vector3(0, 1.0, 0), decor_root)
	MaterialLib.mesh(MaterialLib.cylinder(0.75, 0.55, 0.2, 24), MaterialLib.toon(Color(0.82, 0.8, 0.77)), Vector3(0, 1.65, 0), decor_root)
	MaterialLib.mesh(MaterialLib.sphere(0.25), MaterialLib.water(), Vector3(0, 1.85, 0), decor_root)
	_static_cylinder(1.85, 1.6, Vector3(0, 0.8, 0))
	# Bancos e postes de luz
	_bench(Places.poi_pos("banco_praca"), PI * 0.8)
	_bench(Vector3(-4.6, 0, -4.8), -PI * 0.75)
	_bench(Vector3(-5.5, 0, 3.2), -PI * 0.35)
	for i in range(4):
		var a := TAU * i / 4.0 + PI / 4.0
		_lamp(Vector3(cos(a) * 6.6, 0, sin(a) * 6.6))
	# Vasos de flores
	for i in range(6):
		var a2 := TAU * i / 6.0
		var p := Vector3(cos(a2) * 3.2, 0, sin(a2) * 3.2)
		MaterialLib.mesh(MaterialLib.cylinder(0.32, 0.24, 0.4, 12), MaterialLib.toon(Color(0.78, 0.45, 0.32)), p + Vector3(0, 0.2, 0), decor_root)
		var colors := [Color(0.98, 0.5, 0.55), Color(1.0, 0.85, 0.3), Color(0.6, 0.6, 1.0)]
		for j in range(3):
			MaterialLib.mesh(MaterialLib.sphere(0.12), MaterialLib.toon(colors[(i + j) % 3]), p + Vector3(cos(j * 2.1) * 0.13, 0.48, sin(j * 2.1) * 0.13), decor_root)


func _bench(pos: Vector3, rot: float) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = rot
	decor_root.add_child(b)
	var wood := MaterialLib.toon(WOOD_LIGHT)
	MaterialLib.mesh(MaterialLib.box(Vector3(1.8, 0.1, 0.55)), wood, Vector3(0, 0.45, 0), b)
	MaterialLib.mesh(MaterialLib.box(Vector3(1.8, 0.45, 0.08)), wood, Vector3(0, 0.75, -0.25), b)
	for side in [-1, 1]:
		MaterialLib.mesh(MaterialLib.box(Vector3(0.08, 0.45, 0.5)), MaterialLib.toon(Color(0.3, 0.3, 0.32)), Vector3(0.8 * side, 0.22, 0), b)
	var body := _static_box(Vector3(1.8, 0.9, 0.5), pos + Vector3(0, 0.45, 0), rot)
	body.position = pos + Vector3(0, 0.45, 0) + Vector3(sin(rot), 0, cos(rot)) * -0.1


func _lamp(pos: Vector3) -> void:
	MaterialLib.mesh(MaterialLib.cylinder(0.07, 0.1, 2.6, 10), MaterialLib.toon(Color(0.25, 0.27, 0.3)), pos + Vector3(0, 1.3, 0), decor_root)
	var bulb := MaterialLib.mesh(MaterialLib.sphere(0.22), MaterialLib.toon(Color(1.0, 0.93, 0.7), 0.5, 0.0), pos + Vector3(0, 2.7, 0), decor_root)
	bulb.material_override = MaterialLib.toon(Color(1.0, 0.93, 0.7)).duplicate()
	bulb.add_to_group("lamp_bulb")
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 2.6, 0)
	light.light_color = Color(1.0, 0.82, 0.55)
	light.omni_range = 7.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	decor_root.add_child(light)
	lamps.append(light)
	_static_cylinder(0.15, 2.6, pos + Vector3(0, 1.3, 0))


func _build_pond() -> void:
	var center := Places.poi_pos("lago")
	var r: float = Places.POIS["lago"]["radius"]
	MaterialLib.mesh(MaterialLib.cylinder(r + 0.5, r + 0.6, 0.06, 40), MaterialLib.toon(SAND.darkened(0.05)), center + Vector3(0, 0.01, 0), decor_root)
	var water := MaterialLib.mesh(MaterialLib.cylinder(r, r, 0.05, 40), MaterialLib.water(), center + Vector3(0, 0.05, 0), decor_root)
	water.add_to_group("water")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(22):
		var a := TAU * i / 22.0
		if absf(wrapf(a - PI, -PI, PI)) < 0.25:
			continue  # espaço do píer
		var s := rng.randf_range(0.25, 0.45)
		MaterialLib.mesh(MaterialLib.sphere(s, s * 1.2), MaterialLib.toon(Color(0.7, 0.7, 0.72)), center + Vector3(cos(a), 0, sin(a)) * (r + 0.35) + Vector3(0, 0.1, 0), decor_root)
	# Vitórias-régias
	for i in range(6):
		var p := center + Vector3(rng.randf_range(-3, 3), 0.09, rng.randf_range(-3, 3))
		MaterialLib.mesh(MaterialLib.cylinder(0.4, 0.4, 0.02, 14), MaterialLib.toon(Color(0.35, 0.7, 0.35)), p, decor_root)
		if i % 2 == 0:
			MaterialLib.mesh(MaterialLib.sphere(0.12), MaterialLib.toon(Color(1.0, 0.75, 0.85)), p + Vector3(0.1, 0.08, 0), decor_root)
	_static_cylinder(r + 0.2, 2.0, center + Vector3(0, 0.5, 0))
	# Píer de madeira
	var dock := Places.poi_pos("doca")
	var planks := MaterialLib.toon(WOOD_LIGHT)
	for i in range(5):
		MaterialLib.mesh(MaterialLib.box(Vector3(0.45, 0.08, 1.6)), planks, Vector3(dock.x + 0.8 + i * 0.5, 0.15, dock.z), decor_root)
	for z in [-0.7, 0.7]:
		MaterialLib.mesh(MaterialLib.cylinder(0.08, 0.08, 0.6, 8), MaterialLib.toon(WOOD), Vector3(dock.x + 3.0, 0.2, dock.z + z), decor_root)


func _build_garden() -> void:
	var c := Places.poi_pos("jardim")
	var soil := MaterialLib.toon(Color(0.55, 0.38, 0.26))
	var flower_colors := [Color(0.98, 0.5, 0.55), Color(1.0, 0.85, 0.3), Color(0.55, 0.6, 1.0), Color(0.98, 0.97, 0.9), Color(0.8, 0.5, 0.95)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for row in range(2):
		for col in range(3):
			var p := c + Vector3(-3.0 + col * 3.0, 0, -1.6 + row * 3.0)
			MaterialLib.mesh(MaterialLib.box(Vector3(2.2, 0.25, 1.4)), MaterialLib.toon(WOOD), p + Vector3(0, 0.12, 0), decor_root)
			MaterialLib.mesh(MaterialLib.box(Vector3(2.0, 0.27, 1.2)), soil, p + Vector3(0, 0.13, 0), decor_root)
			for k in range(7):
				var fp := p + Vector3(rng.randf_range(-0.85, 0.85), 0.3, rng.randf_range(-0.45, 0.45))
				MaterialLib.mesh(MaterialLib.cylinder(0.015, 0.015, 0.25, 4), MaterialLib.toon(Color(0.3, 0.6, 0.3)), fp + Vector3(0, 0.1, 0), decor_root)
				MaterialLib.mesh(MaterialLib.sphere(0.09), MaterialLib.toon(flower_colors[(row * 3 + col + k) % flower_colors.size()]), fp + Vector3(0, 0.24, 0), decor_root)
	# Cerquinha baixa (sem colisão para não bloquear o acesso)
	var fence := MaterialLib.toon(Color(0.98, 0.96, 0.9))
	for i in range(14):
		var x := -5.2 + i * 0.8
		for z in [-3.2, 4.6]:
			if z > 0 and absf(x) < 1.6:
				continue  # entrada
			MaterialLib.mesh(MaterialLib.box(Vector3(0.1, 0.55, 0.1)), fence, c + Vector3(x, 0.27, z), decor_root)
	# Regador e placa
	MaterialLib.mesh(MaterialLib.cylinder(0.15, 0.18, 0.3, 12), MaterialLib.toon(Color(0.4, 0.65, 0.8)), c + Vector3(4.6, 0.15, 1.2), decor_root)
	_sign(c + Vector3(-5.6, 0, 4.9), "Jardim Comunitário")


func _sign(pos: Vector3, text: String) -> void:
	MaterialLib.mesh(MaterialLib.cylinder(0.05, 0.05, 1.1, 6), MaterialLib.toon(WOOD), pos + Vector3(0, 0.55, 0), decor_root)
	MaterialLib.mesh(MaterialLib.box(Vector3(1.4, 0.45, 0.06)), MaterialLib.toon(WOOD_LIGHT), pos + Vector3(0, 1.15, 0), decor_root)
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color(0.35, 0.22, 0.14)
	label.outline_size = 0
	label.position = pos + Vector3(0, 1.15, 0.04)
	decor_root.add_child(label)


func _build_house(house_id: String) -> void:
	var style: Dictionary = HOUSE_STYLES.get(house_id, HOUSE_STYLES["casa_jogadora"])
	var c := Places.house_pos(house_id)
	var door_dir := (Places.house_door(house_id) - c).normalized()
	var rot := atan2(door_dir.x, door_dir.z)
	var house := Node3D.new()
	house.name = house_id
	house.position = c
	house.rotation.y = rot
	decor_root.add_child(house)
	house_nodes[house_id] = house
	var wall := MaterialLib.toon(style["wall"])
	var roof := MaterialLib.toon(style["roof"])
	MaterialLib.mesh(MaterialLib.box(Vector3(4.6, 0.3, 4.6)), MaterialLib.toon(Color(0.75, 0.72, 0.68)), Vector3(0, 0.15, 0), house)
	MaterialLib.mesh(MaterialLib.box(Vector3(4.2, 2.6, 4.2)), wall, Vector3(0, 1.6, 0), house)
	var prism := PrismMesh.new()
	prism.size = Vector3(4.9, 1.9, 4.9)
	var roof_mi := MaterialLib.mesh(prism, roof, Vector3(0, 3.85, 0), house)
	roof_mi.rotation.y = PI / 2.0
	# Chaminé
	MaterialLib.mesh(MaterialLib.box(Vector3(0.5, 1.2, 0.5)), MaterialLib.toon(Color(0.7, 0.42, 0.35)), Vector3(1.1, 4.3, -0.9), house)
	# Porta e degrau
	MaterialLib.mesh(MaterialLib.box(Vector3(1.0, 1.7, 0.1)), MaterialLib.toon(WOOD), Vector3(0, 1.15, 2.12), house)
	MaterialLib.mesh(MaterialLib.sphere(0.06), MaterialLib.toon(Color(0.95, 0.8, 0.3)), Vector3(0.35, 1.15, 2.2), house)
	MaterialLib.mesh(MaterialLib.box(Vector3(1.6, 0.12, 0.7)), MaterialLib.toon(Color(0.75, 0.72, 0.68)), Vector3(0, 0.06, 2.6), house)
	# Janelas que acendem à noite
	for side in [-1, 1]:
		MaterialLib.mesh(MaterialLib.box(Vector3(0.85, 0.85, 0.08)), MaterialLib.toon(Color(0.98, 0.98, 0.95)), Vector3(1.3 * side, 1.9, 2.11), house)
		MaterialLib.mesh(MaterialLib.box(Vector3(0.68, 0.68, 0.1)), MaterialLib.window_glass(), Vector3(1.3 * side, 1.9, 2.12), house)
		MaterialLib.mesh(MaterialLib.box(Vector3(0.1, 0.68, 0.68)), MaterialLib.window_glass(), Vector3(2.12 * side, 1.9, 0.0), house)
	# Caixa de correio
	MaterialLib.mesh(MaterialLib.cylinder(0.04, 0.04, 0.9, 6), MaterialLib.toon(WOOD), Vector3(-1.9, 0.45, 3.0), house)
	MaterialLib.mesh(MaterialLib.box(Vector3(0.35, 0.28, 0.45)), roof, Vector3(-1.9, 1.0, 3.0), house)
	# Arbustos na frente
	for side in [-1, 1]:
		MaterialLib.mesh(MaterialLib.sphere(0.5, 0.75), MaterialLib.toon(GRASS_DARK.darkened(0.1)), Vector3(1.75 * side, 0.4, 2.55), house)
	# Placa com o nome
	var label := Label3D.new()
	label.text = Places.HOUSES[house_id]["label"]
	label.font_size = 48
	label.pixel_size = 0.005
	label.modulate = Color(0.35, 0.22, 0.14)
	label.outline_modulate = Color(1, 0.97, 0.9)
	label.outline_size = 10
	label.position = Vector3(0, 3.05, 2.2)
	house.add_child(label)
	_static_box(Vector3(4.4, 3.0, 4.4), c + Vector3(0, 1.5, 0), rot)


func _build_pois() -> void:
	# Quiosque de pães (Tobias)
	var q := Places.poi_pos("quiosque")
	var stall := Node3D.new()
	stall.position = q + Vector3(-1.4, 0, -1.0)
	stall.rotation.y = atan2(-stall.position.x, -stall.position.z)
	decor_root.add_child(stall)
	MaterialLib.mesh(MaterialLib.box(Vector3(2.4, 1.0, 0.9)), MaterialLib.toon(WOOD_LIGHT), Vector3(0, 0.5, 0), stall)
	for x in [-1.1, 1.1]:
		MaterialLib.mesh(MaterialLib.cylinder(0.05, 0.05, 2.3, 6), MaterialLib.toon(WOOD), Vector3(x, 1.15, -0.35), stall)
	var awning := MaterialLib.mesh(MaterialLib.box(Vector3(2.7, 0.08, 1.4)), MaterialLib.toon(Color(0.95, 0.5, 0.45)), Vector3(0, 2.3, 0.05), stall)
	awning.rotation.x = 0.25
	for i in range(4):
		MaterialLib.mesh(MaterialLib.sphere(0.13, 0.16), MaterialLib.toon(Color(0.88, 0.62, 0.32)), Vector3(-0.8 + i * 0.5, 1.07, 0.1), stall)
	_static_box(Vector3(2.4, 1.0, 0.9), stall.position + Vector3(0, 0.5, 0), stall.rotation.y)
	# Mural de recados (Pipa)
	var m := Places.poi_pos("mural") + Vector3(0.9, 0, 0.9)
	MaterialLib.mesh(MaterialLib.box(Vector3(1.6, 1.1, 0.1)), MaterialLib.toon(Color(0.75, 0.55, 0.38)), m + Vector3(0, 1.3, 0), decor_root).rotation.y = -PI / 4.0
	for x in [-0.6, 0.6]:
		MaterialLib.mesh(MaterialLib.cylinder(0.05, 0.05, 1.8, 6), MaterialLib.toon(WOOD), m + Vector3(x * 0.7, 0.9, -x * 0.7), decor_root)
	for i in range(4):
		var paper := MaterialLib.mesh(MaterialLib.box(Vector3(0.28, 0.32, 0.02)), MaterialLib.toon([Color(1, 1, 0.85), Color(0.85, 0.95, 1), Color(1, 0.88, 0.9)][i % 3]), m + Vector3(-0.35 + i * 0.25, 1.35 + (i % 2) * 0.15, 0) + Vector3(0.05, 0, 0.05), decor_root)
		paper.rotation.y = -PI / 4.0
	_static_box(Vector3(1.6, 1.8, 0.3), m + Vector3(0, 0.9, 0), -PI / 4.0)
	# Estante comunitária (Otávio)
	var e := Places.poi_pos("estante") + Vector3(-0.9, 0, 0.9)
	var shelf := Node3D.new()
	shelf.position = e
	shelf.rotation.y = PI / 4.0
	decor_root.add_child(shelf)
	MaterialLib.mesh(MaterialLib.box(Vector3(1.5, 1.8, 0.5)), MaterialLib.toon(WOOD), Vector3(0, 0.9, 0), shelf)
	var book_colors := [Color(0.8, 0.3, 0.3), Color(0.3, 0.5, 0.8), Color(0.9, 0.75, 0.3), Color(0.4, 0.7, 0.45)]
	for row in range(3):
		for i in range(6):
			MaterialLib.mesh(MaterialLib.box(Vector3(0.16, 0.38, 0.3)), MaterialLib.toon(book_colors[(row + i) % 4]), Vector3(-0.55 + i * 0.21, 0.35 + row * 0.55, 0.12), shelf)
	MaterialLib.mesh(MaterialLib.box(Vector3(1.8, 0.1, 0.8)), MaterialLib.toon(Color(0.3, 0.45, 0.6)), Vector3(0, 1.9, 0.1), shelf)
	_static_box(Vector3(1.5, 1.8, 0.5), e + Vector3(0, 0.9, 0), PI / 4.0)
	# Coreto (Bento)
	var g := Places.poi_pos("coreto")
	MaterialLib.mesh(MaterialLib.cylinder(2.6, 2.7, 0.18, 8), MaterialLib.toon(Color(0.95, 0.93, 0.88)), g + Vector3(0, 0.09, 0), decor_root)
	for i in range(8):
		var a := TAU * i / 8.0
		if i == 6:
			continue  # entrada voltada para a praça
		var pp := g + Vector3(cos(a), 0, sin(a)) * 2.35
		MaterialLib.mesh(MaterialLib.cylinder(0.08, 0.08, 2.4, 8), MaterialLib.toon(Color(0.98, 0.98, 0.98)), pp + Vector3(0, 1.3, 0), decor_root)
		_static_cylinder(0.12, 2.4, pp + Vector3(0, 1.2, 0))
	MaterialLib.mesh(MaterialLib.cylinder(0.2, 3.0, 1.2, 8), MaterialLib.toon(Color(0.35, 0.6, 0.3)), g + Vector3(0, 3.1, 0), decor_root)
	# Mirante (Otávio e Ravena)
	var mv := Places.poi_pos("mirante")
	MaterialLib.mesh(MaterialLib.cylinder(3.2, 3.3, 0.15, 10), MaterialLib.toon(WOOD_LIGHT), mv + Vector3(0, 0.08, 0), decor_root)
	var scope := Node3D.new()
	scope.position = mv + Vector3(1.4, 0, -1.4)
	decor_root.add_child(scope)
	for i in range(3):
		var leg := MaterialLib.mesh(MaterialLib.cylinder(0.03, 0.03, 1.3, 6), MaterialLib.toon(Color(0.3, 0.3, 0.32)), Vector3(cos(TAU * i / 3.0) * 0.25, 0.6, sin(TAU * i / 3.0) * 0.25), scope)
		leg.rotation = Vector3(sin(TAU * i / 3.0) * 0.3, 0, -cos(TAU * i / 3.0) * 0.3)
	var tube := MaterialLib.mesh(MaterialLib.cylinder(0.1, 0.14, 1.1, 12), MaterialLib.toon(Color(0.85, 0.7, 0.3)), Vector3(0, 1.4, 0), scope)
	tube.rotation = Vector3(-0.9, 0.6, 0)
	_static_cylinder(0.4, 1.6, scope.position + Vector3(0, 0.8, 0))
	var easel := Node3D.new()
	easel.position = mv + Vector3(-1.5, 0, -1.2)
	easel.rotation.y = 0.6
	decor_root.add_child(easel)
	MaterialLib.mesh(MaterialLib.box(Vector3(0.9, 0.7, 0.05)), MaterialLib.toon(Color(0.98, 0.98, 0.95)), Vector3(0, 1.3, 0), easel)
	MaterialLib.mesh(MaterialLib.box(Vector3(0.5, 0.3, 0.06)), MaterialLib.toon(Color(0.45, 0.65, 0.9)), Vector3(-0.1, 1.38, 0.01), easel)
	MaterialLib.mesh(MaterialLib.box(Vector3(0.4, 0.2, 0.06)), MaterialLib.toon(Color(0.5, 0.8, 0.45)), Vector3(0.15, 1.18, 0.01), easel)
	for x in [-0.35, 0.35]:
		MaterialLib.mesh(MaterialLib.cylinder(0.03, 0.03, 1.6, 6), MaterialLib.toon(WOOD), Vector3(x, 0.8, -0.05), easel)
	_static_cylinder(0.45, 1.6, easel.position + Vector3(0, 0.8, 0))
	_bench(mv + Vector3(0, 0, -2.4), PI)
	_sign(mv + Vector3(2.8, 0, 1.6), "Mirante")
	# Fogueira na praia
	var f := Places.poi_pos("fogueira")
	for i in range(5):
		var a2 := TAU * i / 5.0
		var log := MaterialLib.mesh(MaterialLib.cylinder(0.1, 0.1, 0.9, 8), MaterialLib.toon(WOOD), f + Vector3(cos(a2) * 0.25, 0.15, sin(a2) * 0.25), decor_root)
		log.rotation = Vector3(PI / 2.0, a2, 0.4)
	var flame := MaterialLib.mesh(MaterialLib.cylinder(0.0, 0.35, 0.8, 8), MaterialLib.toon(Color(1.0, 0.6, 0.2), 0.5, 1.2), f + Vector3(0, 0.55, 0), decor_root)
	flame.add_to_group("fire")
	var fl := OmniLight3D.new()
	fl.position = f + Vector3(0, 1.0, 0)
	fl.light_color = Color(1.0, 0.6, 0.3)
	fl.omni_range = 8.0
	fl.light_energy = 0.0
	decor_root.add_child(fl)
	fire_lights.append(fl)
	for i in range(4):
		var a3 := TAU * i / 4.0 + 0.4
		var seat := MaterialLib.mesh(MaterialLib.cylinder(0.25, 0.28, 0.45, 10), MaterialLib.toon(WOOD_LIGHT), f + Vector3(cos(a3), 0, sin(a3)) * 2.0 + Vector3(0, 0.2, 0), decor_root)
		seat.rotation.z = 0.0
	_static_cylinder(0.6, 1.0, f + Vector3(0, 0.3, 0))
	# Guarda-sol na praia sul (Marina)
	var ps := Places.poi_pos("praia_sul") + Vector3(2.0, 0, 0)
	MaterialLib.mesh(MaterialLib.cylinder(0.05, 0.05, 2.4, 6), MaterialLib.toon(Color(0.95, 0.95, 0.95)), ps + Vector3(0, 1.1, 0), decor_root)
	MaterialLib.mesh(MaterialLib.cylinder(0.05, 1.5, 0.5, 12), MaterialLib.toon(Color(0.25, 0.7, 0.72)), ps + Vector3(0, 2.3, 0), decor_root)
	MaterialLib.mesh(MaterialLib.box(Vector3(1.0, 0.05, 1.8)), MaterialLib.toon(Color(1.0, 0.8, 0.4)), ps + Vector3(1.2, -0.05, 0.5), decor_root)
	_static_cylinder(0.15, 2.4, ps + Vector3(0, 1.1, 0))
	# Cestos no pomar
	var po := Places.poi_pos("pomar")
	MaterialLib.mesh(MaterialLib.cylinder(0.35, 0.28, 0.4, 12), MaterialLib.toon(WOOD_LIGHT), po + Vector3(0.8, 0.2, 0.6), decor_root)
	_sign(po + Vector3(-1.5, 0, 2.2), "Pomar")


func _build_trees() -> void:
	var trunk_mat := MaterialLib.toon(Color(0.5, 0.34, 0.22))
	var greens := [Color(0.38, 0.7, 0.36), Color(0.45, 0.75, 0.4), Color(0.33, 0.62, 0.38), Color(0.5, 0.78, 0.36)]
	var i := 0
	for t in IslandLayout.generate()["trees"]:
		i += 1
		var p := Places.pos3(t["pos"])
		var s: float = t["scale"]
		var tree := Node3D.new()
		tree.position = p
		tree.rotation.y = float(i) * 1.7
		tree.scale = Vector3.ONE * s
		decor_root.add_child(tree)
		var green: Color = greens[i % greens.size()]
		match t["type"]:
			"pine":
				MaterialLib.mesh(MaterialLib.cylinder(0.16, 0.22, 1.2, 8), trunk_mat, Vector3(0, 0.6, 0), tree)
				var pine := green.darkened(0.15)
				for k in range(3):
					MaterialLib.mesh(MaterialLib.cylinder(0.0, 1.4 - k * 0.35, 1.5, 10), MaterialLib.toon(pine), Vector3(0, 1.6 + k * 0.85, 0), tree)
			"fruit":
				MaterialLib.mesh(MaterialLib.cylinder(0.16, 0.24, 1.5, 8), trunk_mat, Vector3(0, 0.75, 0), tree)
				MaterialLib.mesh(MaterialLib.sphere(1.3, 2.2), MaterialLib.toon(green), Vector3(0, 2.3, 0), tree)
				var fruit_color := ItemDB.color(t["fruit"])
				for k in range(7):
					var a := TAU * k / 7.0
					MaterialLib.mesh(MaterialLib.sphere(0.13), MaterialLib.toon(fruit_color), Vector3(cos(a) * 1.15, 2.1 + sin(a * 3.0) * 0.4, sin(a) * 1.15), tree)
			_:
				MaterialLib.mesh(MaterialLib.cylinder(0.18, 0.26, 1.6, 8), trunk_mat, Vector3(0, 0.8, 0), tree)
				MaterialLib.mesh(MaterialLib.sphere(1.25, 2.1), MaterialLib.toon(green), Vector3(0, 2.4, 0), tree)
				MaterialLib.mesh(MaterialLib.sphere(0.85, 1.4), MaterialLib.toon(green.lightened(0.08)), Vector3(0.55, 2.9, 0.3), tree)
				MaterialLib.mesh(MaterialLib.sphere(0.75, 1.2), MaterialLib.toon(green.darkened(0.06)), Vector3(-0.5, 2.7, -0.35), tree)
		_static_cylinder(0.32 * s, 2.0, p + Vector3(0, 1.0, 0))


func _build_ground_decor() -> void:
	# Tufos de grama e florzinhas decorativas com MultiMesh (barato para a GPU).
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var tuft := MaterialLib.cylinder(0.0, 0.09, 0.32, 5)
	var tuft_mm := MultiMesh.new()
	tuft_mm.transform_format = MultiMesh.TRANSFORM_3D
	tuft_mm.mesh = tuft
	var transforms := []
	var attempts := 0
	while transforms.size() < 700 and attempts < 6000:
		attempts += 1
		var r := sqrt(rng.randf()) * (Places.ISLAND_RADIUS - 1.5)
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * r
		if IslandLayout.distance_to_paths(p) < 1.4 or p.length() < 7.5:
			continue
		var xf := Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(p.x, 0.14, p.y))
		transforms.append(xf)
	tuft_mm.instance_count = transforms.size()
	for k in range(transforms.size()):
		tuft_mm.set_instance_transform(k, transforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = tuft_mm
	mmi.material_override = MaterialLib.toon(GRASS_DARK)
	decor_root.add_child(mmi)
	var colors := [Color(1.0, 0.95, 0.95), Color(1.0, 0.82, 0.35), Color(0.95, 0.6, 0.75), Color(0.7, 0.7, 1.0)]
	for ci in range(colors.size()):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = MaterialLib.sphere(0.07)
		var pts := []
		attempts = 0
		while pts.size() < 70 and attempts < 2000:
			attempts += 1
			var r2 := sqrt(rng.randf()) * (Places.ISLAND_RADIUS - 2.0)
			var a2 := rng.randf() * TAU
			var p2 := Vector2(cos(a2), sin(a2)) * r2
			if IslandLayout.distance_to_paths(p2) < 1.4 or p2.length() < 7.5:
				continue
			pts.append(Transform3D(Basis(), Vector3(p2.x, 0.12, p2.y)))
		mm.instance_count = pts.size()
		for k in range(pts.size()):
			mm.set_instance_transform(k, pts[k])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = MaterialLib.toon(colors[ci])
		decor_root.add_child(mi)
	# Pedras decorativas na praia
	for k in range(18):
		var a3 := rng.randf() * TAU
		var r3 := rng.randf_range(Places.ISLAND_RADIUS + 0.5, Places.WALK_RADIUS - 0.5)
		var s := rng.randf_range(0.2, 0.5)
		MaterialLib.mesh(MaterialLib.sphere(s, s * 1.3), MaterialLib.toon(Color(0.72, 0.7, 0.68)), Vector3(cos(a3) * r3, -0.05, sin(a3) * r3), decor_root)
