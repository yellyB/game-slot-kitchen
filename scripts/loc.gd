class_name Loc
extends RefCounted

static var locale := "ko"

const LOCALES := ["ko", "en", "ja", "zh", "de", "pt", "fr", "es"]
const SAVE_PATH := "user://locale.save"
static var _inited := false

static func init() -> void:
	if _inited:
		return
	_inited = true
	var saved := _load_saved()
	if saved in LOCALES:
		locale = saved
		return
	var sys := OS.get_locale_language()
	locale = sys if sys in LOCALES else "en"

static func set_locale(code: String) -> void:
	locale = code
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(code)

static func _load_saved() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	return f.get_as_text().strip_edges() if f else ""

static func _table() -> Dictionary:
	match locale:
		"en": return LocaleEn.S
		"ja": return LocaleJa.S
		"zh": return LocaleZh.S
		"de": return LocaleDe.S
		"pt": return LocalePt.S
		"fr": return LocaleFr.S
		"es": return LocaleEs.S
	return LocaleKo.S

static func t(key: String) -> String:
	var s := _table()
	if s.has(key):
		return s[key]
	return LocaleKo.S.get(key, key)
