class_name ItemIcon
extends Control
## Ícone desenhado de um item (sem imagens externas).

var item_id: String = ""


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var col := ItemDB.color(item_id)
	var kind: String = ItemDB.get_item(item_id).get("kind", "")
	draw_circle(c, r, Color(1, 1, 1, 0.9))
	draw_arc(c, r, 0, TAU, 32, Color(0.86, 0.76, 0.6), 2.0, true)
	match kind:
		"flor":
			for i in range(5):
				var a := TAU * i / 5.0 - PI / 2.0
				draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.38, r * 0.3, col)
			draw_circle(c, r * 0.22, Color(1.0, 0.82, 0.3))
		"fruta":
			draw_circle(c + Vector2(0, r * 0.08), r * 0.55, col)
			draw_line(c - Vector2(0, r * 0.45), c - Vector2(-r * 0.15, r * 0.75), Color(0.45, 0.3, 0.2), 3.0)
			draw_circle(c + Vector2(r * 0.25, -r * 0.55), r * 0.16, Color(0.4, 0.7, 0.35))
		"material":
			if item_id == "galho":
				draw_line(c + Vector2(-r * 0.6, r * 0.5), c + Vector2(r * 0.6, -r * 0.5), col, 6.0)
				draw_line(c + Vector2(0, 0), c + Vector2(r * 0.35, r * 0.3), col, 4.0)
			else:
				draw_circle(c, r * 0.55, col)
				draw_circle(c + Vector2(-r * 0.15, -r * 0.18), r * 0.15, col.lightened(0.3))
		"praia":
			if item_id == "estrela_do_mar":
				var pts := PackedVector2Array()
				for i in range(10):
					var a2 := TAU * i / 10.0 - PI / 2.0
					var rr := r * (0.7 if i % 2 == 0 else 0.3)
					pts.append(c + Vector2(cos(a2), sin(a2)) * rr)
				draw_colored_polygon(pts, col)
			else:
				draw_circle(c + Vector2(0, r * 0.1), r * 0.55, col)
				for i in range(4):
					var x := -r * 0.35 + i * r * 0.23
					draw_line(c + Vector2(x, r * 0.55), c + Vector2(x * 0.3, -r * 0.35), col.darkened(0.2), 2.0)
		_:
			draw_circle(c, r * 0.5, col)
