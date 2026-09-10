extends RefCounted
class_name NineDotCatalog
## Compatibility shim → SongLibrary / SongResolve.

const _Resolve = preload("res://scripts/songs/song_resolve.gd")

static func list_songs() -> Array:
	return SongLibrary.list_songs()

static func notes_path_for(meta: Dictionary, diff: String) -> String:
	return _Resolve.notes_path(meta, diff)
