extends Node

signal performed

var _payload: Dictionary = {}
var _source: Object = null


func has_selection() -> bool:
	return not _payload.is_empty()


func on_click(node: Object) -> void:
	if node == _source:
		clear()
		return

	if has_selection() and node.has_method("can_accept") and node.can_accept(_payload):
		node.accept(_payload)
		clear()
		performed.emit()
		return

	if node.has_method("get_move_payload"):
		var p: Dictionary = node.get_move_payload()
		if not p.is_empty():
			_select(node, p)
			return

	clear()


func on_drop(target: Object, payload: Dictionary) -> void:
	if target.has_method("can_accept") and target.can_accept(payload):
		target.accept(payload)
		performed.emit()


func begin_drag() -> void:
	clear()


func background_click() -> void:
	clear()


func _select(node: Object, payload: Dictionary) -> void:
	clear()
	_payload = payload
	_source = node
	if node.has_method("set_selected"):
		node.set_selected(true)


func clear() -> void:
	if _source != null and is_instance_valid(_source) and _source.has_method("set_selected"):
		_source.set_selected(false)
	_payload = {}
	_source = null
