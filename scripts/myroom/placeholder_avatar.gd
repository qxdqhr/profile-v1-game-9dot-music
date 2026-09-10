extends Node3D
## Packed placeholder — builds procedural OC avatar on ready.

const _Loader = preload("res://scripts/myroom/myroom_model_loader.gd")

@export var tint: Color = Color(0.45, 0.85, 0.78, 1.0)

func _ready() -> void:
	for c in get_children():
		c.queue_free()
	var built := _Loader.build_procedural_avatar(tint)
	for c in built.get_children():
		built.remove_child(c)
		add_child(c)
	built.queue_free()
