extends Control
## Song select as 2000s flip-phone contacts (list-first + softkeys).

const DIFF_ORDER: Array[String] = ["easy", "normal", "hard", "extreme"]

@onready var _status_title: Label = $Shell/StatusBar/StatusRow/StatusTitle
@onready var _status_count: Label = $Shell/StatusBar/StatusRow/StatusCount
@onready var _lcd_frame: PanelContainer = $Shell/LcdFrame
@onready var _scroll: ScrollContainer = $Shell/LcdFrame/LcdInner/Scroll
@onready var _list: VBoxContainer = $Shell/LcdFrame/LcdInner/Scroll/List
@onready var _focus_strip: ColorRect = $Shell/LcdFrame/LcdInner/FocusStrip
@onready var _focus_label: Label = $Shell/LcdFrame/LcdInner/FocusStrip/FocusLabel
@onready var _soft_bar: ColorRect = $Shell/SoftBar
@onready var _back_btn: Button = $Shell/SoftBar/SoftRow/BackBtn
@onready var _diff_btn: Button = $Shell/SoftBar/SoftRow/DiffBtn
@onready var _play_btn: Button = $Shell/SoftBar/SoftRow/PlayBtn
@onready var _bg: ColorRect = $BG
@onready var _status_bar: ColorRect = $Shell/StatusBar

var _songs: Array = []
var _selected_idx: int = 0
var _diff_idx: int = 1
var _row_buttons: Array[Button] = []
var _mode: String = "songs" # songs | diffs

func _ready() -> void:
	NineDotTheme.apply_to(self)
	_apply_phone_chrome()
	_back_btn.theme_type_variation = &"SoftKey"
	_diff_btn.theme_type_variation = &"SoftKey"
	_play_btn.theme_type_variation = &"SoftKey"
	_back_btn.pressed.connect(_on_soft_back)
	_diff_btn.pressed.connect(_on_soft_diff)
	_play_btn.pressed.connect(_on_soft_play)
	for b in [_back_btn, _diff_btn, _play_btn]:
		NineDotUiJuice.wire_button_press_juice(b)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_songs = NineDotCatalog.list_songs()
	_build_song_list()
	if _songs.is_empty():
		_status_count.text = "0/0"
		_focus_label.text = "未找到谱面（res://charts/*/meta.json）"
		_diff_btn.disabled = true
		_play_btn.disabled = true
	else:
		_select_index(0)
	await get_tree().process_frame
	NineDotUiJuice.enter_panel(_lcd_frame)

func _apply_phone_chrome() -> void:
	_bg.color = NineDotTheme.PHONE_CHROME
	_status_bar.color = NineDotTheme.PHONE_CHROME
	_soft_bar.color = NineDotTheme.PHONE_SOFT_BAR
	_focus_strip.color = Color(0.68, 0.8, 0.74, 1)
	_status_title.add_theme_color_override("font_color", Color(0.85, 0.94, 0.9, 1))
	_status_count.add_theme_color_override("font_color", Color(0.7, 0.85, 0.78, 1))
	_focus_label.add_theme_color_override("font_color", NineDotTheme.PHONE_INK)
	# LCD shell: flat mint panel, almost no radius (phone bezel)
	var lcd := StyleBoxFlat.new()
	lcd.bg_color = NineDotTheme.PHONE_LCD
	lcd.border_color = NineDotTheme.PHONE_LCD_EDGE
	lcd.set_border_width_all(2)
	lcd.set_corner_radius_all(2)
	lcd.set_content_margin_all(0)
	_lcd_frame.add_theme_stylebox_override("panel", lcd)

func _build_song_list() -> void:
	_mode = "songs"
	_status_title.text = "通讯录 · 曲目"
	for c in _list.get_children():
		c.queue_free()
	_row_buttons.clear()
	var i := 0
	for song in _songs:
		var btn := _make_contact_row(i, song)
		_list.add_child(btn)
		_row_buttons.append(btn)
		i += 1
	_refresh_soft_labels()

func _make_contact_row(index: int, song: Dictionary) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"ContactRow"
	btn.custom_minimum_size = Vector2(0, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.text = _row_text(index, song)
	var captured := index
	btn.pressed.connect(func(): _on_row_pressed(captured))
	NineDotUiJuice.wire_button_press_juice(btn)
	return btn

func _row_text(index: int, song: Dictionary) -> String:
	var dur := int(song.get("durationMs", 0))
	var mm := int(dur / 60000.0)
	var ss := int((dur % 60000) / 1000.0)
	var artist := String(song.get("artist", ""))
	if artist.strip_edges() == "":
		artist = "—"
	return "%02d  %s\n      %s · %d:%02d" % [
		index + 1,
		String(song.get("title", "?")),
		artist,
		mm,
		ss,
	]

func _on_row_pressed(index: int) -> void:
	if _mode == "diffs":
		_diff_idx = index
		_apply_diff_highlight()
		_refresh_focus_strip()
		_refresh_soft_labels()
		return
	# Second tap on focused contact opens Options (难度), like flip-phone.
	if index == _selected_idx:
		_open_diff_book()
		return
	_select_index(index)

func _select_index(index: int) -> void:
	if index < 0 or index >= _songs.size():
		return
	_selected_idx = index
	var song: Dictionary = _songs[index]
	PlaySession.select_chart(String(song.get("id", "")), String(song.get("_metaPath", "")))
	_clamp_diff_to_available()
	_apply_song_highlight()
	_refresh_status()
	_refresh_focus_strip()
	_refresh_soft_labels()
	_ensure_row_visible(_selected_idx)

func _apply_song_highlight() -> void:
	for i in range(_row_buttons.size()):
		var btn := _row_buttons[i]
		if not is_instance_valid(btn):
			continue
		btn.theme_type_variation = &"ContactRowSelected" if i == _selected_idx else &"ContactRow"

func _apply_diff_highlight() -> void:
	for i in range(_row_buttons.size()):
		var btn := _row_buttons[i]
		if not is_instance_valid(btn):
			continue
		btn.theme_type_variation = &"ContactRowSelected" if i == _diff_idx else &"ContactRow"

func _refresh_status() -> void:
	_status_count.text = "%d/%d" % [_selected_idx + 1, _songs.size()]

func _refresh_focus_strip() -> void:
	if _songs.is_empty():
		return
	if _mode == "diffs":
		var key := _diff_key_at(_diff_idx)
		var avail := _diff_available(key)
		_focus_label.text = "难度 %s · %s" % [key.capitalize(), "可玩" if avail else "未实装"]
		return
	var song: Dictionary = _songs[_selected_idx]
	_focus_label.text = "BPM %s · 偏移 %sms · %s" % [
		str(song.get("bpm", "?")),
		str(song.get("offsetMs", 0)),
		String((song.get("video", {}) as Dictionary).get("source", "none")),
	]

func _refresh_soft_labels() -> void:
	if _mode == "diffs":
		_back_btn.text = "列表"
		_diff_btn.text = "选中"
		_play_btn.text = "开始"
		var key := _diff_key_at(_diff_idx)
		_play_btn.disabled = not _diff_available(key)
		_diff_btn.disabled = false
		return
	_back_btn.text = "返回"
	_diff_btn.text = _current_diff_key().capitalize()
	_play_btn.text = "开始"
	_diff_btn.disabled = _songs.is_empty()
	_play_btn.disabled = _songs.is_empty() or not _diff_available(_current_diff_key())

func _current_diff_key() -> String:
	return _diff_key_at(_diff_idx)

func _diff_key_at(idx: int) -> String:
	return DIFF_ORDER[clampi(idx, 0, DIFF_ORDER.size() - 1)]

func _diff_available(diff_key: String) -> bool:
	if _songs.is_empty():
		return false
	var song: Dictionary = _songs[_selected_idx]
	var diffs: Dictionary = song.get("difficulties", {})
	var entry = diffs.get(diff_key, null)
	return typeof(entry) == TYPE_DICTIONARY and entry != null and String(entry.get("file", "")) != ""

func _clamp_diff_to_available() -> void:
	if _diff_available(_current_diff_key()):
		return
	for i in range(DIFF_ORDER.size()):
		if _diff_available(DIFF_ORDER[i]):
			_diff_idx = i
			return

func _ensure_row_visible(index: int) -> void:
	call_deferred("_scroll_to_row", index)

func _scroll_to_row(index: int) -> void:
	if index < 0 or index >= _row_buttons.size():
		return
	var btn := _row_buttons[index]
	if not is_instance_valid(btn):
		return
	_scroll.ensure_control_visible(btn)

func _on_soft_back() -> void:
	if _mode == "diffs":
		_build_song_list()
		_select_index(_selected_idx)
		return
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _on_soft_diff() -> void:
	if _songs.is_empty():
		return
	if _mode == "diffs":
		# Confirm highlight stays; treat as "select this difficulty"
		_refresh_soft_labels()
		NineDotUiJuice.pulse_button(_diff_btn)
		return
	_open_diff_book()

func _open_diff_book() -> void:
	_mode = "diffs"
	_status_title.text = "选项 · 难度"
	for c in _list.get_children():
		c.queue_free()
	_row_buttons.clear()
	var song: Dictionary = _songs[_selected_idx]
	var diffs: Dictionary = song.get("difficulties", {})
	for i in range(DIFF_ORDER.size()):
		var key := DIFF_ORDER[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var entry = diffs.get(key, null)
		var available := typeof(entry) == TYPE_DICTIONARY and entry != null and String(entry.get("file", "")) != ""
		btn.text = "%02d  %s\n      %s" % [i + 1, key.capitalize(), "可玩" if available else "未实装"]
		btn.disabled = not available
		btn.theme_type_variation = &"ContactRow"
		var captured := i
		if available:
			btn.pressed.connect(func(): _on_row_pressed(captured))
			NineDotUiJuice.wire_button_press_juice(btn)
		_list.add_child(btn)
		_row_buttons.append(btn)
	_clamp_diff_to_available()
	_apply_diff_highlight()
	_refresh_focus_strip()
	_refresh_soft_labels()
	_ensure_row_visible(_diff_idx)

func _on_soft_play() -> void:
	if _songs.is_empty():
		return
	var key := _current_diff_key()
	if not _diff_available(key):
		_focus_label.text = "该难度不可用 — 按中间键换难度"
		return
	var song: Dictionary = _songs[_selected_idx]
	var path := NineDotCatalog.notes_path_for(song, key)
	if path.is_empty():
		_focus_label.text = "该难度不可用"
		return
	PlaySession.select_diff(key)
	get_tree().change_scene_to_file("res://scenes/play.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_soft_back()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_on_soft_play()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_nudge(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_nudge(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		if _mode == "songs":
			_open_diff_book()
		else:
			_nudge(1 if event.is_action_pressed("ui_right") else -1)
		get_viewport().set_input_as_handled()

func _nudge(delta: int) -> void:
	if _mode == "diffs":
		var next := clampi(_diff_idx + delta, 0, DIFF_ORDER.size() - 1)
		# skip disabled
		var guard := 0
		while guard < DIFF_ORDER.size() and not _diff_available(_diff_key_at(next)):
			next = clampi(next + delta, 0, DIFF_ORDER.size() - 1)
			guard += 1
			if next == _diff_idx:
				break
		_on_row_pressed(next)
		_ensure_row_visible(_diff_idx)
		return
	if _songs.is_empty():
		return
	_select_index(posmod(_selected_idx + delta, _songs.size()))
