extends Control
## Legacy path — redirects to MyRoom gate (M0+).

func _ready() -> void:
	get_tree().change_scene_to_file("res://scenes/myroom/gate.tscn")
