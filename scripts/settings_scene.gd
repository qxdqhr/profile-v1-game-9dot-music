extends Control
## Settings with top horizontally-scrollable tabs (game / video / volume).

@onready var _tab_scroll: ScrollContainer = $Center/Panel/Margin/Root/TabScroll
@onready var _tab_game: Button = $Center/Panel/Margin/Root/TabScroll/TabRow/TabGame
@onready var _tab_video: Button = $Center/Panel/Margin/Root/TabScroll/TabRow/TabVideo
@onready var _tab_audio: Button = $Center/Panel/Margin/Root/TabScroll/TabRow/TabAudio

@onready var _game_page: ScrollContainer = $Center/Panel/Margin/Root/Pages/GamePage
@onready var _video_page: ScrollContainer = $Center/Panel/Margin/Root/Pages/VideoPage
@onready var _audio_page: ScrollContainer = $Center/Panel/Margin/Root/Pages/AudioPage

@onready var _vol: HSlider = $Center/Panel/Margin/Root/Pages/AudioPage/AudioBody/VolSlider
@onready var _vol_label: Label = $Center/Panel/Margin/Root/Pages/AudioPage/AudioBody/VolLabel

@onready var _off: SpinBox = $Center/Panel/Margin/Root/Pages/GamePage/GameBody/OffsetSpin
@onready var _off_label: Label = $Center/Panel/Margin/Root/Pages/GamePage/GameBody/OffsetLabel
@onready var _vibrate: CheckButton = $Center/Panel/Margin/Root/Pages/GamePage/GameBody/VibrateCheck
@onready var _hit_sfx: CheckButton = $Center/Panel/Margin/Root/Pages/GamePage/GameBody/HitSfxCheck
@onready var _hud_layout: OptionButton = $Center/Panel/Margin/Root/Pages/GamePage/GameBody/HudLayoutOption
@onready var _hud_layout_label: Label = $Center/Panel/Margin/Root/Pages/GamePage/GameBody/HudLayoutLabel
@onready var _reset_btn: Button = $Center/Panel/Margin/Root/Pages/GamePage/GameBody/ResetBtn

@onready var _video_fit: OptionButton = $Center/Panel/Margin/Root/Pages/VideoPage/VideoBody/VideoFitOption
@onready var _video_fit_label: Label = $Center/Panel/Margin/Root/Pages/VideoPage/VideoBody/VideoFitLabel

@onready var _back_btn: Button = $Center/Panel/Margin/Root/BackBtn

const _Hud = preload("res://scripts/play_hud_layout.gd")

enum Tab { GAME, VIDEO, AUDIO }

var _tab: int = Tab.GAME

func _ready() -> void:
	NineDotTheme.clear_cache()
	NineDotTheme.apply_to(self)
	_vol.min_value = 0.0
	_vol.max_value = 1.0
	_vol.step = 0.01
	_vol.value = AppSettings.volume_linear
	_off.min_value = -200
	_off.max_value = 200
	_off.step = 1
	_off.value = AppSettings.offset_ms
	_vibrate.button_pressed = AppSettings.vibration_enabled
	_hit_sfx.button_pressed = AppSettings.hit_sfx_enabled
	_video_fit.clear()
	for label in AppSettings.VIDEO_FIT_LABELS:
		_video_fit.add_item(label)
	_video_fit.select(AppSettings.video_fit_index())
	_video_fit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_layout.clear()
	for label in _Hud.LABELS:
		_hud_layout.add_item(label)
	_hud_layout.select(AppSettings.hud_layout_index())
	_hud_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vol.value_changed.connect(_on_vol)
	_off.value_changed.connect(_on_off)
	_vibrate.toggled.connect(_on_vibrate)
	_hit_sfx.toggled.connect(_on_hit_sfx)
	_video_fit.item_selected.connect(_on_video_fit)
	_hud_layout.item_selected.connect(_on_hud_layout)
	_reset_btn.pressed.connect(_on_reset)
	_back_btn.pressed.connect(func(): get_tree().change_scene_to_file(PlaySession.settings_back_scene))
	_tab_game.pressed.connect(func(): _select_tab(Tab.GAME))
	_tab_video.pressed.connect(func(): _select_tab(Tab.VIDEO))
	_tab_audio.pressed.connect(func(): _select_tab(Tab.AUDIO))
	for b in [_reset_btn, _back_btn, _tab_game, _tab_video, _tab_audio]:
		NineDotUiJuice.wire_button_press_juice(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for b in [_tab_game, _tab_video, _tab_audio]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_select_tab(Tab.GAME)
	_refresh_labels()
	await get_tree().process_frame
	NineDotUiJuice.enter_panel($Center/Panel)

func _select_tab(which: int) -> void:
	_tab = which
	_game_page.visible = which == Tab.GAME
	_video_page.visible = which == Tab.VIDEO
	_audio_page.visible = which == Tab.AUDIO
	_style_tab(_tab_game, which == Tab.GAME)
	_style_tab(_tab_video, which == Tab.VIDEO)
	_style_tab(_tab_audio, which == Tab.AUDIO)
	call_deferred("_ensure_tab_visible", which)

func _style_tab(btn: Button, active: bool) -> void:
	btn.theme_type_variation = &"SettingsTabActive" if active else &"SettingsTab"

func _ensure_tab_visible(which: int) -> void:
	var btn: Button = _tab_game
	match which:
		Tab.VIDEO:
			btn = _tab_video
		Tab.AUDIO:
			btn = _tab_audio
		_:
			btn = _tab_game
	if is_instance_valid(_tab_scroll) and is_instance_valid(btn):
		_tab_scroll.ensure_control_visible(btn)

func _on_vol(v: float) -> void:
	AppSettings.volume_linear = v
	AppSettings.save_settings()
	_refresh_labels()

func _on_off(v: float) -> void:
	AppSettings.offset_ms = int(v)
	AppSettings.save_settings()
	_refresh_labels()

func _on_vibrate(on: bool) -> void:
	AppSettings.vibration_enabled = on
	AppSettings.save_settings()

func _on_hit_sfx(on: bool) -> void:
	AppSettings.hit_sfx_enabled = on
	AppSettings.save_settings()

func _on_video_fit(idx: int) -> void:
	AppSettings.set_video_fit_index(idx)
	_refresh_labels()

func _on_hud_layout(idx: int) -> void:
	AppSettings.set_hud_layout_index(idx)
	_refresh_labels()

func _on_reset() -> void:
	AppSettings.reset_offset()
	_off.value = 0
	_refresh_labels()

func _refresh_labels() -> void:
	_vol_label.text = "主音量  %.0f%%" % (AppSettings.volume_linear * 100.0)
	_off_label.text = "判定偏移  %d ms（正值更晚判定）" % AppSettings.offset_ms
	var hint := ""
	match AppSettings.video_fit:
		AppSettings.VIDEO_FIT_BAND:
			hint = "Fit 层：提示条与九宫格之间的条带"
		AppSettings.VIDEO_FIT_LETTERBOX:
			hint = "完整：全屏等比，上下留边"
		AppSettings.VIDEO_FIT_COVER:
			hint = "铺满：全屏等比，左右裁切"
		_:
			hint = ""
	_video_fit_label.text = "视频适配 · %s" % hint
	var hud_i := AppSettings.hud_layout_index()
	var hud_name := _Hud.LABELS[hud_i] if hud_i < _Hud.LABELS.size() else AppSettings.hud_layout
	_hud_layout_label.text = "HUD 排布 · %s（判定→Combo→分数→准度）" % hud_name
