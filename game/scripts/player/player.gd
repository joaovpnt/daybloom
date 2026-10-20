class_name Player
extends CharacterBody3D
## Jogadora: movimentação WASD relativa à câmera fixa, interação com E.

const SPEED := 4.6
const RUN_SPEED := 7.0
const ACCEL := 14.0
const INTERACT_RANGE := 2.4
const GRAVITY := 20.0

var visual: CharacterVisual
var input_enabled: bool = true
## Usado pelos testes para simular entrada sem teclado.
var debug_input: Vector2 = Vector2.ZERO
var current_target: Node = null
var _walk_phase := 0.0
var _scan_timer := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.5
	shape.shape = capsule
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)
	visual = CharacterVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.setup("characters/player")
	add_to_group("player")


func get_move_input() -> Vector2:
	if not input_enabled:
		return Vector2.ZERO
	if debug_input != Vector2.ZERO:
		return debug_input.limit_length(1.0)
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	return v.limit_length(1.0)


func _physics_process(delta: float) -> void:
	var input := get_move_input()
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	var target_vel := Vector3(input.x, 0, input.y) * (RUN_SPEED if running else SPEED)
	velocity.x = move_toward(velocity.x, target_vel.x, ACCEL * delta * SPEED)
	velocity.z = move_toward(velocity.z, target_vel.z, ACCEL * delta * SPEED)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		var target_rot := atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rot, minf(1.0, delta * 12.0))
	_animate(delta, flat.length())
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		_update_target()
	GameState.player_position = global_position
	GameState.player_rotation = rotation.y


func _animate(_delta: float, speed: float) -> void:
	if speed > 5.6:
		visual.play("run", clampf(speed / RUN_SPEED, 0.7, 1.3))
	elif speed > 0.3:
		visual.play("walk", clampf(speed / SPEED * 1.15, 0.6, 1.4))
	else:
		visual.play("idle")


func _update_target() -> void:
	var best: Node = null
	var best_score := INF
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	for node in get_tree().get_nodes_in_group("interactable"):
		var n3 := node as Node3D
		if n3 == null or not n3.is_visible_in_tree():
			continue
		if node.has_method("can_interact") and not node.can_interact():
			continue
		var to := n3.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > INTERACT_RANGE:
			continue
		var score := d - (fwd.dot(to.normalized()) * 0.8 if d > 0.01 else 0.0)
		if score < best_score:
			best_score = score
			best = node
	if best != current_target:
		current_target = best
		EventBus.interaction_prompt_changed.emit("" if best == null else "[E] " + best.get_interaction_text())


func try_interact() -> bool:
	if not input_enabled:
		return false
	_update_target()
	if current_target and is_instance_valid(current_target):
		if current_target is ResourceNode:
			visual.play_once("interact")
		current_target.interact(self)
		_update_target()
		return true
	return false


func set_talking(on: bool) -> void:
	visual.talking = false
	if on:
		visual.flash_expression("happy", 1.5)


func face_towards(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = atan2(d.x, d.z)
