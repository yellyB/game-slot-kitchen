extends Node

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_sweep(get_tree().root)


func _sweep(n: Node) -> void:
	for c in n.get_children():
		_on_node_added(c)
		_sweep(c)


func _on_node_added(node: Node) -> void:
	if not (node is BaseButton):
		return
	var btn := node as BaseButton
	if btn.get_meta("no_press_pop", false) or btn.has_meta("_press_pop"):
		return
	btn.set_meta("_press_pop", true)
	btn.button_down.connect(_press.bind(btn, true))
	btn.button_up.connect(_press.bind(btn, false))


func _press(btn: BaseButton, down: bool) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween()
	if down:
		tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
