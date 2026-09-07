extends Control
## Song select + difficulty (missing diffs greyed).

const META_PATH := "res://charts/song-metronome-001/meta.json"

@onready var _list: VBoxContainer = $Center/VBox/List
@onready var _diff_box: VBoxContainer = $Center/VBox/DiffBox
@onready var _hint: Label = $Center/VBox/Hint

var _meta: Dictionary = {}
var _selected_id := ""

func _ready() -> void:
	$Center/VBox/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	_meta = NineDotChart.load_meta(META_PATH)
	_build_song_row()
	_build_diffs()
	_hint.text = "选择难度后开始（MVP 仅 Normal）"

func _build_song_row() -> void:
	for c in _list.get_children():
		c.queue_free()
	var btn := Button.new()
	btn.text = "%s\n%s" % [String(_meta.get("title", "Untitled")), String(_meta.get("artist", ""))]
	btn.custom_minimum_size = Vector2(280, 64)
	btn.pressed.connect(func(): _selected_id = String(_meta.get("id", "")); _hint.text = "已选：%s" % btn.text.replace("\n", " · "))
	_list.add_child(btn)
	_selected_id = String(_meta.get("id", ""))

func _build_diffs() -> void:
	for c in _diff_box.get_children():
		c.queue_free()
	var diffs: Dictionary = _meta.get("difficulties", {})
	for key in ["easy", "normal", "hard", "extreme"]:
		var btn := Button.new()
		btn.text = key.capitalize()
		btn.custom_minimum_size = Vector2(280, 40)
		var entry = diffs.get(key, null)
		var available := typeof(entry) == TYPE_DICTIONARY and entry != null and String(entry.get("file", "")) != ""
		btn.disabled = not available
		if available:
			var k := key
			btn.pressed.connect(func(): _start_diff(k))
		_diff_box.add_child(btn)

func _start_diff(diff: String) -> void:
	if diff != "normal":
		_hint.text = "MVP 仅开放 Normal"
		return
	get_tree().change_scene_to_file("res://scenes/play.tscn")
