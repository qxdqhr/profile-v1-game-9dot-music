extends RefCounted
class_name NineDotFeedback
## Hit / miss SFX (procedural) + handheld vibration.

static var _tap_stream: AudioStreamWAV
static var _slide_stream: AudioStreamWAV
static var _miss_stream: AudioStreamWAV
static var _empty_stream: AudioStreamWAV

static func ensure_streams() -> void:
	if _tap_stream == null:
		_tap_stream = _make_blip(880.0, 45, 0.55)
	if _slide_stream == null:
		_slide_stream = _make_blip(520.0, 70, 0.5)
	if _miss_stream == null:
		_miss_stream = _make_noise_blip(90, 0.28)
	if _empty_stream == null:
		_empty_stream = _make_blip(220.0, 35, 0.22)

static func play_tap(player: AudioStreamPlayer) -> void:
	ensure_streams()
	_play(player, _tap_stream)

static func play_slide(player: AudioStreamPlayer) -> void:
	ensure_streams()
	_play(player, _slide_stream)

static func play_miss(player: AudioStreamPlayer) -> void:
	ensure_streams()
	_play(player, _miss_stream)

static func play_empty(player: AudioStreamPlayer) -> void:
	ensure_streams()
	_play(player, _empty_stream)

static func vibrate_arm() -> void:
	if not AppSettings.vibration_enabled:
		return
	Input.vibrate_handheld(NineDotConfig.HAPTIC_ARM_MS, NineDotConfig.HAPTIC_ARM_AMP)

static func vibrate_complete() -> void:
	if not AppSettings.vibration_enabled:
		return
	Input.vibrate_handheld(NineDotConfig.HAPTIC_COMPLETE_MS, NineDotConfig.HAPTIC_COMPLETE_AMP)

static func vibrate_miss() -> void:
	if not AppSettings.vibration_enabled:
		return
	Input.vibrate_handheld(NineDotConfig.HAPTIC_MISS_MS, NineDotConfig.HAPTIC_MISS_AMP)

static func _play(player: AudioStreamPlayer, stream: AudioStreamWAV) -> void:
	if not AppSettings.hit_sfx_enabled or player == null or stream == null:
		return
	player.stream = stream
	player.volume_db = linear_to_db(maxi(0.001, AppSettings.volume_linear))
	player.play()

static func _make_blip(freq_hz: float, duration_ms: int, peak: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * duration_ms / 1000.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var env := 1.0 - float(i) / float(maxi(n - 1, 1))
		env = env * env
		var sample := int(clampf(sin(TAU * freq_hz * t) * peak * env, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _pack_wav(data, rate)

static func _make_noise_blip(duration_ms: int, peak: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * duration_ms / 1000.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in range(n):
		var env := 1.0 - float(i) / float(maxi(n - 1, 1))
		env = env * env
		var sample := int(clampf((rng.randf() * 2.0 - 1.0) * peak * env, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _pack_wav(data, rate)

static func _pack_wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
