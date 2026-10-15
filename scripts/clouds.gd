extends Node2D
## Далёкий параллакс-слой: облака и розовые кроны сакур.
## Главный скрипт ставит этому узлу global_position = cam_top_left * 0.55,
## поэтому слой движется в 0.45 раза медленнее мира (платформ).


func _cloud(x: float, y: float, s: float, alpha: float) -> void:
	var c := Color(1, 1, 1, alpha)
	for pair in [[0.0, 0.0, 34.0], [30.0, 6.0, 26.0], [-32.0, 8.0, 24.0], [8.0, -14.0, 24.0]]:
		var pts := PackedVector2Array()
		for i in range(20):
			var a := float(i) / 20.0 * TAU
			pts.append(Vector2(x + pair[0] * s + cos(a) * pair[2] * s, y + pair[1] * s + sin(a) * pair[2] * 0.62 * s))
		draw_colored_polygon(pts, c)


func _draw() -> void:
	# Кроны сакур вдалеке.
	for i in range(8):
		var x := -150.0 + float(i) * 320.0
		var y := 105.0 + float(i % 3) * 55.0
		var pts := PackedVector2Array()
		for k in range(24):
			var a := float(k) / 24.0 * TAU
			pts.append(Vector2(x + cos(a) * 90.0, y + sin(a) * 32.0))
		draw_colored_polygon(pts, Color(1, 0.72, 0.85, 0.45))
	# Облака.
	for i in range(10):
		_cloud(-120.0 + float(i) * 260.0, 30.0 + float((i * 37) % 200), 0.7 + float(i % 3) * 0.25, 0.30 + float(i % 4) * 0.08)
