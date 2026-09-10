extends Control
## Splash: brand + tap anywhere → hub.

func _ready() -> void:
	NineDotTheme.apply_to(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Hero/Brand.text = NineDotConfig.DISPLAY_NAME
	$Hero/Brand.add_theme_font_size_override("font_size", 42)
	$Hero/Brand.add_theme_color_override("font_color", Color(0.96, 0.98, 1, 1))
	$Hero/Tagline.add_theme_color_override("font_color", NineDotTheme.TEXT_MUTED)
	$Prompt.add_theme_color_override("font_color", NineDotTheme.TEXT_MUTED)
	gui_input.connect(_on_gui_input)
	await get_tree().process_frame
	NineDotUiJuice.pop_control($Hero/Brand, 0.88)
	_pulse_prompt()

func _pulse_prompt() -> void:
	var p: Label = $Prompt
	p.modulate.a = 0.35
	var tw := p.create_tween().bind_node(p)
	tw.set_loops()
	tw.tween_property(p, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "modulate:a", 0.35, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_go_hub()
	elif event is InputEventScreenTouch and event.pressed:
		_go_hub()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_go_hub()
		get_viewport().set_input_as_handled()

func _go_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
