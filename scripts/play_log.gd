class_name PlayLog
extends RefCounted

const PATH := "user://playlog.jsonl"

static func append(entry: Dictionary) -> void:
	var f: FileAccess
	if FileAccess.file_exists(PATH):
		f = FileAccess.open(PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line(JSON.stringify(entry))
	f.close()

static func abs_path() -> String:
	return ProjectSettings.globalize_path(PATH)

static func read_text() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s

static func clear() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.close()
