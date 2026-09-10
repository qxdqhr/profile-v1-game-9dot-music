extends Node
## Persisted player settings (volume, offset, vibration, hit SFX, video fit, HUD).

const SAVE_PATH := "user://nine_dot_settings.cfg"

## Video layout vs landscape PV in portrait play (see RESEARCH-PORTRAIT-LANDSCAPE-VIDEO).
const VIDEO_FIT_BAND := "band" ## Top 16:9 strip (Fit 层)
const VIDEO_FIT_LETTERBOX := "fit" ## Full-screen FIT, letterbox (完整)
const VIDEO_FIT_COVER := "cover" ## Full-screen COVER crop (铺满)
const VIDEO_FIT_OPTIONS: Array[String] = [VIDEO_FIT_BAND, VIDEO_FIT_LETTERBOX, VIDEO_FIT_COVER]
const VIDEO_FIT_LABELS: Array[String] = ["Fit 层", "完整", "铺满"]

const _Hud = preload("res://scripts/play_hud_layout.gd")

var volume_linear: float = 1.0
var offset_ms: int = 0
var vibration_enabled: bool = true
var hit_sfx_enabled: bool = true
var video_fit: String = VIDEO_FIT_BAND
var hud_layout: String = _Hud.LAYOUT_STACK_CENTER

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
	var vf := String(cfg.get_value("video", "fit", VIDEO_FIT_BAND))
	video_fit = vf if vf in VIDEO_FIT_OPTIONS else VIDEO_FIT_BAND
	var hl := String(cfg.get_value("hud", "layout", _Hud.LAYOUT_STACK_CENTER))
	hud_layout = hl if _Hud.is_valid(hl) else _Hud.LAYOUT_STACK_CENTER

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume_linear)
	cfg.set_value("judge", "offset_ms", offset_ms)
	cfg.set_value("feedback", "vibration", vibration_enabled)
	cfg.set_value("feedback", "hit_sfx", hit_sfx_enabled)
	cfg.set_value("video", "fit", video_fit)
	cfg.set_value("hud", "layout", hud_layout)
	cfg.save(SAVE_PATH)

func reset_offset() -> void:
	offset_ms = 0
	save_settings()

func video_fit_index() -> int:
	var i := VIDEO_FIT_OPTIONS.find(video_fit)
	return i if i >= 0 else 0

func set_video_fit_index(i: int) -> void:
	if i < 0 or i >= VIDEO_FIT_OPTIONS.size():
		return
	video_fit = VIDEO_FIT_OPTIONS[i]
	save_settings()

func hud_layout_index() -> int:
	return _Hud.index_of(hud_layout)

func set_hud_layout_index(i: int) -> void:
	if i < 0 or i >= _Hud.OPTIONS.size():
		return
	hud_layout = _Hud.OPTIONS[i]
	save_settings()
