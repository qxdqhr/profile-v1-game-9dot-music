extends Node
## Cross-scene play selection (chart id + difficulty).

var chart_id: String = "song-metronome-001"
var diff: String = "normal"
var meta_path: String = "res://charts/song-metronome-001/meta.json"

func select_chart(id: String, meta: String) -> void:
	chart_id = id
	meta_path = meta

func select_diff(d: String) -> void:
	diff = d
