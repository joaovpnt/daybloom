class_name CameraRig
extends Camera3D
## Câmera elevada em terceira pessoa, no estilo dos simuladores de vida:
## ângulo fixo, segue a jogadora com suavidade e permite zoom pela roda do mouse.

const OFFSET := Vector3(0, 10.5, 11.5)

var target: Node3D
var zoom: float = 1.0
var _focus := Vector3.ZERO


func _ready() -> void:
	fov = 42.0
	near = 0.3
	far = 300.0
	current = true
	if target:
		_focus = target.global_position
		_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.08, 0.55, 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.08, 0.55, 1.5)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_focus = _focus.lerp(target.global_position, minf(1.0, delta * 6.0))
	_apply()


func snap() -> void:
	if target:
		_focus = target.global_position
		_apply()


func _apply() -> void:
	global_position = _focus + OFFSET * zoom
	look_at(_focus + Vector3(0, 0.9, 0), Vector3.UP)
