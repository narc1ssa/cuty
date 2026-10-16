extends Node
## Фоновая музыка, синтезированная в коде (без аудиофайлов):
## генерируем зацикленный AudioStreamWAV и играем через AudioStreamPlayer.
## Громкость управляется общим флагом `muted` (клавиша M).

const MIX_RATE := 22050

var muted := false
var _player: AudioStreamPlayer = null
var _stream: AudioStreamWAV = null


func _ready() -> void:
	_stream = _make_music()
	_player = AudioStreamPlayer.new()
	_player.stream = _stream
	_player.volume_db = -14.0
	add_child(_player)
	_player.play()


func _make_music() -> AudioStreamWAV:
	# Спокойная пентатоническая мелодия в духе «сакурового леса».
	var notes := [
		[523.25, 0.4], [659.25, 0.4], [783.99, 0.4], [659.25, 0.4],
		[523.25, 0.4], [392.00, 0.4], [440.00, 0.4], [523.25, 0.8],
		[587.33, 0.4], [659.25, 0.4], [783.99, 0.4], [880.00, 0.4],
		[783.99, 0.4], [659.25, 0.4], [523.25, 0.4], [392.00, 0.8],
	]
	var data := PackedByteArray()
	for note in notes:
		var freq := float(note[0])
		var dur := float(note[1])
		var n := int(MIX_RATE * dur)
		var phase := 0.0
		for i in range(n):
			var k := float(i) / float(maxi(1, n))
			phase += freq / MIX_RATE
			var v := sin(phase * TAU) * 0.7 + sin(phase * TAU * 2.0) * 0.2
			var env := (1.0 - k * 0.3) * minf(1.0, k * 10.0)
			data.append(int(clampf(128.0 + v * env * 26.0, 0.0, 255.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = data.size()
	wav.data = data
	return wav


func play() -> void:
	if _player != null and not _player.playing:
		_player.play()


func stop() -> void:
	if _player != null:
		_player.stop()


func set_muted(m: bool) -> void:
	muted = m
	if _player != null:
		_player.volume_db = -80.0 if m else -14.0
