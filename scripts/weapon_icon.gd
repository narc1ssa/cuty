class_name MilaWeaponIcon
extends Control
## Маленькая иконка оружия для панели способностей HUD: рисуется кодом
## (без спрайтов) — звёздочка, сердце или зайчик, см. kind.

@export var kind := "star"  # star | heart | bunny

var dim := false  # true, если заряды закончились (иконка гаснет)


func set_dim(v: bool) -> void:
	if dim != v:
		dim = v
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var a := 0.35 if dim else 1.0
	match kind:
		"heart":
			_draw_heart(c, 15.0, Color(1, 0.37, 0.62, a))
		"bunny":
			_draw_bunny(c, 13.0, Color(0.16, 0.08, 0.18, a), Color(1, 0.8, 0.86, a))
		_:
			_draw_star(c, 16.0, Color(1, 0.84, 0.30, a))
			_draw_star(c, 7.0, Color(1, 1, 1, a))


func _draw_star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var rr := r * 0.45 if i % 2 == 1 else r
		var ang := float(i) * PI / 5.0 - PI / 2.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, color)


func _draw_heart(c: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(28):
		var t := float(i) / 28.0 * TAU
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(c + Vector2(x, y) * (s / 16.0))
	draw_colored_polygon(pts, color)


func _draw_bunny(c: Vector2, s: float, color: Color, inner: Color) -> void:
	draw_circle(c + Vector2(-s * 0.38, -s * 0.78), s * 0.30, color)
	draw_circle(c + Vector2(s * 0.38, -s * 0.78), s * 0.30, color)
	draw_circle(c + Vector2(-s * 0.38, -s * 0.78), s * 0.15, inner)
	draw_circle(c + Vector2(s * 0.38, -s * 0.78), s * 0.15, inner)
	draw_circle(c + Vector2(0, s * 0.2), s * 0.8, color)
