class_name Loc
extends RefCounted
## 경량 i18n — 언어별 파일(data/locale/<code>.gd의 const S)에서 문자열 조회.
## autoload 아님(static), project.godot 안 건드림. 화면은 Loc.t("키")로만 조회.
##
## 새 문자열 추가: ko.gd·en.gd·ja.gd 세 파일에 같은 키를 넣는다.
## 새 언어 추가: data/locale/<code>.gd 만들고 LOCALES + _table()에 한 줄 추가.

static var locale := "ko"

const LOCALES := ["ko", "en", "ja"]

## 현재 언어의 문자열 테이블.
static func _table() -> Dictionary:
	match locale:
		"en": return LocaleEn.S
		"ja": return LocaleJa.S
	return LocaleKo.S

## 키의 현재 언어 텍스트. 없으면 한국어 폴백, 그것도 없으면 키 그대로(누락 표시).
static func t(key: String) -> String:
	var s := _table()
	if s.has(key):
		return s[key]
	return LocaleKo.S.get(key, key)
