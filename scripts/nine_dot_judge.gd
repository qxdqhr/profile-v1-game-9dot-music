extends RefCounted
class_name NineDotJudge

static func grade_for_delta_ms(abs_delta: int) -> int:
	if abs_delta <= NineDotConfig.JUDGE_PERFECT_MS:
		return NineDotConfig.Grade.PERFECT
	if abs_delta <= NineDotConfig.JUDGE_GREAT_MS:
		return NineDotConfig.Grade.GREAT
	if abs_delta <= NineDotConfig.JUDGE_GOOD_MS:
		return NineDotConfig.Grade.GOOD
	return NineDotConfig.Grade.MISS

static func grade_name(g: int) -> String:
	match g:
		NineDotConfig.Grade.PERFECT:
			return "Perfect"
		NineDotConfig.Grade.GREAT:
			return "Great"
		NineDotConfig.Grade.GOOD:
			return "Good"
		_:
			return "Miss"

static func initial_score() -> Dictionary:
	return {
		"perfect": 0,
		"great": 0,
		"good": 0,
		"miss": 0,
		"combo": 0,
		"max_combo": 0,
	}

static func apply(score: Dictionary, grade: int) -> Dictionary:
	var s := score.duplicate()
	match grade:
		NineDotConfig.Grade.PERFECT:
			s["perfect"] += 1
			s["combo"] += 1
		NineDotConfig.Grade.GREAT:
			s["great"] += 1
			s["combo"] += 1
		NineDotConfig.Grade.GOOD:
			s["good"] += 1
			s["combo"] += 1
		_:
			s["miss"] += 1
			s["combo"] = 0
	s["max_combo"] = maxi(int(s["max_combo"]), int(s["combo"]))
	return s

static func accuracy_pct(score: Dictionary) -> float:
	var total := int(score["perfect"]) + int(score["great"]) + int(score["good"]) + int(score["miss"])
	if total <= 0:
		return 0.0
	var weighted := float(score["perfect"]) * 1.0 + float(score["great"]) * 0.75 + float(score["good"]) * 0.5
	return weighted / float(total) * 100.0
