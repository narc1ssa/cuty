class_name MilaBullet
extends Area2D
## Снаряд из панели способностей Милы: три вида оружия —
## "star" (звёздочка, бесконечный боезапас), "heart" (сердце, двойной урон,
## ограниченные заряды) и "bunny" (зайчик, пробивает насквозь несколько
## врагов, ограниченные заряды). Параметры полёта и урона — в WEAPON_STATS.

const WEAPON_STATS := {
	"star": {"speed": 660.0, "damage": 1, "pierce": false, "life": 1.1},
	"heart": {"speed": 520.0, "damage": 2, "pierce": false, "life": 1.2},
	"bunny": {"speed": 760.0, "damage": 1, "pierce": true, "life": 1.3},
}

var velocity := Vector2.ZERO
var life := 1.1
var weapon := "star"
var damage := 1
var pierce := false
var _rot := 0.0
var _hit_ids := {}


func setup(from_pos: Vector2, dir: int, weapon_name: String = "star") -> void:
	weapon = weapon_name if WEAPON_STATS.has(weapon_name) else "star"
	var cfg: Dictionary = WEAPON_STATS[weapon]
	global_position = from_pos
	velocity = Vector2(dir * float(cfg["speed"]), 0)
	damage = int(cfg["damage"])
	pierce = bool(cfg["pierce"])
	life = float(cfg["life"])


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


func _draw_heart(s: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(28):
		var t := float(i) / 28.0 * TAU
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, y) * (s / 16.0))
	draw_colored_polygon(pts, color)


func _draw_bunny(s: float) -> void:
	var body := Color(0.16, 0.08, 0.18)
	var inner := Color(1, 0.8, 0.86)
	draw_circle(Vector2(-s * 0.38, -s * 0.78), s * 0.30, body)
	draw_circle(Vector2(s * 0.38, -s * 0.78), s * 0.30, body)
	draw_circle(Vector2(-s * 0.38, -s * 0.78), s * 0.15, inner)
	draw_circle(Vector2(s * 0.38, -s * 0.78), s * 0.15, inner)
	draw_circle(Vector2(0, s * 0.2), s * 0.8, body)


func _draw() -> void:
	match weapon:
		"heart":
			_draw_heart(15.0, Color(1, 0.33, 0.58))
			_draw_heart(8.0, Color(1, 0.78, 0.88))
		"bunny":
			_draw_bunny(14.0)
		_:
			_draw_star(13.0, _rot, Color(1, 0.31, 0.85))
			_draw_star(6.0, -_rot, Color.WHITE)


func _on_area_entered(area: Area2D) -> void:
	if not area.has_method("take_hit"):
		return
	if pierce:
		var id := area.get_instance_id()
		if _hit_ids.has(id):
			return
		_hit_ids[id] = true
		area.take_hit(damage)
	else:
		area.take_hit(damage)
		queue_free()
