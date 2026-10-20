class_name CharacterVisual
extends Node3D
## Visual de um personagem importado do Blender: animações (AnimationPlayer),
## expressões faciais (malhas Eyes_* e Mouth_*), piscar e boca falando.

const LOOPING := ["idle", "walk", "run", "talk", "sad"]
const EXPRESSIONS := {
	"neutral": ["Eyes_Open", "Mouth_Smile"],
	"happy": ["Eyes_Happy", "Mouth_Open"],
	"sad": ["Eyes_Sad", "Mouth_Frown"],
	"surprised": ["Eyes_Open", "Mouth_Open"],
	"angry": ["Eyes_Sad", "Mouth_Frown"],
	"sleep": ["Eyes_Closed", "Mouth_Smile"],
	"tired": ["Eyes_Closed", "Mouth_Frown"],
}

var model: Node3D
var anim: AnimationPlayer
var parts: Dictionary = {}
var expression: String = "neutral"
var talking: bool = false
var current_anim: String = ""
var _one_shot: String = ""
var _blink_timer := 2.0
var _blinking := 0.0
var _mouth_timer := 0.0
var _mouth_open := false
var _expr_timer := 0.0
var _base_expression := "neutral"


func setup(model_rel: String) -> void:
	model = ModelLib.instance(model_rel)
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		parts[String(mi.name)] = mi
	if anim:
		for a in LOOPING:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		anim.animation_finished.connect(_on_anim_finished)
	_apply_expression()
	play("idle")


func has_animation(name_: String) -> bool:
	return anim != null and anim.has_animation(name_)


## Toca uma animação em loop (ignorada enquanto uma animação única estiver ativa).
func play(name_: String, speed: float = 1.0) -> void:
	if anim == null or not anim.has_animation(name_):
		return
	if _one_shot != "":
		return
	if current_anim != name_:
		anim.play(name_, 0.2, speed)
		current_anim = name_
	else:
		anim.speed_scale = speed


## Toca uma animação única (reação) e depois volta ao ciclo normal.
func play_once(name_: String) -> void:
	if anim == null or not anim.has_animation(name_):
		return
	_one_shot = name_
	current_anim = name_
	anim.play(name_, 0.12)
	anim.speed_scale = 1.0


func _on_anim_finished(name_: StringName) -> void:
	if String(name_) == _one_shot:
		_one_shot = ""
		current_anim = ""
		play("idle")


func is_reacting() -> bool:
	return _one_shot != ""


## Expressão de base (ligada ao humor) e expressões temporárias (reações).
func set_base_expression(e: String) -> void:
	_base_expression = e if EXPRESSIONS.has(e) else "neutral"
	if _expr_timer <= 0.0:
		expression = _base_expression
		_apply_expression()


func flash_expression(e: String, seconds: float) -> void:
	expression = e if EXPRESSIONS.has(e) else "neutral"
	_expr_timer = seconds
	_apply_expression()


func _apply_expression() -> void:
	var shown: Array = EXPRESSIONS.get(expression, EXPRESSIONS["neutral"]).duplicate()
	if _blinking > 0.0 and shown[0] == "Eyes_Open":
		shown[0] = "Eyes_Closed"
	if talking and expression in ["neutral", "happy", "surprised"]:
		shown[1] = "Mouth_Open" if _mouth_open else "Mouth_Smile"
	for key in parts:
		var k: String = key
		if k.begins_with("Eyes_") or k.begins_with("Mouth_"):
			(parts[k] as MeshInstance3D).visible = shown.has(k)


func _process(delta: float) -> void:
	var dirty := false
	if _expr_timer > 0.0:
		_expr_timer -= delta
		if _expr_timer <= 0.0:
			expression = _base_expression
			dirty = true
	_blink_timer -= delta
	if _blink_timer <= 0.0 and _blinking <= 0.0:
		_blinking = 0.12
		_blink_timer = randf_range(2.0, 5.0)
		dirty = true
	elif _blinking > 0.0:
		_blinking -= delta
		if _blinking <= 0.0:
			dirty = true
	if talking:
		_mouth_timer -= delta
		if _mouth_timer <= 0.0:
			_mouth_timer = randf_range(0.08, 0.18)
			_mouth_open = not _mouth_open
			dirty = true
	elif _mouth_open:
		_mouth_open = false
		dirty = true
	if dirty:
		_apply_expression()


func visible_expression_parts() -> Array:
	var out := []
	for key in parts:
		if (parts[key] as MeshInstance3D).visible and (String(key).begins_with("Eyes_") or String(key).begins_with("Mouth_")):
			out.append(key)
	return out
