extends Node
## Фоновая музыка уровня: чередование двух настоящих мелодий из файлов
## res://music.mp3 и res://music_soft.mp3. Как только одна дорожка
## заканчивается — тут же начинает играть следующая, и так по кругу
## бесконечно (без разрывов между переключениями).
## Громкость управляется общим флагом `muted` (клавиша M).

const TRACK_PATHS := ["res://music.mp3", "res://music_soft.mp3"]
const VOLUME_DB := -10.0

var muted := false
var _player: AudioStreamPlayer = null
var _tracks: Array = []
var _track_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in TRACK_PATHS:
		var stream: AudioStream = load(path)
		if stream != null:
			_tracks.append(stream)
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.finished.connect(_play_next)
	_play_current()


func _play_current() -> void:
	if _tracks.is_empty():
		return
	_player.stream = _tracks[_track_index]
	_player.play()


func _play_next() -> void:
	if _tracks.is_empty():
		return
	_track_index = (_track_index + 1) % _tracks.size()
	_play_current()


func play() -> void:
	if _player != null and not _player.playing:
		_play_current()


func stop() -> void:
	if _player != null:
		_player.stop()


func set_muted(m: bool) -> void:
	muted = m
	if _player != null:
		_player.volume_db = -80.0 if m else VOLUME_DB
