class_name Codex
extends RefCounted

const PATH := "user://codex.save"

static var _discovered := {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		for id in data:
			_discovered[id] = true


static func discover(id: String) -> void:
	_ensure_loaded()
	if _discovered.has(id):
		return
	_discovered[id] = true
	_save()


static func is_discovered(id: String) -> bool:
	_ensure_loaded()
	return _discovered.has(id)


static func discovered_count() -> int:
	_ensure_loaded()
	return _discovered.size()


static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_discovered.keys()))
