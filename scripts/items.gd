extends Node2D
## Рисует все собираемые предметы уровня: монеты, кристаллы, сердечки.
## Данные (Array of Dictionary) принадлежат главному скрипту, здесь
## только отрисовка и лёгкое покачивание.

var items: Array = []


func _process(_delta: float) -> void:
	queue_redraw()


func _star(centre: Vector2, radius: float, rot: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var r := radius * 0.45 if i % 2 == 1 else radius
		var a := rot + float(i) * PI / 5.0 - PI / 2.0
		pts.append(centre + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for it in items:
		if it["taken"]:
			continue
		var centre := Vector2(float(it["x"]), float(it["y"]) + sin(t * 2.4 + float(it["ph"])) * 5.0)
		match it["kind"]:
			"coin":
				var squash := absf(cos(t * 3.0 + float(it["ph"]))) * 0.7 + 0.3
				draw_circle(centre, 13.0, Color(1, 0.85, 0.30))
				draw_arc(centre, 13.0, 0, TAU, 24, Color(0.85, 0.59, 0), 2.5)
				_star(centre, 7.0 * squash, t * 2.0, Color(1, 0.95, 0.69))
			"gem":
				var pts := PackedVector2Array([
					centre + Vector2(0, -15), centre + Vector2(11, 0),
					centre + Vector2(0, 17), centre + Vector2(-11, 0)])
				draw_colored_polygon(pts, Color(0.43, 0.91, 1))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.11, 0.62, 0.77), 2.0)
			"heart":
				var s := 1.0 + sin(t * 4.0) * 0.1
				var pts := PackedVector2Array()
				for i in range(22):
					var a := float(i) / 22.0 * TAU
					# Параметрическое сердце.
					var hx := 16.0 * pow(sin(a), 3.0)
					var hy := 13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)
					pts.append(centre + Vector2(hx, -hy) * 0.85 * s)
				draw_colored_polygon(pts, Color(1, 0.37, 0.62))
