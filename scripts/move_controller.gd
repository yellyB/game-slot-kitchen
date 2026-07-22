extends Node

signal performed

var default_target := Callable()

var _payload: Dictionary = {}
var _source: Object = null


func has_selection() -> bool:
	return not _payload.is_empty()


func on_click(node: Object) -> void:
	if _source != null and not is_instance_valid(_source):
		_payload = {}
		_source = null

	if node.has_method("is_quick") and node.is_quick() and node.has_method("get_move_payload"):
		clear()
		quick(node.get_move_payload())
		return

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


func quick(payload: Dictionary) -> bool:
	if default_target.is_null() or payload.is_empty():
		return false
	var target = default_target.call(payload)
	if target != null and is_instance_valid(target) \
			and target.has_method("can_accept") and target.can_accept(payload):
		target.accept(payload)
		performed.emit()
		return true
	return false


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
