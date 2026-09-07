extends Control

func _ready() -> void:
	$Center/Panel/Margin/VBox/Body.text = "%s\nv0.5.0 · Godot Web\n\n九宫格 Tap / Slide\n音频主时钟 · 视频跟随\n百万计分 · Agent 生谱管线\n\nPRD：docs/REQUIREMENTS.md\n旁路：/games/9dot-music/" % NineDotConfig.DISPLAY_NAME
	$Center/Panel/Margin/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
