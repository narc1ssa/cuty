extends Node2D
## МИЛА • 1-4 «Сакуровый лес» — главный скрипт уровня (порт веб-версии).
##
## Мир 2861x768 по карте res://map.png. Платформы размечены по
## нарисованным платформам карты и созданы как односторонние
## StaticBody2D: приземление сверху, прыжок сквозь них снизу.
## Слои: небо -> облака-параллакс (x0.45) -> карта (x1.0) -> портал,
## предметы, враги, Мила -> лепестки трёх глубин и веточки (передний
## план) -> HUD.

const WORLD_W := 2861.0
const WORLD_H := 768.0
const VIEW := Vector2(1280, 720)
const GOAL_RECT := Rect2(2610, 50, 125, 145)
const GOAL_CENTRE := Vector2(2670, 132)

# [x, y верхнего края, ширина]
const PLATFORMS := [
	[-30, 488, 210], [300, 548, 320], [435, 455, 265], [640, 368, 240],
	[915, 276, 270], [1080, 415, 275], [1335, 565, 245], [1540, 455, 265],
	[1525, 264, 285], [1740, 498, 220], [1795, 345, 355], [2140, 378, 175],
	[2295, 408, 175], [2330, 405, 295], [2445, 252, 155], [2440, 188, 421],
	[140, 708, 385], [760, 708, 390], [1240, 708, 430], [1745, 608, 215],
	[2245, 518, 220], [2050, 612, 811], [2675, 568, 185],
]
const SPIKES := [Rect2(535, 650, 215, 110), Rect2(1880, 625, 165, 120)]
# Чекпоинты: позиция ног героини при возрождении.
const CHECKPOINTS := [Vector2(83, 488), Vector2(1811, 498), Vector2(2401, 405)]
const SPAWN := Vector2(83, 488)

const ENEMY_TYPES := {
	"slime": {"hp": 2, "speed": 46.0, "h": 54.0, "score": 100, "fly": false},
	"bat": {"hp": 1, "speed": 78.0, "h": 60.0, "score": 150, "fly": true},
	"spider": {"hp": 2, "speed": 66.0, "h": 56.0, "score": 150, "fly": false},
	"mushroom": {"hp": 2, "speed": 38.0, "h": 66.0, "score": 100, "fly": false},
	"spiker": {"hp": 3, "speed": 34.0, "h": 74.0, "score": 250, "fly": false},
	"purple": {"hp": 2, "speed": 56.0, "h": 60.0, "score": 150, "fly": false},
}
# У каждого врага — своя платформа (plat) и свой участок патруля.
const ENEMY_SPAWNS := [
	{"type": "slime", "plat": 1, "min": 330, "max": 560},
	{"type": "mushroom", "plat": 2, "min": 460, "max": 650},
	{"type": "spiker", "plat": 3, "min": 665, "max": 820},
	{"type": "bat", "plat": 4, "min": 940, "max": 1140},
	{"type": "purple", "plat": 5, "min": 1110, "max": 1300},
	{"type": "spider", "plat": 6, "min": 1365, "max": 1520},
	{"type": "slime", "plat": 7, "min": 1570, "max": 1750},
	{"type": "mushroom", "plat": 8, "min": 1560, "max": 1750},
	{"type": "spiker", "plat": 10, "min": 1840, "max": 2080},
	{"type": "bat", "plat": 13, "min": 2360, "max": 2560},
	{"type": "spider", "plat": 21, "min": 2120, "max": 2560},
	{"type": "purple", "plat": 15, "min": 2470, "max": 2585},
]

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const BulletScene := preload("res://scenes/Bullet.tscn")

var state := "menu"  # menu | playing | paused | win-anim | win | over
# Нетипизированные поля: у узлов кастомные скрипты со своими методами.
var player
var hud
var sfx
var music
var clouds
var petals
var portal
var items_node

var enemies: Array = []
var items: Array = []
var floaters: Array = []
var time_sec := 0.0
var combo := 0
var combo_timer := 0.0
var max_combo := 0
var coins_got := 0
var gems_got := 0
var kills := 0
var total_coins := 0
var total_gems := 0
var warned := false
var respawn_point := SPAWN
var last_safe := SPAWN
var _safe_timer := 0.0
var _win_timer := 0.0
var _win_from := Vector2.ZERO
var _prev_cam_x := 0.0
var _cam_shake := 0.0

var _enemy_textures := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_enemy_textures = {
		"slime": preload("res://assets/sprites/enemy_slime.png"),
		"bat": preload("res://assets/sprites/enemy_bat.png"),
		"spider": preload("res://assets/sprites/enemy_spider.png"),
		"mushroom": preload("res://assets/sprites/enemy_mushroom.png"),
		"spiker": preload("res://assets/sprites/enemy_spiker.png"),
		"purple": preload("res://assets/sprites/enemy_purple.png"),
	}

	sfx = preload("res://scripts/sfx.gd").new()
	add_child(sfx)

	music = preload("res://scripts/music.gd").new()
	add_child(music)

	# Небо за картой.
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -2
	add_child(sky_layer)
	var sky := ColorRect.new()
	sky.color = Color(0.47, 0.78, 0.95)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_layer.add_child(sky)

	# Карта мира.
	var map_sprite := Sprite2D.new()
	map_sprite.texture = preload("res://map.png")
	map_sprite.centered = false
	map_sprite.z_index = -10
	add_child(map_sprite)

	# Параллакс-облака (двигаются в 0.45 раза медленнее мира).
	clouds = preload("res://scripts/clouds.gd").new()
	clouds.z_index = -5
	add_child(clouds)

	_build_platforms()

	# Крутящаяся воронка портала у храма справа.
	portal = preload("res://scripts/portal.gd").new()
	portal.position = GOAL_CENTRE
	portal.z_index = 3
	add_child(portal)

	items_node = preload("res://scripts/items.gd").new()
	items_node.z_index = 2
	add_child(items_node)

	player = PlayerScene.instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE  # иначе унаследует ALWAYS от Main и пауза не встанет
	player.z_index = 10
	add_child(player)
	player.shot_fired.connect(_on_player_shot)

	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	player.virtual_keys = hud.touch_keys
	hud.start_requested.connect(start_game)
	hud.resume_requested.connect(resume_game)
	hud.pause_requested.connect(_toggle_pause)
	hud.sound_requested.connect(_toggle_sound)

	# Лепестки сакуры поверх мира (CanvasLayer 8, под HUD).
	var petal_layer := CanvasLayer.new()
	petal_layer.layer = 8
	add_child(petal_layer)
	petals = preload("res://scripts/petals.gd").new()
	petals.set_anchors_preset(Control.PRESET_FULL_RECT)
	petal_layer.add_child(petals)

	reset_game()
	state = "menu"
	player.active = false
	hud.show_menu()


func _build_platforms() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for p in PLATFORMS:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(float(p[2]), 24)
		col.shape = shape
		col.position = Vector2(float(p[0]) + float(p[2]) / 2.0, float(p[1]) + 12.0)
		col.one_way_collision = true
		body.add_child(col)


func _make_items() -> Array:
	var list: Array = []
	var coin_rows := [
		[340, 500], [430, 500], [520, 500], [480, 408], [580, 408], [690, 320], [790, 320],
		[970, 228], [1070, 228], [1130, 367], [1230, 367], [1400, 517], [1500, 517],
		[1600, 407], [1700, 407], [1600, 216], [1700, 216], [1800, 450], [1900, 297],
		[2000, 297], [2200, 344], [2400, 357], [2520, 247], [700, 660], [900, 660],
		[1450, 660], [1800, 560], [2320, 470], [2750, 520],
	]
	for i in range(coin_rows.size()):
		list.append({"kind": "coin", "x": float(coin_rows[i][0]), "y": float(coin_rows[i][1]),
			"taken": false, "ph": float(i) * 0.7})
	for pos in [[250, 660], [1030, 660], [1830, 555], [2300, 465], [2520, 560]]:
		list.append({"kind": "gem", "x": float(pos[0]), "y": float(pos[1]), "taken": false, "ph": 1.1})
	for pos in [[1000, 218], [2330, 455]]:
		list.append({"kind": "heart", "x": float(pos[0]), "y": float(pos[1]), "taken": false, "ph": 0.0})
	return list


func reset_game() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for b in get_tree().get_nodes_in_group("bullets"):
		b.queue_free()
	for f in floaters:
		if is_instance_valid(f["node"]):
			f["node"].queue_free()
	floaters.clear()

	player.set_physics_process(true)
	player.reset(SPAWN)
	respawn_point = SPAWN
	last_safe = SPAWN
	_safe_timer = 0.0
	time_sec = 0.0
	combo = 0
	combo_timer = 0.0
	max_combo = 0
	coins_got = 0
	gems_got = 0
	kills = 0
	warned = false
	_win_timer = 0.0
	_cam_shake = 0.0

	for i in range(ENEMY_SPAWNS.size()):
		var spawn: Dictionary = ENEMY_SPAWNS[i]
		var t: Dictionary = ENEMY_TYPES[spawn["type"]]
		var enemy: MilaEnemy = EnemyScene.instantiate() as MilaEnemy
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(enemy)
		enemy.died.connect(_on_enemy_died)
		enemy.touched_player.connect(_on_enemy_touched)
		enemy.got_hit.connect(_on_enemy_got_hit)
		var tex: Texture2D = _enemy_textures[spawn["type"]]
		enemy.setup({
			"type": spawn["type"], "hp": t["hp"], "speed": t["speed"], "h": t["h"],
			"fly": t["fly"], "min_x": spawn["min"], "max_x": spawn["max"],
			"platform_y": float(PLATFORMS[int(spawn["plat"])][1]),
			"dir": -1 if i % 2 == 1 else 1,
		}, tex)
		enemies.append(enemy)

	items = _make_items()
	total_coins = items.filter(func(it): return it["kind"] == "coin").size()
	total_gems = items.filter(func(it): return it["kind"] == "gem").size()
	items_node.items = items
	_update_hud()


func start_game() -> void:
	get_tree().paused = false
	reset_game()
	state = "playing"
	player.active = true
	hud.show_game()


func _toggle_pause() -> void:
	if state == "playing":
		pause_game()
	elif state == "paused":
		resume_game()


func pause_game() -> void:
	if state != "playing":
		return
	state = "paused"
	get_tree().paused = true
	hud.show_pause()


func resume_game() -> void:
	if state != "paused":
		return
	get_tree().paused = false
	state = "playing"
	hud.show_game()


func _toggle_sound() -> void:
	sfx.muted = not sfx.muted
	music.set_muted(sfx.muted)
	hud.set_sound_text(not sfx.muted)


func game_over() -> void:
	state = "over"
	player.active = false
	sfx.play("die")
	hud.show_over(_stats_text())


func _stats_text() -> String:
	return "Время: %02d:%02d      Монеты: %d / %d      Кристаллы: %d / %d\nВрагов побеждено: %d / %d      Макс. комбо: x%d" % [
		int(time_sec) / 60, int(time_sec) % 60, coins_got, total_coins,
		gems_got, total_gems, kills, ENEMY_SPAWNS.size(), max_combo]


func _on_player_shot(from_pos: Vector2, dir: int, weapon: String = "star") -> void:
	var bullet: MilaBullet = BulletScene.instantiate() as MilaBullet
	bullet.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bullet)
	bullet.setup(from_pos, dir, weapon)
	sfx.play("shoot")
	var col := Color(1, 0.55, 0.91)
	if weapon == "heart":
		col = Color(1, 0.35, 0.58)
	elif weapon == "bunny":
		col = Color(0.22, 0.14, 0.24)
	burst(from_pos, col, 3, 90.0)


func _on_enemy_got_hit(at_pos: Vector2) -> void:
	sfx.play("hit")
	burst(at_pos, Color(1, 0.55, 0.91), 6, 200.0)


func _on_enemy_died(enemy) -> void:
	kills += 1
	combo += 1
	combo_timer = 4.0
	max_combo = maxi(max_combo, combo)
	var score: int = ENEMY_TYPES[enemy.enemy_type]["score"]
	burst(enemy.global_position, Color(1, 0.56, 0.77), 18, 300.0)
	burst(enemy.global_position, Color(1, 0.85, 0.29), 8, 240.0)
	add_floater(enemy.global_position + Vector2(0, -40), "+%d  x%d" % [score, combo], Color(1, 0.85, 0.29))
	if randf() < 0.45:
		items.append({"kind": "coin", "x": enemy.global_position.x, "y": enemy.global_position.y,
			"taken": false, "ph": randf() * 6.0})
		items_node.items = items
	sfx.play("die")
	_update_hud()


func _on_enemy_touched(enemy) -> void:
	if state != "playing":
		return
	if player.take_damage(enemy.global_position.x):
		combo = 0
		_cam_shake = 7.0
		sfx.play("hurt")
		burst(player.body_center(), Color(1, 0.37, 0.62), 10, 200.0)
		_update_hud()
		if player.hp <= 0:
			game_over()


func burst(at_pos: Vector2, color: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	p.amount = amount
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = color
	p.position = at_pos
	p.z_index = 20
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func add_floater(at_pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	label.position = at_pos - Vector2(24, 10)
	label.z_index = 30
	add_child(label)
	floaters.append({"node": label, "life": 1.0})


func _update_hud() -> void:
	var foes := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			foes += 1
	var progress := clampf((player.global_position.x - 40.0) / (GOAL_CENTRE.x - 120.0), 0.0, 1.0)
	hud.set_stats(player.hp, coins_got, gems_got, combo, foes, player.energy, time_sec, progress,
		player.heart_charges, MilaPlayer.HEART_MAX, player.bunny_charges, MilaPlayer.BUNNY_MAX)


func _process(delta: float) -> void:
	# Камера и параллакс-слои обновляются всегда (и в меню красиво).
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var cam_tl := cam.get_screen_center_position() - VIEW / 2.0
		clouds.global_position = cam_tl * 0.55
		petals.cam_delta_x += cam_tl.x - _prev_cam_x
		_prev_cam_x = cam_tl.x
		if _cam_shake > 0.0:
			_cam_shake = maxf(0.0, _cam_shake - delta * 26.0)
			player.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _cam_shake
		elif is_instance_valid(player):
			player.camera.offset = Vector2.ZERO

	# Всплывающие очки.
	for f in floaters:
		f["life"] = float(f["life"]) - delta * 0.8
		var node: Label = f["node"]
		if is_instance_valid(node):
			node.position.y -= 34.0 * delta
			node.modulate.a = clampf(float(f["life"]), 0.0, 1.0)
	floaters = floaters.filter(func(f): return float(f["life"]) > 0.0)

	if state == "win-anim":
		_win_timer += delta
		var k := minf(1.0, _win_timer / 1.4)
		player.global_position = _win_from.lerp(GOAL_CENTRE, k * k)
		var spr: Sprite2D = player.get_node("Sprite")
		spr.rotation = k * 4.5
		spr.scale = Vector2.ONE * 0.343 * (1.0 - k * 0.85)
		if _win_timer > 1.45:
			state = "win"
			player.visible = false
			hud.show_win(_stats_text())
		return

	if state != "playing":
		return

	time_sec += delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0

	# Безопасная точка и чекпоинты.
	if player.is_on_floor():
		_safe_timer += delta
		if _safe_timer > 0.4:
			last_safe = player.global_position
			_safe_timer = 0.0
		for cp in CHECKPOINTS:
			if player.global_position.x > cp.x - 40.0:
				respawn_point = cp
	else:
		_safe_timer = 0.0

	# Падение в пропасть.
	if player.global_position.y > WORLD_H + 60.0:
		player.hp -= 1
		player.hp_changed.emit(player.hp)
		sfx.play("hurt")
		if player.hp <= 0:
			_update_hud()
			game_over()
			return
		player.global_position = respawn_point
		player.velocity = Vector2.ZERO
		player.start_invulnerability(1.5)

	# Колючие колёса на нижнем маршруте.
	var feet_rect := Rect2(player.global_position + Vector2(-15, -70), Vector2(30, 70))
	for spike in SPIKES:
		if feet_rect.intersects(spike) and not player.is_invulnerable():
			if player.take_damage(spike.get_center().x):
				combo = 0
				sfx.play("hurt")
				if player.hp <= 0:
					_update_hud()
					game_over()
					return
				player.global_position = last_safe
				player.velocity = Vector2.ZERO
			break

	# Предметы.
	for it in items:
		if it["taken"]:
			continue
		var item_pos := Vector2(float(it["x"]), float(it["y"]))
		if absf(item_pos.x - player.global_position.x) < 40.0 \
				and absf(item_pos.y - player.body_center().y) < 56.0:
			it["taken"] = true
			match it["kind"]:
				"coin":
					coins_got += 1
					sfx.play("coin")
					add_floater(item_pos + Vector2(0, -16), "+1 монета", Color(1, 0.85, 0.29))
				"gem":
					gems_got += 1
					sfx.play("gem")
					add_floater(item_pos + Vector2(0, -16), "+1 кристалл", Color(0.50, 0.89, 1))
				"heart":
					if player.heal():
						add_floater(item_pos + Vector2(0, -16), "+1 сердце", Color(1, 0.56, 0.77))
					else:
						coins_got += 3
						add_floater(item_pos + Vector2(0, -16), "+3 монеты", Color(1, 0.85, 0.29))
					sfx.play("coin")
			burst(item_pos, Color(1, 0.95, 0.69), 8, 150.0)

	# Предупреждение о первом враге рядом.
	if not warned:
		for e in enemies:
			if is_instance_valid(e) and not e.dead \
					and absf(e.global_position.x - player.global_position.x) < 360.0:
				warned = true
				hud.show_toast()
				break

	# Финал: Мила входит в воронку храма.
	if feet_rect.intersects(GOAL_RECT):
		state = "win-anim"
		_win_timer = 0.0
		_win_from = player.global_position
		player.active = false
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
		sfx.play("win")
		burst(GOAL_CENTRE, Color(1, 0.55, 0.91), 30, 360.0)

	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P, KEY_ESCAPE:
				_toggle_pause()
			KEY_M:
				_toggle_sound()
			KEY_R:
				if state in ["playing", "paused", "win", "over"]:
					start_game()
			KEY_ENTER:
				if state == "menu":
					start_game()
