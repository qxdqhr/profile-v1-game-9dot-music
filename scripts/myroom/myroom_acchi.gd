extends Control
## あっちむいてホイ — RPS then look direction; first to 2.

signal finished(won: bool, affection: int)

enum Phase { INTRO, RPS, LOOK, DONE }

const HANDS := ["✊", "✌️", "✋"] # rock paper scissors display
const DIRS := ["←", "→", "↑", "↓"]
const DIR_KEYS := ["left", "right", "up", "down"]

var _phase: Phase = Phase.INTRO
var _p_score := 0
var _c_score := 0
var _target_dir := 0
var _lbl: Label
var _row: HBoxContainer
var _hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(300, 340)
	panel.position = Vector2(-150, -170)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var head := Label.new()
	head.text = "あっちむいてホイ"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 18)
	v.add_child(head)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	_lbl = Label.new()
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_lbl)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	v.add_child(_row)
	var skip := Button.new()
	skip.text = "放弃"
	skip.pressed.connect(func(): _end(false, 0))
	v.add_child(skip)
	_set_phase(Phase.RPS)

func _clear_row() -> void:
	for c in _row.get_children():
		c.queue_free()

func _set_phase(p: Phase) -> void:
	_phase = p
	_clear_row()
	_lbl.text = "你 %d — %d 对方" % [_p_score, _c_score]
	match p:
		Phase.RPS:
			_hint.text = "先猜拳！赢了才能指方向"
			for i in range(3):
				var b := Button.new()
				b.text = HANDS[i]
				b.custom_minimum_size = Vector2(64, 48)
				var idx := i
				b.pressed.connect(func(): _on_rps(idx))
				_row.add_child(b)
		Phase.LOOK:
			_hint.text = "指一个方向！"
			_target_dir = randi() % 4
			for i in range(4):
				var b := Button.new()
				b.text = DIRS[i]
				b.custom_minimum_size = Vector2(56, 48)
				var idx := i
				b.pressed.connect(func(): _on_look(idx))
				_row.add_child(b)
		_:
			pass

func _on_rps(player: int) -> void:
	var cpu := randi() % 3
	# 0 rock, 1 scissors, 2 paper — win if (player - cpu + 3) % 3 == 2? 
	# rock(0) beats scissors(1), scissors(1) beats paper(2), paper(2) beats rock(0)
	var diff := (player - cpu + 3) % 3
	if diff == 0:
		_hint.text = "平手，再来！（对方 %s）" % HANDS[cpu]
		return
	if diff == 2: # player wins standard? rock-scissors: 0-1=2 mod3? (0-1+3)%3=2 yes player wins
		_hint.text = "猜拳赢了！（对方 %s）" % HANDS[cpu]
		_set_phase(Phase.LOOK)
	else:
		_hint.text = "猜拳输了…（对方 %s）" % HANDS[cpu]
		_c_score += 1
		_check_score()

func _on_look(player_dir: int) -> void:
	# CPU faces a random direction; player wins if CPU looks same as pointed? 
	# Classic: winner of RPS points; loser turns head; if match, pointer scores.
	var cpu_look := randi() % 4
	if player_dir == cpu_look:
		_p_score += 1
		_hint.text = "指中了！对方看向 %s" % DIRS[cpu_look]
	else:
		_c_score += 1
		_hint.text = "没指中…对方看向 %s" % DIRS[cpu_look]
	_check_score()

func _check_score() -> void:
	_lbl.text = "你 %d — %d 对方" % [_p_score, _c_score]
	if _p_score >= 2:
		_end(true, 3)
	elif _c_score >= 2:
		_end(false, 1)
	else:
		get_tree().create_timer(0.55).timeout.connect(func():
			if is_instance_valid(self) and _phase != Phase.DONE:
				_set_phase(Phase.RPS)
		, CONNECT_ONE_SHOT)
func _end(won: bool, aff: int) -> void:
	_phase = Phase.DONE
	finished.emit(won, aff)
	queue_free()
