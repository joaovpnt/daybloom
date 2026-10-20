class_name CameraRig
extends Camera3D
## Câmera elevada em terceira pessoa (ângulo fixo, seguimento suave e zoom).
## Objetos entre a câmera e a jogadora (árvores, casas, coreto) ficam
## translúcidos temporariamente, usando a transparência por instância — os
## materiais compartilhados nunca são alterados.

const OFFSET := Vector3(0, 10.0, 11.0)
const ZOOM_MIN := 0.6
const ZOOM_MAX := 1.6
const OCCLUDER_MASK := 8
const FADE_ALPHA := 0.72
const FADE_SPEED := 6.0
const RELEASE_DELAY := 0.35

var target: Node3D
var zoom: float = 1.0
var _zoom_target: float = 1.0
var _focus := Vector3.ZERO
var _scan_timer := 0.0
## visual (Node3D) -> {"alpha": float, "last_hit": float}
var faded: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	fov = 40.0
	near = 0.3
	far = 320.0
	current = true
	_zoom_target = zoom
	if target:
		_focus = target.global_position
		_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = clampf(_zoom_target - 0.1, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = clampf(_zoom_target + 0.1, ZOOM_MIN, ZOOM_MAX)


func set_zoom_immediate(z: float) -> void:
	zoom = clampf(z, ZOOM_MIN, ZOOM_MAX * 1.5)
	_zoom_target = zoom


func _process(delta: float) -> void:
	_time += delta
	if target == null or not is_instance_valid(target):
		return
	if absf(zoom - _zoom_target) > 0.001:
		zoom = lerpf(zoom, _zoom_target, minf(1.0, delta * 8.0))
	# Seguimento suave com leve antecipação do movimento
	var lead := Vector3.ZERO
	if target is CharacterBody3D:
		var v: Vector3 = (target as CharacterBody3D).velocity
		lead = Vector3(v.x, 0, v.z) * 0.25
	_focus = _focus.lerp(target.global_position + lead, minf(1.0, delta * 5.0))
	_apply()
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.08
		_scan_occluders()
	_update_fades(delta)


func snap() -> void:
	if target:
		_focus = target.global_position
		zoom = _zoom_target if _zoom_target > 0 else zoom
		_apply()


func _apply() -> void:
	global_position = _focus + OFFSET * zoom
	look_at(_focus + Vector3(0, 0.9, 0), Vector3.UP)


## Lança raios da câmera até a cabeça e os pés da jogadora.
func _scan_occluders() -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	var space := get_world_3d().direct_space_state
	var head := target.global_position + Vector3(0, 1.3, 0)
	var feet := target.global_position + Vector3(0, 0.3, 0)
	for to in [head, feet, target.global_position + Vector3(0, 0.8, 0)]:
		var exclude: Array[RID] = []
		for i in range(4):
			var q := PhysicsRayQueryParameters3D.create(global_position, to, OCCLUDER_MASK, exclude)
			q.collide_with_areas = false
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var body: Object = hit["collider"]
			exclude.append(hit["rid"])
			if body and body.has_meta("visual"):
				var visual: Node3D = body.get_meta("visual")
				if is_instance_valid(visual):
					if not faded.has(visual):
						faded[visual] = {"alpha": 0.0, "last_hit": _time}
					faded[visual]["last_hit"] = _time


func _update_fades(delta: float) -> void:
	for visual in faded.keys():
		if not is_instance_valid(visual):
			faded.erase(visual)
			continue
		var st: Dictionary = faded[visual]
		var want := FADE_ALPHA if _time - float(st["last_hit"]) < RELEASE_DELAY else 0.0
		var a: float = move_toward(float(st["alpha"]), want, delta * FADE_SPEED * FADE_ALPHA)
		if a != float(st["alpha"]):
			st["alpha"] = a
			_set_transparency(visual, a)
		if a <= 0.0 and want <= 0.0:
			_set_transparency(visual, 0.0)
			faded.erase(visual)


static func _set_transparency(visual: Node3D, a: float) -> void:
	for gi in visual.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).transparency = a
	if visual is GeometryInstance3D:
		(visual as GeometryInstance3D).transparency = a


func is_faded(visual: Node3D) -> bool:
	return faded.has(visual) and float(faded[visual]["alpha"]) > 0.05
