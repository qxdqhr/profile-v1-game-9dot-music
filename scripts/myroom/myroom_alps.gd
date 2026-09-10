extends Control
## アルプス一万尺 — tap circles / swipe arrows, 3 rounds speeding up.

signal finished(won: bool, affection: int)

var _round := 0
var _hits := 0
var _need := 3
var _deadline := 0.0
var _mode := "" # tap | swipe
var _target_dir := Vector2.RIGHT
var _lbl: Label
var _hint: Label
var _arena: Control
var _target: Button
var _swipe_start := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 380)
	panel.position = Vector2(-160, -190)
	add_child(panel)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % s, 12)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)
	var head := Label.new()
	head.text = "アルプス一万尺"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 18)
	v.add_child(head)
	_lbl = Label.new()
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_lbl)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	_arena = Control.new()
	_arena.custom_minimum_size = Vector2(0, 220)
	_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arena.gui_input.connect(_on_arena_input)
	v.add_child(_arena)
	var skip := Button.new()
	skip.text = "放弃"
	skip.pressed.connect(func(): _finish(false, 0))
	v.add_child(skip)
	_next_round()

func _process(delta: float) -> void:
	if _deadline <= 0.0:
		return
	_deadline -= delta
	_lbl.text = "回合 %d/3 · 命中 %d/%d · %.1fs" % [_round, _hits, _need, maxf(0.0, _deadline)]
	if _deadline <= 0.0:
		_finish(_hits >= _need, 2 if _hits >= _need else 1)

func _next_round() -> void:
	_round += 1
	if _round > 3:
		_finish(_hits >= _need, 3 if _hits >= _need else 1)
		return
	_hits = 0
	_need = 2 + _round # 3,4,5
	_deadline = 6.0 - _round * 0.8
	_mode = "tap" if _round % 2 == 1 else "swipe"
	if _target and is_instance_valid(_target):
		_target.queue_free()
		_target = null
	if _mode == "tap":
		_hint.text = "快点圆圈！"
		_spawn_tap()
	else:
		_hint.text = "在区域里滑动箭头方向"
		var dirs: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
		_target_dir = dirs[randi() % 4]
		var arrow := _dir_glyph(_target_dir)
		_hint.text = "滑动：%s" % arrow

func _spawn_tap() -> void:
	if _target and is_instance_valid(_target):
		_target.queue_free()
	_target = Button.new()
	_target.text = "●"
	_target.custom_minimum_size = Vector2(56, 56)
	_arena.add_child(_target)
	await get_tree().process_frame
	var aw := maxf(80.0, _arena.size.x - 60.0)
	var ah := maxf(80.0, _arena.size.y - 60.0)
	_target.position = Vector2(randf() * aw, randf() * ah)
	_target.pressed.connect(_on_tap_hit)

func _on_tap_hit() -> void:
	_hits += 1
	if _hits >= _need:
		_next_round()
	else:
		_spawn_tap()

func _on_arena_input(event: InputEvent) -> void:
	if _mode != "swipe":
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_swipe_start = st.position
		else:
			_judge_swipe(st.position - _swipe_start)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_swipe_start = mb.position
			else:
				_judge_swipe(mb.position - _swipe_start)

func _judge_swipe(delta: Vector2) -> void:
	if delta.length() < 40.0:
		return
	var n := delta.normalized()
	var ok := n.dot(_target_dir) > 0.55
	if ok:
		_hits += 1
		if _hits >= _need:
			_next_round()
		else:
			var dirs2: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
			_target_dir = dirs2[randi() % 4]
			_hint.text = "滑动：%s" % _dir_glyph(_target_dir)

func _dir_glyph(d: Vector2) -> String:
	if d == Vector2.LEFT:
		return "←"
	if d == Vector2.RIGHT:
		return "→"
	if d == Vector2.UP:
		return "↑"
	return "↓"

func _finish(won: bool, aff: int) -> void:
	_deadline = -1.0
	finished.emit(won, aff)
	queue_free()
