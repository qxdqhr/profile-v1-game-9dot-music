extends Node
## Persisted player settings (MVP: volume + judge offset).

const SAVE_PATH := "user://nine_dot_settings.cfg"

var volume_linear: float = 1.0
var offset_ms: int = 0

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	volume_linear = float(cfg.get_value("audio", "volume", 1.0))
	offset_ms = int(cfg.get_value("judge", "offset_ms", 0))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume_linear)
	cfg.set_value("judge", "offset_ms", offset_ms)
	cfg.save(SAVE_PATH)

func reset_offset() -> void:
	offset_ms = 0
	save_settings()
