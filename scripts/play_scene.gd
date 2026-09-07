extends Control
## M1 play: Tap/Slide on nine-grid with audio-master (generated metronome).

enum Status { READY, PLAYING, PAUSED, ENDED }

const META_PATH := "res://charts/song-metronome-001/meta.json"
const NOTES_PATH := "res://charts/song-metronome-001/normal.json"

var _status: Status = Status.READY
var _notes: Array = []
var _score: Dictionary = {}
var _meta: Dictionary = {}
var _centers: Array[Vector2] = []
var _origin := Vector2.ZERO
var _grid_size := NineDotConfig.GRID_SIZE
var _cell := 0.0
var _band := 0.0
var _node_r := 0.0
var _feedback := ""
var _clock: NineDotClock
var _fingers: Dictionary = {} # id -> gesture dict
var _player_offset := 0

@onready var _hud: Label = $UI/HUD
@onready var _feedback_label: Label = $UI/Feedback
@onready var _pause_btn: Button = $UI/Controls/PauseBtn
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _start_btn: Button = $UI/Overlay/VBox/StartBtn
@onready var _retry_btn: Button = $UI/Overlay/VBox/RetryBtn
@onready var _back_btn: Button = $UI/Overlay/VBox/BackBtn
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var _grid_layer: Control = $GridLayer

func _ready() -> void:
	custom_minimum_size = Vector2(NineDotConfig.VIEW_W, NineDotConfig.VIEW_H)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player_offset = AppSettings.offset_ms
	_audio.volume_db = linear_to_db(maxi(0.001, AppSettings.volume_linear))
	_clock = NineDotClock.new()
	add_child(_clock)
	_pause_btn.pressed.connect(_toggle_pause)
	_start_btn.pressed.connect(_on_start)
	_retry_btn.pressed.connect(_on_retry)
	_back_btn.pressed.connect(_on_back)
	_grid_layer.draw.connect(_draw_grid)
	_grid_layer.gui_input.connect(_on_grid_gui_input)
	_rebuild_geometry()
	_reset_to_ready()
	get_viewport().size_changed.connect(_rebuild_geometry)

func _rebuild_geometry() -> void:
	_grid_size = minf(NineDotConfig.GRID_SIZE, size.x - NineDotConfig.GRID_MARGIN * 2.0)
	_origin = Vector2((size.x - _grid_size) * 0.5, NineDotConfig.GRID_TOP)
	_centers = NineDotGeometry.node_centers(_origin, _grid_size)
	_cell = NineDotGeometry.cell_size(_grid_size)
	_band = NineDotGeometry.slide_band_half_width(_cell)
	_node_r = _cell * NineDotConfig.NODE_HIT_RADIUS_FRAC
	_grid_layer.queue_redraw()

func _reset_to_ready() -> void:
	_meta = NineDotChart.load_meta(META_PATH)
	_notes = NineDotChart.load_notes(NOTES_PATH)
	_score = NineDotJudge.initial_score()
	_status = Status.READY
	_fingers.clear()
	_feedback = "点击开始 · Normal"
	_overlay.visible = true
	_over_msg.text = "%s\n%s\nNormal" % [NineDotConfig.DISPLAY_NAME, String(_meta.get("title", ""))]
	_start_btn.visible = true
	_retry_btn.visible = false
	_back_btn.visible = true
	_pause_btn.text = "暂停"
	_clock.stop()
	_update_hud()
	_grid_layer.queue_redraw()

func _on_start() -> void:
	_notes = NineDotChart.load_notes(NOTES_PATH)
	_score = NineDotJudge.initial_score()
	_fingers.clear()
	var duration := int(_meta.get("durationMs", 16000))
	var bpm := float(_meta.get("bpm", 120))
	var stream := NineDotMetronome.build_stream(duration, bpm)
	_audio.stream = stream
	_audio.volume_db = linear_to_db(maxi(0.001, AppSettings.volume_linear))
	_clock.setup(_audio, int(_meta.get("offsetMs", 0)), AppSettings.offset_ms, duration + 500)
	_clock.start()
	_status = Status.PLAYING
	_overlay.visible = false
	_feedback = "开始！"
	_update_hud()

func _on_retry() -> void:
	_reset_to_ready()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _toggle_pause() -> void:
	if _status == Status.PLAYING:
		_status = Status.PAUSED
		_clock.pause()
		_pause_btn.text = "继续"
		_feedback = "已暂停"
	elif _status == Status.PAUSED:
		_status = Status.PLAYING
		_clock.resume()
		_pause_btn.text = "暂停"
		_feedback = "继续"
	_update_hud()

func _process(_delta: float) -> void:
	if _status != Status.PLAYING:
		return
	var now := _clock.now_ms()
	_sweep_misses(now)
	if _all_judged() or _clock.poll_ended():
		_end_play()
	_update_hud()
	_grid_layer.queue_redraw()

func _end_play() -> void:
	_status = Status.ENDED
	_clock.stop()
	_overlay.visible = true
	var acc := NineDotJudge.accuracy_pct(_score)
	_over_msg.text = "结算\nAccuracy %.1f%%\nMax Combo %d\nP %d  G %d  Good %d  Miss %d" % [
		acc, int(_score["max_combo"]), int(_score["perfect"]), int(_score["great"]), int(_score["good"]), int(_score["miss"])
	]
	_start_btn.visible = false
	_retry_btn.visible = true
	_back_btn.visible = true
	_update_hud()

func _all_judged() -> bool:
	for n in _notes:
		if not bool(n["judged"]):
			return false
	return _notes.size() > 0

func _sweep_misses(now: int) -> void:
	for n in _notes:
		if bool(n["judged"]):
			continue
		if now > int(n["tMs"]) + NineDotConfig.JUDGE_GOOD_MS:
			_resolve(n, NineDotConfig.Grade.MISS, "Miss")

func _resolve(note: Dictionary, grade: int, fb: String) -> void:
	if bool(note["judged"]):
		return
	note["judged"] = true
	note["grade"] = grade
	_score = NineDotJudge.apply(_score, grade)
	_feedback = fb

func _on_grid_gui_input(event: InputEvent) -> void:
	if _status != Status.PLAYING:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_finger_down(st.index, st.position)
		else:
			_finger_up(st.index, st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_finger_move(sd.index, sd.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_finger_down(0, mb.position)
		else:
			_finger_up(0, mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finger_move(0, mm.position)

func _finger_down(id: int, pos: Vector2) -> void:
	var now := _clock.now_ms()
	# Prefer slide if touch near an active slide start; else tap.
	var slide_idx := _find_slide_candidate(now, pos)
	if slide_idx >= 0:
		var note: Dictionary = _notes[slide_idx]
		var ends := _slide_ends(note)
		_fingers[id] = {
			"kind": "slide",
			"note_idx": slide_idx,
			"start": ends[0],
			"end": ends[1],
			"max_progress": NineDotGeometry.progress_on_segment(pos, ends[0], ends[1]),
		}
		return
	var node := NineDotGeometry.hit_node(_centers, pos, _node_r)
	if node > 0:
		var tap_idx := _find_tap_candidate(now, node)
		if tap_idx >= 0:
			var note2: Dictionary = _notes[tap_idx]
			var delta := absi(now - int(note2["tMs"]))
			var g := NineDotJudge.grade_for_delta_ms(delta)
			_resolve(note2, g, NineDotJudge.grade_name(g))
			return
	_fingers[id] = { "kind": "idle", "pos": pos }

func _finger_move(id: int, pos: Vector2) -> void:
	if not _fingers.has(id):
		return
	var g: Dictionary = _fingers[id]
	if String(g.get("kind", "")) != "slide":
		return
	var note: Dictionary = _notes[int(g["note_idx"])]
	if bool(note["judged"]):
		_fingers.erase(id)
		return
	var a: Vector2 = g["start"]
	var b: Vector2 = g["end"]
	var dist := NineDotGeometry.dist_to_segment(pos, a, b)
	if dist > _band * 2.0:
		# Left the band hard — miss on release; mark progress frozen.
		g["off_band"] = true
		_fingers[id] = g
		return
	var prog := NineDotGeometry.progress_on_segment(pos, a, b)
	g["max_progress"] = maxf(float(g.get("max_progress", 0.0)), prog)
	g["off_band"] = false
	_fingers[id] = g
	if float(g["max_progress"]) >= NineDotConfig.SLIDE_COMPLETE_FRAC:
		_finish_slide(id)

func _finger_up(id: int, pos: Vector2) -> void:
	if not _fingers.has(id):
		return
	var g: Dictionary = _fingers[id]
	_fingers.erase(id)
	if String(g.get("kind", "")) != "slide":
		return
	var note: Dictionary = _notes[int(g["note_idx"])]
	if bool(note["judged"]):
		return
	var a: Vector2 = g["start"]
	var b: Vector2 = g["end"]
	var dist := NineDotGeometry.dist_to_segment(pos, a, b)
	var off := bool(g.get("off_band", false)) or dist > _band * 2.0
	var prog := maxf(float(g.get("max_progress", 0.0)), NineDotGeometry.progress_on_segment(pos, a, b))
	var now := _clock.now_ms()
	if off or prog < NineDotConfig.SLIDE_COMPLETE_FRAC:
		_resolve(note, NineDotConfig.Grade.MISS, "Miss")
		return
	var delta := absi(now - int(note["tMs"]))
	var grade := NineDotJudge.grade_for_delta_ms(delta)
	_resolve(note, grade, NineDotJudge.grade_name(grade))

func _finish_slide(id: int) -> void:
	if not _fingers.has(id):
		return
	var g: Dictionary = _fingers[id]
	var note: Dictionary = _notes[int(g["note_idx"])]
	if bool(note["judged"]):
		_fingers.erase(id)
		return
	var now := _clock.now_ms()
	var delta := absi(now - int(note["tMs"]))
	var grade := NineDotJudge.grade_for_delta_ms(delta)
	_resolve(note, grade, NineDotJudge.grade_name(grade))
	_fingers.erase(id)

func _slide_ends(note: Dictionary) -> PackedVector2Array:
	var edge: PackedInt32Array = note["edge"]
	var a := int(edge[0])
	var b := int(edge[1])
	var pa := _centers[a - 1]
	var pb := _centers[b - 1]
	if String(note["dir"]) == "b_to_a":
		return PackedVector2Array([pb, pa])
	return PackedVector2Array([pa, pb])

func _find_tap_candidate(now: int, node: int) -> int:
	var best := -1
	var best_abs := NineDotConfig.JUDGE_GOOD_MS + 1
	for i in range(_notes.size()):
		var n: Dictionary = _notes[i]
		if bool(n["judged"]) or String(n["type"]) != "tap":
			continue
		if int(n["node"]) != node:
			continue
		var d := absi(now - int(n["tMs"]))
		if d <= NineDotConfig.JUDGE_GOOD_MS and d < best_abs:
			best_abs = d
			best = i
	return best

func _find_slide_candidate(now: int, pos: Vector2) -> int:
	var best := -1
	var best_abs := NineDotConfig.JUDGE_GOOD_MS + 1
	for i in range(_notes.size()):
		var n: Dictionary = _notes[i]
		if bool(n["judged"]) or String(n["type"]) != "slide":
			continue
		var d := absi(now - int(n["tMs"]))
		if d > NineDotConfig.JUDGE_GOOD_MS:
			continue
		# Also allow starting a bit early during approach window
		if now < int(n["tMs"]) - NineDotConfig.JUDGE_GOOD_MS:
			continue
		var ends := _slide_ends(n)
		if NineDotGeometry.dist_to_segment(pos, ends[0], ends[1]) > _band * 2.0:
			continue
		var near_start := pos.distance_to(ends[0]) <= _node_r * 1.4
		var prog := NineDotGeometry.progress_on_segment(pos, ends[0], ends[1])
		if not near_start and prog > 0.25:
			continue
		if d < best_abs:
			best_abs = d
			best = i
	return best

func _draw_grid() -> void:
	var now := 0
	if _status == Status.PLAYING or _status == Status.PAUSED:
		now = _clock.now_ms()
	# Edges
	for e in NineDotGeometry.legal_edges():
		var a: int = e[0]
		var b: int = e[1]
		var col := Color(0.25, 0.32, 0.4, 0.55)
		_grid_layer.draw_line(_centers[a - 1], _centers[b - 1], col, 2.0, true)
	# Active notes highlight
	for n in _notes:
		if bool(n["judged"]):
			continue
		var t := int(n["tMs"])
		var until := t - now
		if until > NineDotConfig.APPROACH_MS or until < -NineDotConfig.JUDGE_GOOD_MS:
			continue
		var alpha := 1.0 - clampf(float(absi(until)) / float(NineDotConfig.APPROACH_MS), 0.0, 0.85)
		if String(n["type"]) == "tap":
			var c := _centers[int(n["node"]) - 1]
			_grid_layer.draw_circle(c, _node_r * 1.05, Color(0.35, 0.85, 1.0, 0.25 + 0.5 * alpha))
			_grid_layer.draw_arc(c, _node_r, 0, TAU, 48, Color(0.5, 0.95, 1.0, alpha), 3.0, true)
		else:
			var ends := _slide_ends(n)
			_grid_layer.draw_line(ends[0], ends[1], Color(1.0, 0.75, 0.25, 0.35 + 0.55 * alpha), 8.0, true)
			_grid_layer.draw_circle(ends[0], 8.0, Color(1.0, 0.85, 0.3, alpha))
			# Direction tip
			var tip := ends[0].lerp(ends[1], 0.65)
			_grid_layer.draw_circle(tip, 5.0, Color(1.0, 0.9, 0.5, alpha))
	# Nodes
	for i in range(_centers.size()):
		var c: Vector2 = _centers[i]
		_grid_layer.draw_circle(c, _node_r * 0.92, Color(0.12, 0.16, 0.22, 0.92))
		_grid_layer.draw_arc(c, _node_r * 0.92, 0, TAU, 40, Color(0.55, 0.7, 0.85, 0.9), 2.0, true)

func _update_hud() -> void:
	var now := 0
	if _status == Status.PLAYING or _status == Status.PAUSED:
		now = _clock.now_ms()
	_hud.text = "%s\nCombo %d  Acc %.1f%%\n%d ms" % [
		NineDotConfig.DISPLAY_NAME,
		int(_score["combo"]),
		NineDotJudge.accuracy_pct(_score),
		now,
	]
	_feedback_label.text = _feedback
	_pause_btn.visible = _status == Status.PLAYING or _status == Status.PAUSED
