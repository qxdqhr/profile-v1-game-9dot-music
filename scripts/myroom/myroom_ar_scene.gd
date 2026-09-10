extends Control
## MyRoom AR — Portrait (selfie overlay) + Live (plane place + idle).

const _Loader = preload("res://scripts/myroom/myroom_model_loader.gd")
const _Progress = preload("res://scripts/myroom/myroom_progress.gd")
const _Paths = preload("res://scripts/myroom/myroom_paths.gd")
const _Cast = preload("res://scripts/myroom/myroom_cast.gd")
const _Cam = preload("res://scripts/myroom/myroom_camera.gd")

enum Mode { PORTRAIT, LIVE }

@onready var _cam_rect: TextureRect = $CamBG
@onready var _status: Label = $UI/TopBar/Status
@onready var _back: Button = $UI/TopBar/BackBtn
@onready var _mode_portrait: Button = $UI/ModeRow/PortraitBtn
@onready var _mode_live: Button = $UI/ModeRow/LiveBtn
@onready var _hint: Label = $UI/Hint
@onready var _scale: HSlider = $UI/Bottom/ScaleSlider
@onready var _scale_lbl: Label = $UI/Bottom/ScaleLbl
@onready var _capture: Button = $UI/Bottom/BtnRow/CaptureBtn
@onready var _idle_btn: Button = $UI/Bottom/BtnRow/IdleBtn
@onready var _world_host: SubViewportContainer = $WorldHost
@onready var _svp: SubViewport = $WorldHost/SubViewport
@onready var _anchor: Node3D = $WorldHost/SubViewport/World/AvatarAnchor
@onready var _cam3d: Camera3D = $WorldHost/SubViewport/World/Camera3D
@onready var _plane: MeshInstance3D = $WorldHost/SubViewport/World/Ground

var _camera
var _mode: Mode = Mode.PORTRAIT
var _avatar: Node3D
var _slot := "miku"
var _idle_t := 0.0
var _idle_on := true
var _base_scale := 1.0
var _placed := false
var _drag := false
var _drag_last := Vector2.ZERO

func _ready() -> void:
	NineDotTheme.apply_to(self)
	_Paths.ensure_dirs()
	DirAccess.make_dir_recursive_absolute("user://myroom/photos")
	_Progress.ensure()
	_slot = _Progress.active_slot()
	_svp.own_world_3d = true
	_svp.transparent_bg = true
	_camera = _Cam.new()
	_camera.status_changed.connect(func(ok: bool, msg: String):
		_status.text = "%s · %s" % [_Cast.display_name(_slot), msg]
	)
	_camera.start()
	if _camera.texture:
		_cam_rect.texture = _camera.texture
	_cam_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cam_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/myroom/gate.tscn"))
	_mode_portrait.pressed.connect(func(): _set_mode(Mode.PORTRAIT))
	_mode_live.pressed.connect(func(): _set_mode(Mode.LIVE))
	_capture.pressed.connect(_on_capture)
	_idle_btn.pressed.connect(func():
		_idle_on = not _idle_on
		_idle_btn.text = "待机:开" if _idle_on else "待机:关"
	)
	_scale.min_value = 0.4
	_scale.max_value = 2.2
	_scale.step = 0.05
	_scale.value = 1.0
	_scale.value_changed.connect(_on_scale)
	for b in [_back, _mode_portrait, _mode_live, _capture, _idle_btn]:
		NineDotUiJuice.wire_button_press_juice(b)
	_setup_ground()
	_respawn_avatar()
	_set_mode(Mode.PORTRAIT)
	_world_host.gui_input.connect(_on_world_input)
	await get_tree().process_frame
	NineDotUiJuice.pop_control($UI/TopBar, 0.92)

func _exit_tree() -> void:
	if _camera:
		_camera.stop()

func _process(delta: float) -> void:
	if _camera:
		_camera.tick_fallback(delta)
	if _avatar == null:
		return
	if _idle_on:
		_idle_t += delta
		var bob := sin(_idle_t * 2.2) * 0.03
		var sway := sin(_idle_t * 1.4) * 0.04
		_avatar.position.y = bob
		_avatar.rotation.y = sway
		if _mode == Mode.LIVE and _placed:
			# Soft “short performance” pulse every ~6s
			var pulse := 1.0 + 0.04 * maxf(0.0, sin(_idle_t * 1.05))
			_avatar.scale = Vector3.ONE * (_base_scale * _scale.value * pulse)
		else:
			_avatar.scale = Vector3.ONE * (_base_scale * _scale.value)
	else:
		_avatar.position.y = 0.0
		_avatar.rotation.y = 0.0
		_avatar.scale = Vector3.ONE * (_base_scale * _scale.value)

func _setup_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	_plane.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.08)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plane.material_override = mat
	_plane.position = Vector3(0, 0, 0)

func _respawn_avatar() -> void:
	for c in _anchor.get_children():
		c.queue_free()
	_avatar = _Loader.spawn_avatar(_anchor, _slot)
	_base_scale = 1.0
	_on_scale(_scale.value)

func _set_mode(m: Mode) -> void:
	_mode = m
	_mode_portrait.disabled = m == Mode.PORTRAIT
	_mode_live.disabled = m == Mode.LIVE
	_capture.visible = true
	_idle_btn.visible = true
	if m == Mode.PORTRAIT:
		_hint.text = "Portrait：缩放角色，拍合影保存到相册"
		_capture.text = "合影"
		_placed = true
		_anchor.position = Vector3(0, 0, 0)
		_cam3d.position = Vector3(0, 1.05, 2.2)
		_cam3d.look_at(Vector3(0, 0.85, 0))
		_plane.visible = false
		_base_scale = 1.15
	else:
		_hint.text = "Live：点地面放置；拖动移动；可开待机晃动"
		_capture.text = "截图"
		_placed = false
		_anchor.position = Vector3(0, 0, -0.4)
		_cam3d.position = Vector3(0, 1.6, 3.2)
		_cam3d.look_at(Vector3(0, 0.4, 0))
		_plane.visible = true
		_base_scale = 0.95
		if _avatar:
			_avatar.visible = false
	_on_scale(_scale.value)
	_status.text = "%s · %s" % [
		_Cast.display_name(_slot),
		"摄像头" if _camera and not _camera.using_fallback else "模拟背景"
	]

func _on_scale(v: float) -> void:
	_scale_lbl.text = "缩放 %.2f" % v
	if _avatar:
		_avatar.scale = Vector3.ONE * (_base_scale * v)

func _on_world_input(event: InputEvent) -> void:
	if _mode != Mode.LIVE:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_place_or_begin_drag(st.position)
		else:
			_drag = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _drag:
			_drag_place(sd.position)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_place_or_begin_drag(mb.position)
		else:
			_drag = false
	elif event is InputEventMouseMotion and _drag:
		_drag_place((event as InputEventMouseMotion).position)

func _place_or_begin_drag(local_pos: Vector2) -> void:
	var hit: Vector3 = _ray_to_ground(local_pos)
	if not hit.is_finite():
		return
	_anchor.position = hit
	_placed = true
	if _avatar:
		_avatar.visible = true
	_drag = true
	_drag_last = local_pos
	_hint.text = "已放置 · 拖动可移动"

func _drag_place(local_pos: Vector2) -> void:
	var hit: Vector3 = _ray_to_ground(local_pos)
	if hit.is_finite():
		_anchor.position = hit
	_drag_last = local_pos

func _ray_to_ground(local_pos: Vector2) -> Vector3:
	# Map SubViewportContainer local → SubViewport pixels.
	var vp_size := Vector2(_svp.size)
	var host_size := _world_host.size
	if host_size.x < 1.0 or host_size.y < 1.0:
		return Vector3(INF, INF, INF)
	var px := Vector2(local_pos.x / host_size.x * vp_size.x, local_pos.y / host_size.y * vp_size.y)
	var origin := _cam3d.project_ray_origin(px)
	var dir := _cam3d.project_ray_normal(px)
	if absf(dir.y) < 0.0001:
		return Vector3(INF, INF, INF)
	var t := -origin.y / dir.y
	if t < 0.0:
		return Vector3(INF, INF, INF)
	var p := origin + dir * t
	p.x = clampf(p.x, -3.5, 3.5)
	p.z = clampf(p.z, -3.5, 3.5)
	p.y = 0.0
	return p

func _on_capture() -> void:
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		_hint.text = "截图失败"
		return
	# Crop roughly to content (full screen ok for MVP).
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var path := "user://myroom/photos/%s_%s.png" % [
		"portrait" if _mode == Mode.PORTRAIT else "live",
		stamp
	]
	var err := img.save_png(path)
	if err == OK:
		_hint.text = "已保存 %s" % path.get_file()
	else:
		_hint.text = "保存失败（%s）" % error_string(err)
