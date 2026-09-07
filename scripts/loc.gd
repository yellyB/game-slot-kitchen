class_name Loc
extends RefCounted
## 경량 i18n — 언어별 파일(data/locale/<code>.gd의 const S)에서 문자열 조회.
## autoload 아님(static), project.godot 안 건드림. 화면은 Loc.t("키")로만 조회.
##
## 새 문자열 추가: ko.gd·en.gd·ja.gd 세 파일에 같은 키를 넣는다.
## 새 언어 추가: data/locale/<code>.gd 만들고 LOCALES + _table()에 한 줄 추가.

static var locale := "ko"

const LOCALES := ["ko", "en", "ja", "zh", "de", "pt", "fr", "es"]
const SAVE_PATH := "user://locale.save"
static var _inited := false

## 앱 시작 시 1회 — 저장된 선택이 있으면 그걸, 없으면 기기 언어로 자동 선택(미지원이면 영어).
static func init() -> void:
	if _inited:
		return
	_inited = true
	var saved := _load_saved()
	if saved in LOCALES:
		locale = saved
		return
	var sys := OS.get_locale_language()   # "ko"/"en"/"ja"/"zh"/"de"/"pt"/"fr"/"es" 등
	locale = sys if sys in LOCALES else "en"

## 언어 변경 + 디스크 저장(재시작에도 유지). 설정 화면에서 호출.
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

## 현재 언어의 문자열 테이블.
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

## 키의 현재 언어 텍스트. 없으면 한국어 폴백, 그것도 없으면 키 그대로(누락 표시).
static func t(key: String) -> String:
	var s := _table()
	if s.has(key):
		return s[key]
	return LocaleKo.S.get(key, key)
