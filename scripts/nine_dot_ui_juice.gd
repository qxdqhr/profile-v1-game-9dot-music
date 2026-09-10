extends RefCounted
class_name NineDotUiJuice
## UI Tween helpers (gd-agentic: godot-tweening — kill-before-recreate, EASE_OUT).

static func pop_control(node: Control, from_scale: float = 0.72) -> void:
	if node == null:
		return
	_kill_meta_tween(node)
	node.pivot_offset = node.size * 0.5
	if node.size == Vector2.ZERO:
		node.pivot_offset = Vector2(60, 16)
	node.scale = Vector2(from_scale, from_scale)
	node.modulate.a = 0.35
	var tw := node.create_tween().bind_node(node)
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector2.ONE, 0.28)
	tw.tween_property(node, "modulate:a", 1.0, 0.18)
	node.set_meta("_juice_tween", tw)

static func enter_panel(panel: Control) -> void:
	if panel == null:
		return
	_kill_meta_tween(panel)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().bind_node(panel)
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35)
	tw.tween_property(panel, "modulate:a", 1.0, 0.28)
	panel.set_meta("_juice_tween", tw)

static func pulse_button(btn: BaseButton) -> void:
	if btn == null:
		return
	_kill_meta_tween(btn)
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween().bind_node(btn)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.06)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.12)
	btn.set_meta("_juice_tween", tw)

static func wire_button_press_juice(btn: BaseButton) -> void:
	if btn == null or btn.has_meta("_juice_wired"):
		return
	btn.set_meta("_juice_wired", true)
	btn.button_down.connect(func(): pulse_button(btn))

static func stagger_buttons(buttons: Array) -> void:
	var i := 0
	for b in buttons:
		if b is Control:
			var c := b as Control
			c.modulate.a = 0.0
			var delay := 0.05 * float(i)
			var tw := c.create_tween().bind_node(c)
			tw.tween_interval(delay)
			tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(c, "modulate:a", 1.0, 0.28)
			i += 1

static func _kill_meta_tween(node: Node) -> void:
	if node.has_meta("_juice_tween"):
		var old: Variant = node.get_meta("_juice_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
