extends RefCounted
class_name SongEntry
## Helpers for song library entry dictionaries (meta + library fields).

const _Paths = preload("res://scripts/songs/song_paths.gd")

## Enriches a loaded meta dict with library fields. Mutates and returns meta.
static func enrich(meta: Dictionary, category: String, root_path: String, meta_path: String) -> Dictionary:
	var song_id := String(meta.get("id", root_path.get_file()))
	if song_id.is_empty():
		song_id = root_path.get_file()
	meta["_category"] = category
	meta["_id"] = song_id
	meta["_key"] = _Paths.make_key(category, song_id)
	meta["_root"] = root_path
	meta["_metaPath"] = meta_path
	meta["_dir"] = song_id
	return meta

static func key_of(entry: Dictionary) -> String:
	return String(entry.get("_key", ""))

static func category_of(entry: Dictionary) -> String:
	return String(entry.get("_category", ""))

static func root_of(entry: Dictionary) -> String:
	return String(entry.get("_root", ""))

static func meta_path_of(entry: Dictionary) -> String:
	return String(entry.get("_metaPath", ""))
