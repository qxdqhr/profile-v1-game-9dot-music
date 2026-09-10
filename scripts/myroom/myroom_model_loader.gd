extends RefCounted
class_name MyRoomModelLoader
## Load user glTF/GLB or fall back to procedural / packed placeholder.
## PMX: deferred — convert offline to glTF or plug Godot-MMD later.

const _Paths = preload("res://scripts/myroom/myroom_paths.gd")
const _Cast = preload("res://scripts/myroom/myroom_cast.gd")

static func spawn_avatar(parent: Node3D, slot_id: String = "miku") -> Node3D:
	_Paths.ensure_dirs()
	var tint := _Cast.tint(slot_id)
	# Prefer user model folder matching slot id.
	var preferred := _Paths.USER_MODELS.path_join(slot_id)
	var path := _Paths.find_model_file(preferred)
	if path.is_empty():
		var user_dirs := _Paths.list_user_model_dirs()
		for d in user_dirs:
			path = _Paths.find_model_file(d)
			if not path.is_empty():
				break
	if not path.is_empty():
		var loaded := _load_gltf_scene(path)
		if loaded:
			parent.add_child(loaded)
			return loaded
	if ResourceLoader.exists(_Paths.RES_PLACEHOLDER_SCENE):
		var packed := load(_Paths.RES_PLACEHOLDER_SCENE) as PackedScene
		if packed:
			var inst: Node = packed.instantiate()
			parent.add_child(inst)
			if inst is Node3D:
				_apply_tint(inst as Node3D, tint)
				return inst as Node3D
	var built := build_procedural_avatar(tint)
	parent.add_child(built)
	return built

static func _apply_tint(root: Node3D, tint: Color) -> void:
	for c in root.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				var mat := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				# Only recolor body-like teal materials roughly.
				var a: Color = mat.albedo_color
				if a.g > a.r and a.g > 0.5:
					mat.albedo_color = tint
					mi.material_override = mat

static func _load_gltf_scene(path: String) -> Node3D:
	if path.begins_with("res://"):
		if not ResourceLoader.exists(path):
			return null
		var ps := load(path)
		if ps is PackedScene:
			var n: Node = (ps as PackedScene).instantiate()
			return n as Node3D
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_warning("MyRoomModelLoader: cannot load %s (%s)" % [path, error_string(err)])
		return null
	var root: Node = doc.generate_scene(state)
	if root is Node3D:
		return root as Node3D
	var wrap := Node3D.new()
	wrap.name = "UserModel"
	if root:
		wrap.add_child(root)
	return wrap

## Simple OC silhouette (not Crypton Miku) — free to ship. Tint = slot color.
static func build_procedural_avatar(tint: Color = Color(0.45, 0.85, 0.78, 1.0)) -> Node3D:
	var root := Node3D.new()
	root.name = "PlaceholderAvatar"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.55
	var hair := StandardMaterial3D.new()
	hair.albedo_color = tint.darkened(0.15)
	hair.roughness = 0.7
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.96, 0.88, 0.82, 1.0)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 0.85
	body.mesh = cap
	body.material_override = mat
	body.position = Vector3(0, 0.55, 0)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.18
	sph.height = 0.36
	head.mesh = sph
	head.material_override = skin
	head.position = Vector3(0, 1.15, 0)
	root.add_child(head)
	for side in [-1.0, 1.0]:
		var tail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.55, 0.08)
		tail.mesh = box
		tail.material_override = hair
		tail.position = Vector3(side * 0.16, 1.0, -0.05)
		tail.rotation_degrees = Vector3(15, 0, side * 25)
		root.add_child(tail)
	var shadow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 0.02
	shadow.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.25)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = sm
	shadow.position = Vector3(0, 0.01, 0)
	root.add_child(shadow)
	return root
