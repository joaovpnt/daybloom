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


static func model_for(kind: String, item_id: String) -> String:
	match kind:
		"flower":
			return "environment/flower_%s" % item_id
		"shell":
			return "props/item_starfish" if item_id == "estrela_do_mar" else "props/item_shell"
		"branch":
			return "props/item_branch"
		"fruit":
			return "props/item_%s" % item_id
		"stone":
			return "props/item_stone"
	return "props/item_stone"


func _build_visual(kind: String, item_id: String) -> Node3D:
	var v := Node3D.new()
	var model := ModelLib.instance(model_for(kind, item_id), false)
	model.scale = Vector3.ONE * (1.25 if kind == "flower" else 1.6)
	v.add_child(model)
	# Brilho sutil para indicar que é coletável
	var spark := MaterialLib.mesh(MaterialLib.sphere(0.04), MaterialLib.toon(Color(1, 1, 0.85), 0.2, 2.0), Vector3(0.14, 0.62, 0.05), v)
	spark.name = "Spark"
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
