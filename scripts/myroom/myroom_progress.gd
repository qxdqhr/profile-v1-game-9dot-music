extends RefCounted
class_name MyRoomProgress
## Persist MyRoom unlock / affection / décor / session state.

const _Paths = preload("res://scripts/myroom/myroom_paths.gd")
const _Cast = preload("res://scripts/myroom/myroom_cast.gd")

## Fallback if cast table missing a threshold (legacy).
const UNLOCK_CLEARS_PER_SLOT := 3

const AFFECTION_MAX_LEVEL := 6
const AFFECTION_GAUGE_MAX := 10
const SESSION_POINT_CAP := 8
const SESSION_COOLDOWN_SEC := 45.0
const COMM_SUCCESS_FOR_INVITE := 3

static func ensure() -> void:
	_Paths.ensure_dirs()

static func _cfg() -> ConfigFile:
	ensure()
	var cfg := ConfigFile.new()
	cfg.load(_Paths.USER_PROGRESS)
	return cfg

static func _save(cfg: ConfigFile) -> void:
	cfg.save(_Paths.USER_PROGRESS)

# --- Unlock ---

static func get_official_normal_clears() -> int:
	return int(_cfg().get_value("unlock", "official_normal_clears", 0))

static func add_official_normal_clear() -> void:
	var cfg := _cfg()
	var n := int(cfg.get_value("unlock", "official_normal_clears", 0)) + 1
	cfg.set_value("unlock", "official_normal_clears", n)
	_save(cfg)

static func is_slot_unlocked(slot_id: String) -> bool:
	return get_official_normal_clears() >= _Cast.unlock_threshold(slot_id)

static func unlocked_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in _Cast.SLOTS:
		if is_slot_unlocked(String(s["id"])):
			out.append(s)
	return out

static func unlocked_slot_count() -> int:
	return unlocked_slots().size()

static func active_slot() -> String:
	var id := String(_cfg().get_value("room", "active_slot", "miku"))
	if not is_slot_unlocked(id):
		return "miku"
	return id

static func set_active_slot(slot_id: String) -> void:
	if not is_slot_unlocked(slot_id):
		return
	var cfg := _cfg()
	cfg.set_value("room", "active_slot", slot_id)
	_save(cfg)

# --- Affection ---

static func affection_level(slot_id: String) -> int:
	return clampi(int(_cfg().get_value("affection", "%s_level" % slot_id, 1)), 1, AFFECTION_MAX_LEVEL)

static func affection_gauge(slot_id: String) -> int:
	return clampi(int(_cfg().get_value("affection", "%s_gauge" % slot_id, 0)), 0, AFFECTION_GAUGE_MAX)

static func set_affection(slot_id: String, level: int, gauge: int) -> void:
	var cfg := _cfg()
	level = clampi(level, 1, AFFECTION_MAX_LEVEL)
	gauge = clampi(gauge, 0, AFFECTION_GAUGE_MAX)
	if level >= AFFECTION_MAX_LEVEL:
		gauge = AFFECTION_GAUGE_MAX
	cfg.set_value("affection", "%s_level" % slot_id, level)
	cfg.set_value("affection", "%s_gauge" % slot_id, gauge)
	_save(cfg)

## Add affection points (returns {added, level_up, level, gauge}).
static func add_affection(slot_id: String, points: int) -> Dictionary:
	var level := affection_level(slot_id)
	var gauge := affection_gauge(slot_id)
	var added := 0
	var level_up := false
	for _i in range(maxi(0, points)):
		if level >= AFFECTION_MAX_LEVEL and gauge >= AFFECTION_GAUGE_MAX:
			break
		gauge += 1
		added += 1
		if gauge > AFFECTION_GAUGE_MAX:
			if level < AFFECTION_MAX_LEVEL:
				level += 1
				gauge = 0
				level_up = true
			else:
				gauge = AFFECTION_GAUGE_MAX
				break
	set_affection(slot_id, level, gauge)
	return {"added": added, "level_up": level_up, "level": level, "gauge": gauge}

static func set_affection_level(slot_id: String, level: int) -> void:
	set_affection(slot_id, level, affection_gauge(slot_id))

# --- Mood / anger ---

static func is_angry(slot_id: String) -> bool:
	return bool(_cfg().get_value("mood", "%s_angry" % slot_id, false))

static func set_angry(slot_id: String, angry: bool) -> void:
	var cfg := _cfg()
	cfg.set_value("mood", "%s_angry" % slot_id, angry)
	if not angry:
		cfg.set_value("mood", "%s_bursts" % slot_id, 0)
	_save(cfg)

static func heart_bursts(slot_id: String) -> int:
	return int(_cfg().get_value("mood", "%s_bursts" % slot_id, 0))

static func add_heart_burst(slot_id: String) -> int:
	var cfg := _cfg()
	var n := int(cfg.get_value("mood", "%s_bursts" % slot_id, 0)) + 1
	cfg.set_value("mood", "%s_bursts" % slot_id, n)
	_save(cfg)
	return n

static func reset_heart_bursts(slot_id: String) -> void:
	var cfg := _cfg()
	cfg.set_value("mood", "%s_bursts" % slot_id, 0)
	_save(cfg)

# --- Session / cooldown ---

static func session_points(slot_id: String) -> int:
	return int(_cfg().get_value("session", "%s_points" % slot_id, 0))

static func cooldown_until(slot_id: String) -> float:
	return float(_cfg().get_value("session", "%s_cool_until" % slot_id, 0.0))

static func is_on_cooldown(slot_id: String) -> bool:
	return Time.get_unix_time_from_system() < cooldown_until(slot_id)

static func cooldown_remaining(slot_id: String) -> float:
	return maxf(0.0, cooldown_until(slot_id) - Time.get_unix_time_from_system())

static func add_session_points(slot_id: String, pts: int) -> void:
	var cfg := _cfg()
	var n := int(cfg.get_value("session", "%s_points" % slot_id, 0)) + pts
	cfg.set_value("session", "%s_points" % slot_id, n)
	if n >= SESSION_POINT_CAP:
		cfg.set_value("session", "%s_cool_until" % slot_id, Time.get_unix_time_from_system() + SESSION_COOLDOWN_SEC)
		cfg.set_value("session", "%s_points" % slot_id, 0)
	_save(cfg)

static func clear_cooldown(slot_id: String) -> void:
	var cfg := _cfg()
	cfg.set_value("session", "%s_cool_until" % slot_id, 0.0)
	cfg.set_value("session", "%s_points" % slot_id, 0)
	_save(cfg)

# --- Comm streak / fever ---

static func comm_success_streak(slot_id: String) -> int:
	return int(_cfg().get_value("comm", "%s_streak" % slot_id, 0))

static func bump_comm_success(slot_id: String) -> int:
	var cfg := _cfg()
	var n := int(cfg.get_value("comm", "%s_streak" % slot_id, 0)) + 1
	cfg.set_value("comm", "%s_streak" % slot_id, n)
	_save(cfg)
	return n

static func reset_comm_streak(slot_id: String) -> void:
	var cfg := _cfg()
	cfg.set_value("comm", "%s_streak" % slot_id, 0)
	_save(cfg)

static func fever_charges(slot_id: String) -> int:
	return int(_cfg().get_value("comm", "%s_fever" % slot_id, 0))

static func add_fever_charge(slot_id: String) -> void:
	var cfg := _cfg()
	cfg.set_value("comm", "%s_fever" % slot_id, int(cfg.get_value("comm", "%s_fever" % slot_id, 0)) + 1)
	_save(cfg)

static func consume_fever_charge(slot_id: String) -> bool:
	var cfg := _cfg()
	var n := int(cfg.get_value("comm", "%s_fever" % slot_id, 0))
	if n <= 0:
		return false
	cfg.set_value("comm", "%s_fever" % slot_id, n - 1)
	_save(cfg)
	return true

# --- Décor ---

static func decor_theme() -> String:
	return String(_cfg().get_value("decor", "theme", "teal"))

static func set_decor_theme(theme_id: String) -> void:
	var cfg := _cfg()
	cfg.set_value("decor", "theme", theme_id)
	_save(cfg)

static func furniture_id() -> String:
	return String(_cfg().get_value("decor", "furniture", "simple"))

static func set_furniture_id(fid: String) -> void:
	var cfg := _cfg()
	cfg.set_value("decor", "furniture", fid)
	_save(cfg)

# --- Onegai ---

static func onegai_kind() -> String:
	return String(_cfg().get_value("onegai", "kind", ""))

static func set_onegai(kind: String) -> void:
	var cfg := _cfg()
	cfg.set_value("onegai", "kind", kind)
	_save(cfg)

static func clear_onegai() -> void:
	set_onegai("")
