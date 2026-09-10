extends RefCounted
class_name SongImport
## Import user packs into user://songs/users/ (APK / desktop). Web: no-op for now.
## Zip / .9dotz reserved — not implemented in MVP.

const _Paths = preload("res://scripts/songs/song_paths.gd")

static func supports_platform() -> bool:
	return OS.get_name() != "Web"

static func users_root() -> String:
	return _Paths.category_root(_Paths.CAT_USERS)

## Copy an on-disk set folder into users/<id>/. Returns library key or "".
static func import_set_folder(source_dir: String, song_id: String = "") -> String:
	if not supports_platform():
		push_warning("SongImport: not supported on this platform")
		return ""
	if song_id.is_empty():
		song_id = source_dir.get_file()
	if song_id.is_empty():
		return ""
	var meta_src := source_dir.path_join("meta.json")
	if not FileAccess.file_exists(meta_src):
		push_warning("SongImport: missing meta.json in %s" % source_dir)
		return ""
	var dest := _Paths.set_root(_Paths.CAT_USERS, song_id)
	DirAccess.make_dir_recursive_absolute(dest)
	var dir := DirAccess.open(source_dir)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and not fname.begins_with("."):
			_copy_file(source_dir.path_join(fname), dest.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()
	return _Paths.make_key(_Paths.CAT_USERS, song_id)

static func _copy_file(from_path: String, to_path: String) -> bool:
	var src := FileAccess.open(from_path, FileAccess.READ)
	if src == null:
		return false
	var bytes := src.get_buffer(src.get_length())
	src.close()
	var dst := FileAccess.open(to_path, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_buffer(bytes)
	dst.close()
	return true
