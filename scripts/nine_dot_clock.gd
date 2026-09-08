extends Node
class_name NineDotClock
## Audio-master clock with Godot mix/latency compensation (monotonic).

signal ended

var _player: AudioStreamPlayer
var _offset_ms: int = 0
var _chart_offset_ms: int = 0
var _fallback_start_usec: int = 0
var _use_fallback: bool = true
var _playing: bool = false
var _paused: bool = false
var _duration_ms: int = 0
var _frozen_raw_ms: int = 0
var _last_raw_ms: int = 0

func setup(player: AudioStreamPlayer, chart_offset_ms: int, player_offset_ms: int, duration_ms: int) -> void:
	_player = player
	_chart_offset_ms = chart_offset_ms
	_offset_ms = player_offset_ms
	_duration_ms = duration_ms
	_use_fallback = player == null or player.stream == null
	_last_raw_ms = 0

func start() -> void:
	_playing = true
	_paused = false
	_frozen_raw_ms = 0
	_last_raw_ms = 0
	_fallback_start_usec = Time.get_ticks_usec()
	if not _use_fallback and _player:
		_player.play(0.0)

func pause() -> void:
	if not _playing or _paused:
		return
	_frozen_raw_ms = _raw_ms_now()
	_paused = true
	if not _use_fallback and _player:
		_player.stream_paused = true

func resume() -> void:
	if not _playing or not _paused:
		return
	_paused = false
	if _use_fallback:
		_fallback_start_usec = Time.get_ticks_usec() - _frozen_raw_ms * 1000
	if not _use_fallback and _player:
		_player.stream_paused = false

func stop() -> void:
	_playing = false
	_paused = false
	_last_raw_ms = 0
	if _player:
		_player.stop()
		_player.stream_paused = false

func is_playing() -> bool:
	return _playing and not _paused

func now_ms() -> int:
	if not _playing:
		return 0
	var raw := _frozen_raw_ms if _paused else _raw_ms_now()
	return raw + _chart_offset_ms + _offset_ms

func _raw_ms_now() -> int:
	if _use_fallback or _player == null or not _player.playing:
		var fb := int((Time.get_ticks_usec() - _fallback_start_usec) / 1000.0)
		_last_raw_ms = maxi(_last_raw_ms, fb)
		return _last_raw_ms
	# Godot docs: playback + since_last_mix - output_latency (Android latency often 0).
	var sec := _player.get_playback_position()
	sec += AudioServer.get_time_since_last_mix()
	sec -= AudioServer.get_output_latency()
	var ms := int(sec * 1000.0)
	if ms < _last_raw_ms:
		ms = _last_raw_ms
	else:
		_last_raw_ms = ms
	return ms

func poll_ended() -> bool:
	if not _playing or _paused:
		return false
	if now_ms() >= _duration_ms:
		_playing = false
		if _player:
			_player.stop()
		ended.emit()
		return true
	return false
