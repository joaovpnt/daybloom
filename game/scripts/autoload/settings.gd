extends Node
## Configurações gráficas e de interface, salvas em user://settings.cfg.

const PATH := "user://settings.cfg"

var fullscreen: bool = false
var vsync: bool = true
var msaa: int = 2               # 0, 2, 4
var shadows: int = 2            # 0 desligadas, 1 médias, 2 altas
var ssao: bool = true
var glow: bool = true
var render_scale: float = 1.0   # 0.75 a 1.0
var show_fps: bool = false
var ui_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)
	msaa = int(cfg.get_value("video", "msaa", msaa))
	shadows = int(cfg.get_value("video", "shadows", shadows))
	ssao = cfg.get_value("video", "ssao", ssao)
	glow = cfg.get_value("video", "glow", glow)
	render_scale = clampf(float(cfg.get_value("video", "render_scale", render_scale)), 0.5, 1.0)
	show_fps = cfg.get_value("interface", "show_fps", show_fps)
	ui_scale = clampf(float(cfg.get_value("interface", "ui_scale", ui_scale)), 0.8, 1.3)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "msaa", msaa)
	cfg.set_value("video", "shadows", shadows)
	cfg.set_value("video", "ssao", ssao)
	cfg.set_value("video", "glow", glow)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("interface", "show_fps", show_fps)
	cfg.set_value("interface", "ui_scale", ui_scale)
	cfg.save(PATH)


func apply() -> void:
	if DisplayServer.get_name() == "headless":
		EventBus.settings_changed.emit()
		return
	var vp := get_viewport()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match msaa:
		4:
			vp.msaa_3d = Viewport.MSAA_4X
		2:
			vp.msaa_3d = Viewport.MSAA_2X
		_:
			vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = render_scale
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	get_tree().root.content_scale_factor = ui_scale
	EventBus.settings_changed.emit()
