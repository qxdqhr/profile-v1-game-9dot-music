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
	if FileAccess.file_exists(path):
		var lower := path.to_lower()
		if lower.ends_with(".ogg") or lower.ends_with(".oga"):
			var stream := AudioStreamOggVorbis.load_from_file(path)
			if stream:
				return stream
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	# Official seed used to copy remapped import bytes into user:// — fall back to res://.
	var res_fallback := _official_res_fallback(path, "audio.ogg")
	if res_fallback != "" and ResourceLoader.exists(res_fallback):
		push_warning("Audio user copy unusable, using %s" % res_fallback)
		return load(res_fallback) as AudioStream
	push_warning("Audio missing: %s" % path)
	return null

static func load_video(path: String) -> VideoStream:
	if path.is_empty() or path == "none":
		return null
	if path.begins_with("res://"):
		# ogv may exist as packed file without ResourceLoader type.
		if ResourceLoader.exists(path):
			return load(path) as VideoStream
		if FileAccess.file_exists(path):
			var vs_res := VideoStreamTheora.new()
			vs_res.file = path
			return vs_res
		push_warning("Video missing: %s" % path)
		return null
	if FileAccess.file_exists(path):
		var lower := path.to_lower()
		if lower.ends_with(".ogv") or lower.ends_with(".ogg"):
			var vs := VideoStreamTheora.new()
			vs.file = path
			return vs
		if ResourceLoader.exists(path):
			return load(path) as VideoStream
	var res_fallback := _official_res_fallback(path, "video.ogv")
	if res_fallback != "":
		if ResourceLoader.exists(res_fallback):
			return load(res_fallback) as VideoStream
		if FileAccess.file_exists(res_fallback):
			var vs2 := VideoStreamTheora.new()
			vs2.file = res_fallback
			return vs2
	push_warning("Video missing: %s" % path)
	return null

## user://songs/official/<id>/audio.ogg → res://charts/<id>/audio.ogg
static func _official_res_fallback(user_path: String, media_file: String) -> String:
	var marker := "user://songs/official/"
	if not user_path.begins_with(marker):
		return ""
	var rest := user_path.trim_prefix(marker)
	var slash := rest.find("/")
	if slash <= 0:
		return ""
	var song_id := rest.substr(0, slash)
	if song_id.is_empty():
		return ""
	return "res://charts/%s/%s" % [song_id, media_file]
