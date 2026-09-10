extends Control

func _ready() -> void:
	NineDotTheme.apply_to(self)
	$Center/Panel/Margin/VBox/Body.text = "%s\nv0.6.3 · Godot Web / APK\n\n九宫格 Tap / Slide\n音频主时钟 · 视频跟随\n百万计分 · Agent 生谱管线\n\nPRD：docs/REQUIREMENTS.md\n旁路：/games/9dot-music/" % NineDotConfig.DISPLAY_NAME
	$Center/Panel/Margin/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	NineDotUiJuice.wire_button_press_juice($Center/Panel/Margin/VBox/BackBtn)
	$Center/Panel/Margin/VBox/BackBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	await get_tree().process_frame
	NineDotUiJuice.enter_panel($Center/Panel)
