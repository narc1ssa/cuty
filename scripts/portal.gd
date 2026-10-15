extends Node2D
## Крутящаяся розовая воронка портала поверх храма на карте:
## вращающиеся спиральные рукава, пульсация, звёздочки на орбите.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _star(radius: float, rot: float, color: Color, centre: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var r := radius * 0.45 if i % 2 == 1 else radius
		var a := rot + float(i) * PI / 5.0 - PI / 2.0
		pts.append(centre + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


func _draw() -> void:
	var pulse := 1.0 + sin(_t * 2.4) * 0.05
	# Свечение.
	for pair in [[78.0, Color(1, 0.5, 0.92, 0.20)], [56.0, Color(1, 0.62, 0.95, 0.35)], [38.0, Color(1, 0.78, 0.97, 0.55)]]:
		draw_circle(Vector2.ZERO, pair[0] * pulse, pair[1])
	# Три спиральных рукава.
	for arm in range(3):
		var base := _t * 1.9 + float(arm) * TAU / 3.0
		var pts := PackedVector2Array()
		var steps := 24
		for i in range(steps + 1):
			var a := float(i) / float(steps) * PI * 1.5
			var r := (6.0 + a * 9.5) * pulse
			pts.append(Vector2(cos(base + a), sin(base + a) * 0.92) * r)
		draw_polyline(pts, Color(1, 0.86, 0.98, 0.9) if arm % 2 == 0 else Color(1, 0.47, 0.86, 0.85), 5.0)
	# Яркое ядро.
	draw_circle(Vector2.ZERO, 9.0 + sin(_t * 5.0) * 2.0, Color.WHITE)
	# Звёздочки на орбите.
	for i in range(6):
		var a := _t * 2.6 + float(i) * PI / 3.0
		var r := 52.0 + sin(_t * 3.0 + float(i)) * 7.0
		_star(6.0, a * 2.0, Color(1, 0.85, 0.29) if i % 2 == 0 else Color(1, 0.89, 0.97),
			Vector2(cos(a), sin(a) * 0.9) * r)
