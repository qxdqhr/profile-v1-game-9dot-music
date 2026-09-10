extends Node
## Persisted player settings (volume, offset, vibration, hit SFX, video fit, HUD, note colors / slide width).

const SAVE_PATH := "user://nine_dot_settings.cfg"

## Video layout vs landscape PV in portrait play (see RESEARCH-PORTRAIT-LANDSCAPE-VIDEO).
const VIDEO_FIT_BAND := "band" ## Top 16:9 strip (Fit 层)
const VIDEO_FIT_LETTERBOX := "fit" ## Full-screen FIT, letterbox (完整)
const VIDEO_FIT_COVER := "cover" ## Full-screen COVER crop (铺满)
const VIDEO_FIT_OPTIONS: Array[String] = [VIDEO_FIT_BAND, VIDEO_FIT_LETTERBOX, VIDEO_FIT_COVER]
const VIDEO_FIT_LABELS: Array[String] = ["Fit 层", "完整", "铺满"]

## Note color presets (粉橙黄绿蓝紫白) — UI shows swatches only.
const NOTE_COLOR_IDS: Array[String] = [
	"pink", "orange", "yellow", "green", "blue", "purple", "white",
]
const NOTE_COLOR_BY_ID := {
	"pink": Color(0.95, 0.28, 0.55, 1.0),
	"orange": Color(1.0, 0.55, 0.2, 1.0),
	"yellow": Color(1.0, 0.82, 0.22, 1.0),
	"green": Color(0.35, 0.85, 0.45, 1.0),
	"blue": Color(0.35, 0.65, 1.0, 1.0),
	"purple": Color(0.72, 0.42, 0.95, 1.0),
	"white": Color(0.95, 0.96, 0.98, 1.0),
}
const DEFAULT_TAP_PRESET := "pink"
const DEFAULT_SLIDE_PRESET := "yellow"

## Slide track thickness: thin / medium / wide — UI shows bar icons only.
const SLIDE_WIDTH_IDS: Array[String] = ["thin", "medium", "wide"]
const DEFAULT_SLIDE_WIDTH := "medium"
## Runtime draw metrics: band_px, chevron_size, chevron_stroke, end_radius
const SLIDE_WIDTH_METRICS := {
	"thin": {"band": 5.0, "chevron": 6.5, "stroke": 1.6, "end": 5.0},
	"medium": {"band": 10.0, "chevron": 9.0, "stroke": 2.4, "end": 7.0},
	"wide": {"band": 16.0, "chevron": 12.0, "stroke": 3.2, "end": 9.0},
}
const SLIDE_WIDTH_ICON_H := {"thin": 3, "medium": 7, "wide": 13}

const _Hud = preload("res://scripts/play_hud_layout.gd")
const _Icons = preload("res://scripts/note_style_icons.gd")

var volume_linear: float = 1.0
var offset_ms: int = 0
var vibration_enabled: bool = true
var hit_sfx_enabled: bool = true
var video_fit: String = VIDEO_FIT_BAND
var hud_layout: String = _Hud.LAYOUT_STACK_CENTER
var tap_preset: String = DEFAULT_TAP_PRESET
var slide_preset: String = DEFAULT_SLIDE_PRESET
var slide_width: String = DEFAULT_SLIDE_WIDTH

var tap_color: Color:
	get:
		return color_for_preset(tap_preset)

var slide_color: Color:
	get:
		return color_for_preset(slide_preset)

func _ready() -> void:
	load_settings()

func color_for_preset(preset_id: String) -> Color:
	if NOTE_COLOR_BY_ID.has(preset_id):
		return NOTE_COLOR_BY_ID[preset_id] as Color
	return NOTE_COLOR_BY_ID[DEFAULT_TAP_PRESET] as Color

func is_note_preset(preset_id: String) -> bool:
	return preset_id in NOTE_COLOR_IDS

func note_preset_index(preset_id: String) -> int:
	var i := NOTE_COLOR_IDS.find(preset_id)
	return i if i >= 0 else 0

func is_slide_width(id: String) -> bool:
	return id in SLIDE_WIDTH_IDS

func slide_width_index(id: String = "") -> int:
	var key := id if id != "" else slide_width
	var i := SLIDE_WIDTH_IDS.find(key)
	return i if i >= 0 else 1

func slide_metrics() -> Dictionary:
	if SLIDE_WIDTH_METRICS.has(slide_width):
		return SLIDE_WIDTH_METRICS[slide_width]
	return SLIDE_WIDTH_METRICS[DEFAULT_SLIDE_WIDTH]

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
	tap_preset = _load_preset(cfg, "tap_preset", "tap_color", DEFAULT_TAP_PRESET)
	slide_preset = _load_preset(cfg, "slide_preset", "slide_color", DEFAULT_SLIDE_PRESET)
	var sw := String(cfg.get_value("notes", "slide_width", DEFAULT_SLIDE_WIDTH))
	slide_width = sw if is_slide_width(sw) else DEFAULT_SLIDE_WIDTH

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume_linear)
	cfg.set_value("judge", "offset_ms", offset_ms)
	cfg.set_value("feedback", "vibration", vibration_enabled)
	cfg.set_value("feedback", "hit_sfx", hit_sfx_enabled)
	cfg.set_value("video", "fit", video_fit)
	cfg.set_value("hud", "layout", hud_layout)
	cfg.set_value("notes", "tap_preset", tap_preset)
	cfg.set_value("notes", "slide_preset", slide_preset)
	cfg.set_value("notes", "slide_width", slide_width)
	cfg.save(SAVE_PATH)

func reset_offset() -> void:
	offset_ms = 0
	save_settings()

func reset_note_colors() -> void:
	tap_preset = DEFAULT_TAP_PRESET
	slide_preset = DEFAULT_SLIDE_PRESET
	slide_width = DEFAULT_SLIDE_WIDTH
	save_settings()

func set_tap_preset_index(i: int) -> void:
	if i < 0 or i >= NOTE_COLOR_IDS.size():
		return
	tap_preset = NOTE_COLOR_IDS[i]
	save_settings()

func set_slide_preset_index(i: int) -> void:
	if i < 0 or i >= NOTE_COLOR_IDS.size():
		return
	slide_preset = NOTE_COLOR_IDS[i]
	save_settings()

func set_slide_width_index(i: int) -> void:
	if i < 0 or i >= SLIDE_WIDTH_IDS.size():
		return
	slide_width = SLIDE_WIDTH_IDS[i]
	save_settings()

func tap_fill_color() -> Color:
	var c := tap_color
	return Color(c.r, c.g, c.b, 0.45)

func slide_soft_color() -> Color:
	var c := slide_color
	return Color(c.r, c.g, c.b, 0.55)

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

func make_color_option_icons() -> Array:
	var out: Array = []
	for id in NOTE_COLOR_IDS:
		out.append(_Icons.color_swatch(color_for_preset(id)))
	return out

func make_slide_width_icons() -> Array:
	var out: Array = []
	for id in SLIDE_WIDTH_IDS:
		var h: int = int(SLIDE_WIDTH_ICON_H.get(id, 7))
		out.append(_Icons.slide_width_bar(h))
	return out

## Prefer preset id; migrate legacy Color / html string to nearest preset.
func _load_preset(cfg: ConfigFile, preset_key: String, legacy_color_key: String, fallback: String) -> String:
	if cfg.has_section_key("notes", preset_key):
		var raw: Variant = cfg.get_value("notes", preset_key, fallback)
		if typeof(raw) == TYPE_STRING and is_note_preset(String(raw)):
			return String(raw)
	if cfg.has_section_key("notes", legacy_color_key):
		var legacy: Variant = cfg.get_value("notes", legacy_color_key, Color.WHITE)
		return _nearest_preset(_coerce_color(legacy, color_for_preset(fallback)))
	return fallback

func _coerce_color(v: Variant, fallback: Color) -> Color:
	if typeof(v) == TYPE_COLOR:
		return v as Color
	if typeof(v) == TYPE_STRING:
		return Color.html(String(v))
	return fallback

func _nearest_preset(c: Color) -> String:
	var best := DEFAULT_TAP_PRESET
	var best_d := 999.0
	for id in NOTE_COLOR_IDS:
		var p: Color = NOTE_COLOR_BY_ID[id]
		var d := (c.r - p.r) * (c.r - p.r) + (c.g - p.g) * (c.g - p.g) + (c.b - p.b) * (c.b - p.b)
		if d < best_d:
			best_d = d
			best = id
	return best
