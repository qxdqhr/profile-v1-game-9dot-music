extends Node3D
class_name MyRoomAvatar
## Runtime helper for OC GLB: toon materials, idle anim, shape-key expressions.

const TOON_SHADER := preload("res://shaders/myroom_toon.gdshader")

var _meshes: Array[MeshInstance3D] = []
var _anim_player: AnimationPlayer
var _expr_tween: Tween
var _blink_t := 0.0

func setup_from(root: Node3D) -> void:
	_collect(root)
	_apply_toon()
	_find_anim(root)
	_play_idle()
	set_process(true)

func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect(c)

func _find_anim(n: Node) -> void:
	if n is AnimationPlayer and _anim_player == null:
		_anim_player = n as AnimationPlayer
	for c in n.get_children():
		_find_anim(c)

func _apply_toon() -> void:
	for mi in _meshes:
		var count := mi.mesh.get_surface_count() if mi.mesh else 0
		for s in range(count):
			var base: Material = mi.get_active_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = TOON_SHADER
			var col := Color(0.9, 0.9, 0.9, 1.0)
			if base is StandardMaterial3D:
				col = (base as StandardMaterial3D).albedo_color
				var tex: Texture2D = (base as StandardMaterial3D).albedo_texture
				if tex:
					mat.set_shader_parameter("albedo_tex", tex)
			elif base is BaseMaterial3D:
				col = (base as BaseMaterial3D).albedo_color
			mat.set_shader_parameter("albedo", col)
			mi.set_surface_override_material(s, mat)

func _play_idle() -> void:
	if _anim_player == null:
		return
	for anim_name in _anim_player.get_animation_list():
		var n := String(anim_name)
		if n.to_lower().contains("idle") or n == "idle":
			_anim_player.play(anim_name)
			return
	if _anim_player.get_animation_list().size() > 0:
		_anim_player.play(_anim_player.get_animation_list()[0])

func set_expression(expr: String, weight: float = 1.0, dur: float = 0.25) -> void:
	# Reset then set target blend shape across meshes.
	for mi in _meshes:
		_zero_blend_shapes(mi)
		var idx := _find_blend(mi, expr)
		if idx < 0:
			continue
		if _expr_tween and _expr_tween.is_valid():
			_expr_tween.kill()
		_expr_tween = create_tween()
		var from := mi.get_blend_shape_value(idx)
		_expr_tween.tween_method(
			func(v: float): mi.set_blend_shape_value(idx, v),
			from,
			clampf(weight, 0.0, 1.0),
			dur
		)

func pulse_expression(expr: String, hold: float = 0.6) -> void:
	set_expression(expr, 1.0, 0.2)
	get_tree().create_timer(hold).timeout.connect(func(): set_expression(expr, 0.0, 0.35))

func _zero_blend_shapes(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in range(mi.mesh.get_blend_shape_count()):
		mi.set_blend_shape_value(i, 0.0)

func _find_blend(mi: MeshInstance3D, expr: String) -> int:
	if mi.mesh == null:
		return -1
	var want := expr.to_lower()
	for i in range(mi.mesh.get_blend_shape_count()):
		var n := String(mi.mesh.get_blend_shape_name(i)).to_lower()
		if n == want or n.ends_with("/" + want) or n.contains(want):
			return i
	return -1

func _process(delta: float) -> void:
	_blink_t += delta
	if _blink_t > 3.5:
		_blink_t = 0.0
		_do_blink()

func _do_blink() -> void:
	for mi in _meshes:
		var idx := _find_blend(mi, "blink")
		if idx < 0:
			continue
		var tw := create_tween()
		tw.tween_method(func(v: float): mi.set_blend_shape_value(idx, v), 0.0, 1.0, 0.08)
		tw.tween_method(func(v: float): mi.set_blend_shape_value(idx, v), 1.0, 0.0, 0.12)
