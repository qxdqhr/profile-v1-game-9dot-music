extends RefCounted
class_name NineDotMedia
## Load builtin chart audio/video; keep video glued to audio timeline (anti-desync).

const VIDEO_SYNC_TOLERANCE_SEC := 0.08

static func load_audio(path: String) -> AudioStream:
	if path.is_empty() or path.begins_with("generated://"):
		return null
	if not ResourceLoader.exists(path):
		push_warning("Audio missing: %s" % path)
		return null
	return load(path) as AudioStream

static func load_video(path: String) -> VideoStream:
	if path.is_empty() or path == "none":
		return null
	if not ResourceLoader.exists(path):
		push_warning("Video missing: %s" % path)
		return null
	return load(path) as VideoStream

static func start_av(audio: AudioStreamPlayer, video: VideoStreamPlayer) -> void:
	if audio and audio.stream:
		audio.play(0.0)
	if video and video.stream:
		video.paused = false
		video.play()

static func pause_av(audio: AudioStreamPlayer, video: VideoStreamPlayer, paused: bool) -> void:
	if audio:
		audio.stream_paused = paused
	if video and video.stream:
		video.paused = paused

static func stop_av(audio: AudioStreamPlayer, video: VideoStreamPlayer) -> void:
	if audio:
		audio.stop()
		audio.stream_paused = false
	if video and video.stream:
		video.paused = false
		video.stop()

## Call every frame while playing: audio is master, video seeks if drift exceeds tolerance.
static func sync_video_to_audio(audio: AudioStreamPlayer, video: VideoStreamPlayer) -> void:
	if audio == null or video == null or video.stream == null:
		return
	if not audio.playing:
		return
	var target := audio.get_playback_position()
	if absf(video.stream_position - target) > VIDEO_SYNC_TOLERANCE_SEC:
		video.stream_position = target
