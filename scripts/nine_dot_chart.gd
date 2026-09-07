extends RefCounted
class_name NineDotChart

static func load_meta(path: String) -> Dictionary:
	return _load_json(path)

static func load_notes(path: String) -> Array:
	var data := _load_json(path)
	if data.is_empty():
		return []
	var raw: Array = data.get("notes", [])
	var notes: Array = []
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var n := _normalize_note(item)
		if not n.is_empty():
			notes.append(n)
	notes.sort_custom(func(a, b): return int(a["tMs"]) < int(b["tMs"]))
	return notes

static func _normalize_note(item: Dictionary) -> Dictionary:
	var t_ms := int(item.get("tMs", -1))
	var typ := String(item.get("type", ""))
	if t_ms < 0:
		return {}
	match typ:
		"tap":
			var node := int(item.get("node", 0))
			if node < 1 or node > 9:
				return {}
			return {
				"tMs": t_ms,
				"type": "tap",
				"node": node,
				"judged": false,
				"grade": -1,
			}
		"slide":
			var edge = item.get("edge", [])
			if typeof(edge) != TYPE_ARRAY or edge.size() != 2:
				return {}
			var a := int(edge[0])
			var b := int(edge[1])
			if not NineDotGeometry.is_legal_edge(a, b):
				push_warning("Illegal slide edge %d-%d skipped" % [a, b])
				return {}
			var dir := String(item.get("dir", "a_to_b"))
			if dir != "a_to_b" and dir != "b_to_a":
				dir = "a_to_b"
			return {
				"tMs": t_ms,
				"type": "slide",
				"edge": PackedInt32Array([a, b]),
				"dir": dir,
				"judged": false,
				"grade": -1,
				"progress": 0.0,
			}
		_:
			return {}

static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Chart missing: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open: %s" % path)
		return {}
	var text := f.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON: %s" % path)
		return {}
	return parsed
