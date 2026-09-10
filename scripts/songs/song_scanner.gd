extends RefCounted
class_name SongScanner
## Scan user://songs/<category>/<id>/meta.json into entry dictionaries.

const _Paths = preload("res://scripts/songs/song_paths.gd")
const _Entry = preload("res://scripts/songs/song_entry.gd")

static func scan_all() -> Array:
	var out: Array = []
	for category in list_categories():
		out.append_array(scan_category(category))
	return out

static func list_categories() -> Array[String]:
	var found: Array[String] = []
	var root := DirAccess.open(_Paths.USER_ROOT)
	if root == null:
		return found
	root.list_dir_begin()
	var name := root.get_next()
	while name != "":
		if root.current_is_dir() and not name.begins_with("."):
			found.append(name)
		name = root.get_next()
	root.list_dir_end()
	found.sort_custom(func(a, b): return _category_rank(a) < _category_rank(b) or (_category_rank(a) == _category_rank(b) and a < b))
	return found

static func scan_category(category: String) -> Array:
	var out: Array = []
	var cat_path := _Paths.category_root(category)
	var dir := DirAccess.open(cat_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			var root_path := _Paths.set_root(category, name)
			var meta_path := root_path.path_join("meta.json")
			if FileAccess.file_exists(meta_path):
				var meta := NineDotChart.load_meta(meta_path)
				if not meta.is_empty():
					out.append(_Entry.enrich(meta, category, root_path, meta_path))
		name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a, b): return String(a.get("title", "")) < String(b.get("title", "")))
	return out

static func group_entries(entries: Array) -> Array:
	var by_cat: Dictionary = {}
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var cat := _Entry.category_of(e)
		if not by_cat.has(cat):
			by_cat[cat] = []
		(by_cat[cat] as Array).append(e)
	var cats: Array[String] = []
	for k in by_cat.keys():
		cats.append(String(k))
	cats.sort_custom(func(a, b): return _category_rank(a) < _category_rank(b) or (_category_rank(a) == _category_rank(b) and a < b))
	var groups: Array = []
	for cat in cats:
		groups.append({
			"category": cat,
			"label": _Paths.category_label(cat),
			"songs": by_cat[cat],
		})
	return groups

static func _category_rank(category: String) -> int:
	var i := _Paths.CATEGORY_ORDER.find(category)
	return i if i >= 0 else 1000 + abs(category.hash())
