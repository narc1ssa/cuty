extends Area2D
## Враг: патрулирует строго свою платформу между min_x и max_x.
## Летучие мыши (fly) парят над платформой по синусоиде.

signal died(enemy: Area2D)
signal touched_player(enemy: Area2D)
signal got_hit(at_pos: Vector2)

var enemy_type := "slime"
var hp := 2
var max_hp := 2
var speed := 46.0
var display_height := 54.0
var fly := false
var min_x := 0.0
var max_x := 0.0
var platform_y := 0.0
var dir := 1
var dead := false

var _t := 0.0
var _flash := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision


func setup(cfg: Dictionary, sprite_texture: Texture2D) -> void:
	enemy_type = cfg["type"]
	max_hp = int(cfg["hp"])
	hp = max_hp
	speed = float(cfg["speed"])
	display_height = float(cfg["h"])
	fly = bool(cfg.get("fly", false))
	min_x = float(cfg["min_x"])
	max_x = float(cfg["max_x"])
	platform_y = float(cfg["platform_y"])
	dir = int(cfg.get("dir", 1))
	global_position.x = (min_x + max_x) / 2.0
	_update_y(0.0)
	if is_node_ready():
		_apply_sprite(sprite_texture)
	else:
		ready.connect(_apply_sprite.bind(sprite_texture), CONNECT_ONE_SHOT)


func _apply_sprite(tex: Texture2D) -> void:
	sprite.texture = tex
	var s := display_height / float(tex.get_height())
	sprite.scale = Vector2(s, s)
	collision.scale = Vector2.ONE * clampf(display_height / 60.0, 0.8, 1.35)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _update_y(time: float) -> void:
	if fly:
		global_position.y = platform_y - 96.0 + sin(time * 2.4) * 13.0
	else:
		global_position.y = platform_y - display_height / 2.0 - absf(sin(time * 6.0)) * 3.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(1.8, 0.5, 0.5) if _flash > 0.0 else Color.WHITE
	global_position.x += dir * speed * delta
	if global_position.x < min_x:
		global_position.x = min_x
		dir = 1
	elif global_position.x > max_x:
		global_position.x = max_x
		dir = -1
	_update_y(_t)
	sprite.flip_h = dir < 0
	queue_redraw()


func _draw() -> void:
	# Полоска HP над врагом, если он уже ранен.
	if not dead and hp < max_hp:
		var w := 44.0
		var y := -display_height / 2.0 - 14.0
		draw_rect(Rect2(-w / 2.0, y, w, 6), Color(0.12, 0.02, 0.1, 0.65))
		draw_rect(Rect2(-w / 2.0 + 1, y + 1, (w - 2) * float(hp) / float(max_hp), 4), Color(1, 0.37, 0.62))


func take_hit() -> void:
	if dead:
		return
	hp -= 1
	_flash = 0.14
	got_hit.emit(global_position)
	queue_redraw()
	if hp <= 0:
		dead = true
		died.emit(self)
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not dead and body.is_in_group("player"):
		touched_player.emit(self)
