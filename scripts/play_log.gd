class_name PlayLog
extends RefCounted

const PATH := "user://playlog.jsonl"

static var _ver_cache := ""

static func version() -> String:
	if _ver_cache != "":
		return _ver_cache
	var out: Array = []
	var dir := ProjectSettings.globalize_path("res://")
	var rc := OS.execute("git", ["-C", dir, "describe", "--always", "--dirty", "--abbrev=7"], out)
	var v := String(out[0]).strip_edges() if out.size() > 0 else ""
	_ver_cache = v if (rc == 0 and v != "") else "unknown"
	return _ver_cache

static func append(entry: Dictionary) -> void:
	if not entry.has("commit"):
		entry["commit"] = version()
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
