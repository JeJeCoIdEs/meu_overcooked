extends Node
class_name SoundEffects

static var _instance: SoundEffects = null

var _players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}

static func get_instance() -> SoundEffects:
	return _instance

func _enter_tree() -> void:
	_instance = self

func _ready() -> void:
	# Cria pool de AudioStreamPlayers para tocar vários sons simultaneamente
	for i in range(8):
		var p = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)
		
	_generate_all_sfx()

func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func play(sfx_name: String, pitch_scale: float = 1.0) -> void:
	if not _sfx_cache.has(sfx_name):
		return
	var player = _get_free_player()
	player.stream = _sfx_cache[sfx_name]
	player.pitch_scale = pitch_scale
	player.play()

func _generate_all_sfx() -> void:
	_sfx_cache["pickup"] = _make_pop_sfx(700.0, 300.0, 0.07)
	_sfx_cache["drop"] = _make_pop_sfx(350.0, 150.0, 0.05)
	_sfx_cache["chop"] = _make_chop_sfx()
	_sfx_cache["deliver"] = _make_deliver_sfx()
	_sfx_cache["deliver_big"] = _make_deliver_big_sfx()
	_sfx_cache["trash"] = _make_trash_sfx()
	_sfx_cache["win"] = _make_win_sfx()

func _create_stream(data: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _make_pop_sfx(start_freq: float, end_freq: float, duration: float) -> AudioStreamWAV:
	var rate = 22050
	var total_samples = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(rate)
		var progress = float(i) / float(total_samples)
		var freq = lerp(start_freq, end_freq, progress)
		phase += 2.0 * PI * freq / float(rate)
		
		# Envelope com ataque instantâneo e decaimento exponencial
		var env = exp(-t * 35.0)
		var s = sin(phase) * env
		bytes[i] = clampi(int(s * 120.0 + 128.0), 0, 255)
		
	return _create_stream(bytes, rate)

func _make_chop_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.08
	var total_samples = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(rate)
		# Ruído seco combinado com impacto grave
		var noise = randf_range(-1.0, 1.0)
		phase += 2.0 * PI * 130.0 / float(rate)
		var env = exp(-t * 45.0)
		var s = (noise * 0.7 + sin(phase) * 0.5) * env
		bytes[i] = clampi(int(s * 125.0 + 128.0), 0, 255)
		
	return _create_stream(bytes, rate)

func _make_deliver_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.35
	var total_samples = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples)
	
	var phase1 = 0.0
	var phase2 = 0.0
	for i in range(total_samples):
		var t = float(i) / float(rate)
		# Duas notas brilhantes tipo sino (G5 784Hz -> C6 1046Hz)
		var f1 = 784.0 if t < 0.12 else 1046.0
		var f2 = 1568.0 if t < 0.12 else 2093.0
		phase1 += 2.0 * PI * f1 / float(rate)
		phase2 += 2.0 * PI * f2 / float(rate)
		
		var env = exp(-fmod(t, 0.12) * 15.0) * (1.0 - t / duration)
		var s = (sin(phase1) * 0.7 + sin(phase2) * 0.3) * env
		bytes[i] = clampi(int(s * 120.0 + 128.0), 0, 255)
		
	return _create_stream(bytes, rate)

func _make_deliver_big_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.5
	var total_samples = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples)
	
	var notes = [523.25, 659.25, 783.99, 1046.50] # C5, E5, G5, C6
	var note_dur = 0.1
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(rate)
		var note_idx = mini(int(t / note_dur), notes.size() - 1)
		var freq = notes[note_idx]
		phase += 2.0 * PI * freq / float(rate)
		
		var t_in_note = fmod(t, note_dur) if note_idx < notes.size() - 1 else (t - (notes.size() - 1) * note_dur)
		var env = exp(-t_in_note * 12.0)
		var s = (sin(phase) + 0.3 * sin(phase * 2.0)) * env
		bytes[i] = clampi(int(s * 115.0 + 128.0), 0, 255)
		
	return _create_stream(bytes, rate)

func _make_trash_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.15
	var total_samples = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples)
	
	var phase = 0.0
	for i in range(total_samples):
		var t = float(i) / float(rate)
		var progress = float(i) / float(total_samples)
		var freq = lerp(450.0, 90.0, progress)
		phase += 2.0 * PI * freq / float(rate)
		var noise = randf_range(-0.4, 0.4)
		var env = exp(-t * 20.0)
		var s = (sin(phase) * 0.6 + noise) * env
		bytes[i] = clampi(int(s * 110.0 + 128.0), 0, 255)
		
	return _create_stream(bytes, rate)

func _make_win_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.8
	var total_samples = int(duration * rate)
	var bytes = PackedByteArray()
	bytes.resize(total_samples)
	
	var chords = [523.25, 659.25, 783.99, 1046.50]
	var phase1 = 0.0
	var phase2 = 0.0
	for i in range(total_samples):
		var t = float(i) / float(rate)
		var chord_idx = mini(int(t / 0.18), chords.size() - 1)
		var base_f = chords[chord_idx]
		phase1 += 2.0 * PI * base_f / float(rate)
		phase2 += 2.0 * PI * (base_f * 1.5) / float(rate)
		
		var env = 1.0 - (t / duration) * 0.7
		var s = (sin(phase1) * 0.5 + sin(phase2) * 0.4) * env
		bytes[i] = clampi(int(s * 120.0 + 128.0), 0, 255)
		
	return _create_stream(bytes, rate)
