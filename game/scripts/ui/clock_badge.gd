class_name ClockBadge
extends PanelContainer
## Relógio compacto do HUD: ícone de sol/lua, dia e horário.

var icon: Control
var day_label: Label
var time_label: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.94), 999, UiTheme.LINE, 2, true, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)
	icon = SkyIcon.new()
	icon.custom_minimum_size = Vector2(34, 34)
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	h.add_child(v)
	day_label = UiTheme.label("Dia 1", UiTheme.SIZE_SMALL, UiTheme.INK_SOFT, true)
	v.add_child(day_label)
	time_label = UiTheme.label("08:00", 24, UiTheme.INK)
	time_label.add_theme_font_override("font", UiTheme.font_display())
	v.add_child(time_label)


func _process(_delta: float) -> void:
	day_label.text = "Dia %d · %s" % [GameClock.day, GameClock.period()]
	time_label.text = GameClock.format_hm(GameClock.minute)
	icon.queue_redraw()


class SkyIcon:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var h := GameClock.minute / 60.0
		var night := h >= 19.0 or h < 5.5
		if night:
			draw_circle(c, r * 0.95, Color("394a80"))
			draw_circle(c + Vector2(r * 0.12, -r * 0.05), r * 0.5, Color("fff3c4"))
			draw_circle(c + Vector2(r * 0.32, -r * 0.18), r * 0.42, Color("394a80"))
			draw_circle(c + Vector2(-r * 0.45, -r * 0.4), r * 0.07, Color("fff3c4"))
			draw_circle(c + Vector2(-r * 0.2, r * 0.45), r * 0.05, Color("fff3c4"))
		else:
			var dusk := h >= 17.5
			var bg := Color("ffd58a") if dusk else Color("bfe3ff")
			draw_circle(c, r * 0.95, bg)
			var sun := Color("ff9e5a") if dusk else Color("ffc94a")
			for i in range(8):
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.48, c + Vector2(cos(a), sin(a)) * r * 0.72, sun, 2.5, true)
			draw_circle(c, r * 0.36, sun)
