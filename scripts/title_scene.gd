extends Control
## Title: brand-first hero (M3/M4).

func _ready() -> void:
	$Hero/Brand.text = NineDotConfig.DISPLAY_NAME
	$Menu/EnterBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/song_select.tscn"))
	$Menu/AgentBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/agent.tscn"))
	$Menu/SettingsBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/settings.tscn"))
	$Menu/AboutBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/about.tscn"))
