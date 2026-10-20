class_name ResourceNode
extends Node3D
## Recurso coletável (flor, concha, galho, fruta, pedra). O estado real fica
## em GameState.resources; este nó apenas o representa e permite a coleta.

var resource_id: String = ""
var _visual: Node3D
var _shown_item: String = ""


func setup(id: String) -> void:
	resource_id = id
	name = "Recurso_" + id
	add_to_group("interactable")
	add_to_group("resource_node")
	refresh()


func _state() -> Dictionary:
	return GameState.resources.get(resource_id, {})


func is_available() -> bool:
	return bool(_state().get("available", false))


func refresh() -> void:
	var st := _state()
	var item: String = st.get("item_id", "")
	if item != _shown_item:
		_shown_item = item
		if _visual:
			_visual.queue_free()
		_visual = _build_visual(st.get("kind", "flower"), item)
		add_child(_visual)
	visible = is_available()


func _build_visual(kind: String, item_id: String) -> Node3D:
	var v := Node3D.new()
	var c := ItemDB.color(item_id)
	match kind:
		"flower":
			MaterialLib.mesh(MaterialLib.cylinder(0.02, 0.02, 0.4, 5), MaterialLib.toon(Color(0.3, 0.6, 0.3)), Vector3(0, 0.2, 0), v)
			for i in range(5):
				var a := TAU * i / 5.0
				MaterialLib.mesh(MaterialLib.sphere(0.08), MaterialLib.toon(c), Vector3(cos(a) * 0.09, 0.42, sin(a) * 0.09), v)
			MaterialLib.mesh(MaterialLib.sphere(0.06), MaterialLib.toon(Color(1.0, 0.85, 0.3)), Vector3(0, 0.44, 0), v)
			MaterialLib.mesh(MaterialLib.sphere(0.1, 0.05), MaterialLib.toon(Color(0.35, 0.65, 0.3)), Vector3(0.08, 0.12, 0), v)
		"shell":
			var s := MaterialLib.mesh(MaterialLib.sphere(0.16, 0.12), MaterialLib.toon(c, 0.4), Vector3(0, 0.05, 0), v)
			s.scale = Vector3(1.0, 1.0, 0.8)
			if item_id == "estrela_do_mar":
				for i in range(5):
					var arm := MaterialLib.mesh(MaterialLib.capsule(0.05, 0.3), MaterialLib.toon(c), Vector3(cos(TAU * i / 5.0) * 0.12, 0.04, sin(TAU * i / 5.0) * 0.12), v)
					arm.rotation = Vector3(PI / 2.0, 0, -TAU * i / 5.0 + PI / 2.0)
		"branch":
			var b := MaterialLib.mesh(MaterialLib.cylinder(0.04, 0.05, 0.7, 6), MaterialLib.toon(c), Vector3(0, 0.05, 0), v)
			b.rotation = Vector3(PI / 2.0, 0.5, 0)
			var b2 := MaterialLib.mesh(MaterialLib.cylinder(0.025, 0.03, 0.3, 5), MaterialLib.toon(c), Vector3(0.1, 0.07, 0.1), v)
			b2.rotation = Vector3(PI / 2.0, -0.6, 0)
		"fruit":
			MaterialLib.mesh(MaterialLib.sphere(0.15), MaterialLib.toon(c), Vector3(0, 0.15, 0), v)
			MaterialLib.mesh(MaterialLib.sphere(0.06, 0.03), MaterialLib.toon(Color(0.3, 0.6, 0.3)), Vector3(0.05, 0.3, 0), v)
		"stone":
			var st := MaterialLib.mesh(MaterialLib.sphere(0.17, 0.12), MaterialLib.toon(c, 0.5), Vector3(0, 0.05, 0), v)
			st.scale = Vector3(1.2, 1.0, 0.9)
	# Brilho sutil para indicar que é coletável
	var spark := MaterialLib.mesh(MaterialLib.sphere(0.035), MaterialLib.toon(Color(1, 1, 0.85), 0.2, 2.0), Vector3(0.12, 0.55, 0.05), v)
	spark.name = "Spark"
	return v


func _process(delta: float) -> void:
	if visible and _visual:
		var spark := _visual.get_node_or_null("Spark")
		if spark:
			spark.position.y = 0.5 + sin(Time.get_ticks_msec() * 0.004 + position.x) * 0.06


func get_interaction_text() -> String:
	return "Pegar " + ItemDB.display_name(_shown_item)


func can_interact() -> bool:
	return is_available()


func interact(_player: Node) -> void:
	var result := GameState.collect_resource(resource_id)
	if result["ok"]:
		EventBus.toast_requested.emit("+1 %s" % ItemDB.display_name(result["item_id"]))
	else:
		EventBus.toast_requested.emit("Não foi possível pegar: %s" % result["reason"])
	refresh()
