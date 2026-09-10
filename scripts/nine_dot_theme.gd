extends RefCounted
class_name NineDotTheme
## Shared Theme for 9-Dot (gd-agentic: godot-ui-theming).
## Apply at each scene root — do not mutate StyleBoxes in place later without duplicate().
## Call clear_cache() after editing theme builders during hot-reload sessions.

const BG := Color(0.04, 0.07, 0.11, 1.0)
const PANEL := Color(0.09, 0.13, 0.18, 0.96)
const PANEL_BORDER := Color(0.35, 0.55, 0.62, 0.55)
const TEXT := Color(0.92, 0.96, 1.0, 1.0)
const TEXT_MUTED := Color(0.62, 0.76, 0.84, 1.0)
const ACCENT := Color(0.95, 0.28, 0.55, 1.0)
const ACCENT_SLIDE := Color(1.0, 0.82, 0.22, 1.0)
const BTN := Color(0.14, 0.22, 0.28, 1.0)
const BTN_HOVER := Color(0.22, 0.34, 0.42, 1.0)
const BTN_PRESS := Color(0.10, 0.16, 0.20, 1.0)
const FOCUS := Color(0.95, 0.55, 0.72, 0.95)

# Flip-phone contact-list palette (song select)
const PHONE_CHROME := Color(0.12, 0.16, 0.2, 1.0)
const PHONE_LCD := Color(0.78, 0.88, 0.82, 1.0)
const PHONE_LCD_EDGE := Color(0.55, 0.68, 0.62, 1.0)
const PHONE_INK := Color(0.08, 0.18, 0.16, 1.0)
const PHONE_MUTED := Color(0.28, 0.4, 0.36, 1.0)
const PHONE_SELECT := Color(0.1, 0.28, 0.48, 1.0)
const PHONE_SELECT_FG := Color(0.95, 0.98, 1.0, 1.0)
const PHONE_SOFT_BAR := Color(0.1, 0.14, 0.18, 1.0)

static var _cached: Theme

static func clear_cache() -> void:
	_cached = null

static func get_theme() -> Theme:
	if _cached == null:
		_cached = build()
	return _cached

static func apply_to(root: Control) -> void:
	if root == null:
		return
	root.theme = get_theme()

static func build() -> Theme:
	var t := Theme.new()
	var font: Font = load("res://addons/sa2kit_godot/fonts/SourceHanSansCN-Regular.otf") as Font
	if font:
		t.default_font = font
	t.default_font_size = 15

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)

	t.set_stylebox("panel", "PanelContainer", _flat(PANEL, PANEL_BORDER, 14, 1, 16))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 10)

	t.set_stylebox("normal", "Button", _flat(BTN, PANEL_BORDER, 12, 1, 12))
	t.set_stylebox("hover", "Button", _flat(BTN_HOVER, ACCENT, 12, 1, 12))
	t.set_stylebox("pressed", "Button", _flat(BTN_PRESS, ACCENT_SLIDE, 12, 2, 12))
	t.set_stylebox("disabled", "Button", _flat(Color(0.12, 0.14, 0.16, 0.7), Color(0.3, 0.3, 0.32, 0.4), 12, 1, 12))
	t.set_stylebox("focus", "Button", _flat(BTN_HOVER, FOCUS, 12, 2, 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1, 1))
	t.set_color("font_pressed_color", "Button", ACCENT_SLIDE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.55, 0.58, 0.7))
	t.set_font_size("font_size", "Button", 16)
	t.set_constant("outline_size", "Button", 0)

	# Primary CTA variation
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _flat(Color(0.72, 0.18, 0.42, 1), Color(1, 0.7, 0.85, 0.5), 12, 1, 14))
	t.set_stylebox("hover", "PrimaryButton", _flat(Color(0.85, 0.24, 0.5, 1), Color(1, 0.85, 0.9, 0.7), 12, 2, 14))
	t.set_stylebox("pressed", "PrimaryButton", _flat(Color(0.55, 0.12, 0.32, 1), ACCENT_SLIDE, 12, 2, 14))
	t.set_stylebox("focus", "PrimaryButton", _flat(Color(0.85, 0.24, 0.5, 1), FOCUS, 12, 2, 14))
	t.set_color("font_color", "PrimaryButton", Color(1, 0.96, 0.98, 1))
	t.set_font_size("font_size", "PrimaryButton", 18)

	# Flip-phone contacts (song select) — Series40-ish LCD + softkeys
	t.set_color("lcd_bg", "Phone", PHONE_LCD)
	t.set_color("lcd_ink", "Phone", PHONE_INK)
	t.set_color("lcd_muted", "Phone", PHONE_MUTED)
	t.set_color("select_bg", "Phone", PHONE_SELECT)
	t.set_color("select_fg", "Phone", PHONE_SELECT_FG)
	t.set_color("chrome", "Phone", PHONE_CHROME)
	t.set_color("soft_bar", "Phone", PHONE_SOFT_BAR)

	t.set_type_variation("ContactRow", "Button")
	t.set_stylebox("normal", "ContactRow", _flat_sides(PHONE_LCD, Color(0.55, 0.68, 0.62, 0.55), 0, 0, 10, 8, 0, 1))
	t.set_stylebox("hover", "ContactRow", _flat_sides(Color(0.72, 0.84, 0.78, 1), Color(0.45, 0.6, 0.55, 0.7), 0, 0, 10, 8, 0, 1))
	t.set_stylebox("pressed", "ContactRow", _flat_sides(PHONE_SELECT, Color(0.05, 0.15, 0.28, 1), 0, 0, 10, 8, 0, 1))
	t.set_stylebox("focus", "ContactRow", _flat_sides(PHONE_SELECT, Color(0.9, 0.95, 1, 0.35), 0, 0, 10, 8, 0, 2))
	t.set_stylebox("disabled", "ContactRow", _flat_sides(Color(0.7, 0.76, 0.74, 1), Color(0.5, 0.55, 0.52, 0.4), 0, 0, 10, 8, 0, 1))
	t.set_color("font_color", "ContactRow", PHONE_INK)
	t.set_color("font_hover_color", "ContactRow", PHONE_INK)
	t.set_color("font_pressed_color", "ContactRow", PHONE_SELECT_FG)
	t.set_color("font_focus_color", "ContactRow", PHONE_SELECT_FG)
	t.set_font_size("font_size", "ContactRow", 15)
	t.set_constant("outline_size", "ContactRow", 0)

	t.set_type_variation("ContactRowSelected", "Button")
	t.set_stylebox("normal", "ContactRowSelected", _flat_sides(PHONE_SELECT, Color(0.05, 0.12, 0.22, 1), 0, 0, 10, 8, 0, 0))
	t.set_stylebox("hover", "ContactRowSelected", _flat_sides(Color(0.16, 0.38, 0.62, 1), Color(0.05, 0.12, 0.22, 1), 0, 0, 10, 8, 0, 0))
	t.set_stylebox("pressed", "ContactRowSelected", _flat_sides(Color(0.08, 0.22, 0.4, 1), Color(0.05, 0.12, 0.22, 1), 0, 0, 10, 8, 0, 0))
	t.set_stylebox("focus", "ContactRowSelected", _flat_sides(PHONE_SELECT, Color(0.9, 0.95, 1, 0.4), 0, 0, 10, 8, 0, 2))
	t.set_color("font_color", "ContactRowSelected", PHONE_SELECT_FG)
	t.set_color("font_hover_color", "ContactRowSelected", PHONE_SELECT_FG)
	t.set_color("font_pressed_color", "ContactRowSelected", PHONE_SELECT_FG)
	t.set_color("font_focus_color", "ContactRowSelected", PHONE_SELECT_FG)
	t.set_font_size("font_size", "ContactRowSelected", 15)

	t.set_type_variation("SoftKey", "Button")
	t.set_stylebox("normal", "SoftKey", _flat(Color(0.18, 0.24, 0.3, 1), Color(0.4, 0.5, 0.55, 0.5), 4, 1, 8))
	t.set_stylebox("hover", "SoftKey", _flat(Color(0.26, 0.34, 0.4, 1), ACCENT_SLIDE, 4, 1, 8))
	t.set_stylebox("pressed", "SoftKey", _flat(Color(0.12, 0.16, 0.2, 1), ACCENT, 4, 1, 8))
	t.set_stylebox("focus", "SoftKey", _flat(Color(0.26, 0.34, 0.4, 1), FOCUS, 4, 1, 8))
	t.set_stylebox("disabled", "SoftKey", _flat(Color(0.14, 0.16, 0.18, 0.8), Color(0.3, 0.32, 0.34, 0.4), 4, 1, 8))
	t.set_color("font_color", "SoftKey", Color(0.92, 0.96, 0.98, 1))
	t.set_color("font_disabled_color", "SoftKey", Color(0.5, 0.55, 0.58, 0.7))
	t.set_font_size("font_size", "SoftKey", 13)

	# Settings top tabs
	t.set_type_variation("SettingsTab", "Button")
	t.set_stylebox("normal", "SettingsTab", _flat(Color(0.12, 0.16, 0.2, 1), Color(0.35, 0.45, 0.5, 0.4), 10, 1, 10))
	t.set_stylebox("hover", "SettingsTab", _flat(Color(0.18, 0.24, 0.3, 1), ACCENT_SLIDE, 10, 1, 10))
	t.set_stylebox("pressed", "SettingsTab", _flat(Color(0.1, 0.14, 0.18, 1), ACCENT, 10, 1, 10))
	t.set_stylebox("focus", "SettingsTab", _flat(Color(0.18, 0.24, 0.3, 1), FOCUS, 10, 1, 10))
	t.set_color("font_color", "SettingsTab", TEXT_MUTED)
	t.set_color("font_hover_color", "SettingsTab", TEXT)
	t.set_color("font_pressed_color", "SettingsTab", TEXT)
	t.set_font_size("font_size", "SettingsTab", 14)

	t.set_type_variation("SettingsTabActive", "Button")
	t.set_stylebox("normal", "SettingsTabActive", _flat(Color(0.55, 0.14, 0.32, 1), Color(1, 0.7, 0.85, 0.55), 10, 1, 10))
	t.set_stylebox("hover", "SettingsTabActive", _flat(Color(0.65, 0.18, 0.38, 1), Color(1, 0.85, 0.9, 0.7), 10, 1, 10))
	t.set_stylebox("pressed", "SettingsTabActive", _flat(Color(0.45, 0.1, 0.26, 1), ACCENT_SLIDE, 10, 1, 10))
	t.set_stylebox("focus", "SettingsTabActive", _flat(Color(0.65, 0.18, 0.38, 1), FOCUS, 10, 1, 10))
	t.set_color("font_color", "SettingsTabActive", Color(1, 0.96, 0.98, 1))
	t.set_color("font_hover_color", "SettingsTabActive", Color(1, 1, 1, 1))
	t.set_color("font_pressed_color", "SettingsTabActive", ACCENT_SLIDE)
	t.set_font_size("font_size", "SettingsTabActive", 14)

	t.set_stylebox("slider", "HSlider", _flat(Color(0.16, 0.2, 0.24, 1), PANEL_BORDER, 6, 1, 4))
	t.set_stylebox("grabber_area", "HSlider", _flat(ACCENT, Color(0, 0, 0, 0), 6, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color(1.0, 0.4, 0.65, 1), Color(0, 0, 0, 0), 6, 0, 0))

	# Play HUD: song title frame
	t.set_type_variation("TitleFrame", "PanelContainer")
	t.set_stylebox(
		"panel",
		"TitleFrame",
		_flat(Color(0.06, 0.1, 0.14, 0.82), Color(0.95, 0.28, 0.55, 0.55), 8, 1, 8),
	)

	# Song progress (DIVA-like solid strip)
	var prog_bg := StyleBoxFlat.new()
	prog_bg.bg_color = Color(0.08, 0.1, 0.14, 0.85)
	prog_bg.set_corner_radius_all(0)
	prog_bg.set_content_margin_all(0)
	var prog_fill := StyleBoxFlat.new()
	prog_fill.bg_color = ACCENT
	prog_fill.set_corner_radius_all(0)
	prog_fill.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", prog_bg)
	t.set_stylebox("fill", "ProgressBar", prog_fill)
	t.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))

	t.set_stylebox("normal", "SpinBox", _flat(BTN, PANEL_BORDER, 8, 1, 8))

	# CheckButton: do NOT inherit Button hover/pressed flats (ON looks pressed,
	# hover then swaps to hover flat → feels reversed). Keep row chrome stable;
	# on/off reads from font + switch icon only.
	var check_row := _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0, 8)
	var check_row_hover := _flat(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 8, 0, 8)
	t.set_stylebox("normal", "CheckButton", check_row)
	t.set_stylebox("pressed", "CheckButton", check_row)
	t.set_stylebox("hover", "CheckButton", check_row_hover)
	t.set_stylebox("hover_pressed", "CheckButton", check_row_hover)
	t.set_stylebox("focus", "CheckButton", _flat(Color(1, 1, 1, 0.04), FOCUS, 8, 1, 8))
	t.set_stylebox("disabled", "CheckButton", check_row)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", ACCENT_SLIDE)
	t.set_color("font_hover_color", "CheckButton", Color(1, 1, 1, 1))
	t.set_color("font_hover_pressed_color", "CheckButton", Color(1.0, 0.88, 0.45, 1))
	t.set_color("font_focus_color", "CheckButton", TEXT)
	t.set_color("font_disabled_color", "CheckButton", Color(0.5, 0.55, 0.58, 0.7))

	# Custom palette type for scripts / _draw
	t.set_color("primary", "Palette", ACCENT)
	t.set_color("slide", "Palette", ACCENT_SLIDE)
	t.set_color("muted", "Palette", TEXT_MUTED)
	t.set_color("bg", "Palette", BG)
	return t

static func _flat(bg: Color, border: Color, radius: float, border_w: float, content_margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(int(border_w))
	s.set_corner_radius_all(int(radius))
	s.set_content_margin_all(content_margin)
	return s

static func _flat_sides(
	bg: Color,
	border: Color,
	radius: float,
	border_w: float,
	pad_h: float,
	pad_v: float,
	border_top: float = -1.0,
	border_bottom: float = -1.0,
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_corner_radius_all(int(radius))
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	var bw := int(border_w)
	s.border_width_left = bw
	s.border_width_right = bw
	s.border_width_top = int(border_top) if border_top >= 0.0 else bw
	s.border_width_bottom = int(border_bottom) if border_bottom >= 0.0 else bw
	return s
