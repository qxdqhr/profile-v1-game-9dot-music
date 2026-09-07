extends Control
## Title: brand + Enter / Settings / About.

func _ready() -> void:
	$Center/VBox/Title.text = NineDotConfig.DISPLAY_NAME
	$Center/VBox/EnterBtn.pressed.connect(_on_enter)
	$Center/VBox/SettingsBtn.pressed.connect(_on_settings)
	$Center/VBox/AboutBtn.pressed.connect(_on_about)

func _on_enter() -> void:
	get_tree().change_scene_to_file("res://scenes/song_select.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_about() -> void:
	get_tree().change_scene_to_file("res://scenes/about.tscn")
