extends RefCounted
class_name NineDotCatalog
## Discover builtin + user(agent) charts.

static func list_songs() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://charts")
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if dir.current_is_dir() and not name.begins_with("."):
				var meta_path := "res://charts/%s/meta.json" % name
				if FileAccess.file_exists(meta_path):
					var meta := NineDotChart.load_meta(meta_path)
					if not meta.is_empty():
						meta["_dir"] = name
						meta["_metaPath"] = meta_path
						out.append(meta)
			name = dir.get_next()
		dir.list_dir_end()
	for user_meta in NineDotAgent.list_user_charts():
		out.append(user_meta)
	out.sort_custom(func(a, b): return String(a.get("title", "")) < String(b.get("title", "")))
	return out

static func notes_path_for(meta: Dictionary, diff: String) -> String:
	var dir := String(meta.get("_dir", meta.get("id", "")))
	var diffs: Dictionary = meta.get("difficulties", {})
	var entry = diffs.get(diff, null)
	if typeof(entry) != TYPE_DICTIONARY or entry == null:
		return ""
	var file := String(entry.get("file", ""))
	if file.is_empty():
		return ""
	if bool(meta.get("_userChart", false)):
		return "%s/%s/%s" % [NineDotAgent.USER_ROOT, dir, file]
	return "res://charts/%s/%s" % [dir, file]
