extends Control
## Title: brand-first hero (M3).

func _ready() -> void:
	$Hero/Brand.text = NineDotConfig.DISPLAY_NAME
	$Menu/EnterBtn.pressed.connect(_on_enter)
	$Menu/SettingsBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/settings.tscn"))
	$Menu/AboutBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/about.tscn"))

func _on_enter() -> void:
	get_tree().change_scene_to_file("res://scenes/song_select.tscn")
