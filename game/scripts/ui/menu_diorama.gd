class_name MenuDiorama
extends SubViewportContainer
## Fundo 3D do menu principal: a própria ilha (mesmos modelos do jogo),
## iluminada no fim de tarde, com alguns moradores na praça e a câmera
## girando devagar. Roda em um SubViewport com mundo próprio.

const ORBIT_RADIUS := 34.0
const ORBIT_HEIGHT := 17.0
const ORBIT_SPEED := 0.035
const FOCUS := Vector3(2.0, 0.0, 6.0)

var viewport: SubViewport
var camera: Camera3D
var day_night: DayNight
var world_root: Node3D
var villagers: Array = []
var _angle := 0.6
var _talk_timer := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world_root = Node3D.new()
	world_root.name = "Diorama"
	viewport.add_child(world_root)
	var builder := IslandBuilder.new()
	builder.build(world_root)
	day_night = DayNight.new()
	world_root.add_child(day_night)
	day_night.setup(builder.lamps, builder.fire_lights)
	day_night.set_process(false)
	day_night.apply_time(16.6 * 60.0)
	# Vista de longe: menos neblina para não desbotar a ilha.
	day_night.env.fog_density = 0.0005
	_spawn_villagers()
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 260.0
	world_root.add_child(camera)
	camera.make_current()
	_update_camera()


func _spawn_villagers() -> void:
	# Pequenas cenas da vida na ilha, com as animações exportadas do Blender.
	var scenes := [
		["lila", Vector2(-1.6, 3.2), "talk"], ["bento", Vector2(0.2, 4.4), "idle"],
		["pipa", Vector2(4.6, 3.0), "happy"], ["tobias", Vector2(9.6, 9.2), "talk"],
		["celeste", Vector2(-14.6, 12.0), "idle"], ["marina", Vector2(15.4, 18.8), "idle"],
	]
	for s in scenes:
		var vis := CharacterVisual.new()
		world_root.add_child(vis)
		vis.setup("characters/villager_%s" % s[0])
		vis.position = Places.pos3(s[1])
		var look: Vector2 = Vector2(0.4, 6.0) - (s[1] as Vector2)
		vis.rotation.y = atan2(look.x, look.y)
		if s[2] == "happy":
			vis.set_base_expression("happy")
			vis.play("idle")
		else:
			vis.play(s[2])
		vis.talking = s[2] == "talk"
		villagers.append(vis)


func _process(delta: float) -> void:
	_angle += delta * ORBIT_SPEED
	_update_camera()
	_talk_timer -= delta
	if _talk_timer <= 0.0 and not villagers.is_empty():
		_talk_timer = 3.5
		var v: CharacterVisual = villagers[randi() % villagers.size()]
		if v.has_animation("happy") and not v.is_reacting():
			v.play_once("happy")
			v.flash_expression("happy", 1.5)


func _update_camera() -> void:
	if camera == null:
		return
	var off := Vector3(sin(_angle), 0.0, cos(_angle)) * ORBIT_RADIUS
	camera.position = FOCUS + off + Vector3(0, ORBIT_HEIGHT, 0)
	camera.look_at(FOCUS + Vector3(0, 1.5, 0), Vector3.UP)
