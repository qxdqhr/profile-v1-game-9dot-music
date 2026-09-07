extends Control
## Play: Tap/Slide + audio-master clock + video follow (M2).

enum Status { READY, PLAYING, PAUSED, ENDED }

const FALLBACK_META := "res://charts/song-metronome-001/meta.json"
const FALLBACK_NOTES := "res://charts/song-metronome-001/normal.json"

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
var _fingers: Dictionary = {}
var _diff_key := "normal"
var _meta_path := FALLBACK_META

@onready var _hud: Label = $UI/HUD
@onready var _feedback_label: Label = $UI/Feedback
@onready var _pause_btn: Button = $UI/Controls/PauseBtn
@onready var _pause_menu: ColorRect = $UI/PauseMenu
@onready var _restart_btn: Button = $UI/PauseMenu/Row/RestartBtn
@onready var _songs_btn: Button = $UI/PauseMenu/Row/SongsBtn
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _start_btn: Button = $UI/Overlay/VBox/StartBtn
@onready var _retry_btn: Button = $UI/Overlay/VBox/RetryBtn
@onready var _back_btn: Button = $UI/Overlay/VBox/BackBtn
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var _video: VideoStreamPlayer = $Video
@onready var _grid_layer: Control = $GridLayer

func _ready() -> void:
	custom_minimum_size = Vector2(NineDotConfig.VIEW_W, NineDotConfig.VIEW_H)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_diff_key = PlaySession.diff if String(PlaySession.diff) != "" else "normal"
	_meta_path = PlaySession.meta_path if String(PlaySession.meta_path) != "" else FALLBACK_META
	_audio.volume_db = linear_to_db(maxi(0.001, AppSettings.volume_linear))
	_clock = NineDotClock.new()
	add_child(_clock)
	_pause_btn.pressed.connect(_toggle_pause)
	_restart_btn.pressed.connect(_on_pause_restart)
	_songs_btn.pressed.connect(_on_back)
	_start_btn.pressed.connect(_on_start)
	_retry_btn.pressed.connect(_on_retry)
	_back_btn.pressed.connect(_on_back)
	_pause_menu.visible = false
	_pause_menu.gui_input.connect(_on_pause_menu_gui_input)
	_grid_layer.draw.connect(_draw_grid)
	_grid_layer.gui_input.connect(_on_grid_gui_input)
	_rebuild_geometry()
	_reset_to_ready()
	get_viewport().size_changed.connect(_rebuild_geometry)

func _notes_path() -> String:
	var path := NineDotCatalog.notes_path_for(_meta, _diff_key)
	if path != "":
		return path
	# Enrich meta with _dir for catalog helper
	var enriched := _meta.duplicate()
	if not enriched.has("_dir"):
		enriched["_dir"] = String(_meta.get("id", "song-metronome-001"))
	path = NineDotCatalog.notes_path_for(enriched, _diff_key)
	return path if path != "" else FALLBACK_NOTES

func _rebuild_geometry() -> void:
	_grid_size = minf(NineDotConfig.GRID_SIZE, size.x - NineDotConfig.GRID_MARGIN * 2.0)
	_origin = Vector2((size.x - _grid_size) * 0.5, NineDotConfig.GRID_TOP)
	_centers = NineDotGeometry.node_centers(_origin, _grid_size)
	_cell = NineDotGeometry.cell_size(_grid_size)
	_band = NineDotGeometry.slide_band_half_width(_cell)
	_node_r = _cell * NineDotConfig.NODE_HIT_RADIUS_FRAC
	_grid_layer.queue_redraw()

func _reset_to_ready() -> void:
	_meta = NineDotChart.load_meta(_meta_path)
	if not _meta.has("_dir"):
		_meta["_dir"] = String(_meta.get("id", "song-metronome-001"))
	_notes = NineDotChart.load_notes(_notes_path())
	_score = NineDotJudge.initial_score(_notes.size())
	_status = Status.READY
	_fingers.clear()
	_feedback = "点击开始 · %s" % _diff_key.capitalize()
	_overlay.visible = true
	_over_msg.text = "%s\n%s\n%s\n点开始" % [NineDotConfig.DISPLAY_NAME, String(_meta.get("title", "")), _diff_key.capitalize()]
	_start_btn.visible = true
	_retry_btn.visible = false
	_back_btn.visible = true
	_pause_btn.text = "⏸"
	_pause_menu.visible = false
	_clock.stop()
	NineDotMedia.stop_av(_audio, _video)
	_prepare_streams(false)
	_update_hud()
	_grid_layer.queue_redraw()

func _prepare_streams(autoplay: bool) -> void:
	var audio_path := String((_meta.get("audio", {}) as Dictionary).get("path", ""))
	var video_path := String((_meta.get("video", {}) as Dictionary).get("path", ""))
	var audio_stream := NineDotMedia.load_audio(audio_path)
	if audio_stream == null:
		var duration := int(_meta.get("durationMs", 16000))
		audio_stream = NineDotMetronome.build_stream(duration, float(_meta.get("bpm", 120)))
	_audio.stream = audio_stream
	_audio.volume_db = linear_to_db(maxi(0.001, AppSettings.volume_linear))
	var video_stream := NineDotMedia.load_video(video_path)
	_video.stream = video_stream
	_video.volume_db = -80.0
	if autoplay:
		NineDotMedia.start_av(_audio, _video)

func _on_start() -> void:
	_notes = NineDotChart.load_notes(_notes_path())
	_score = NineDotJudge.initial_score(_notes.size())
	_fingers.clear()
	var duration := int(_meta.get("durationMs", 16000))
	_prepare_streams(false)
	_clock.setup(_audio, int(_meta.get("offsetMs", 0)), AppSettings.offset_ms, duration + 500)
	# Clock start plays audio; also start video at 0 glued to audio.
	_clock.start()
	if _video.stream:
		_video.play()
		_video.stream_position = 0.0
	_status = Status.PLAYING
	_overlay.visible = false
	_pause_menu.visible = false
	_pause_btn.text = "停"
	_feedback = "开始！"
	_update_hud()

func _on_retry() -> void:
	_reset_to_ready()

func _on_pause_restart() -> void:
	_pause_menu.visible = false
	_on_start()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/song_select.tscn")

func _toggle_pause() -> void:
	if _status == Status.PLAYING:
		_enter_pause()
	elif _status == Status.PAUSED:
		_leave_pause()

func _enter_pause() -> void:
	_status = Status.PAUSED
	_clock.pause()
	if _video.stream:
		_video.paused = true
	_pause_btn.text = "续"
	_pause_menu.visible = true
	_feedback = ""
	_update_hud()

func _leave_pause() -> void:
	_status = Status.PLAYING
	_clock.resume()
	if _video.stream:
		_video.paused = false
	_pause_btn.text = "⏸"
	_pause_menu.visible = false
	_feedback = "继续"
	_update_hud()

func _on_pause_menu_gui_input(event: InputEvent) -> void:
	# Tap dimmed area (not the icon buttons) to resume.
	if not _pause_menu.visible or _status != Status.PAUSED:
		return
	var tapped := false
	var local_pos := Vector2.ZERO
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tapped = true
			local_pos = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			tapped = true
			local_pos = st.position
	if not tapped:
		return
	var row: Control = _pause_menu.get_node("Row")
	var global_pos := _pause_menu.get_global_transform() * local_pos
	if not row.get_global_rect().has_point(global_pos):
		_leave_pause()

func _process(_delta: float) -> void:
	if _status == Status.PLAYING:
		NineDotMedia.sync_video_to_audio(_audio, _video)
		var now := _clock.now_ms()
		_sweep_misses(now)
		if _all_judged() or _clock.poll_ended():
			_end_play()
		_update_hud()
		_grid_layer.queue_redraw()
	elif _status == Status.PAUSED:
		_grid_layer.queue_redraw()

func _end_play() -> void:
	_status = Status.ENDED
	_clock.stop()
	NineDotMedia.stop_av(_audio, _video)
	PlaySession.store_result(String(_meta.get("title", "")), _score)
	get_tree().change_scene_to_file("res://scenes/result.tscn")

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
	for e in NineDotGeometry.legal_edges():
		var a: int = e[0]
		var b: int = e[1]
		_grid_layer.draw_line(_centers[a - 1], _centers[b - 1], Color(0.25, 0.32, 0.4, 0.45), 2.0, true)
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
			_grid_layer.draw_circle(c, _node_r * 1.05, Color(0.35, 0.85, 1.0, 0.2 + 0.45 * alpha))
			_grid_layer.draw_arc(c, _node_r, 0, TAU, 48, Color(0.5, 0.95, 1.0, alpha), 3.0, true)
		else:
			var ends := _slide_ends(n)
			_grid_layer.draw_line(ends[0], ends[1], Color(1.0, 0.75, 0.25, 0.3 + 0.5 * alpha), 8.0, true)
			_grid_layer.draw_circle(ends[0], 8.0, Color(1.0, 0.85, 0.3, alpha))
			var tip := ends[0].lerp(ends[1], 0.65)
			_grid_layer.draw_circle(tip, 5.0, Color(1.0, 0.9, 0.5, alpha))
	for i in range(_centers.size()):
		var c: Vector2 = _centers[i]
		_grid_layer.draw_circle(c, _node_r * 0.92, Color(0.12, 0.16, 0.22, 0.75))
		_grid_layer.draw_arc(c, _node_r * 0.92, 0, TAU, 40, Color(0.55, 0.7, 0.85, 0.85), 2.0, true)

func _update_hud() -> void:
	var now := 0
	if _status == Status.PLAYING or _status == Status.PAUSED:
		now = _clock.now_ms()
	_hud.text = "%s\nScore %d\nCombo %d  Acc %.1f%%\n%d ms" % [
		NineDotConfig.DISPLAY_NAME,
		int(_score.get("score", 0)),
		int(_score["combo"]),
		NineDotJudge.accuracy_pct(_score),
		now,
	]
	_feedback_label.text = _feedback
	_pause_btn.visible = _status == Status.PLAYING or _status == Status.PAUSED
