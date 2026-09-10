extends RefCounted
class_name SongPaths
## Paths & category labels for the external song library.

const USER_ROOT := "user://songs"
const RES_CHARTS := "res://charts"
const SEED_MARKER := "user://songs/.seeded"
const CAT_OFFICIAL := "official"
const CAT_USERS := "users"

## Preferred display order; unknown dirs append alphabetically.
const CATEGORY_ORDER: Array[String] = [CAT_OFFICIAL, CAT_USERS]

const CATEGORY_LABELS := {
	CAT_OFFICIAL: "官方",
	CAT_USERS: "我的",
}

static func category_label(category: String) -> String:
	if CATEGORY_LABELS.has(category):
		return String(CATEGORY_LABELS[category])
	return category

static func category_root(category: String) -> String:
	return "%s/%s" % [USER_ROOT, category]

static func set_root(category: String, song_id: String) -> String:
	return "%s/%s/%s" % [USER_ROOT, category, song_id]

static func make_key(category: String, song_id: String) -> String:
	return "%s/%s" % [category, song_id]

static func parse_key(key: String) -> PackedStringArray:
	var parts := key.split("/", false, 1)
	if parts.size() != 2:
		return PackedStringArray()
	return parts
