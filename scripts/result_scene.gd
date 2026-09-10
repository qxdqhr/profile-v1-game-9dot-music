extends Control
## Result screen — theme + panel enter juice.

@onready var _body: Label = $Center/Panel/Margin/VBox/Body

func _ready() -> void:
	NineDotTheme.apply_to(self)
	var s: Dictionary = PlaySession.last_score
	var acc := NineDotJudge.accuracy_pct(s) if not s.is_empty() else 0.0
	_body.text = "%s\n%s · %s\n\nScore  %d\nAccuracy  %.1f%%\nMax Combo  %d\n\nPerfect  %d\nGreat  %d\nGood  %d\nMiss  %d" % [
		NineDotConfig.DISPLAY_NAME,
		PlaySession.last_title,
		PlaySession.diff.capitalize(),
		int(s.get("score", 0)),
		acc,
		int(s.get("max_combo", 0)),
		int(s.get("perfect", 0)),
		int(s.get("great", 0)),
		int(s.get("good", 0)),
		int(s.get("miss", 0)),
	]
	$Center/Panel/Margin/VBox/RetryBtn.theme_type_variation = &"PrimaryButton"
	$Center/Panel/Margin/VBox/RetryBtn.pressed.connect(_on_retry)
	$Center/Panel/Margin/VBox/SongsBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/song_select.tscn"))
	$Center/Panel/Margin/VBox/TitleBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	for b in [$Center/Panel/Margin/VBox/RetryBtn, $Center/Panel/Margin/VBox/SongsBtn, $Center/Panel/Margin/VBox/TitleBtn]:
		NineDotUiJuice.wire_button_press_juice(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	await get_tree().process_frame
	NineDotUiJuice.enter_panel($Center/Panel)

func _on_retry() -> void:
	get_tree().change_scene_to_file("res://scenes/play.tscn")
