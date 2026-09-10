extends RefCounted
class_name SongSeed
## First-run: copy res://charts/* into user://songs/official/<id>/.

const _Paths = preload("res://scripts/songs/song_paths.gd")
const SKIP_SUFFIXES: Array[String] = [".import", ".uid", ".md"]

static func needs_seed() -> bool:
	if FileAccess.file_exists(_Paths.SEED_MARKER):
		return false
	var official := DirAccess.open(_Paths.category_root(_Paths.CAT_OFFICIAL))
	if official == null:
		return true
	official.list_dir_begin()
	var name := official.get_next()
	while name != "":
		if official.current_is_dir() and not name.begins_with("."):
			var meta := _Paths.set_root(_Paths.CAT_OFFICIAL, name).path_join("meta.json")
			if FileAccess.file_exists(meta):
				official.list_dir_end()
				return false
		name = official.get_next()
	official.list_dir_end()
	return true

static func ensure_seeded() -> int:
	ensure_dirs()
	if not needs_seed():
		return 0
	var copied := seed_from_res_charts()
	_write_marker(copied)
	return copied

static func seed_from_res_charts() -> int:
	var src := DirAccess.open(_Paths.RES_CHARTS)
	if src == null:
		push_warning("SongSeed: cannot open %s" % _Paths.RES_CHARTS)
		return 0
	var count := 0
	src.list_dir_begin()
	var name := src.get_next()
	while name != "":
		if src.current_is_dir() and not name.begins_with("."):
			if _copy_set(name):
				count += 1
		name = src.get_next()
	src.list_dir_end()
	return count

static func ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(_Paths.USER_ROOT)
	DirAccess.make_dir_recursive_absolute(_Paths.category_root(_Paths.CAT_OFFICIAL))
	DirAccess.make_dir_recursive_absolute(_Paths.category_root(_Paths.CAT_USERS))

static func _copy_set(song_id: String) -> bool:
	var from_root := "%s/%s" % [_Paths.RES_CHARTS, song_id]
	var to_root := _Paths.set_root(_Paths.CAT_OFFICIAL, song_id)
	DirAccess.make_dir_recursive_absolute(to_root)
	var dir := DirAccess.open(from_root)
	if dir == null:
		return false
	var copied_any := false
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and not _should_skip(fname):
			var from_path := from_root.path_join(fname)
			var to_path := to_root.path_join(fname)
			if _copy_file(from_path, to_path):
				copied_any = true
		fname = dir.get_next()
	dir.list_dir_end()
	var meta_path := to_root.path_join("meta.json")
	if FileAccess.file_exists(meta_path):
		_rewrite_meta_relative(meta_path, song_id)
	return copied_any

static func _should_skip(fname: String) -> bool:
	if fname.begins_with("."):
		return true
	for suf in SKIP_SUFFIXES:
		if fname.ends_with(suf):
			return true
	return false

static func _copy_file(from_path: String, to_path: String) -> bool:
	var src := FileAccess.open(from_path, FileAccess.READ)
	if src == null:
		push_warning("SongSeed: cannot read %s" % from_path)
		return false
	var bytes := src.get_buffer(src.get_length())
	src.close()
	var dst := FileAccess.open(to_path, FileAccess.WRITE)
	if dst == null:
		push_warning("SongSeed: cannot write %s" % to_path)
		return false
	dst.store_buffer(bytes)
	dst.close()
	return true

static func _rewrite_meta_relative(meta_path: String, song_id: String) -> void:
	var meta := NineDotChart.load_meta(meta_path)
	if meta.is_empty():
		return
	if typeof(meta.get("audio", null)) == TYPE_DICTIONARY:
		var audio: Dictionary = meta["audio"]
		audio["path"] = _to_relative(String(audio.get("path", "")), song_id, "audio.ogg")
		meta["audio"] = audio
	if typeof(meta.get("video", null)) == TYPE_DICTIONARY:
		var video: Dictionary = meta["video"]
		var vp := String(video.get("path", ""))
		if vp != "" and vp != "none":
			video["path"] = _to_relative(vp, song_id, "video.ogv")
		meta["video"] = video
	var text := JSON.stringify(meta, "\t")
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()

static func _to_relative(path: String, song_id: String, fallback_name: String) -> String:
	if path.is_empty():
		return fallback_name
	if not path.contains("://"):
		return path.get_file() if path.contains("/") else path
	var marker := "/%s/" % song_id
	var idx := path.find(marker)
	if idx >= 0:
		return path.substr(idx + marker.length())
	return path.get_file() if path.get_file() != "" else fallback_name

static func _write_marker(copied: int) -> void:
	var f := FileAccess.open(_Paths.SEED_MARKER, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"schemaVersion": 1,
		"copied": copied,
		"from": _Paths.RES_CHARTS,
		"to": _Paths.category_root(_Paths.CAT_OFFICIAL),
	}, "\t"))
	f.close()
