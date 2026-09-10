extends Node
## Cross-scene play selection + last result payload.

const _Paths = preload("res://scripts/songs/song_paths.gd")
const _Entry = preload("res://scripts/songs/song_entry.gd")

var chart_id: String = "song-metronome-001"
var library_key: String = "official/song-metronome-001"
var category: String = "official"
var diff: String = "normal"
var meta_path: String = ""
var last_score: Dictionary = {}
var last_title: String = ""
## Where Settings "返回" should go (default hub).
var settings_back_scene: String = "res://scenes/hub.tscn"

func select_entry(entry: Dictionary) -> void:
	library_key = _Entry.key_of(entry)
	category = _Entry.category_of(entry)
	chart_id = String(entry.get("id", entry.get("_id", "")))
	meta_path = _Entry.meta_path_of(entry)

func select_chart(id: String, meta: String, cat: String = "") -> void:
	chart_id = id
	meta_path = meta
	if cat != "":
		category = cat
		library_key = _Paths.make_key(cat, id)
	elif meta.begins_with(_Paths.USER_ROOT):
		var rest := meta.trim_prefix(_Paths.USER_ROOT + "/")
		var parts := rest.split("/")
		if parts.size() >= 2:
			category = parts[0]
			library_key = _Paths.make_key(parts[0], parts[1])

func select_diff(d: String) -> void:
	diff = d

func store_result(title: String, score: Dictionary) -> void:
	last_title = title
	last_score = score.duplicate()

func open_settings_from(back_scene: String) -> void:
	settings_back_scene = back_scene if not back_scene.is_empty() else "res://scenes/hub.tscn"
	get_tree().change_scene_to_file("res://scenes/settings.tscn")
