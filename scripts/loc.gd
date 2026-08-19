class_name Loc
extends RefCounted

static var locale := "ko"

const LOCALES := ["ko", "en"]

static func _table() -> Dictionary:
	match locale:
		"en": return LocaleEn.S
		"ja": return LocaleJa.S
	return LocaleKo.S

static func t(key: String) -> String:
	var s := _table()
	if s.has(key):
		return s[key]
	return LocaleKo.S.get(key, key)
