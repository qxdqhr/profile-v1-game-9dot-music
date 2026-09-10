extends RefCounted
class_name SongResolve
## Resolve notes / audio / video paths from a song entry (relative or absolute).

const _Paths = preload("res://scripts/songs/song_paths.gd")
const _Entry = preload("res://scripts/songs/song_entry.gd")

static func notes_path(entry: Dictionary, diff: String) -> String:
	var diffs: Dictionary = entry.get("difficulties", {})
	var d = diffs.get(diff, null)
	if typeof(d) != TYPE_DICTIONARY or d == null:
		return ""
	var file := String(d.get("file", ""))
	if file.is_empty():
		return ""
	return join(entry, file)

static func audio_path(entry: Dictionary) -> String:
	var audio: Dictionary = entry.get("audio", {}) if typeof(entry.get("audio", {})) == TYPE_DICTIONARY else {}
	return resolve_media(entry, String(audio.get("path", "")))

static func video_path(entry: Dictionary) -> String:
	var video: Dictionary = entry.get("video", {}) if typeof(entry.get("video", {})) == TYPE_DICTIONARY else {}
	var p := String(video.get("path", ""))
	if p.is_empty() or p == "none":
		return ""
	return resolve_media(entry, p)

## Absolute if contains ://; else relative to set root.
## Official charts: prefer res://charts/<id>/<file> when present (APK-safe).
static func resolve_media(entry: Dictionary, raw: String) -> String:
	if raw.is_empty():
		return ""
	if raw.contains("://"):
		return raw
	var cat := _Entry.category_of(entry)
	var song_id := String(entry.get("_id", entry.get("id", "")))
	if cat == _Paths.CAT_OFFICIAL and song_id != "":
		var res_path := "%s/%s/%s" % [_Paths.RES_CHARTS, song_id, raw.get_file() if raw.contains("/") else raw]
		if ResourceLoader.exists(res_path) or FileAccess.file_exists(res_path):
			return res_path
	return join(entry, raw)

static func join(entry: Dictionary, relative: String) -> String:
	var root := _Entry.root_of(entry)
	if root.is_empty():
		var dir := String(entry.get("_dir", entry.get("id", "")))
		if dir.is_empty():
			return relative
		return "%s/%s/%s" % [_Paths.RES_CHARTS, dir, relative]
	if relative.begins_with("/"):
		return root.path_join(relative.substr(1))
	return root.path_join(relative)
