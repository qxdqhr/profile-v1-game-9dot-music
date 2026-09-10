extends Control
## MyRoom placeholder — hub entry for future personal space.

func _ready() -> void:
	NineDotTheme.apply_to(self)
	$Center/Panel/Margin/VBox/Body.add_theme_color_override("font_color", NineDotTheme.TEXT_MUTED)
	$Center/Panel/Margin/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	NineDotUiJuice.wire_button_press_juice($Center/Panel/Margin/VBox/BackBtn)
	$Center/Panel/Margin/VBox/BackBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	await get_tree().process_frame
	NineDotUiJuice.enter_panel($Center/Panel)
