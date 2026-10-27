class_name MilaPlayer
extends CharacterBody2D
## Мила: ходьба, двойной прыжок (койот-тайм + буфер прыжка), стрельба.
## Начало координат тела — у ног героини, спрайт рисуется вверх от него.

signal shot_fired(from_pos: Vector2, dir: int, weapon: String)
signal hp_changed(hp: int)

const SPEED := 265.0
const GRAVITY := 1750.0
const JUMP_VELOCITY := 775.0
const DOUBLE_JUMP_VELOCITY := 715.0
const MAX_HP := 5

## Панель способностей (как на макете HUD.png): Z — звёздный бластер
## (бесконечно, тратит энергию), X — сердечный выстрел (двойной урон,
## ограниченные заряды), C — выстрел-зайчик (пробивает насквозь
## нескольких врагов, ограниченные заряды). Заряды X/C медленно
## восстанавливаются сами по себе, как энергия бластера.
const HEART_MAX := 3
const HEART_REGEN_TIME := 9.0
const HEART_COOLDOWN := 0.35

const BUNNY_MAX := 6
const BUNNY_REGEN_TIME := 6.0
const BUNNY_COOLDOWN := 0.26

var textures := {}
var face := 1
var hp := MAX_HP
var active := false
var energy := 100.0
var heart_charges := HEART_MAX
var bunny_charges := BUNNY_MAX

var _coyote := 0.0
var _jump_buffer := 0.0
var _air_jumps_used := 0
var _invuln := 0.0
var _shoot_cd := 0.0
var _shoot_anim := 0.0
var _hurt_anim := 0.0
var _run_time := 0.0
var _prev_jump_held := false
var _heart_cd := 0.0
var _bunny_cd := 0.0
var _heart_regen := 0.0
var _bunny_regen := 0.0

# Виртуальные клавиши с сенсорных кнопок HUD: {"left":bool, ...}
var virtual_keys := {}

@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	add_to_group("player")
	textures = {
		"idle": preload("res://assets/sprites/hero_idle.png"),
		"run1": preload("res://assets/sprites/hero_run1.png"),
		"run2": preload("res://assets/sprites/hero_run2.png"),
		"jump": preload("res://assets/sprites/hero_jump.png"),
		"shoot": preload("res://assets/sprites/hero_shoot.png"),
		"hurt": preload("res://assets/sprites/hero_hurt.png"),
	}
	camera.limit_left = 0
	camera.limit_right = 2861
	camera.limit_top = 0
	camera.limit_bottom = 768
	_set_sprite("idle", 106.0)


func reset(spawn_feet: Vector2) -> void:
	global_position = spawn_feet
	velocity = Vector2.ZERO
	hp = MAX_HP
	face = 1
	energy = 100.0
	heart_charges = HEART_MAX
	bunny_charges = BUNNY_MAX
	_invuln = 0.0
	_shoot_cd = 0.0
	_shoot_anim = 0.0
	_hurt_anim = 0.0
	_heart_cd = 0.0
	_bunny_cd = 0.0
	_heart_regen = 0.0
	_bunny_regen = 0.0
	_air_jumps_used = 0
	visible = true
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	hp_changed.emit(hp)


func _key(action: String) -> bool:
	if virtual_keys.get(action, false):
		return true
	match action:
		"left":
			return Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
		"right":
			return Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
		"jump":
			return Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) \
				or Input.is_physical_key_pressed(KEY_SPACE)
		"shoot":
			return Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_J) \
				or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		"heart":
			return Input.is_physical_key_pressed(KEY_X)
		"bunny":
			return Input.is_physical_key_pressed(KEY_C)
	return false


func _physics_process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta
	if _shoot_cd > 0.0:
		_shoot_cd -= delta
	if _heart_cd > 0.0:
		_heart_cd -= delta
	if _bunny_cd > 0.0:
		_bunny_cd -= delta
	if _shoot_anim > 0.0:
		_shoot_anim -= delta
	if _hurt_anim > 0.0:
		_hurt_anim -= delta
	energy = minf(100.0, energy + 26.0 * delta)

	if heart_charges < HEART_MAX:
		_heart_regen += delta
		if _heart_regen >= HEART_REGEN_TIME:
			_heart_regen -= HEART_REGEN_TIME
			heart_charges += 1
	else:
		_heart_regen = 0.0

	if bunny_charges < BUNNY_MAX:
		_bunny_regen += delta
		if _bunny_regen >= BUNNY_REGEN_TIME:
			_bunny_regen -= BUNNY_REGEN_TIME
			bunny_charges += 1
	else:
		_bunny_regen = 0.0

	var move := 0
	if active:
		move = (1 if _key("right") else 0) - (1 if _key("left") else 0)
	if move != 0:
		face = move
		_run_time += delta
	velocity.x = move * SPEED

	# Прыжок: буфер + койот-тайм, в воздухе доступен ещё один прыжок.
	var jump_held := active and _key("jump")
	if jump_held and not _prev_jump_held:
		_jump_buffer = 0.12
	elif _jump_buffer > 0.0:
		_jump_buffer -= delta
	_prev_jump_held = jump_held

	if is_on_floor():
		_coyote = 0.09
		_air_jumps_used = 0
	elif _coyote > 0.0:
		_coyote -= delta

	if _jump_buffer > 0.0 and (_coyote > 0.0 or _air_jumps_used < 1):
		var is_double := _coyote <= 0.0
		velocity.y = -DOUBLE_JUMP_VELOCITY if is_double else -JUMP_VELOCITY
		if is_double:
			_air_jumps_used += 1
		_jump_buffer = 0.0
		_coyote = 0.0

	velocity.y = minf(980.0, velocity.y + GRAVITY * delta)

	# Прицеливание мышью задаёт направление, если мышь правее/левее Милы.
	if active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		face = 1 if get_global_mouse_position().x >= global_position.x else -1

	if active and _key("shoot") and _shoot_cd <= 0.0 and energy >= 7.0:
		_shoot_cd = 0.21
		energy -= 7.0
		_shoot_anim = 0.22
		shot_fired.emit(global_position + Vector2(face * 34.0, -48.0), face, "star")
	elif active and _key("heart") and _heart_cd <= 0.0 and heart_charges > 0:
		_heart_cd = HEART_COOLDOWN
		heart_charges -= 1
		_shoot_anim = 0.22
		shot_fired.emit(global_position + Vector2(face * 34.0, -48.0), face, "heart")
	elif active and _key("bunny") and _bunny_cd <= 0.0 and bunny_charges > 0:
		_bunny_cd = BUNNY_COOLDOWN
		bunny_charges -= 1
		_shoot_anim = 0.22
		shot_fired.emit(global_position + Vector2(face * 34.0, -48.0), face, "bunny")

	move_and_slide()
	global_position.x = clampf(global_position.x, -18.0, 2861.0 - 10.0)
	_update_sprite(delta)


func _set_sprite(key: String, target_height: float) -> void:
	var tex: Texture2D = textures[key]
	if sprite.texture != tex:
		sprite.texture = tex
	var s := target_height / float(tex.get_height())
	sprite.scale = Vector2(s, s)
	sprite.position = Vector2(0, -target_height / 2.0)


func _update_sprite(_delta: float) -> void:
	var key := "idle"
	var h := 106.0
	if _hurt_anim > 0.0:
		key = "hurt"
	elif _shoot_anim > 0.0:
		key = "shoot"
		h = 100.0
	elif not is_on_floor():
		key = "jump"
	elif absf(velocity.x) > 10.0:
		key = "run1" if int(_run_time * 7.0) % 2 == 0 else "run2"
	_set_sprite(key, h)
	sprite.flip_h = face < 0
	# Мигание в период неуязвимости после удара.
	sprite.modulate.a = 0.35 if (_invuln > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 0) else 1.0


func take_damage(from_x: float) -> bool:
	## Возвращает true, если урон реально нанесён (не в неуязвимости).
	if _invuln > 0.0 or not active:
		return false
	hp -= 1
	_invuln = 1.3
	_hurt_anim = 0.35
	velocity = Vector2(-240.0 if global_position.x < from_x else 240.0, -320.0)
	hp_changed.emit(hp)
	return true


func heal() -> bool:
	if hp >= MAX_HP:
		return false
	hp += 1
	hp_changed.emit(hp)
	return true


func is_invulnerable() -> bool:
	return _invuln > 0.0


func start_invulnerability(sec: float) -> void:
	_invuln = maxf(_invuln, sec)


func body_center() -> Vector2:
	return global_position + Vector2(0, -39)
