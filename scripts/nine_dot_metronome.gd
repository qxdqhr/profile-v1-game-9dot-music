extends RefCounted
class_name NineDotMetronome
## Build a mono click track AudioStreamWAV for audio-master clock (MVP placeholder).

static func build_stream(duration_ms: int, bpm: float, click_ms: Array = []) -> AudioStreamWAV:
	var rate := 44100
	var total_samples := int(rate * duration_ms / 1000.0) + rate
	var data := PackedByteArray()
	data.resize(total_samples * 2)
	for i in range(total_samples * 2):
		data[i] = 0

	var times: Array = click_ms.duplicate()
	if times.is_empty():
		var interval := int(60000.0 / maxf(bpm, 1.0))
		var t := 0
		while t < duration_ms:
			times.append(t)
			t += interval

	for t_ms in times:
		_write_click(data, rate, int(t_ms))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

static func _write_click(data: PackedByteArray, rate: int, t_ms: int) -> void:
	var start := int(rate * t_ms / 1000.0)
	var length := int(rate * 0.02)
	for i in range(length):
		var idx := start + i
		if idx < 0 or idx * 2 + 1 >= data.size():
			break
		var env := 1.0 - float(i) / float(length)
		var sample := int(sin(float(i) * 0.8) * 12000.0 * env)
		sample = clampi(sample, -32767, 32767)
		data[idx * 2] = sample & 0xFF
		data[idx * 2 + 1] = (sample >> 8) & 0xFF
