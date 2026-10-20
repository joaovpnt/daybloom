class_name MenuBackground
extends Control
## Fundo animado do menu: céu, colinas, mar e flores balançando.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Céu em faixas
	var sky := [Color(0.62, 0.84, 0.96), Color(0.75, 0.9, 0.97), Color(0.9, 0.95, 0.96), Color(1.0, 0.95, 0.85)]
	for i in range(sky.size()):
		draw_rect(Rect2(0, h * i / 4.0 * 0.6, w, h * 0.6 / 4.0 + 1), sky[i])
	draw_rect(Rect2(0, h * 0.6, w, h * 0.4), Color(1.0, 0.95, 0.85))
	# Sol
	draw_circle(Vector2(w * 0.8, h * 0.18), 70, Color(1.0, 0.9, 0.55, 0.9))
	draw_circle(Vector2(w * 0.8, h * 0.18), 95, Color(1.0, 0.9, 0.55, 0.25))
	# Nuvens
	for i in range(4):
		var x := fmod(w * (0.15 + i * 0.27) + _t * (10.0 + i * 3.0), w + 300.0) - 150.0
		var y := h * (0.1 + (i % 2) * 0.1)
		for k in range(4):
			draw_circle(Vector2(x + k * 38, y + (k % 2) * 8), 34 - (k % 2) * 6, Color(1, 1, 1, 0.9))
	# Mar
	draw_rect(Rect2(0, h * 0.55, w, h * 0.12), Color(0.45, 0.8, 0.86))
	for i in range(12):
		var wx := fmod(i * 160.0 + _t * 25.0, w + 100.0) - 50.0
		draw_line(Vector2(wx, h * 0.6 + (i % 3) * 14), Vector2(wx + 40, h * 0.6 + (i % 3) * 14), Color(1, 1, 1, 0.6), 3.0)
	# Colinas
	var hills := [[0.62, Color(0.6, 0.83, 0.46)], [0.7, Color(0.5, 0.76, 0.4)], [0.8, Color(0.44, 0.7, 0.37)]]
	for hill in hills:
		var pts := PackedVector2Array()
		var base: float = h * hill[0]
		pts.append(Vector2(0, h))
		for i in range(41):
			var x2 := w * i / 40.0
			pts.append(Vector2(x2, base + sin(i * 0.45 + hill[0] * 10.0) * 28.0 + cos(i * 0.21) * 18.0))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, hill[1])
	# Flores balançando
	var colors := [Color(0.98, 0.55, 0.6), Color(1.0, 0.85, 0.3), Color(0.6, 0.65, 1.0), Color(1, 1, 1)]
	for i in range(28):
		var fx := w * fmod(i * 0.137 + 0.03, 1.0)
		var fy := h * (0.84 + fmod(i * 0.071, 0.14))
		var sway := sin(_t * 1.6 + i) * 5.0
		draw_line(Vector2(fx, fy + 20), Vector2(fx + sway, fy), Color(0.3, 0.55, 0.3), 3.0)
		var c: Color = colors[i % colors.size()]
		for k in range(5):
			var a := TAU * k / 5.0 + _t * 0.3
			draw_circle(Vector2(fx + sway, fy) + Vector2(cos(a), sin(a)) * 7.0, 6.0, c)
		draw_circle(Vector2(fx + sway, fy), 4.5, Color(1.0, 0.82, 0.3))
