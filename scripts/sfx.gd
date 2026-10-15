extends Node
## Короткие звуковые эффекты, синтезированные в коде (без аудиофайлов):
## генерируем AudioStreamWAV и играем через пул плееров.

const MIX_RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var muted := false


func _ready() -> void:
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["shoot"] = _sweep(920.0, 240.0, 0.12, true)
	_streams["jump"] = _sweep(300.0, 640.0, 0.14, false)
	_streams["coin"] = _melody([950.0, 1420.0], 0.09)
	_streams["gem"] = _sweep(700.0, 1400.0, 0.16, false)
	_streams["hit"] = _sweep(220.0, 90.0, 0.14, true)
	_streams["hurt"] = _sweep(420.0, 110.0, 0.24, true)
	_streams["die"] = _sweep(520.0, 60.0, 0.45, false)
	_streams["win"] = _melody([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.13)


func _make_wav(samples: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = samples
	return wav


func _sweep(f0: float, f1: float, dur: float, square: bool) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n)
	var phase := 0.0
	for i in range(n):
		var k := float(i) / float(maxi(1, n))
		var freq := lerpf(f0, f1, k)
		phase += freq / MIX_RATE
		var v: float
		if square:
			v = 1.0 if sin(phase * TAU) >= 0.0 else -1.0
		else:
			v = sin(phase * TAU)
		var env := 1.0 - k
		data[i] = int(clampf(128.0 + v * env * 52.0, 0.0, 255.0))
	return _make_wav(data)


func _melody(notes: Array, note_dur: float) -> AudioStreamWAV:
	var per := int(MIX_RATE * note_dur)
	var data := PackedByteArray()
	for note in notes:
		var freq := float(note)
		for i in range(per):
			var env := 1.0 - float(i) / float(per) * 0.6
			var v := sin(float(i) * freq / MIX_RATE * TAU)
			data.append(int(clampf(128.0 + v * env * 48.0, 0.0, 255.0)))
	return _make_wav(data)


func play(sfx_name: String) -> void:
	if muted or not _streams.has(sfx_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.play()
