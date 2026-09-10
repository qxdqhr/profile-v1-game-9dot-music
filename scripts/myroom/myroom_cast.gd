extends RefCounted
class_name MyRoomCast
## Character room slots (logical Vocaloid cast; models are OC / user import).

## unlock_at: official NORMAL+ clear count required to unlock this slot.
const SLOTS: Array[Dictionary] = [
	{"id": "miku", "name": "Miku", "tint": Color(0.45, 0.85, 0.78), "unlock_at": 0},
	{"id": "rin", "name": "Rin", "tint": Color(0.95, 0.78, 0.35), "unlock_at": 3},
	{"id": "len", "name": "Len", "tint": Color(0.95, 0.88, 0.45), "unlock_at": 6},
	{"id": "luka", "name": "Luka", "tint": Color(0.92, 0.55, 0.75), "unlock_at": 9},
	{"id": "meiko", "name": "MEIKO", "tint": Color(0.85, 0.35, 0.32), "unlock_at": 12},
	{"id": "kaito", "name": "KAITO", "tint": Color(0.35, 0.55, 0.95), "unlock_at": 15},
]

static func slot_by_id(slot_id: String) -> Dictionary:
	for s in SLOTS:
		if String(s["id"]) == slot_id:
			return s
	return SLOTS[0]

static func display_name(slot_id: String) -> String:
	return String(slot_by_id(slot_id).get("name", slot_id))

static func tint(slot_id: String) -> Color:
	return slot_by_id(slot_id).get("tint", Color(0.45, 0.85, 0.78)) as Color

static func unlock_threshold(slot_id: String) -> int:
	return int(slot_by_id(slot_id).get("unlock_at", 999))
