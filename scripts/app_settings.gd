extends Node
## Persisted player settings (volume, offset, vibration, hit SFX).

const SAVE_PATH := "user://nine_dot_settings.cfg"

var volume_linear: float = 1.0
var offset_ms: int = 0
var vibration_enabled: bool = true
var hit_sfx_enabled: bool = true

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	volume_linear = float(cfg.get_value("audio", "volume", 1.0))
	offset_ms = int(cfg.get_value("judge", "offset_ms", 0))
	vibration_enabled = bool(cfg.get_value("feedback", "vibration", true))
	hit_sfx_enabled = bool(cfg.get_value("feedback", "hit_sfx", true))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume_linear)
	cfg.set_value("judge", "offset_ms", offset_ms)
	cfg.set_value("feedback", "vibration", vibration_enabled)
	cfg.set_value("feedback", "hit_sfx", hit_sfx_enabled)
	cfg.save(SAVE_PATH)

func reset_offset() -> void:
	offset_ms = 0
	save_settings()
