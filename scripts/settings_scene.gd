extends Control

@onready var _vol: HSlider = $Center/VBox/VolSlider
@onready var _off: SpinBox = $Center/VBox/OffsetSpin
@onready var _vol_label: Label = $Center/VBox/VolLabel
@onready var _off_label: Label = $Center/VBox/OffsetLabel

func _ready() -> void:
	_vol.min_value = 0.0
	_vol.max_value = 1.0
	_vol.step = 0.01
	_vol.value = AppSettings.volume_linear
	_off.min_value = -200
	_off.max_value = 200
	_off.step = 1
	_off.value = AppSettings.offset_ms
	_vol.value_changed.connect(_on_vol)
	_off.value_changed.connect(_on_off)
	$Center/VBox/ResetBtn.pressed.connect(_on_reset)
	$Center/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	_refresh_labels()

func _on_vol(v: float) -> void:
	AppSettings.volume_linear = v
	AppSettings.save_settings()
	_refresh_labels()

func _on_off(v: float) -> void:
	AppSettings.offset_ms = int(v)
	AppSettings.save_settings()
	_refresh_labels()

func _on_reset() -> void:
	AppSettings.reset_offset()
	_off.value = 0
	_refresh_labels()

func _refresh_labels() -> void:
	_vol_label.text = "主音量 %.0f%%" % (AppSettings.volume_linear * 100.0)
	_off_label.text = "判定偏移 %d ms" % AppSettings.offset_ms
