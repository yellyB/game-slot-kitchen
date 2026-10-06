
const COMMIT_FILE := "res://build_commit.txt"


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


static func commit() -> String:
	if FileAccess.file_exists(COMMIT_FILE):
		return FileAccess.get_file_as_string(COMMIT_FILE).strip_edges()
	var out: Array = []
	var proj := ProjectSettings.globalize_path("res://")
	if OS.execute("git", ["-C", proj, "rev-parse", "--short", "HEAD"], out) == 0 and not out.is_empty():
		return str(out[0]).strip_edges()
	return "?"


static func label() -> String:
	return "test: " + commit() if OS.is_debug_build() else "v" + version()
