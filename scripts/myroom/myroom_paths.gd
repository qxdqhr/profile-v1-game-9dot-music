extends RefCounted
class_name MyRoomPaths
## Paths for MyRoom models and progress (aligned with song library style).

const USER_ROOT := "user://myroom"
const USER_MODELS := "user://myroom/models"
const USER_PROGRESS := "user://myroom/progress.cfg"
const RES_PLACEHOLDER_SCENE := "res://scenes/myroom/placeholder_avatar.tscn"

static func ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(USER_ROOT)
	DirAccess.make_dir_recursive_absolute(USER_MODELS)

static func list_user_model_dirs() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(USER_MODELS)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			out.append(USER_MODELS.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out

## Prefer model.glb / model.gltf under a set folder.
static func find_model_file(set_dir: String) -> String:
	for fname in ["model.glb", "model.gltf", "avatar.glb", "avatar.gltf"]:
		var p := set_dir.path_join(fname)
		if FileAccess.file_exists(p):
			return p
	return ""
