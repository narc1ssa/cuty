extends CanvasLayer
## Пользовательский интерфейс по макетам HUD.png / preview.png:
## профиль Милы с сердечками, баннер уровня, комбо и таймер, энергия
## бластера, прогресс «флаг -> портал», предупреждение о врагах,
## сенсорные кнопки и экраны (меню / пауза / победа / поражение).
## Весь интерфейс строится кодом, отдельная сцена не нужна.

signal start_requested
signal resume_requested
signal pause_requested
signal sound_requested

const PINK := Color(1, 0.56, 0.77)
const DARK := Color(0.17, 0.09, 0.19, 0.88)

var touch_keys := {"left": false, "right": false, "jump": false, "shoot": false}

var _hud_root: Control
var _hearts: Label
var _coins: Label
var _gems: Label
var _combo: Label
var _timer: Label
var _foes: Label
var _energy: ProgressBar
var _progress_fill: ColorRect
var _progress_track: ColorRect
var _progress_marker: ColorRect
var _progress_frac := 0.0
var _toast: PanelContainer
var _toast_left := 0.0
var _sound_btn: Button

var _menu: Control
var _pause: Control
var _win: Control
var _over: Control
var _win_stats: Label
var _over_stats: Label
var _touch_root: Control


func _panel(bg: Color = DARK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(1, 0.59, 0.80, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.2, 0, 0.15, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _big_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 52)
	b.add_theme_font_size_override("font_size", 20)
	for state_name in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.91, 0.33, 0.61) if state_name != "pressed" else Color(0.78, 0.22, 0.5)
		sb.border_color = Color(1, 0.82, 0.90)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(26)
		b.add_theme_stylebox_override(state_name, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b


func _full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_touch()
	_menu = _build_overlay("МИЛА", "1-4  •  САКУРОВЫЙ ЛЕС",
		"Добеги от розового флажка на левом краю леса до крайнего правого храма с крутящейся розовой воронкой. Прыгай по платформам, стреляй звёздочками по врагам — каждый патрулирует свою платформу, — собирай монеты и кристаллы!\n\nУправление:  стрелки / A D — движение,  стрелка вверх / W / Пробел — прыжок (в воздухе ещё раз),  Z / X / J или мышь — стрельба,  P / Esc — пауза,  M — звук,  R — заново.",
		"Играть", true)
	_pause = _build_overlay("Пауза", "", "Лепестки сакуры подождут.", "Продолжить", false)
	_win = _build_overlay("Уровень пройден!", "", "Мила добралась до храма и шагнула в крутящуюся розовую воронку!", "Играть ещё раз", false)
	_over = _build_overlay("Ох, Мила упала…", "", "Сердечки закончились. Но сакуровый лес верит в тебя — попробуй ещё раз!", "Попробовать снова", false)
	_menu.get_meta("button").pressed.connect(func() -> void: start_requested.emit())
	_win.get_meta("button").pressed.connect(func() -> void: start_requested.emit())
	_over.get_meta("button").pressed.connect(func() -> void: start_requested.emit())
	_pause.get_meta("button").pressed.connect(func() -> void: resume_requested.emit())
	_win_stats = _win.get_meta("stats")
	_over_stats = _over.get_meta("stats")
	show_menu()


func _build_hud() -> void:
	_hud_root = _full_rect(Control.new())
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	# Профиль слева сверху.
	var profile := _panel()
	profile.position = Vector2(12, 12)
	_hud_root.add_child(profile)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	profile.add_child(hbox)
	var portrait := TextureRect.new()
	portrait.texture = preload("res://assets/sprites/hero_idle.png")
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(portrait)
	var vbox := VBoxContainer.new()
	hbox.add_child(vbox)
	vbox.add_child(_label("МИЛА", 22, Color(1, 0.84, 0.93)))
	_hearts = _label("", 18, Color(1, 0.37, 0.62))
	vbox.add_child(_hearts)
	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 12)
	vbox.add_child(res)
	_coins = _label("Монеты: 0", 14, Color(1, 0.85, 0.30))
	_gems = _label("Кристаллы: 0", 14, Color(0.50, 0.89, 1))
	res.add_child(_coins)
	res.add_child(_gems)

	# Баннер уровня и прогресс по центру.
	var banner := _label("1-4  •  САКУРОВЫЙ ЛЕС", 19, Color(1, 0.91, 0.96))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -260
	banner.offset_right = 260
	banner.offset_top = 14
	banner.offset_bottom = 42
	_hud_root.add_child(banner)
	var track_box := Control.new()
	track_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	track_box.offset_left = -210
	track_box.offset_right = 210
	track_box.offset_top = 50
	track_box.offset_bottom = 62
	track_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(track_box)
	_progress_track = ColorRect.new()
	_progress_track.color = Color(0.12, 0.04, 0.14, 0.65)
	_full_rect(_progress_track)
	track_box.add_child(_progress_track)
	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(1, 0.56, 0.77)
	_progress_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	track_box.add_child(_progress_fill)
	_progress_marker = ColorRect.new()
	_progress_marker.color = Color(1, 0.85, 0.30)
	_progress_marker.size = Vector2(8, 16)
	_progress_marker.position = Vector2(-4, -2)
	track_box.add_child(_progress_marker)

	# Комбо, таймер и кнопки справа сверху.
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -430
	right.offset_right = -12
	right.offset_top = 12
	right.offset_bottom = 56
	_hud_root.add_child(right)
	var combo_panel := _panel()
	right.add_child(combo_panel)
	_combo = _label("Комбо x0", 16, Color(1, 0.85, 0.30))
	combo_panel.add_child(_combo)
	var timer_panel := _panel()
	right.add_child(timer_panel)
	_timer = _label("00:00", 16)
	timer_panel.add_child(_timer)
	_sound_btn = Button.new()
	_sound_btn.text = "Звук и музыка: вкл"
	_sound_btn.pressed.connect(func() -> void: sound_requested.emit())
	right.add_child(_sound_btn)
	var pause_btn := Button.new()
	pause_btn.text = "Пауза"
	pause_btn.pressed.connect(func() -> void: pause_requested.emit())
	right.add_child(pause_btn)

	# Подсказки слева внизу.
	var hints := _panel()
	hints.position = Vector2(12, 720 - 58)
	_hud_root.add_child(hints)
	hints.add_child(_label("Стрелки — движение   •   Вверх/Пробел — прыжок x2   •   Z — атака", 13, Color(1, 0.89, 0.95)))

	# Оружие и энергия справа внизу.
	var weapon := _panel()
	weapon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	weapon.grow_vertical = Control.GROW_DIRECTION_BEGIN
	weapon.offset_left = -292
	weapon.offset_right = -12
	weapon.offset_top = -78
	weapon.offset_bottom = -12
	_hud_root.add_child(weapon)
	var wvbox := VBoxContainer.new()
	weapon.add_child(wvbox)
	wvbox.add_child(_label("ЗВЁЗДНЫЙ БЛАСТЕР  •  ЭНЕРГИЯ", 12, Color(1, 0.84, 0.93)))
	_energy = ProgressBar.new()
	_energy.min_value = 0
	_energy.max_value = 100
	_energy.value = 100
	_energy.show_percentage = false
	_energy.custom_minimum_size = Vector2(250, 12)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0, 0, 0, 0.45)
	bg_sb.set_corner_radius_all(6)
	_energy.add_theme_stylebox_override("background", bg_sb)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(1, 0.37, 0.66)
	fill_sb.set_corner_radius_all(6)
	_energy.add_theme_stylebox_override("fill", fill_sb)
	wvbox.add_child(_energy)
	_foes = _label("Врагов осталось: 0", 12, Color(0.91, 0.85, 1))
	wvbox.add_child(_foes)

	# Предупреждение о врагах.
	_toast = _panel(Color(1, 0.92, 0.97, 0.95))
	_toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.offset_left = -330
	_toast.offset_right = -14
	_toast.offset_top = 86
	_toast.offset_bottom = 126
	_toast.add_child(_label("ОСТОРОЖНО! ВРАГИ!", 16, Color(0.36, 0.13, 0.27)))
	_toast.visible = false
	_hud_root.add_child(_toast)


func _build_touch() -> void:
	_touch_root = _full_rect(Control.new())
	_touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_root)
	var defs := [
		["left", "<", Vector2(18, 720 - 150)], ["right", ">", Vector2(96, 720 - 150)],
		["shoot", "S", Vector2(1280 - 176, 720 - 150)], ["jump", "^", Vector2(1280 - 88, 720 - 150)],
	]
	for d in defs:
		var b := Button.new()
		b.text = str(d[1])
		var btn_pos: Vector2 = d[2]
		b.position = btn_pos
		b.size = Vector2(64, 64)
		b.add_theme_font_size_override("font_size", 24)
		var key: String = d[0]
		b.button_down.connect(func() -> void: touch_keys[key] = true)
		b.button_up.connect(func() -> void: touch_keys[key] = false)
		_touch_root.add_child(b)
	_touch_root.visible = DisplayServer.is_touchscreen_available()


func _build_overlay(title: String, subtitle: String, text: String, button_text: String, is_menu: bool) -> Control:
	var root := Control.new()
	_full_rect(root)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.03, 0.13, 0.55)
	_full_rect(dim)
	root.add_child(dim)
	var centre := CenterContainer.new()
	_full_rect(centre)
	root.add_child(centre)
	var card := _panel(Color(0.20, 0.10, 0.23, 0.97))
	card.custom_minimum_size = Vector2(560, 0)
	centre.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	var title_label := _label(title, 38, Color(1, 0.84, 0.93))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	if subtitle != "":
		var sub := _label(subtitle, 17, Color(1, 0.73, 0.85))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sub)
	var body := _label(text, 15, Color(0.96, 0.91, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	vbox.add_child(body)
	var stats := _label("", 16, Color(1, 0.85, 0.30))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.visible = not is_menu  # строки статистики заполняет главный скрипт
	vbox.add_child(stats)
	var btn := _big_button(button_text)
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_child(btn)
	vbox.add_child(btn_box)
	root.set_meta("button", btn)
	root.set_meta("stats", stats)
	return root


func _process(delta: float) -> void:
	if _toast.visible:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false
	# Маркер прогресса по доле пути.
	if is_instance_valid(_progress_track) and _progress_track.size.x > 4.0:
		_progress_fill.anchor_right = _progress_frac
		_progress_marker.position.x = _progress_frac * _progress_track.size.x - 4.0


func show_toast() -> void:
	_toast.visible = true
	_toast_left = 2.4


func set_sound_text(on: bool) -> void:
	_sound_btn.text = "Звук и музыка: вкл" if on else "Звук и музыка: выкл"


func set_stats(hp: int, coins: int, gems: int, combo: int, foes: int, energy: float, time_sec: float, progress: float) -> void:
	_hearts.text = "♥".repeat(maxi(0, hp)) + "♡".repeat(maxi(0, 5 - hp))
	_coins.text = "Монеты: %d" % coins
	_gems.text = "Кристаллы: %d" % gems
	_combo.text = "Комбо x%d" % combo
	_timer.text = "%02d:%02d" % [int(time_sec) / 60, int(time_sec) % 60]
	_foes.text = "Врагов осталось: %d" % foes
	_energy.value = energy
	_progress_frac = clampf(progress, 0.0, 1.0)


func _show_only(which: Control) -> void:
	for overlay in [_menu, _pause, _win, _over]:
		overlay.visible = overlay == which
	_hud_root.visible = which == null or which == _pause


func show_menu() -> void:
	_show_only(_menu)


func show_game() -> void:
	_show_only(null)
	_hud_root.visible = true


func show_pause() -> void:
	_show_only(_pause)


func show_win(stats_text: String) -> void:
	_win_stats.text = stats_text
	_show_only(_win)


func show_over(stats_text: String) -> void:
	_over_stats.text = stats_text
	_show_only(_over)
