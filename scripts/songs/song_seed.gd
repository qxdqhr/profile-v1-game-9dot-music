extends RefCounted
class_name SongSeed
## First-run: copy res://charts/* into user://songs/official/<id>/.
## Official audio/video stay on res:// (imported remaps break FileAccess copies on APK).

const _Paths = preload("res://scripts/songs/song_paths.gd")
const SKIP_SUFFIXES: Array[String] = [".import", ".uid", ".md"]
## Do not seed these — load via ResourceLoader from res://charts/<id>/ on device.
const SKIP_MEDIA_NAMES: Array[String] = ["audio.ogg", "audio.oga", "video.ogv"]
const SEED_SCHEMA := 2

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
	var copied := 0
	if needs_seed():
		copied = seed_from_res_charts()
		_write_marker(copied)
	# Always migrate official metas so APK upgrades fix remapped user:// audio.
	migrate_official_media_to_res()
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

## Rewrite official meta audio/video to res://charts/<id>/… and drop broken seeded copies.
static func migrate_official_media_to_res() -> int:
	var root := _Paths.category_root(_Paths.CAT_OFFICIAL)
	var dir := DirAccess.open(root)
	if dir == null:
		return 0
	var fixed := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			if _migrate_one_official(name):
				fixed += 1
		name = dir.get_next()
	dir.list_dir_end()
	if fixed > 0:
		_write_marker_schema_only()
	return fixed

static func _migrate_one_official(song_id: String) -> bool:
	var to_root := _Paths.set_root(_Paths.CAT_OFFICIAL, song_id)
	var meta_path := to_root.path_join("meta.json")
	if not FileAccess.file_exists(meta_path):
		return false
	var meta := NineDotChart.load_meta(meta_path)
	if meta.is_empty():
		return false
	var changed := false
	if typeof(meta.get("audio", null)) == TYPE_DICTIONARY:
		var audio: Dictionary = meta["audio"]
		var want := "%s/%s/audio.ogg" % [_Paths.RES_CHARTS, song_id]
		if String(audio.get("path", "")) != want and ResourceLoader.exists(want):
			audio["path"] = want
			meta["audio"] = audio
			changed = true
	if typeof(meta.get("video", null)) == TYPE_DICTIONARY:
		var video: Dictionary = meta["video"]
		var vp := String(video.get("path", ""))
		if vp != "" and vp != "none":
			var want_v := "%s/%s/video.ogv" % [_Paths.RES_CHARTS, song_id]
			if vp != want_v and ResourceLoader.exists(want_v):
				video["path"] = want_v
				meta["video"] = video
				changed = true
			elif vp != want_v and FileAccess.file_exists(want_v):
				video["path"] = want_v
				meta["video"] = video
				changed = true
	if changed:
		var text := JSON.stringify(meta, "\t")
		var f := FileAccess.open(meta_path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
	# Remove broken seeded media so we never load remapped junk from user://.
	for media_name in SKIP_MEDIA_NAMES:
		var p := to_root.path_join(media_name)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	return changed

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
		_rewrite_meta_official_media(meta_path, song_id)
	return copied_any

static func _should_skip(fname: String) -> bool:
	if fname.begins_with("."):
		return true
	for suf in SKIP_SUFFIXES:
		if fname.ends_with(suf):
			return true
	var lower := fname.to_lower()
	for media_name in SKIP_MEDIA_NAMES:
		if lower == media_name:
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

## Official charts: keep media on res:// so APK ResourceLoader works.
static func _rewrite_meta_official_media(meta_path: String, song_id: String) -> void:
	var meta := NineDotChart.load_meta(meta_path)
	if meta.is_empty():
		return
	if typeof(meta.get("audio", null)) == TYPE_DICTIONARY:
		var audio: Dictionary = meta["audio"]
		audio["path"] = "%s/%s/audio.ogg" % [_Paths.RES_CHARTS, song_id]
		meta["audio"] = audio
	if typeof(meta.get("video", null)) == TYPE_DICTIONARY:
		var video: Dictionary = meta["video"]
		var vp := String(video.get("path", ""))
		if vp != "" and vp != "none":
			video["path"] = "%s/%s/video.ogv" % [_Paths.RES_CHARTS, song_id]
		meta["video"] = video
	var text := JSON.stringify(meta, "\t")
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()

static func _write_marker(copied: int) -> void:
	var f := FileAccess.open(_Paths.SEED_MARKER, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"schemaVersion": SEED_SCHEMA,
		"copied": copied,
		"from": _Paths.RES_CHARTS,
		"to": _Paths.category_root(_Paths.CAT_OFFICIAL),
		"media": "res://charts (not copied)",
	}, "\t"))
	f.close()

static func _write_marker_schema_only() -> void:
	var payload := {
		"schemaVersion": SEED_SCHEMA,
		"migratedMediaToRes": true,
		"from": _Paths.RES_CHARTS,
		"to": _Paths.category_root(_Paths.CAT_OFFICIAL),
	}
	if FileAccess.file_exists(_Paths.SEED_MARKER):
		var raw := FileAccess.get_file_as_string(_Paths.SEED_MARKER)
		var parsed = JSON.parse_string(raw)
		if typeof(parsed) == TYPE_DICTIONARY:
			payload["copied"] = parsed.get("copied", 0)
	var f := FileAccess.open(_Paths.SEED_MARKER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()
