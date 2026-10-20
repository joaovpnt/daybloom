class_name ModelLib
extends RefCounted
## Carrega e instancia os modelos .glb gerados no Blender (game/assets/models).
## Também adapta materiais especiais (janelas e lâmpadas que acendem à noite)
## usando materiais compartilhados, sem modificar os recursos importados.

const ROOT := "res://assets/models/"

static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _lamp_glass: StandardMaterial3D


static func path_for(rel: String) -> String:
	return ROOT + rel + ".glb"


static func exists(rel: String) -> bool:
	return ResourceLoader.exists(path_for(rel))


static func scene(rel: String) -> PackedScene:
	if not _scenes.has(rel):
		_scenes[rel] = load(path_for(rel))
	return _scenes[rel]


## Instancia um modelo e adapta seus materiais especiais.
static func instance(rel: String, shadows: bool = true) -> Node3D:
	var ps := scene(rel)
	assert(ps != null, "modelo ausente: %s" % rel)
	var node: Node3D = ps.instantiate()
	adapt_materials(node, shadows)
	return node


## Primeira malha do modelo (para MultiMesh de vegetação e itens repetidos).
static func mesh(rel: String) -> Mesh:
	if not _meshes.has(rel):
		var tmp := scene(rel).instantiate()
		var mi: MeshInstance3D = tmp.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes[rel] = mi.mesh
		tmp.free()
	return _meshes[rel]


static func lamp_glass() -> StandardMaterial3D:
	if _lamp_glass == null:
		_lamp_glass = StandardMaterial3D.new()
		_lamp_glass.albedo_color = Color(1.0, 0.94, 0.75)
		_lamp_glass.emission_enabled = true
		_lamp_glass.emission = Color(1.0, 0.82, 0.48)
		_lamp_glass.emission_energy_multiplier = 0.0
		_lamp_glass.roughness = 0.3
	return _lamp_glass


static func adapt_materials(root: Node, shadows: bool = true) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not shadows:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.mesh == null:
			continue
		for i in range(m.mesh.get_surface_count()):
			var mat := m.mesh.surface_get_material(i)
			if mat == null:
				continue
			match mat.resource_name:
				"DB_window":
					m.set_surface_override_material(i, MaterialLib.window_glass())
				"DB_lamp_glass":
					m.set_surface_override_material(i, lamp_glass())
