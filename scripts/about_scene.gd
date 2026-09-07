extends Control

func _ready() -> void:
	$Center/Panel/Margin/VBox/Body.text = "%s\nv0.4.0 · Godot Web\n\n九宫格 Tap / Slide 音游\n音频主时钟 · 视频跟随防乱轴\n\nPRD：docs/REQUIREMENTS.md\n旁路：/games/9dot-music/\n对标手感：MikuFlick" % NineDotConfig.DISPLAY_NAME
	$Center/Panel/Margin/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
