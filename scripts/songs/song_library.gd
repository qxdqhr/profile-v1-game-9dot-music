extends Node
## Autoload facade: seed + scan + resolve for the song library module.

const _Paths = preload("res://scripts/songs/song_paths.gd")
const _Entry = preload("res://scripts/songs/song_entry.gd")
const _Seed = preload("res://scripts/songs/song_seed.gd")
const _Scanner = preload("res://scripts/songs/song_scanner.gd")
const _Resolve = preload("res://scripts/songs/song_resolve.gd")

var _entries: Array = []
var _by_key: Dictionary = {}
var _seeded_count: int = -1

func _ready() -> void:
	ensure_ready()

func ensure_ready() -> void:
	_seeded_count = _Seed.ensure_seeded()
	refresh()

func refresh() -> void:
	_Seed.ensure_dirs()
	_entries = _Scanner.scan_all()
	_by_key.clear()
	for e in _entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var k: String = _Entry.key_of(e)
		if k != "":
			_by_key[k] = e

func list_songs() -> Array:
	return _entries.duplicate()

func list_grouped() -> Array:
	return _Scanner.group_entries(_entries)

func get_by_key(key: String) -> Dictionary:
	if _by_key.has(key):
		return (_by_key[key] as Dictionary).duplicate(true)
	return {}

func get_by_meta_path(meta_path: String) -> Dictionary:
	for e in _entries:
		if typeof(e) == TYPE_DICTIONARY and _Entry.meta_path_of(e) == meta_path:
			return (e as Dictionary).duplicate(true)
	return {}

func notes_path_for(entry: Dictionary, diff: String) -> String:
	return _Resolve.notes_path(entry, diff)

func audio_path_for(entry: Dictionary) -> String:
	return _Resolve.audio_path(entry)

func video_path_for(entry: Dictionary) -> String:
	return _Resolve.video_path(entry)

func last_seed_count() -> int:
	return _seeded_count

func category_label(category: String) -> String:
	return _Paths.category_label(category)

func make_key(category: String, song_id: String) -> String:
	return _Paths.make_key(category, song_id)

func user_root() -> String:
	return _Paths.USER_ROOT

func entry_key(entry: Dictionary) -> String:
	return _Entry.key_of(entry)

func entry_category(entry: Dictionary) -> String:
	return _Entry.category_of(entry)

func entry_meta_path(entry: Dictionary) -> String:
	return _Entry.meta_path_of(entry)
