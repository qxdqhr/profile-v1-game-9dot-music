extends Control
## MyRoom gate: choose Room or AR.

const _Platform = preload("res://scripts/myroom/myroom_platform.gd")

@onready var _room_btn: Button = $Center/Panel/Margin/VBox/RoomBtn
@onready var _ar_btn: Button = $Center/Panel/Margin/VBox/ArBtn
@onready var _hint: Label = $Center/Panel/Margin/VBox/Hint
@onready var _back: Button = $Center/Panel/Margin/VBox/BackBtn

func _ready() -> void:
	NineDotTheme.apply_to(self)
	if not _Platform.is_available():
		_hint.text = _Platform.unavailable_hint()
		_room_btn.disabled = true
		_ar_btn.disabled = true
	else:
		_hint.text = "选择模式"
	_room_btn.theme_type_variation = &"PrimaryButton"
	_room_btn.pressed.connect(_on_room)
	_ar_btn.pressed.connect(_on_ar)
	_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	for b in [_room_btn, _ar_btn, _back]:
		NineDotUiJuice.wire_button_press_juice(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ar_btn.text = "AR 模式"
	_ar_btn.disabled = not _Platform.is_available()
	await get_tree().process_frame
	NineDotUiJuice.enter_panel($Center/Panel)

func _on_room() -> void:
	get_tree().change_scene_to_file("res://scenes/myroom/room.tscn")

func _on_ar() -> void:
	get_tree().change_scene_to_file("res://scenes/myroom/ar.tscn")
