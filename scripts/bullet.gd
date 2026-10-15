class_name MilaBullet
extends Area2D
## Розовая звёздочка-снаряд из бластера Милы.

var velocity := Vector2.ZERO
var life := 1.1
var _rot := 0.0


func setup(from_pos: Vector2, dir: int) -> void:
	global_position = from_pos
	velocity = Vector2(dir * 660.0, 0)


func _ready() -> void:
	add_to_group("bullets")
	z_index = 15
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_rot += delta * 9.0
	life -= delta
	queue_redraw()
	if life <= 0.0 or global_position.x < -80.0 or global_position.x > 2941.0:
		queue_free()


func _draw_star(radius: float, rot: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var r := radius * 0.45 if i % 2 == 1 else radius
		var a := rot + float(i) * PI / 5.0 - PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


func _draw() -> void:
	_draw_star(13.0, _rot, Color(1, 0.31, 0.85))
	_draw_star(6.0, -_rot, Color.WHITE)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_hit"):
		area.take_hit()
		queue_free()
