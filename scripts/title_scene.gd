extends Control
## Title: brand-first hero + theme/juice (gd-agentic UI skills).

func _ready() -> void:
	NineDotTheme.apply_to(self)
	$Hero/Brand.text = NineDotConfig.DISPLAY_NAME
	$Hero/Brand.add_theme_font_size_override("font_size", 42)
	$Hero/Brand.add_theme_color_override("font_color", Color(0.96, 0.98, 1, 1))
	$Hero/Tagline.add_theme_color_override("font_color", NineDotTheme.TEXT_MUTED)
	var enter: Button = $Menu/EnterBtn
	enter.theme_type_variation = &"PrimaryButton"
	enter.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/song_select.tscn"))
	$Menu/AgentBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/agent.tscn"))
	$Menu/SettingsBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/settings.tscn"))
	$Menu/AboutBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/about.tscn"))
	for b in [$Menu/EnterBtn, $Menu/AgentBtn, $Menu/SettingsBtn, $Menu/AboutBtn]:
		NineDotUiJuice.wire_button_press_juice(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Enter animation after one layout frame so pivot/size are valid.
	await get_tree().process_frame
	NineDotUiJuice.pop_control($Hero/Brand, 0.85)
	NineDotUiJuice.stagger_buttons([$Menu/EnterBtn, $Menu/AgentBtn, $Menu/SettingsBtn, $Menu/AboutBtn])
