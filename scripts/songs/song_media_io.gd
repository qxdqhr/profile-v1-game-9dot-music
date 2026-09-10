extends RefCounted
class_name SongMediaIo
## Load audio/video from res:// (imported) or user:// (runtime decode).

static func load_audio(path: String) -> AudioStream:
	if path.is_empty() or path.begins_with("generated://"):
		return null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
		push_warning("Audio missing: %s" % path)
		return null
	if not FileAccess.file_exists(path):
		push_warning("Audio missing: %s" % path)
		return null
	var lower := path.to_lower()
	if lower.ends_with(".ogg") or lower.ends_with(".oga"):
		var stream := AudioStreamOggVorbis.load_from_file(path)
		if stream:
			return stream
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	push_warning("Audio unsupported or failed: %s" % path)
	return null

static func load_video(path: String) -> VideoStream:
	if path.is_empty() or path == "none":
		return null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			return load(path) as VideoStream
		push_warning("Video missing: %s" % path)
		return null
	if not FileAccess.file_exists(path):
		push_warning("Video missing: %s" % path)
		return null
	var lower := path.to_lower()
	if lower.ends_with(".ogv") or lower.ends_with(".ogg"):
		var vs := VideoStreamTheora.new()
		vs.file = path
		return vs
	if ResourceLoader.exists(path):
		return load(path) as VideoStream
	push_warning("Video unsupported or failed: %s" % path)
	return null
