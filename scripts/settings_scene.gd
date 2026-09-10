extends Control

@onready var _vol: HSlider = $Center/Panel/Margin/VBox/VolSlider
@onready var _off: SpinBox = $Center/Panel/Margin/VBox/OffsetSpin
@onready var _vol_label: Label = $Center/Panel/Margin/VBox/VolLabel
@onready var _off_label: Label = $Center/Panel/Margin/VBox/OffsetLabel
@onready var _vibrate: CheckButton = $Center/Panel/Margin/VBox/VibrateCheck
@onready var _hit_sfx: CheckButton = $Center/Panel/Margin/VBox/HitSfxCheck

func _ready() -> void:
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
	_vol.value_changed.connect(_on_vol)
	_off.value_changed.connect(_on_off)
	_vibrate.toggled.connect(_on_vibrate)
	_hit_sfx.toggled.connect(_on_hit_sfx)
	$Center/Panel/Margin/VBox/ResetBtn.pressed.connect(_on_reset)
	$Center/Panel/Margin/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	for b in [$Center/Panel/Margin/VBox/ResetBtn, $Center/Panel/Margin/VBox/BackBtn]:
		NineDotUiJuice.wire_button_press_juice(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_labels()
	await get_tree().process_frame
	NineDotUiJuice.enter_panel($Center/Panel)

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

func _on_reset() -> void:
	AppSettings.reset_offset()
	_off.value = 0
	_refresh_labels()

func _refresh_labels() -> void:
	_vol_label.text = "主音量  %.0f%%" % (AppSettings.volume_linear * 100.0)
	_off_label.text = "判定偏移  %d ms（正值更晚判定）" % AppSettings.offset_ms
