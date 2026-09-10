extends Control
## MyRoom room (M1–M5): touch comm, minigames, gifts, décor, onegai, cast slots.

const _Loader = preload("res://scripts/myroom/myroom_model_loader.gd")
const _Progress = preload("res://scripts/myroom/myroom_progress.gd")
const _Paths = preload("res://scripts/myroom/myroom_paths.gd")
const _Cast = preload("res://scripts/myroom/myroom_cast.gd")
const _Comm = preload("res://scripts/myroom/myroom_comm.gd")
const _Gifts = preload("res://scripts/myroom/myroom_gifts.gd")
const _Decor = preload("res://scripts/myroom/myroom_decor.gd")
const _Onegai = preload("res://scripts/myroom/myroom_onegai.gd")
const _Acchi = preload("res://scripts/myroom/myroom_acchi.gd")
const _Alps = preload("res://scripts/myroom/myroom_alps.gd")

@onready var _bg: ColorRect = $BG
@onready var _status: Label = $UI/TopBar/Status
@onready var _back: Button = $UI/TopBar/BackBtn
@onready var _anchor: Node3D = $WorldHost/SubViewport/World/AvatarAnchor
@onready var _floor: MeshInstance3D = $WorldHost/SubViewport/World/Floor
@onready var _svp: SubViewport = $WorldHost/SubViewport
@onready var _ui: CanvasLayer = $UI
@onready var _zones: Control = $UI/TouchZones
@onready var _heart_bar: ProgressBar = $UI/Hud/HeartBar
@onready var _aff_lbl: Label = $UI/Hud/AffLabel
@onready var _msg: Label = $UI/Hud/Msg
@onready var _hand: Label = $UI/Hud/HandHint
@onready var _fever_btn: Button = $UI/Hud/BtnRow/FeverBtn
@onready var _back_touch: Button = $UI/Hud/BtnRow/BackTouchBtn
@onready var _actions: HBoxContainer = $UI/Actions
@onready var _onegai_bubble: PanelContainer = $UI/OnegaiBubble
@onready var _onegai_text: Label = $UI/OnegaiBubble/Margin/VBox/Text
@onready var _onegai_yes: Button = $UI/OnegaiBubble/Margin/VBox/Row/YesBtn
@onready var _onegai_no: Button = $UI/OnegaiBubble/Margin/VBox/Row/NoBtn
@onready var _furn: MeshInstance3D = $WorldHost/SubViewport/World/Furniture

var _slot := "miku"
var _comm
var _avatar: Node3D
var _panel_host: Control
var _angry_yaw := 0.0

func _ready() -> void:
	NineDotTheme.apply_to(self)
	_Paths.ensure_dirs()
	_Progress.ensure()
	_svp.own_world_3d = true
	_slot = _Progress.active_slot()
	_comm = _Comm.new()
	_comm.bind_slot(_slot)
	_comm.heart_changed.connect(_on_heart)
	_comm.segment_result.connect(_on_segment)
	_comm.anger_changed.connect(_on_anger)
	_comm.cooldown_changed.connect(func(_on): _refresh_hud())
	_comm.invite_ready.connect(_on_invite)
	_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/myroom/gate.tscn"))
	NineDotUiJuice.wire_button_press_juice(_back)
	_fever_btn.pressed.connect(_on_fever_pressed)
	_back_touch.button_down.connect(func(): _begin_zone("back"))
	_back_touch.button_up.connect(func(): _comm.end_touch())
	_wire_zones()
	_wire_actions()
	_onegai_yes.pressed.connect(_accept_onegai)
	_onegai_no.pressed.connect(_dismiss_onegai)
	_onegai_bubble.visible = false
	_panel_host = Control.new()
	_panel_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_panel_host)
	_setup_floor()
	_apply_decor()
	_respawn_avatar()
	_refresh_hud()
	_maybe_roll_onegai()
	await get_tree().process_frame
	NineDotUiJuice.pop_control($UI/TopBar, 0.92)

func _process(delta: float) -> void:
	if _Progress.is_angry(_slot):
		_comm.tick_reconcile(delta)
		_angry_yaw = lerpf(_angry_yaw, PI, 1.0 - exp(-6.0 * delta))
	else:
		_angry_yaw = lerpf(_angry_yaw, 0.0, 1.0 - exp(-6.0 * delta))
		_comm.tick(delta)
	if _avatar:
		_avatar.rotation.y = _angry_yaw
	if _Progress.is_on_cooldown(_slot):
		_hand.modulate = Color(1, 0.45, 0.45, 0.7)
		_hand.text = "冷却 %.0fs" % _Progress.cooldown_remaining(_slot)
	else:
		_hand.modulate = Color(0.45, 0.95, 0.55, 1)
		_hand.text = "可沟通"

func _wire_zones() -> void:
	for z in [["Hair", "hair"], ["Face", "face"], ["Body", "body"]]:
		var node: Control = _zones.get_node(z[0])
		var zone_name := String(z[1])
		node.gui_input.connect(func(ev: InputEvent): _zone_input(zone_name, ev))

func _zone_input(zone: String, event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_zone(zone)
		else:
			_comm.end_touch()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_begin_zone(zone)
		else:
			_comm.end_touch()

func _begin_zone(zone: String) -> void:
	if _Progress.is_angry(_slot):
		_comm.begin_reconcile_touch()
	else:
		_comm.begin_touch(zone)

func _wire_actions() -> void:
	var specs: Array = [
		["礼物", _open_gifts],
		["布置", _open_decor],
		["角色", _open_cast],
		["游戏", _open_games_menu],
	]
	for s in specs:
		var b := Button.new()
		b.text = String(s[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(s[1])
		NineDotUiJuice.wire_button_press_juice(b)
		_actions.add_child(b)

func _setup_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	_floor.mesh = plane

func _apply_decor() -> void:
	var theme := _Decor.theme_by_id(_Progress.decor_theme())
	_bg.color = theme.get("bg", Color(0.08, 0.12, 0.14)) as Color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = theme.get("floor", Color(0.18, 0.22, 0.26)) as Color
	mat.roughness = 0.9
	_floor.material_override = mat
	_rebuild_furniture()

func _rebuild_furniture() -> void:
	_furn.mesh = null
	var fid := _Progress.furniture_id()
	var accent := (_Decor.theme_by_id(_Progress.decor_theme()).get("accent", Color.WHITE) as Color)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent.darkened(0.25)
	match fid:
		"sofa":
			var box := BoxMesh.new()
			box.size = Vector3(1.2, 0.35, 0.45)
			_furn.mesh = box
			_furn.material_override = mat
			_furn.position = Vector3(0.9, 0.18, -0.6)
		"stage":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.7
			cyl.bottom_radius = 0.7
			cyl.height = 0.12
			_furn.mesh = cyl
			_furn.material_override = mat
			_furn.position = Vector3(0, 0.06, -0.2)
		_:
			_furn.position = Vector3.ZERO

func _respawn_avatar() -> void:
	for c in _anchor.get_children():
		c.queue_free()
	_avatar = _Loader.spawn_avatar(_anchor, _slot)

func _refresh_hud() -> void:
	var name := _Cast.display_name(_slot)
	var lv := _Progress.affection_level(_slot)
	var g := _Progress.affection_gauge(_slot)
	var clears := _Progress.get_official_normal_clears()
	var slots := _Progress.unlocked_slot_count()
	_status.text = "%s · Lv%d (%d/%d) · 槽 %d · 通关 %d" % [
		name, lv, g, _Progress.AFFECTION_GAUGE_MAX, slots, clears
	]
	_aff_lbl.text = "好感 Lv%d  %d/%d%s" % [
		lv, g, _Progress.AFFECTION_GAUGE_MAX,
		" · 生气" if _Progress.is_angry(_slot) else ""
	]
	_fever_btn.disabled = _Progress.fever_charges(_slot) <= 0 and not bool(_comm.fever_active)
	_fever_btn.text = "Fever×%d" % _Progress.fever_charges(_slot)

func _on_heart(fill: float, fever: bool) -> void:
	_heart_bar.value = fill * 100.0
	_heart_bar.modulate = Color(1.0, 0.45, 0.7) if not fever else Color(1.0, 0.85, 0.3)

func _on_segment(ok: bool, message: String, _added: int) -> void:
	_msg.text = message
	_msg.modulate = Color(0.7, 1.0, 0.8) if ok else Color(1.0, 0.75, 0.7)
	_refresh_hud()

func _on_anger(angry: bool) -> void:
	_msg.text = "生气了…" if angry else "心情平复了"
	_refresh_hud()

func _on_fever_pressed() -> void:
	if _comm.try_start_fever():
		_msg.text = "Fever！"
	_refresh_hud()

func _on_invite(game_id: String) -> void:
	_msg.text = "要不要一起玩？"
	_open_minigame(game_id)

func _open_games_menu() -> void:
	_clear_panels()
	var p := _make_sheet("迷你游戏")
	_add_sheet_btn(p, "あっちむいてホイ", func(): _open_minigame("acchi"))
	_add_sheet_btn(p, "アルプス一万尺", func(): _open_minigame("alps"))
	_add_sheet_btn(p, "关闭", _clear_panels)

func _open_minigame(game_id: String) -> void:
	_clear_panels()
	var game: Control
	if game_id == "alps":
		game = _Alps.new()
	else:
		game = _Acchi.new()
	game.finished.connect(_on_minigame_done)
	_panel_host.add_child(game)
	_panel_host.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_minigame_done(won: bool, aff: int) -> void:
	_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if aff > 0:
		_Progress.add_affection(_slot, aff)
	_msg.text = ("赢了！好感+%d" % aff) if won else ("结束了，好感+%d" % aff)
	_refresh_hud()

func _open_gifts() -> void:
	_clear_panels()
	var p := _make_sheet("礼物")
	for g in _Gifts.list_gifts():
		var gid := String(g["id"])
		var score := _Gifts.score_for(_slot, gid)
		_add_sheet_btn(p, "%s（+%d）" % [String(g["name"]), score], func(): _give(gid))
	_add_sheet_btn(p, "关闭", _clear_panels)

func _give(gift_id: String) -> void:
	var score := _Gifts.score_for(_slot, gift_id)
	var react := _Gifts.reaction_label(_slot, gift_id)
	_Progress.add_affection(_slot, score)
	if _Progress.is_angry(_slot):
		_Progress.set_angry(_slot, false)
		_comm.anger_changed.emit(false)
		react += " · 和好了"
	_msg.text = "%s（%s）" % [react, _Gifts.gift_by_id(gift_id).get("name", gift_id)]
	_clear_panels()
	_refresh_hud()

func _open_decor() -> void:
	_clear_panels()
	var p := _make_sheet("布置")
	var tlab := Label.new()
	tlab.text = "主题"
	p.add_child(tlab)
	for t in _Decor.THEMES:
		var tid := String(t["id"])
		_add_sheet_btn(p, String(t["name"]), func():
			_Progress.set_decor_theme(tid)
			_apply_decor()
			_msg.text = "主题已更换"
		)
	var flab := Label.new()
	flab.text = "家具"
	p.add_child(flab)
	for f in _Decor.FURNITURE:
		var fid := String(f["id"])
		_add_sheet_btn(p, String(f["name"]), func():
			_Progress.set_furniture_id(fid)
			_rebuild_furniture()
			_msg.text = "家具已更换"
		)
	_add_sheet_btn(p, "关闭", _clear_panels)

func _open_cast() -> void:
	_clear_panels()
	var p := _make_sheet("角色房间")
	var clears := _Progress.get_official_normal_clears()
	for s in _Cast.SLOTS:
		var sid := String(s["id"])
		var need := int(s["unlock_at"])
		var unlocked := _Progress.is_slot_unlocked(sid)
		var label := String(s["name"])
		if unlocked:
			if sid == _slot:
				label += " ✓"
			_add_sheet_btn(p, label, func(): _switch_slot(sid))
		else:
			var b := Button.new()
			b.text = "%s（需通关 %d，当前 %d）" % [String(s["name"]), need, clears]
			b.disabled = true
			p.add_child(b)
	_add_sheet_btn(p, "关闭", _clear_panels)

func _switch_slot(sid: String) -> void:
	_Progress.set_active_slot(sid)
	_slot = sid
	_comm.bind_slot(_slot)
	_respawn_avatar()
	_clear_panels()
	_refresh_hud()
	_msg.text = "进入 %s 的房间" % _Cast.display_name(sid)

func _maybe_roll_onegai() -> void:
	var existing := _Progress.onegai_kind()
	if existing != "":
		_show_onegai(existing)
		return
	if randf() < 0.35:
		var roll := _Onegai.roll()
		_Progress.set_onegai(String(roll["id"]))
		_show_onegai(String(roll["id"]))

func _show_onegai(kind: String) -> void:
	_onegai_text.text = _Onegai.label_of(kind)
	_onegai_bubble.visible = true

func _dismiss_onegai() -> void:
	_Progress.clear_onegai()
	_onegai_bubble.visible = false
	_msg.text = "下次再说～"

func _accept_onegai() -> void:
	var kind := _Progress.onegai_kind()
	_Progress.clear_onegai()
	_onegai_bubble.visible = false
	match kind:
		"theme":
			var t: Dictionary = _Decor.THEMES[randi() % _Decor.THEMES.size()]
			_Progress.set_decor_theme(String(t["id"]))
			_apply_decor()
			_msg.text = "换成了「%s」" % String(t["name"])
		"furniture":
			var f: Dictionary = _Decor.FURNITURE[randi() % _Decor.FURNITURE.size()]
			_Progress.set_furniture_id(String(f["id"]))
			_rebuild_furniture()
			_msg.text = "布置成「%s」" % String(f["name"])
		"slot_hint":
			_open_cast()
			_msg.text = "去看看解锁的房间吧"
		"gift_hint":
			_open_gifts()
			_msg.text = "送点什么好呢"
		_:
			_msg.text = "好的！"
	_Progress.add_affection(_slot, 1)
	_refresh_hud()

func _make_sheet(title: String) -> VBoxContainer:
	_panel_host.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_clear_panels()
	)
	_panel_host.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -150
	panel.offset_right = 150
	panel.offset_top = -360
	panel.offset_bottom = -56
	_panel_host.add_child(panel)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % s, 12)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 16)
	v.add_child(head)
	return v

func _add_sheet_btn(parent: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	NineDotUiJuice.wire_button_press_juice(b)
	parent.add_child(b)

func _clear_panels() -> void:
	for c in _panel_host.get_children():
		c.queue_free()
	_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
