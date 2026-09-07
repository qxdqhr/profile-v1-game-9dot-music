extends Control
## Song select + difficulty grey-out (M3).

@onready var _list: VBoxContainer = $Center/Panel/Margin/VBox/List
@onready var _diff_box: VBoxContainer = $Center/Panel/Margin/VBox/DiffBox
@onready var _hint: Label = $Center/Panel/Margin/VBox/Hint
@onready var _detail: Label = $Center/Panel/Margin/VBox/Detail

var _songs: Array = []
var _selected: Dictionary = {}

func _ready() -> void:
	$Center/Panel/Margin/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	_songs = NineDotCatalog.list_songs()
	_build_song_list()
	if _songs.size() > 0:
		_select_song(_songs[0])
	else:
		_hint.text = "未找到谱面（res://charts/*/meta.json）"

func _build_song_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for song in _songs:
		var btn := Button.new()
		var dur := int(song.get("durationMs", 0))
		btn.text = "%s\n%s · %ds" % [String(song.get("title", "?")), String(song.get("artist", "")), int(dur / 1000.0)]
		btn.custom_minimum_size = Vector2(280, 58)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var captured: Dictionary = song
		btn.pressed.connect(func(): _select_song(captured))
		_list.add_child(btn)

func _select_song(song: Dictionary) -> void:
	_selected = song
	PlaySession.select_chart(String(song.get("id", "")), String(song.get("_metaPath", "")))
	var dur := int(song.get("durationMs", 0))
	_detail.text = "BPM %s · 偏移 %sms · %s" % [
		str(song.get("bpm", "?")),
		str(song.get("offsetMs", 0)),
		String((song.get("video", {}) as Dictionary).get("source", "none")),
	]
	_hint.text = "已选：%s（%ds）" % [String(song.get("title", "")), int(dur / 1000.0)]
	_build_diffs()

func _build_diffs() -> void:
	for c in _diff_box.get_children():
		c.queue_free()
	var diffs: Dictionary = _selected.get("difficulties", {})
	for key in ["easy", "normal", "hard", "extreme"]:
		var btn := Button.new()
		btn.text = key.capitalize()
		btn.custom_minimum_size = Vector2(280, 40)
		var entry = diffs.get(key, null)
		var available := typeof(entry) == TYPE_DICTIONARY and entry != null and String(entry.get("file", "")) != ""
		btn.disabled = not available
		if not available:
			btn.text = "%s（未实装）" % key.capitalize()
		else:
			var k := key
			btn.pressed.connect(func(): _start_diff(k))
		_diff_box.add_child(btn)

func _start_diff(diff: String) -> void:
	var path := NineDotCatalog.notes_path_for(_selected, diff)
	if path.is_empty():
		_hint.text = "该难度不可用"
		return
	PlaySession.select_diff(diff)
	get_tree().change_scene_to_file("res://scenes/play.tscn")
