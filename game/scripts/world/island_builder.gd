class_name IslandBuilder
extends RefCounted
## Monta a ilha 0.2 com os modelos criados no Blender: terreno com elevações,
## trilhas orgânicas, praça, bairros, comércio, lago, bosque, pomar, mirante,
## praia e área de lazer. Toda geometria sólida fica sob a NavigationRegion3D
## para gerar o navmesh; volumes de oclusão da câmera ficam na camada 4.

const LAYER_WORLD := 1
const LAYER_CAMERA_OCCLUDER := 8

const PATH_COLOR := Color(0.80, 0.66, 0.47)
const PATH_EDGE := Color(0.66, 0.66, 0.42)
const PLAZA_STONE := Color(0.84, 0.80, 0.73)
const PLAZA_STONE_DARK := Color(0.74, 0.70, 0.64)

var root: Node3D
var nav_region: NavigationRegion3D
var static_root: Node3D
var decor_root: Node3D
var lamps: Array = []
var fire_lights: Array = []
var house_nodes: Dictionary = {}
var occluders: Array = []


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
	_build_terrain()
	_build_water()
	_build_boundary()
	_build_paths()
	_build_plaza()
	_build_pond()
	_build_garden()
	for house_id in Places.HOUSES:
		_build_house(house_id)
	_build_pois()
	_build_vegetation()
	_build_lamps()


func _make_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = LAYER_WORLD
	nm.agent_radius = 0.5
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 35.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.region_min_size = 4.0
	nm.filter_baking_aabb = AABB(Vector3(-56, -1.5, -56), Vector3(112, 4.2, 112))
	return nm


# --- utilidades -------------------------------------------------------------

func _place(rel: String, p: Vector2, rot: float = 0.0, scale: float = 1.0, parent: Node = null, shadows: bool = true) -> Node3D:
	var node := ModelLib.instance(rel, shadows)
	(parent if parent else decor_root).add_child(node)
	node.position = Places.pos3(p)
	node.rotation.y = rot
	node.scale = Vector3.ONE * scale
	return node


func _body(shape: Shape3D, pos: Vector3, rot_y: float = 0.0, layer: int = LAYER_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	static_root.add_child(body)
	body.position = pos
	body.rotation.y = rot_y
	return body


## Obstáculos são altos (6 m) para que seus topos fiquem acima da faixa de
## geração do navmesh: assim nenhum morador "anda" sobre a fonte ou uma mesa.
const BLOCKER_HEIGHT := 6.0


func _box_collider(size: Vector3, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var s := BoxShape3D.new()
	var bottom := pos.y - size.y / 2.0
	s.size = Vector3(size.x, maxf(size.y, BLOCKER_HEIGHT), size.z)
	return _body(s, Vector3(pos.x, bottom + s.size.y / 2.0, pos.z), rot_y)


func _cyl_collider(radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var s := CylinderShape3D.new()
	var bottom := pos.y - height / 2.0
	s.radius = radius
	s.height = maxf(height, BLOCKER_HEIGHT)
	return _body(s, Vector3(pos.x, bottom + s.height / 2.0, pos.z))


## Volume (camada 4) que a câmera usa para detectar objetos na frente da jogadora.
func _occluder(shape: Shape3D, pos: Vector3, visual: Node3D, rot_y: float = 0.0) -> void:
	var body := _body(shape, pos, rot_y, LAYER_CAMERA_OCCLUDER)
	body.set_meta("visual", visual)
	occluders.append(body)


# --- terreno e água ----------------------------------------------------------

func _build_terrain() -> void:
	var mesh := IslandTerrain.build_mesh()
	var mi := MeshInstance3D.new()
	mi.name = "Terreno"
	mi.mesh = mesh
	mi.material_override = IslandTerrain.material()
	decor_root.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "TerrenoColisao"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	static_root.add_child(body)


func _build_water() -> void:
	var ocean := PlaneMesh.new()
	ocean.size = Vector2(440, 440)
	ocean.subdivide_width = 90
	ocean.subdivide_depth = 90
	var mi := MaterialLib.mesh(ocean, MaterialLib.water(), Vector3(0, -0.4, 0), decor_root)
	mi.name = "Oceano"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group("water")


func _build_boundary() -> void:
	var count := 72
	for i in range(count):
		var a := TAU * i / count
		var pos := Vector3(cos(a), 0, sin(a)) * (Places.WALK_RADIUS + 0.8)
		var body := _box_collider(Vector3(4.6, 3.0, 1.0), pos + Vector3(0, 0.6, 0))
		body.look_at_from_position(body.position, Vector3(0, body.position.y, 0), Vector3.UP)


# --- trilhas -------------------------------------------------------------------

func _build_paths() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.18
	var st_edge := SurfaceTool.new()
	st_edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_core := SurfaceTool.new()
	st_core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var all := IslandLayout.paths()
	for pi in range(all.size()):
		var pts: Array = all[pi]
		var core_w := 1.0 if pi == 0 else 0.95
		_ribbon(st_edge, pts, core_w + 0.55, 0.014, PATH_EDGE, noise, 0.25)
		_ribbon(st_core, pts, core_w, 0.026, PATH_COLOR, noise, 0.18)
		# Pedrinhas e flores à beira da trilha
		for i in range(1, pts.size() - 1, 3):
			var p: Vector2 = pts[i]
			var d: Vector2 = ((pts[i + 1] as Vector2) - (pts[i - 1] as Vector2)).normalized()
			var n := Vector2(d.y, -d.x) * (1.0 if i % 2 == 0 else -1.0)
			var q := p + n * rng.randf_range(1.35, 1.7)
			if rng.randf() < 0.55:
				var pebble := _place("environment/rock_c", q, rng.randf() * TAU, rng.randf_range(0.25, 0.45), null, false)
				pebble.name = "Pedrinha"
	for pair in [[st_edge, PATH_EDGE], [st_core, PATH_COLOR]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Trilhas"
		decor_root.add_child(mi)


func _ribbon(st: SurfaceTool, pts: Array, half_w: float, lift: float, color: Color, noise: FastNoiseLite, wobble: float) -> void:
	var left := []
	var right := []
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		var a: Vector2 = pts[max(i - 1, 0)]
		var b: Vector2 = pts[min(i + 1, pts.size() - 1)]
		var d := (b - a).normalized()
		var n := Vector2(d.y, -d.x)
		var wl := half_w * (1.0 + noise.get_noise_2d(p.x, p.y) * wobble * 2.0)
		var wr := half_w * (1.0 + noise.get_noise_2d(p.x + 100.0, p.y) * wobble * 2.0)
		var l := p + n * wl
		var r := p - n * wr
		left.append(Vector3(l.x, IslandTerrain.height(l.x, l.y) + lift, l.y))
		right.append(Vector3(r.x, IslandTerrain.height(r.x, r.y) + lift, r.y))
	for i in range(pts.size() - 1):
		var c := color.lerp(color.darkened(0.08), (noise.get_noise_1d(i * 3.0) + 1.0) * 0.5)
		for v in [left[i], right[i + 1], right[i], left[i], left[i + 1], right[i + 1]]:
			st.set_color(c)
			st.add_vertex(v)


# --- praça ---------------------------------------------------------------------

func _build_plaza() -> void:
	var outer := MaterialLib.mesh(MaterialLib.cylinder(7.0, 7.1, 0.08, 48), MaterialLib.toon(PLAZA_STONE_DARK), Vector3(0, 0.02, 0), decor_root)
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var inner := MaterialLib.mesh(MaterialLib.cylinder(6.4, 6.4, 0.09, 48), MaterialLib.toon(PLAZA_STONE), Vector3(0, 0.025, 0), decor_root)
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Anel decorativo de pedras
	for i in range(36):
		var a := TAU * i / 36.0
		var tile := MaterialLib.mesh(MaterialLib.box(Vector3(0.55, 0.02, 0.3)), MaterialLib.toon(PLAZA_STONE_DARK), Vector3(cos(a) * 4.2, 0.075, sin(a) * 4.2), decor_root)
		tile.rotation.y = -a
	var fountain := _place("props/fountain", Vector2.ZERO)
	_cyl_collider(1.9, 1.6, Vector3(0, 0.8, 0))
	var water := MaterialLib.mesh(MaterialLib.cylinder(1.5, 1.5, 0.04, 28), MaterialLib.water(), Vector3(0, 0.5, 0), decor_root)
	water.add_to_group("water")
	for spec in [[Places.POIS["banco_praca"]["pos"], 0.0], [Vector2(-4.4, 4.2), 0.0], [Vector2(-3.6, -5.2), 0.0], [Vector2(5.4, -3.0), 0.0]]:
		var p: Vector2 = spec[0]
		var rot := atan2(-p.x, -p.y)
		_place("props/bench", p, rot)
		_box_collider(Vector3(1.8, 0.9, 0.7), Places.pos3(p) + Vector3(0, 0.45, 0), rot)
	for i in range(6):
		var a2 := TAU * i / 6.0 + 0.3
		_place("props/flower_pot", Vector2(cos(a2), sin(a2)) * 3.0, a2, 0.9, null, false)


# --- lago --------------------------------------------------------------------

func _build_pond() -> void:
	var center := Places.poi_pos("lago")
	var r: float = Places.POIS["lago"]["radius"]
	var water := MaterialLib.mesh(MaterialLib.cylinder(r + 0.4, r + 0.4, 0.04, 48), MaterialLib.pond_water(), Vector3(center.x, -0.12, center.z), decor_root)
	water.add_to_group("water")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cyl_collider(r + 0.2, 2.0, Vector3(center.x, 0.5, center.z))
	var dock_pos: Vector2 = Places.POIS["doca"]["pos"]
	var lake_c: Vector2 = Places.POIS["lago"]["pos"]
	var dir := (lake_c - dock_pos).normalized()
	_place("props/dock", dock_pos + dir * 0.9, atan2(-dir.x, -dir.y) + PI, 1.0, null, false)
	for spec in IslandLayout.generate()["pads"]:
		var pad := _place("environment/" + spec["model"], spec["pos"], spec["rot"], spec["scale"], null, false)
		pad.position.y = -0.09


# --- jardim comunitário --------------------------------------------------------

func _build_garden() -> void:
	var c := Places.poi_pos("jardim")
	var soil := MaterialLib.toon(Color(0.52, 0.36, 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var flowers := ["flowers_margarida_cluster", "flowers_tulipa_coral_cluster", "flowers_campanula_cluster", "flowers_girassol_cluster"]
	for row in range(2):
		for col in range(3):
			var p := c + Vector3(-3.0 + col * 3.0, 0, -1.6 + row * 3.0)
			MaterialLib.mesh(MaterialLib.box(Vector3(2.2, 0.28, 1.4)), MaterialLib.toon(Color(0.62, 0.44, 0.3)), p + Vector3(0, 0.14, 0), decor_root)
			MaterialLib.mesh(MaterialLib.box(Vector3(2.0, 0.3, 1.2)), soil, p + Vector3(0, 0.15, 0), decor_root)
			for k in range(3):
				var fp := Vector2(p.x - 0.65 + k * 0.65, p.z + rng.randf_range(-0.2, 0.2))
				var f := _place("environment/" + flowers[(row * 3 + col + k) % 4], fp, rng.randf() * TAU, 0.75, null, false)
				f.position.y = 0.3
	for i in range(8):
		var a := TAU * i / 8.0
		if i == 2:
			continue  # entrada voltada para a trilha
		var fp2 := Vector2(c.x, c.z) + Vector2(cos(a), sin(a)) * 5.2
		_place("props/fence_segment", fp2, -a + PI / 2.0, 1.0, null, false)
	_place("props/signpost", Vector2(c.x, c.z) + Vector2(4.6, 3.2), 0.4)


# --- casas ---------------------------------------------------------------------

func _build_house(house_id: String) -> void:
	var c2: Vector2 = Places.HOUSES[house_id]["pos"]
	var rot := Places.house_rotation(house_id)
	var house := _place("buildings/" + house_id, c2, rot)
	house.name = house_id
	house_nodes[house_id] = house
	var c := Places.house_pos(house_id)
	_box_collider(Vector3(5.0, 3.0, 5.0), c + Vector3(0, 1.5, 0), rot)
	var occ := BoxShape3D.new()
	occ.size = Vector3(5.4, 6.0, 5.4)
	_occluder(occ, c + Vector3(0, 3.0, 0), house, rot)
	var label := Label3D.new()
	label.text = Places.HOUSES[house_id]["label"]
	label.font = UiTheme.font_bold()
	label.font_size = 44
	label.pixel_size = 0.0045
	label.modulate = Color(0.35, 0.22, 0.14)
	label.outline_modulate = Color(1, 0.97, 0.9)
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.visibility_range_end = 16.0
	var door := Places.house_door(house_id)
	label.position = door + Vector3(0, 3.2, 0) - Vector3(Places.house_facing(house_id).x, 0, Places.house_facing(house_id).y) * 1.2
	decor_root.add_child(label)


# --- pontos de interesse ------------------------------------------------------

func _face_plaza(p: Vector2) -> float:
	return atan2(-p.x, -p.y)


func _build_pois() -> void:
	# Comércio: quiosque, barris, caixotes
	var q: Vector2 = Places.POIS["quiosque"]["pos"]
	var q_back := q + Vector2(1.4, -1.0)
	var qrot := _face_plaza(q_back)
	_place("props/market_stall", q_back, qrot)
	_box_collider(Vector3(2.6, 1.2, 1.1), Places.pos3(q_back) + Vector3(0, 0.6, 0), qrot)
	_place("props/barrel", q + Vector2(3.0, 0.4), 0.3)
	_place("props/crate", q + Vector2(2.6, -2.4), 0.8)
	_place("props/crate", q + Vector2(3.3, -1.7), 0.2, 0.8)
	_cyl_collider(0.4, 1.0, Places.pos3(q + Vector2(3.0, 0.4)) + Vector3(0, 0.5, 0))
	# Mural de recados
	var m: Vector2 = Places.POIS["mural"]["pos"] + Vector2(-0.8, -1.0)
	_place("props/notice_board", m, _face_plaza(m))
	_box_collider(Vector3(1.8, 2.0, 0.4), Places.pos3(m) + Vector3(0, 1.0, 0), _face_plaza(m))
	# Estante comunitária
	var e: Vector2 = Places.POIS["estante"]["pos"] + Vector2(-1.0, 0.8)
	_place("props/bookshelf", e, _face_plaza(e))
	_box_collider(Vector3(1.6, 2.0, 0.6), Places.pos3(e) + Vector3(0, 1.0, 0), _face_plaza(e))
	_place("props/flower_pot", e + Vector2(1.3, 0.5), 0.0, 0.9, null, false)
	# Coreto (entrada voltada para a praça)
	var g: Vector2 = Places.POIS["coreto"]["pos"]
	var grot := _face_plaza(g)
	var gazebo := _place("props/gazebo", g, grot)
	var occ := SphereShape3D.new()
	occ.radius = 2.8
	_occluder(occ, Places.pos3(g) + Vector3(0, 3.0, 0), gazebo)
	for k in range(8):
		if k == 6:
			continue
		var a := k * TAU / 8.0 + TAU / 16.0
		var local := Vector3(cos(a) * 2.35, 0, -sin(a) * 2.35)
		_cyl_collider(0.14, 2.4, Places.pos3(g) + local.rotated(Vector3.UP, grot) + Vector3(0, 1.2, 0))
	# Mirante sobre a elevação
	var mv: Vector2 = Places.POIS["mirante"]["pos"]
	MaterialLib.mesh(MaterialLib.cylinder(3.2, 3.3, 0.16, 10), MaterialLib.toon(Color(0.82, 0.64, 0.44)), Places.pos3(mv) + Vector3(0, 0.06, 0), decor_root)
	_place("props/telescope", mv + Vector2(1.3, -1.5), 0.6)
	_cyl_collider(0.45, 1.6, Places.pos3(mv + Vector2(1.3, -1.5)) + Vector3(0, 0.8, 0))
	_place("props/easel", mv + Vector2(-1.6, -1.2), -0.5)
	_cyl_collider(0.45, 1.6, Places.pos3(mv + Vector2(-1.6, -1.2)) + Vector3(0, 0.8, 0))
	_place("props/bench", mv + Vector2(0, -2.6), 0.0)
	_box_collider(Vector3(1.8, 0.9, 0.7), Places.pos3(mv + Vector2(0, -2.6)) + Vector3(0, 0.45, 0))
	_place("props/signpost", mv + Vector2(3.2, 2.0), -0.6)
	# Parque (área de lazer)
	var pk: Vector2 = Places.POIS["parque"]["pos"]
	_place("props/picnic_table", pk + Vector2(-1.8, 0.5), 0.3)
	_box_collider(Vector3(1.9, 0.9, 1.6), Places.pos3(pk + Vector2(-1.8, 0.5)) + Vector3(0, 0.45, 0), 0.3)
	_place("props/picnic_table", pk + Vector2(2.4, 1.6), -0.4)
	_box_collider(Vector3(1.9, 0.9, 1.6), Places.pos3(pk + Vector2(2.4, 1.6)) + Vector3(0, 0.45, 0), -0.4)
	var sw := pk + Vector2(0.5, 4.6)
	_place("props/swing", sw, 0.1)
	for sx in [-1.0, 1.0]:
		_cyl_collider(0.15, 2.2, Places.pos3(sw + Vector2(sx * 1.0, 0).rotated(-0.1)) + Vector3(0, 1.1, 0))
	_place("props/flower_pot", pk + Vector2(-3.8, -1.8), 0.0, 1.0, null, false)
	_place("props/flower_pot", pk + Vector2(4.0, -1.0), 0.0, 1.0, null, false)
	# Fogueira na praia
	var f: Vector2 = Places.POIS["fogueira"]["pos"]
	_place("props/campfire", f, 0.0)
	_cyl_collider(0.7, 1.0, Places.pos3(f) + Vector3(0, 0.3, 0))
	var fl := OmniLight3D.new()
	fl.position = Places.pos3(f) + Vector3(0, 1.0, 0)
	fl.light_color = Color(1.0, 0.6, 0.3)
	fl.omni_range = 9.0
	fl.light_energy = 0.0
	decor_root.add_child(fl)
	fire_lights.append(fl)
	for i in range(4):
		var a2 := TAU * i / 4.0 + 0.4
		_place("environment/log", f + Vector2(cos(a2), sin(a2)) * 2.2, -a2, 0.8)
	# Praia sul: guarda-sol
	var ps: Vector2 = Places.POIS["praia_sul"]["pos"] + Vector2(2.5, 0.5)
	_place("props/beach_umbrella", ps, 0.3)
	_cyl_collider(0.15, 2.4, Places.pos3(ps) + Vector3(0, 1.2, 0))
	# Pomar: cesto e placa
	var po: Vector2 = Places.POIS["pomar"]["pos"]
	_place("props/barrel", po + Vector2(4.6, 3.6), 0.0, 0.8)
	_place("props/signpost", po + Vector2(4.0, -3.8), 1.2)


# --- vegetação -----------------------------------------------------------------

func _build_vegetation() -> void:
	var layout := IslandLayout.generate()
	for t in layout["trees"]:
		var node := _place("environment/" + t["model"], t["pos"], t["rot"], t["scale"])
		var s: float = t["scale"]
		_cyl_collider(0.32 * s, 2.0, Places.pos3(t["pos"]) + Vector3(0, 1.0, 0))
		var occ := SphereShape3D.new()
		occ.radius = 1.45 * s
		_occluder(occ, Places.pos3(t["pos"]) + Vector3(0, 2.6 * s, 0), node)
	for bsh in layout["bushes"]:
		var bn := _place("environment/" + bsh["model"], bsh["pos"], bsh["rot"], bsh["scale"])
		_cyl_collider(0.45 * float(bsh["scale"]), 1.0, Places.pos3(bsh["pos"]) + Vector3(0, 0.5, 0))
	for d in layout["decor"]:
		var small: bool = String(d["model"]).begins_with("flowers") or d["model"] in ["fern", "mushrooms"]
		_place("environment/" + d["model"], d["pos"], d["rot"], d["scale"], null, not small)
		if d["model"] in ["rock_b", "stump", "log"] and not d.get("beach", false):
			_cyl_collider(0.45 * float(d["scale"]), 0.8, Places.pos3(d["pos"]) + Vector3(0, 0.3, 0))
	_multimesh(layout["tufts"])
	_multimesh(layout["small_flowers"])


## Agrupa itens pequenos repetidos em MultiMesh (poucas chamadas de desenho).
func _multimesh(items: Array) -> void:
	var by_model := {}
	for it in items:
		if not by_model.has(it["model"]):
			by_model[it["model"]] = []
		by_model[it["model"]].append(it)
	for model in by_model:
		var list: Array = by_model[model]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ModelLib.mesh("environment/" + model)
		mm.instance_count = list.size()
		for i in range(list.size()):
			var it: Dictionary = list[i]
			var p := Places.pos3(it["pos"])
			var b := Basis().rotated(Vector3.UP, it["rot"]).scaled(Vector3.ONE * float(it["scale"]))
			mm.set_instance_transform(i, Transform3D(b, p))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + model
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decor_root.add_child(mmi)


# --- iluminação pública -----------------------------------------------------

func _build_lamps() -> void:
	var spots: Array = IslandLayout.generate()["lamps"].duplicate()
	for i in range(4):
		var a := TAU * i / 4.0 + PI / 4.0
		spots.append({"pos": Vector2(cos(a), sin(a)) * 6.6})
	for spec in spots:
		var p: Vector2 = spec["pos"]
		_place("props/lamp_post", p, atan2(p.x, p.y))
		_cyl_collider(0.18, 2.6, Places.pos3(p) + Vector3(0, 1.3, 0))
		var light := OmniLight3D.new()
		var dir := -Vector2(p.x, p.y).normalized() if p.length() > 0.1 else Vector2(0, 1)
		light.position = Places.pos3(p) + Vector3(0, 2.45, 0)
		light.light_color = Color(1.0, 0.8, 0.52)
		light.omni_range = 8.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		decor_root.add_child(light)
		lamps.append(light)
