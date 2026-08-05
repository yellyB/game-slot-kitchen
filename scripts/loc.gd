class_name Loc
extends RefCounted
## 경량 i18n — 문자열 키 → 로케일별 텍스트. autoload 아님(static), project.godot 안 건드림.
## 현재는 타이틀/설정 화면 문자열만. 게임 내 UI 문자열은 추후(버프 파이프라인 병합 후) 확장.
## 사용: Loc.t("start"). 로케일 변경: Loc.locale = "en" 후 화면 rebuild.

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

## 키의 현재 로케일 텍스트. 없으면 키 그대로(누락 표시).
static func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	return entry.get(locale, entry.get("ko", key))
