extends Control
## Play: Tap fill + Slide arrows + Arm/Track + feedback (M5 / PRD v1.2).

enum Status { READY, PLAYING, PAUSED, ENDED }

const FALLBACK_META := "res://charts/song-metronome-001/meta.json"
const FALLBACK_NOTES := "res://charts/song-metronome-001/normal.json"
const HIT_FX_MS := 280
const ARROW_COUNT := 5

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
var _hit_fx: Array = []
var _sfx: AudioStreamPlayer
var _feedback_until_ms: int = 0
var _last_empty_fb_ms: int = -99999

@onready var _hud: Label = $UI/HUD
@onready var _feedback_label: Label = $UI/Feedback
@onready var _pause_btn: TextureButton = $UI/Controls/PauseBtn
@onready var _pause_menu: ColorRect = $UI/PauseMenu
@onready var _restart_btn: TextureButton = $UI/PauseMenu/Row/RestartBtn
@onready var _songs_btn: TextureButton = $UI/PauseMenu/Row/SongsBtn
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _start_btn: Button = $UI/Overlay/VBox/StartBtn
@onready var _retry_btn: Button = $UI/Overlay/VBox/RetryBtn
@onready var _back_btn: Button = $UI/Overlay/VBox/BackBtn
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var _video: VideoStreamPlayer = $Video
@onready var _grid_layer: Control = $GridLayer

var _tex_pause: Texture2D
var _tex_play: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(NineDotConfig.VIEW_W, NineDotConfig.VIEW_H)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_diff_key = PlaySession.diff if String(PlaySession.diff) != "" else "normal"
	_meta_path = PlaySession.meta_path if String(PlaySession.meta_path) != "" else FALLBACK_META
	_tex_pause = load("res://assets/icons/pause.svg") as Texture2D
	_tex_play = load("res://assets/icons/play.svg") as Texture2D
	_audio.volume_db = linear_to_db(maxi(0.001, AppSettings.volume_linear))
	_clock = NineDotClock.new()
	add_child(_clock)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "HitSfx"
	add_child(_sfx)
	NineDotFeedback.ensure_streams()
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
	_hit_fx.clear()
	_feedback_until_ms = 0
	_last_empty_fb_ms = -99999
	_feedback = "点击开始 · %s" % _diff_key.capitalize()
	_overlay.visible = true
	_over_msg.text = "%s\n%s\n%s\n点开始" % [NineDotConfig.DISPLAY_NAME, String(_meta.get("title", "")), _diff_key.capitalize()]
	_start_btn.visible = true
	_retry_btn.visible = false
	_back_btn.visible = true
	_set_pause_icon(false)
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
	_hit_fx.clear()
	_feedback_until_ms = 0
	_last_empty_fb_ms = -99999
	var duration := int(_meta.get("durationMs", 16000))
	_prepare_streams(false)
	_clock.setup(_audio, int(_meta.get("offsetMs", 0)), AppSettings.offset_ms, duration + 500)
	_clock.start()
	if _video.stream:
		_video.play()
		_video.stream_position = 0.0
	_status = Status.PLAYING
	_overlay.visible = false
	_pause_menu.visible = false
	_set_pause_icon(false)
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

func _set_pause_icon(paused: bool) -> void:
	if _pause_btn == null:
		return
	_pause_btn.texture_normal = _tex_play if paused else _tex_pause
	_pause_btn.tooltip_text = "继续" if paused else "暂停"

func _enter_pause() -> void:
	_status = Status.PAUSED
	_clock.pause()
	if _video.stream:
		_video.paused = true
	_set_pause_icon(true)
	_pause_menu.visible = true
	_feedback = ""
	_update_hud()

func _leave_pause() -> void:
	_status = Status.PLAYING
	_clock.resume()
	if _video.stream:
		_video.paused = false
	_set_pause_icon(false)
	_pause_menu.visible = false
	_feedback = "继续"
	_update_hud()

func _on_pause_menu_gui_input(event: InputEvent) -> void:
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
		_prune_hit_fx(now)
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

func _miss_deadline(note: Dictionary) -> int:
	if String(note["type"]) == "slide":
		return int(note["tMs"]) + NineDotConfig.SLIDE_GOOD_MS
	return int(note["tMs"]) + NineDotConfig.JUDGE_GOOD_MS

func _sweep_misses(now: int) -> void:
	for n in _notes:
		if bool(n["judged"]):
			continue
		if now > _miss_deadline(n):
			_resolve(n, NineDotConfig.Grade.MISS, "Miss", Vector2.ZERO, true)

func _set_feedback(text: String, hold: bool = true) -> void:
	_feedback = text
	if hold:
		_feedback_until_ms = _clock.now_ms() + NineDotConfig.FEEDBACK_HOLD_MS

func _reject_feedback(text: String, pos: Vector2, soft: bool) -> void:
	var now := _clock.now_ms()
	if now - _last_empty_fb_ms < NineDotConfig.EMPTY_FEEDBACK_COOLDOWN_MS:
		return
	_last_empty_fb_ms = now
	_set_feedback(text, true)
	_spawn_hit_fx(pos, NineDotConfig.Grade.MISS, false)
	if soft:
		NineDotFeedback.play_empty(_sfx)
	else:
		NineDotFeedback.play_miss(_sfx)
		NineDotFeedback.vibrate_miss()

func _prune_hit_fx(now: int) -> void:
	var kept: Array = []
	for fx in _hit_fx:
		if int(fx["until"]) > now:
			kept.append(fx)
	_hit_fx = kept

func _spawn_hit_fx(pos: Vector2, grade: int, is_slide: bool) -> void:
	var now := _clock.now_ms()
	var col := NineDotConfig.COLOR_SLIDE if is_slide else NineDotConfig.COLOR_TAP
	if grade == NineDotConfig.Grade.MISS:
		col = Color(0.55, 0.55, 0.6, 1.0)
	elif grade == NineDotConfig.Grade.PERFECT:
		col = Color(1.0, 1.0, 1.0, 1.0)
	_hit_fx.append({
		"pos": pos,
		"until": now + HIT_FX_MS,
		"born": now,
		"color": col,
		"grade": grade,
	})

func _resolve(note: Dictionary, grade: int, fb: String, fx_pos: Vector2, play_audio: bool) -> void:
	if bool(note["judged"]):
		return
	note["judged"] = true
	note["grade"] = grade
	_score = NineDotJudge.apply(_score, grade)
	_set_feedback(fb, true)
	var is_slide := String(note["type"]) == "slide"
	if fx_pos != Vector2.ZERO:
		_spawn_hit_fx(fx_pos, grade, is_slide)
	elif is_slide:
		var ends := _slide_ends(note)
		_spawn_hit_fx(ends[0].lerp(ends[1], 0.5), grade, true)
	else:
		_spawn_hit_fx(_centers[int(note["node"]) - 1], grade, false)
	if not play_audio:
		return
	if grade == NineDotConfig.Grade.MISS:
		NineDotFeedback.play_miss(_sfx)
		NineDotFeedback.vibrate_miss()
	elif is_slide:
		NineDotFeedback.play_slide(_sfx)
		NineDotFeedback.vibrate_complete()
	else:
		NineDotFeedback.play_tap(_sfx)

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
	var node := NineDotGeometry.hit_node(_centers, pos, _node_r)
	var slide_idx := _find_slide_candidate(now, pos)
	# Prefer Tap when finger is clearly on a node (avoids Slide stealing dense charts).
	if node > 0 and slide_idx >= 0:
		var ends := _slide_ends(_notes[slide_idx])
		var dist_edge := NineDotGeometry.dist_to_segment(pos, ends[0], ends[1])
		var dist_node := pos.distance_to(_centers[node - 1])
		if dist_node <= _node_r * 0.92 and dist_node + 4.0 < dist_edge:
			slide_idx = -1
	if slide_idx >= 0:
		var note: Dictionary = _notes[slide_idx]
		var ends2 := _slide_ends(note)
		_fingers[id] = {
			"kind": "slide",
			"note_idx": slide_idx,
			"start": ends2[0],
			"end": ends2[1],
			"max_progress": NineDotGeometry.progress_on_segment(pos, ends2[0], ends2[1]),
			"off_since": -1,
		}
		NineDotFeedback.vibrate_arm()
		_set_feedback("Slide…", false)
		return
	if node > 0:
		var tap_idx := _find_tap_candidate(now, node)
		if tap_idx >= 0:
			var note2: Dictionary = _notes[tap_idx]
			var signed := now - int(note2["tMs"])
			var g := NineDotJudge.grade_for_delta_ms(absi(signed))
			_resolve(note2, g, NineDotJudge.feedback_label(g, signed), _centers[node - 1], true)
			return
		# Late press on a still-alive note → consume as Miss with feedback (not silent).
		var late_idx := _find_late_tap_on_node(now, node)
		if late_idx >= 0:
			var late_note: Dictionary = _notes[late_idx]
			_resolve(late_note, NineDotConfig.Grade.MISS, "Miss Late", _centers[node - 1], true)
			return
		var early_idx := _find_early_tap_on_node(now, node)
		if early_idx >= 0:
			_reject_feedback("Too Early", _centers[node - 1], true)
			_fingers[id] = { "kind": "idle", "pos": pos }
			return
		_reject_feedback("Empty", _centers[node - 1], true)
		_fingers[id] = { "kind": "idle", "pos": pos }
		return
	_reject_feedback("Empty", pos, true)
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
	var now := _clock.now_ms()
	var dist := NineDotGeometry.dist_to_segment(pos, a, b)
	var limit := _band * 2.0
	if dist > limit:
		if int(g.get("off_since", -1)) < 0:
			g["off_since"] = now
		elif now - int(g["off_since"]) > NineDotConfig.SLIDE_OFF_BAND_GRACE_MS:
			_resolve(note, NineDotConfig.Grade.MISS, "Miss", pos, true)
			_fingers.erase(id)
			return
		_fingers[id] = g
		return
	g["off_since"] = -1
	var prog := NineDotGeometry.progress_on_segment(pos, a, b)
	g["max_progress"] = maxf(float(g.get("max_progress", 0.0)), prog)
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
	var now := _clock.now_ms()
	var off_since := int(g.get("off_since", -1))
	var off := dist > _band * 2.0 and (off_since < 0 or now - off_since > NineDotConfig.SLIDE_OFF_BAND_GRACE_MS)
	var prog := maxf(float(g.get("max_progress", 0.0)), NineDotGeometry.progress_on_segment(pos, a, b))
	if off or prog < NineDotConfig.SLIDE_COMPLETE_FRAC:
		_resolve(note, NineDotConfig.Grade.MISS, "Miss", pos, true)
		return
	var signed := now - int(note["tMs"])
	var grade := NineDotJudge.grade_for_slide_delta_ms(absi(signed))
	_resolve(note, grade, NineDotJudge.feedback_label(grade, signed), pos, true)

func _finish_slide(id: int) -> void:
	if not _fingers.has(id):
		return
	var g: Dictionary = _fingers[id]
	var note: Dictionary = _notes[int(g["note_idx"])]
	if bool(note["judged"]):
		_fingers.erase(id)
		return
	var now := _clock.now_ms()
	var signed := now - int(note["tMs"])
	var grade := NineDotJudge.grade_for_slide_delta_ms(absi(signed))
	var mid: Vector2 = Vector2(g["start"]).lerp(Vector2(g["end"]), 0.5)
	_resolve(note, grade, NineDotJudge.feedback_label(grade, signed), mid, true)
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

## Past Good window but not yet auto-swept — consume as Miss with feedback.
func _find_late_tap_on_node(now: int, node: int) -> int:
	var best := -1
	var best_t := 1 << 30
	for i in range(_notes.size()):
		var n: Dictionary = _notes[i]
		if bool(n["judged"]) or String(n["type"]) != "tap":
			continue
		if int(n["node"]) != node:
			continue
		var t := int(n["tMs"])
		if now <= t + NineDotConfig.JUDGE_GOOD_MS:
			continue
		if now > t + NineDotConfig.JUDGE_GOOD_MS + 80:
			continue
		if t < best_t:
			best_t = t
			best = i
	return best

## Inside approach but earlier than Good — warn without consuming.
func _find_early_tap_on_node(now: int, node: int) -> int:
	var best := -1
	var best_until := 1 << 30
	for i in range(_notes.size()):
		var n: Dictionary = _notes[i]
		if bool(n["judged"]) or String(n["type"]) != "tap":
			continue
		if int(n["node"]) != node:
			continue
		var t := int(n["tMs"])
		var until := t - now
		if until <= NineDotConfig.JUDGE_GOOD_MS:
			continue
		if until > NineDotConfig.APPROACH_MS:
			continue
		if until < best_until:
			best_until = until
			best = i
	return best

func _find_slide_candidate(now: int, pos: Vector2) -> int:
	var best := -1
	var best_abs := NineDotConfig.APPROACH_MS + NineDotConfig.JUDGE_GOOD_MS + 1
	for i in range(_notes.size()):
		var n: Dictionary = _notes[i]
		if bool(n["judged"]) or String(n["type"]) != "slide":
			continue
		var t := int(n["tMs"])
		# Arm window: [tMs - APPROACH, tMs + GOOD]
		if now < t - NineDotConfig.APPROACH_MS:
			continue
		if now > t + NineDotConfig.JUDGE_GOOD_MS:
			continue
		var ends := _slide_ends(n)
		if NineDotGeometry.dist_to_segment(pos, ends[0], ends[1]) > _band * 2.0:
			continue
		var near_start := pos.distance_to(ends[0]) <= _node_r * 1.5
		var prog := NineDotGeometry.progress_on_segment(pos, ends[0], ends[1])
		if not near_start and prog > 0.28:
			continue
		var d := absi(now - t)
		if d < best_abs:
			best_abs = d
			best = i
	return best

func _draw_chevron(pos: Vector2, dir: Vector2, size: float, color: Color, width: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var d := dir.normalized()
	var perp := Vector2(-d.y, d.x)
	var tip := pos + d * size
	var left := pos - d * size * 0.45 + perp * size * 0.55
	var right := pos - d * size * 0.45 - perp * size * 0.55
	_grid_layer.draw_polyline(PackedVector2Array([left, tip, right]), color, width, true)

func _draw_slide_arrows(ends: PackedVector2Array, until: int, tracking_prog: float, armed: bool) -> void:
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var dir := b - a
	var alpha := 1.0 - clampf(float(maxi(until, 0)) / float(NineDotConfig.APPROACH_MS), 0.0, 0.75)
	if armed:
		alpha = maxf(alpha, 0.9)
	var phase := float(Time.get_ticks_msec()) * 0.004
	var band_col := NineDotConfig.COLOR_SLIDE_SOFT
	band_col.a = 0.25 + 0.35 * alpha
	_grid_layer.draw_line(a, b, band_col, 10.0, true)
	for i in range(ARROW_COUNT):
		var base := (float(i) / float(ARROW_COUNT) + phase)
		base = base - floorf(base)
		var t := base
		# Dim arrows already "passed" relative to tracking progress when armed.
		var col := NineDotConfig.COLOR_SLIDE
		col.a = (0.35 + 0.65 * alpha) * (0.45 if t < tracking_prog else 1.0)
		var p := a.lerp(b, t)
		_draw_chevron(p, dir, 9.0, col, 2.4)
	_grid_layer.draw_circle(a, 7.0, Color(NineDotConfig.COLOR_SLIDE, alpha))

func _draw_tap_fill(center: Vector2, until: int) -> void:
	# fill 0 at approach start, 1 at tMs (until==0)
	var fill := 1.0 - clampf(float(until) / float(NineDotConfig.APPROACH_MS), 0.0, 1.0)
	if until < 0:
		fill = 1.0
	var outer := _node_r * 1.08
	var inner := outer * fill
	_grid_layer.draw_arc(center, outer, 0, TAU, 56, Color(NineDotConfig.COLOR_TAP, 0.95), 3.2, true)
	if inner > 1.5:
		var fill_c := NineDotConfig.COLOR_TAP_FILL
		fill_c.a = 0.25 + 0.5 * fill
		_grid_layer.draw_circle(center, inner, fill_c)
	if fill >= 0.98:
		_grid_layer.draw_arc(center, outer, 0, TAU, 56, Color(1, 1, 1, 0.85), 2.0, true)

func _tracking_progress_for_note(note_idx: int) -> float:
	for id in _fingers:
		var g: Dictionary = _fingers[id]
		if String(g.get("kind", "")) == "slide" and int(g.get("note_idx", -1)) == note_idx:
			return float(g.get("max_progress", 0.0))
	return 0.0

func _is_note_armed(note_idx: int) -> bool:
	for id in _fingers:
		var g: Dictionary = _fingers[id]
		if String(g.get("kind", "")) == "slide" and int(g.get("note_idx", -1)) == note_idx:
			return true
	return false

func _draw_grid() -> void:
	var now := 0
	if _status == Status.PLAYING or _status == Status.PAUSED:
		now = _clock.now_ms()
	for e in NineDotGeometry.legal_edges():
		var a: int = e[0]
		var b: int = e[1]
		_grid_layer.draw_line(_centers[a - 1], _centers[b - 1], Color(0.25, 0.32, 0.4, 0.45), 2.0, true)
	# Base pads under notes so fill / arrows stay readable on top.
	for i in range(_centers.size()):
		var c: Vector2 = _centers[i]
		_grid_layer.draw_circle(c, _node_r * 0.88, Color(0.12, 0.16, 0.22, 0.72))
		_grid_layer.draw_arc(c, _node_r * 0.88, 0, TAU, 40, Color(0.55, 0.7, 0.85, 0.75), 2.0, true)
	for i in range(_notes.size()):
		var n: Dictionary = _notes[i]
		if bool(n["judged"]):
			continue
		var t := int(n["tMs"])
		var until := t - now
		var late_limit := NineDotConfig.SLIDE_GOOD_MS if String(n["type"]) == "slide" else NineDotConfig.JUDGE_GOOD_MS
		if until > NineDotConfig.APPROACH_MS or until < -late_limit:
			continue
		if String(n["type"]) == "tap":
			_draw_tap_fill(_centers[int(n["node"]) - 1], until)
		else:
			_draw_slide_arrows(_slide_ends(n), until, _tracking_progress_for_note(i), _is_note_armed(i))
	for fx in _hit_fx:
		var born := int(fx["born"])
		var life := clampf(1.0 - float(now - born) / float(HIT_FX_MS), 0.0, 1.0)
		var p: Vector2 = fx["pos"]
		var col: Color = fx["color"]
		col.a = life
		var r := _node_r * (0.4 + (1.0 - life) * 1.4)
		_grid_layer.draw_arc(p, r, 0, TAU, 40, col, 3.0 * life + 1.0, true)
		_grid_layer.draw_circle(p, 6.0 * life, Color(col.r, col.g, col.b, life * 0.7))

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
	if _status == Status.PLAYING and now > _feedback_until_ms and _feedback_until_ms > 0:
		# Keep last feedback until hold expires; do not clear mid-hold.
		pass
	_feedback_label.text = _feedback
	_pause_btn.visible = _status == Status.PLAYING or _status == Status.PAUSED
