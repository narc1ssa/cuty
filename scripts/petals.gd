extends Control
## Передний план (CanvasLayer поверх мира): падающие лепестки сакуры
## трёх глубин + веточки сакуры по углам кадра.
## cam_delta_x каждый кадр передаёт главный скрипт: лепестки разной
## глубины сдвигаются от камеры на разную величину — это и есть
## параллакс переднего плана.

var cam_delta_x := 0.0

var _petals: Array = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(80):
		var depth: float = [0.55, 0.85, 1.25][i % 3]
		_petals.append({
			"pos": Vector2(randf() * 1300.0, randf() * 740.0),
			"size": (4.0 + randf() * 5.0) * depth,
			"depth": depth,
			"fall": 26.0 + randf() * 30.0,
			"sway": randf() * TAU,
			"sway_speed": 0.6 + randf() * 1.1,
			"rot": randf() * PI,
			"spin": randf_range(-1.1, 1.1),
			"alpha": 0.45 + depth * 0.3,
		})


func _process(delta: float) -> void:
	_t += delta
	var view := size
	if view.x < 10.0:
		view = Vector2(1280, 720)
	for p in _petals:
		var pos: Vector2 = p["pos"]
		p["sway"] = float(p["sway"]) + float(p["sway_speed"]) * delta
		pos.y += float(p["fall"]) * float(p["depth"]) * delta
		pos.x += sin(float(p["sway"])) * 42.0 * delta - cam_delta_x * (float(p["depth"]) - 0.8) * 0.9
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		if pos.y > view.y + 18.0:
			pos = Vector2(randf() * view.x, -14.0)
		if pos.x < -20.0:
			pos.x += view.x + 40.0
		elif pos.x > view.x + 20.0:
			pos.x -= view.x + 40.0
		p["pos"] = pos
	cam_delta_x = 0.0
	queue_redraw()


func _petal_shape(centre: Vector2, s: float, rot: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in range(12):
		var a := float(i) / 12.0 * TAU
		# Каплевидный лепесток: уже у кончика, шире к низу.
		var rr := s * (0.55 + 0.45 * sin(a * 0.5 + 0.6))
		var local := Vector2(sin(a) * rr * 0.75, -cos(a) * rr)
		pts.append(centre + local.rotated(rot))
	draw_colored_polygon(pts, Color(1, 0.62, 0.78, alpha))
	draw_circle(centre + Vector2(-s * 0.2, -s * 0.25).rotated(rot), s * 0.22, Color(1, 1, 1, alpha * 0.5))


func _draw() -> void:
	for p in _petals:
		_petal_shape(p["pos"], float(p["size"]), float(p["rot"]), float(p["alpha"]))
	# Веточки сакуры по верхним углам (ближайший слой).
	var sway := sin(_t * 0.8) * 5.0
	var brown := Color(0.36, 0.16, 0.24, 0.9)
	draw_rect(Rect2(-8 + sway, -6, 150, 13), brown)
	draw_rect(Rect2(size.x - 140 + sway, -6, 150, 13), brown)
	draw_rect(Rect2(-6, -8, 13, 105), brown)
	for centre in [Vector2(24 + sway, 16), Vector2(66 + sway, 10), Vector2(112 + sway, 20),
			Vector2(size.x - 34 + sway, 14), Vector2(size.x - 82 + sway, 10), Vector2(size.x - 124 + sway, 22)]:
		var c: Vector2 = centre
		for i in range(6):
			var a := float(i) * 1.05 + c.x
			var pts := PackedVector2Array()
			for k in range(14):
				var aa := float(k) / 14.0 * TAU
				pts.append(c + Vector2(cos(a) * 11.0, sin(a) * 8.0) + Vector2(cos(aa) * 10.0, sin(aa) * 7.0))
			draw_colored_polygon(pts, Color(1, 0.62, 0.78, 0.9))
		draw_circle(c, 5.5, Color(1, 0.78, 0.87, 0.95))
