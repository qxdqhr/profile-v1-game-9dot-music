extends RefCounted
class_name MyRoomGifts
## Gift catalog + simple preference table per slot.

const CATALOG: Array[Dictionary] = [
	{"id": "leek", "name": "葱", "base": 2},
	{"id": "candy", "name": "糖果", "base": 1},
	{"id": "ribbon", "name": "缎带", "base": 2},
	{"id": "tea", "name": "红茶", "base": 2},
	{"id": "mic", "name": "麦克风挂件", "base": 3},
	{"id": "plush", "name": "小玩偶", "base": 2},
]

## slot_id -> gift_id -> bonus (can be 0).
const PREF: Dictionary = {
	"miku": {"leek": 2, "mic": 1, "candy": 0},
	"rin": {"candy": 2, "ribbon": 1},
	"len": {"candy": 1, "mic": 1},
	"luka": {"tea": 2, "ribbon": 1},
	"meiko": {"tea": 2, "plush": 1},
	"kaito": {"mic": 2, "tea": 1},
}

static func list_gifts() -> Array[Dictionary]:
	return CATALOG.duplicate(true)

static func gift_by_id(gift_id: String) -> Dictionary:
	for g in CATALOG:
		if String(g["id"]) == gift_id:
			return g
	return {}

static func score_for(slot_id: String, gift_id: String) -> int:
	var g := gift_by_id(gift_id)
	if g.is_empty():
		return 0
	var base := int(g.get("base", 1))
	var pref_map: Dictionary = PREF.get(slot_id, {})
	var bonus := int(pref_map.get(gift_id, 0))
	return base + bonus

static func reaction_label(slot_id: String, gift_id: String) -> String:
	var pref_map: Dictionary = PREF.get(slot_id, {})
	var bonus := int(pref_map.get(gift_id, 0))
	if bonus >= 2:
		return "超喜欢！"
	if bonus >= 1:
		return "很开心"
	return "谢谢"
