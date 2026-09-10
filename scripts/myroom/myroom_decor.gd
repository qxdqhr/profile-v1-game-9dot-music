extends RefCounted
class_name MyRoomDecor
## Room themes + simple furniture sets.

const THEMES: Array[Dictionary] = [
	{"id": "teal", "name": "薄荷绿", "bg": Color(0.08, 0.12, 0.14), "floor": Color(0.18, 0.22, 0.26), "accent": Color(0.45, 0.85, 0.78)},
	{"id": "sakura", "name": "樱粉", "bg": Color(0.14, 0.08, 0.12), "floor": Color(0.28, 0.18, 0.22), "accent": Color(0.95, 0.6, 0.75)},
	{"id": "night", "name": "夜空", "bg": Color(0.04, 0.05, 0.12), "floor": Color(0.1, 0.12, 0.2), "accent": Color(0.45, 0.55, 0.95)},
	{"id": "sun", "name": "暖阳", "bg": Color(0.14, 0.12, 0.08), "floor": Color(0.28, 0.24, 0.16), "accent": Color(0.95, 0.8, 0.4)},
]

const FURNITURE: Array[Dictionary] = [
	{"id": "simple", "name": "简约"},
	{"id": "sofa", "name": "沙发角"},
	{"id": "stage", "name": "小舞台"},
]

static func theme_by_id(theme_id: String) -> Dictionary:
	for t in THEMES:
		if String(t["id"]) == theme_id:
			return t
	return THEMES[0]

static func furniture_by_id(fid: String) -> Dictionary:
	for f in FURNITURE:
		if String(f["id"]) == fid:
			return f
	return FURNITURE[0]
