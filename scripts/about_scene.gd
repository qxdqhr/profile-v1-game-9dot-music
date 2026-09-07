extends Control

func _ready() -> void:
	$Center/VBox/Body.text = "%s\nv0.2.0 · Godot Web\n\n九宫格 Tap / Slide 音游\nPRD: docs/REQUIREMENTS.md\n\n对标手感：MikuFlick\n引擎旁路：/games/9dot-music/" % NineDotConfig.DISPLAY_NAME
	$Center/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
