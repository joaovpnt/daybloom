class_name DayNight
extends Node3D
## Ciclo visual de dia e noite: sol, céu, luz ambiente, postes e janelas.

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var lamps: Array = []
var fire_lights: Array = []
var _last_update := -100.0

# Paleta por hora: [hora, céu topo, horizonte, cor do sol, energia do sol, ambiente]
const KEYS := [
	[0.0, Color(0.06, 0.08, 0.22), Color(0.16, 0.20, 0.38), Color(0.55, 0.62, 0.95), 0.0, 0.32],
	[5.0, Color(0.12, 0.14, 0.32), Color(0.40, 0.34, 0.50), Color(0.85, 0.62, 0.60), 0.06, 0.32],
	[6.5, Color(0.42, 0.58, 0.84), Color(1.0, 0.74, 0.58), Color(1.0, 0.74, 0.52), 0.55, 0.30],
	[9.0, Color(0.30, 0.56, 0.90), Color(0.70, 0.84, 0.96), Color(1.0, 0.95, 0.86), 1.0, 0.34],
	[15.0, Color(0.28, 0.54, 0.90), Color(0.72, 0.84, 0.96), Color(1.0, 0.93, 0.82), 0.95, 0.34],
	[17.8, Color(0.38, 0.48, 0.80), Color(1.0, 0.74, 0.60), Color(1.0, 0.82, 0.66), 0.78, 0.32],
	[19.4, Color(0.18, 0.18, 0.42), Color(0.66, 0.44, 0.56), Color(0.95, 0.58, 0.50), 0.16, 0.28],
	[21.0, Color(0.07, 0.09, 0.24), Color(0.18, 0.22, 0.40), Color(0.55, 0.62, 0.95), 0.0, 0.32],
	[24.0, Color(0.06, 0.08, 0.22), Color(0.16, 0.20, 0.38), Color(0.55, 0.62, 0.95), 0.0, 0.32],
]


func setup(p_lamps: Array, p_fire: Array) -> void:
	lamps = p_lamps
	fire_lights = p_fire
	sun = DirectionalLight3D.new()
	sun.name = "Sol"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Lua"
	moon.light_color = Color(0.55, 0.62, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	moon.rotation_degrees = Vector3(-55, 140, 0)
	add_child(moon)
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Filmic com exposição contida: cores pastel vivas sem estourar (comparado
	# com AGX/ACES/Linear em Forward+ numa RTX 3050; ver docs/direcao_de_arte.md).
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.78
	env.tonemap_white = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.4
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	EventBus.settings_changed.connect(apply_settings)
	apply_settings()
	apply_time(GameClock.minute)


func apply_settings() -> void:
	env.ssao_enabled = Settings.ssao
	env.glow_enabled = Settings.glow
	sun.shadow_enabled = Settings.shadows > 0
	sun.directional_shadow_max_distance = 55.0 if Settings.shadows < 2 else 80.0
	sun.shadow_blur = 1.5
	RenderingServer.directional_shadow_atlas_set_size(2048 if Settings.shadows < 2 else 4096, true)


func _process(_delta: float) -> void:
	# Atualiza a iluminação algumas vezes por segundo de jogo (barato).
	if absf(GameClock.minute - _last_update) >= 0.5:
		apply_time(GameClock.minute)


func _sample(hour: float) -> Array:
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if hour >= a[0] and hour <= b[0]:
			var t := (hour - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			return [
				(a[1] as Color).lerp(b[1], t),
				(a[2] as Color).lerp(b[2], t),
				(a[3] as Color).lerp(b[3], t),
				lerpf(a[4], b[4], t),
				lerpf(a[5], b[5], t),
			]
	return [KEYS[0][1], KEYS[0][2], KEYS[0][3], KEYS[0][4], KEYS[0][5]]


func night_factor(hour: float) -> float:
	if hour >= 19.0 or hour < 5.0:
		return 1.0
	if hour >= 18.0:
		return hour - 18.0
	if hour < 6.5:
		return 1.0 - (hour - 5.0) / 1.5
	return 0.0


func apply_time(minute: float) -> void:
	_last_update = minute
	var hour := minute / 60.0
	var s := _sample(hour)
	var day_t := clampf((hour - 5.5) / 14.5, 0.0, 1.0)
	sun.rotation.x = -sin(day_t * PI) * 1.1 - 0.12
	sun.rotation.y = deg_to_rad(lerpf(-80.0, 80.0, day_t))
	sun.light_color = s[2]
	sun.light_energy = s[3]
	var night := night_factor(hour)
	moon.light_energy = night * 0.45
	sky_mat.sky_top_color = s[0]
	sky_mat.sky_horizon_color = s[1]
	sky_mat.ground_horizon_color = s[1]
	sky_mat.ground_bottom_color = (s[0] as Color).darkened(0.3)
	# Sombras levemente azuladas (céu) em vez da cor do horizonte: evita que
	# o entardecer deixe a ilha inteira marrom.
	env.ambient_light_color = (s[1] as Color).lerp(s[0], 0.45).lerp(Color(1, 1, 1), 0.15)
	env.ambient_light_energy = s[4] * 0.72
	env.fog_light_color = s[1]
	for lamp in lamps:
		(lamp as OmniLight3D).light_energy = night * 1.6
	for fl in fire_lights:
		(fl as OmniLight3D).light_energy = 0.6 + night * 1.8
	var glass := MaterialLib.window_glass()
	glass.emission_energy_multiplier = night * 1.4
	ModelLib.lamp_glass().emission_energy_multiplier = night * 3.0
	MaterialLib.water().set_shader_parameter("night", night * 0.8)
	MaterialLib.pond_water().set_shader_parameter("night", night * 0.8)
