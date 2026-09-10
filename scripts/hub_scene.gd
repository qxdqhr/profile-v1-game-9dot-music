extends Control
## Hub after splash: rhythm / MyRoom / settings / about.

func _ready() -> void:
	NineDotTheme.apply_to(self)
	$Hero/Brand.text = NineDotConfig.DISPLAY_NAME
	$Hero/Brand.add_theme_color_override("font_color", Color(0.96, 0.98, 1, 1))
	$Hero/Sub.add_theme_color_override("font_color", NineDotTheme.TEXT_MUTED)
	var rhythm: Button = $Menu/RhythmBtn
	rhythm.theme_type_variation = &"PrimaryButton"
	rhythm.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/song_select.tscn"))
	$Menu/MyRoomBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/my_room.tscn"))
	$Menu/SettingsBtn.pressed.connect(func(): PlaySession.open_settings_from("res://scenes/hub.tscn"))
	$Menu/AboutBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/about.tscn"))
	for b in [$Menu/RhythmBtn, $Menu/MyRoomBtn, $Menu/SettingsBtn, $Menu/AboutBtn]:
		NineDotUiJuice.wire_button_press_juice(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	await get_tree().process_frame
	NineDotUiJuice.pop_control($Hero/Brand, 0.9)
	NineDotUiJuice.stagger_buttons([$Menu/RhythmBtn, $Menu/MyRoomBtn, $Menu/SettingsBtn, $Menu/AboutBtn])
