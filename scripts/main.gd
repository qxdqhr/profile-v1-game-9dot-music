extends Control
## 9dot Music scaffold: 3x3 pad UI; wire audio later.

@onready var _hud: Label = $UI/HUD
@onready var _grid: GridContainer = $Center/VBox/Grid
@onready var _hint: Label = $Center/VBox/Hint

var _hits: int = 0

func _ready() -> void:
	for i in range(9):
		var btn := Button.new()
		btn.text = str(i + 1)
		btn.custom_minimum_size = Vector2(88, 88)
		var idx := i
		btn.pressed.connect(func() -> void: _on_pad(idx))
		_grid.add_child(btn)
	_update_hud()

func _on_pad(index: int) -> void:
	_hits += 1
	_hint.text = "点按格 %d（音效待接）" % (index + 1)
	_update_hud()

func _update_hud() -> void:
	_hud.text = "9dot Music\n点按 %d" % _hits
