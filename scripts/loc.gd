class_name Loc
extends RefCounted

static var locale := "ko"

const LOCALES := ["ko", "en", "ja"]

const STRINGS := {
	"start":    {"ko": "시작",   "en": "Start",     "ja": "スタート"},
	"settings": {"ko": "설정",   "en": "Settings",  "ja": "設定"},
	"sound":    {"ko": "소리",   "en": "Sound",     "ja": "サウンド"},
	"bgm":      {"ko": "배경음", "en": "Music",     "ja": "音楽"},
	"sfx":      {"ko": "효과음", "en": "Sound FX",  "ja": "効果音"},
	"vibrate":  {"ko": "진동",   "en": "Vibration", "ja": "バイブ"},
	"language": {"ko": "언어",   "en": "Language",  "ja": "言語"},
}

static func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	return entry.get(locale, entry.get("ko", key))
