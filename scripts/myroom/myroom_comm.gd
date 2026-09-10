extends RefCounted
class_name MyRoomComm
## Touch communication: Heart Gauge + Fever + anger (F 2nd–style hybrid).

const _Progress = preload("res://scripts/myroom/myroom_progress.gd")

const HEART_FILL_PER_SEC := 0.55
const HEART_BURST_AT := 1.0
const BURSTS_TO_ANGER := 3
const SUCCESS_FOR_FEVER := 3
const FEVER_DURATION_SEC := 8.0
const ZONE_MULT := {
	"hair": 1.0,
	"face": 1.15,
	"body": 0.85,
	"back": 1.25,
}

signal heart_changed(fill: float, fever: bool)
signal segment_result(ok: bool, message: String, affection_added: int)
signal anger_changed(angry: bool)
signal cooldown_changed(on_cooldown: bool)
signal invite_ready(game_id: String)

var slot_id: String = "miku"
var heart_fill: float = 0.0
var touching: bool = false
var touch_zone: String = "body"
var fever_active: bool = false
var fever_left: float = 0.0
var _holding: bool = false

func bind_slot(id: String) -> void:
	slot_id = id
	heart_fill = 0.0
	touching = false
	fever_active = false
	fever_left = 0.0

func begin_touch(zone: String) -> void:
	if _Progress.is_angry(slot_id):
		segment_result.emit(false, "生气中…送礼物或填满心条和好", 0)
		return
	if _Progress.is_on_cooldown(slot_id):
		cooldown_changed.emit(true)
		segment_result.emit(false, "休息一下再聊（冷却中）", 0)
		return
	touch_zone = zone if ZONE_MULT.has(zone) else "body"
	touching = true
	_holding = true
	if fever_active:
		# Fever: taps also nudge affection lightly.
		_fever_poke()

func end_touch() -> void:
	if not _holding:
		touching = false
		return
	_holding = false
	touching = false
	if _Progress.is_angry(slot_id):
		# Keep reconcile bar progress across pauses.
		heart_changed.emit(heart_fill, false)
		return
	if _Progress.is_on_cooldown(slot_id):
		heart_fill = 0.0
		heart_changed.emit(heart_fill, fever_active)
		return
	if fever_active:
		heart_fill = 0.0
		heart_changed.emit(heart_fill, fever_active)
		return
	_resolve_release()

func tick(delta: float) -> void:
	if fever_active:
		fever_left -= delta
		if fever_left <= 0.0:
			fever_active = false
			fever_left = 0.0
			heart_changed.emit(heart_fill, false)
	if not touching or not _holding:
		return
	if _Progress.is_angry(slot_id) or _Progress.is_on_cooldown(slot_id):
		return
	if fever_active:
		return
	var mult: float = float(ZONE_MULT.get(touch_zone, 1.0))
	heart_fill = minf(HEART_BURST_AT + 0.05, heart_fill + HEART_FILL_PER_SEC * mult * delta)
	heart_changed.emit(heart_fill, fever_active)
	if heart_fill >= HEART_BURST_AT:
		_on_burst()

func try_start_fever() -> bool:
	if fever_active:
		return true
	if not _Progress.consume_fever_charge(slot_id):
		return false
	fever_active = true
	fever_left = FEVER_DURATION_SEC
	heart_fill = 0.0
	heart_changed.emit(0.0, true)
	return true

func force_reconcile_via_heart() -> void:
	## Fill-to-max while angry reconciles (gift path also clears anger).
	if not _Progress.is_angry(slot_id):
		return
	_Progress.set_angry(slot_id, false)
	_Progress.reset_heart_bursts(slot_id)
	anger_changed.emit(false)
	segment_result.emit(true, "和好了", 0)

func begin_reconcile_touch() -> void:
	## While angry: holding fills a simplify reconcile bar using heart_fill.
	if not _Progress.is_angry(slot_id):
		return
	touching = true
	_holding = true

func tick_reconcile(delta: float) -> void:
	if not _Progress.is_angry(slot_id) or not _holding:
		return
	heart_fill = minf(1.0, heart_fill + 0.4 * delta)
	heart_changed.emit(heart_fill, false)
	if heart_fill >= 1.0:
		_holding = false
		touching = false
		heart_fill = 0.0
		force_reconcile_via_heart()

func _resolve_release() -> void:
	var fill := heart_fill
	heart_fill = 0.0
	heart_changed.emit(0.0, fever_active)
	if fill < 0.15:
		segment_result.emit(false, "再多摸摸看", 0)
		return
	# Sweet spot: mid-high fill without burst.
	var pts := 1
	if fill >= 0.55:
		pts = 2
	if fill >= 0.85:
		pts = 3
	_grant_success(pts, "开心！+%d" % pts)

func _on_burst() -> void:
	_holding = false
	touching = false
	heart_fill = 0.0
	heart_changed.emit(0.0, fever_active)
	var bursts := _Progress.add_heart_burst(slot_id)
	_Progress.reset_comm_streak(slot_id)
	segment_result.emit(false, "心条爆了…本段不加分", 0)
	if bursts >= BURSTS_TO_ANGER:
		_Progress.set_angry(slot_id, true)
		anger_changed.emit(true)
		segment_result.emit(false, "生气了，背过身去…", 0)

func _fever_poke() -> void:
	_grant_success(1, "Fever！+1", false)

func _grant_success(pts: int, msg: String, count_streak: bool = true) -> void:
	var r := _Progress.add_affection(slot_id, pts)
	_Progress.add_session_points(slot_id, int(r.get("added", 0)))
	if count_streak:
		var streak := _Progress.bump_comm_success(slot_id)
		if streak > 0 and streak % SUCCESS_FOR_FEVER == 0:
			_Progress.add_fever_charge(slot_id)
		if streak >= _Progress.COMM_SUCCESS_FOR_INVITE and streak % _Progress.COMM_SUCCESS_FOR_INVITE == 0:
			invite_ready.emit("acchi" if randf() < 0.5 else "alps")
	var extra := ""
	if bool(r.get("level_up", false)):
		extra = " 升级！Lv%d" % int(r.get("level", 1))
	segment_result.emit(true, msg + extra, int(r.get("added", 0)))
	if _Progress.is_on_cooldown(slot_id):
		cooldown_changed.emit(true)
