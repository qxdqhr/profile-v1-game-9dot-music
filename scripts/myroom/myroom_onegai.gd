extends RefCounted
class_name MyRoomOnegai
## Random 「お願い」 requests; accepting applies a system-chosen result.

const KINDS: Array[Dictionary] = [
	{"id": "theme", "text": "想换个房间主题…可以吗？"},
	{"id": "furniture", "text": "想换一下家具布置…"},
	{"id": "slot_hint", "text": "要不要看看其他伙伴的房间？（需已解锁）"},
	{"id": "gift_hint", "text": "有点想要礼物呢…"},
]

static func roll() -> Dictionary:
	return KINDS[randi() % KINDS.size()].duplicate(true)

static func label_of(kind: String) -> String:
	for k in KINDS:
		if String(k["id"]) == kind:
			return String(k["text"])
	return ""
