extends Node
## Synthesized weapon voices. No audio files. Unlocks with the first button press.

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _unlocked: bool = false
const RATE := 22050


func _ready() -> void:
	_streams = {
		"ui": _ui(),
		"rail": _rail(),
		"missile": _missile(),
		"laser": _laser(),
		"tesla": _tesla(),
		"flame": _flame(),
		"drone": _drone(),
		"hit": _hit(),
		"hull": _hull(),
		"level": _arpeggio(),
		"dead": _dead(),
	}
	for _i in 16:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_apply_bus()


func unlock() -> void:
	_unlocked = true


func play(kind: String) -> void:
	if not _unlocked:
		return
	if Profile.sfx_volume <= 0.01:
		return
	if not _streams.has(kind):
		return
	for player in _players:
		if not player.playing:
			player.stream = _streams[kind]
			player.volume_db = linear_to_db(clampf(Profile.sfx_volume, 0.001, 1.0))
			player.play()
			return


func apply_volume() -> void:
	_apply_bus()


func _apply_bus() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if Profile.sfx_volume <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(Profile.sfx_volume))


func _ui() -> AudioStreamWAV:
	return _sweep(0.045, 740.0, 990.0, 0.2, 0.0, 1.4)


func _rail() -> AudioStreamWAV:
	# A short crack: noise spike, then a metal chirp falling fast.
	var dur := 0.055
	var count := _count(dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		var freq := lerpf(2400.0, 680.0, u)
		phase += TAU * freq / float(RATE)
		var crack := (randf() * 2.0 - 1.0) * pow(1.0 - u, 6.0)
		var body := sin(phase) * 0.65 + sin(phase * 2.15) * 0.22
		var env := pow(1.0 - u, 1.35)
		_write(data, i, (crack * 0.85 + body * env) * 0.42, dur, float(i) / float(RATE))
	return _wav(data)


func _missile() -> AudioStreamWAV:
	# Rocket whoosh: low rising body under brown noise.
	var dur := 0.28
	var count := _count(dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var brown := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var u := float(i) / float(count)
		var freq := lerpf(70.0, 150.0, u)
		phase += TAU * freq / float(RATE)
		brown = clampf(brown + (randf() * 2.0 - 1.0) * 0.12, -1.0, 1.0)
		var attack := clampf(t / 0.03, 0.0, 1.0)
		var env := attack * pow(1.0 - u, 0.65)
		var sample := (sin(phase) * 0.45 + brown * 0.7) * env
		_write(data, i, sample * 0.4, dur, t)
	return _wav(data)


func _laser() -> AudioStreamWAV:
	# Clean beam pulse. Short, so the damage ticks read as a pulsed laser.
	var dur := 0.09
	var count := _count(dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		var freq := lerpf(620.0, 980.0, u)
		phase += TAU * freq / float(RATE)
		var env := sin(u * PI)
		var body := sin(phase) * 0.75 + sin(phase * 2.0) * 0.18
		_write(data, i, body * env * 0.28, dur, float(i) / float(RATE))
	return _wav(data)


func _tesla() -> AudioStreamWAV:
	# Buzz plus random arc pops.
	var dur := 0.13
	var count := _count(dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		phase += TAU * 95.0 / float(RATE)
		var buzz := sin(phase) * 0.35 + sin(phase * 3.0) * 0.2
		var pop := 0.0
		if randf() < 0.08:
			pop = (randf() * 2.0 - 1.0) * randf_range(0.4, 1.0)
		var zap := sin(phase * lerpf(14.0, 28.0, randf())) * (1.0 if randf() < 0.25 else 0.15)
		var env := pow(1.0 - u, 0.45)
		_write(data, i, (buzz + pop * 0.8 + zap * 0.25) * env * 0.38, dur, float(i) / float(RATE))
	return _wav(data)


func _flame() -> AudioStreamWAV:
	# A burst of fire. Ticks sit close enough to read as a roar.
	var dur := 0.16
	var count := _count(dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var brown := 0.0
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		phase += TAU * 58.0 / float(RATE)
		brown = clampf(brown * 0.96 + (randf() * 2.0 - 1.0) * 0.18, -1.0, 1.0)
		var crack := 0.0
		if randf() < 0.04:
			crack = randf()
		var env := sin(clampf(u, 0.0, 1.0) * PI)
		var sample := (brown * 0.75 + sin(phase) * 0.2 + crack * 0.35) * env
		_write(data, i, sample * 0.36, dur, float(i) / float(RATE))
	return _wav(data)


func _drone() -> AudioStreamWAV:
	return _sweep(0.04, 980.0, 1560.0, 0.16, 0.05, 1.8)


func _hit() -> AudioStreamWAV:
	return _sweep(0.035, 1800.0, 900.0, 0.16, 0.15, 2.2)


func _hull() -> AudioStreamWAV:
	var dur := 0.2
	var count := _count(dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		phase += TAU * lerpf(110.0, 55.0, u) / float(RATE)
		var env := pow(1.0 - u, 0.7)
		var thump := sin(phase) * 0.7 + (randf() * 2.0 - 1.0) * 0.35 * (1.0 - u)
		_write(data, i, thump * env * 0.46, dur, float(i) / float(RATE))
	return _wav(data)


func _dead() -> AudioStreamWAV:
	return _sweep(0.42, 160.0, 48.0, 0.4, 0.12, 0.55)


func _arpeggio() -> AudioStreamWAV:
	var dur := 0.28
	var count := _count(dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var freqs: Array[float] = [523.0, 659.0, 784.0]
	var phase := 0.0
	var slice := maxi(int(count / 3), 1)
	for i in count:
		var which := mini(int(float(i) / float(count) * 3.0), 2)
		phase += TAU * freqs[which] / float(RATE)
		var env := 1.0 - float(i % slice) / float(slice)
		_write(data, i, sin(phase) * env * 0.28, dur, float(i) / float(RATE))
	return _wav(data)


func _sweep(dur: float, from_hz: float, to_hz: float, volume: float, noise: float, decay: float) -> AudioStreamWAV:
	var count := _count(dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		phase += TAU * lerpf(from_hz, to_hz, u) / float(RATE)
		var env := pow(1.0 - u, decay)
		var sample := sin(phase) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		_write(data, i, sample * env * volume, dur, float(i) / float(RATE))
	return _wav(data)


func _count(dur: float) -> int:
	return maxi(int(RATE * dur), 8)


func _write(data: PackedByteArray, i: int, sample_f: float, dur: float, t: float) -> void:
	var edge := clampf(minf(t / 0.003, (dur - t) / 0.004), 0.0, 1.0)
	data.encode_s16(i * 2, int(clampf(sample_f * edge, -1.0, 1.0) * 32767.0))


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
