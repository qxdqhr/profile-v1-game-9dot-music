extends RefCounted
class_name MyRoomPlatform
## MyRoom is APK-only for shipping; Godot editor stays open for development.

static func is_available() -> bool:
	# Local editor / debug builds can enter the module.
	if OS.has_feature("editor"):
		return true
	if OS.has_feature("myroom_debug"):
		return true
	# Shipping: Android APK only (not Web, not desktop exports).
	return OS.get_name() == "Android"

static func unavailable_hint() -> String:
	return "MyRoom 仅在 Android APK 可用"
