extends Node
## Cross-scene play selection + last result payload.

var chart_id: String = "song-metronome-001"
var diff: String = "normal"
var meta_path: String = "res://charts/song-metronome-001/meta.json"
var last_score: Dictionary = {}
var last_title: String = ""

func select_chart(id: String, meta: String) -> void:
	chart_id = id
	meta_path = meta

func select_diff(d: String) -> void:
	diff = d

func store_result(title: String, score: Dictionary) -> void:
	last_title = title
	last_score = score.duplicate()
