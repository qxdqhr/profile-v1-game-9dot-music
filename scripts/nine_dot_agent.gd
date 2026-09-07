extends RefCounted
class_name NineDotAgent
## Local agent stub: Bilibili URL → heuristic JSON chart under user:// (M4).
## Real remote BV fetch / audio analysis is out of scope; this locks the pipeline UX.

const USER_ROOT := "user://nine_dot_agent"

static func is_bilibili_url(url: String) -> bool:
	var u := url.strip_edges().to_lower()
	return u.contains("bilibili.com") or u.contains("b23.tv") or u.begins_with("bv")

static func cache_key_from_url(url: String) -> String:
	var u := url.strip_edges()
	var key := str(u.hash())
	var re := RegEx.new()
	re.compile("(?i)(BV[0-9A-Za-z]+)")
	var m := re.search(u)
	if m:
		key = m.get_string(1)
	return key

static func generate(url: String, bpm: float = 120.0, duration_ms: int = 16000) -> Dictionary:
	var cache_key := cache_key_from_url(url)
	var dir_name := "agent-%s" % cache_key
	var abs_dir := "%s/%s" % [USER_ROOT, dir_name]
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(abs_dir))
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("mkdir %s -> %s" % [abs_dir, error_string(err)])

	var notes := _build_heuristic_notes(bpm, duration_ms)
	var notes_path := "%s/normal.json" % abs_dir
	var meta_path := "%s/meta.json" % abs_dir
	_write_json(notes_path, {"difficulty": "normal", "notes": notes})

	var meta := {
		"schemaVersion": 1,
		"id": dir_name,
		"title": "Agent · %s" % cache_key,
		"artist": "Auto Chart",
		"bpm": bpm,
		"offsetMs": 0,
		"durationMs": duration_ms,
		"sourceUrl": url.strip_edges(),
		"audio": {"path": "res://charts/song-metronome-001/audio.ogg"},
		"video": {
			"source": "builtin",
			"path": "res://charts/song-metronome-001/video.ogv",
			"cacheKey": cache_key,
		},
		"difficulties": {
			"easy": null,
			"normal": {"file": "normal.json"},
			"hard": null,
			"extreme": null,
		},
		"_dir": dir_name,
		"_metaPath": meta_path,
		"_userChart": true,
	}
	_write_json(meta_path, meta)
	return meta

static func _build_heuristic_notes(bpm: float, duration_ms: int) -> Array:
	var interval := int(60000.0 / maxf(bpm, 1.0))
	var edges: Array = NineDotGeometry.legal_edges()
	var notes: Array = []
	var t := interval * 2
	var i := 0
	while t < duration_ms - interval:
		if i % 5 == 4 and edges.size() > 0:
			var e: PackedInt32Array = edges[i % edges.size()]
			notes.append({
				"tMs": t,
				"type": "slide",
				"edge": [int(e[0]), int(e[1])],
				"dir": "a_to_b" if i % 2 == 0 else "b_to_a",
			})
		else:
			notes.append({"tMs": t, "type": "tap", "node": (i % 9) + 1})
		t += interval
		i += 1
	return notes

static func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))

static func list_user_charts() -> Array:
	var out: Array = []
	var root := DirAccess.open(USER_ROOT)
	if root == null:
		return out
	root.list_dir_begin()
	var name := root.get_next()
	while name != "":
		if root.current_is_dir() and not name.begins_with("."):
			var meta_path := "%s/%s/meta.json" % [USER_ROOT, name]
			if FileAccess.file_exists(meta_path):
				var meta := NineDotChart.load_meta(meta_path)
				if not meta.is_empty():
					meta["_dir"] = name
					meta["_metaPath"] = meta_path
					meta["_userChart"] = true
					out.append(meta)
		name = root.get_next()
	root.list_dir_end()
	return out
