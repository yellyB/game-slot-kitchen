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

	# 게임 — 상단바 / 토스트
	"day_n":         {"ko": "%d일차",   "en": "Day %d",  "ja": "%d日目"},
	"no_empty_slot": {"ko": "빈 칸 없음", "en": "No empty slot", "ja": "空きスロットなし"},

	# 게임 — 결과 모달
	"win_title":       {"ko": "승리! 🎉",       "en": "You Win! 🎉",       "ja": "勝利! 🎉"},
	"win_days":        {"ko": "%d일 완주",       "en": "%d days cleared",   "ja": "%d日 完走"},
	"day_closed":      {"ko": "%d일차 마감",     "en": "Day %d closed",     "ja": "%d日目 終了"},
	"revenue":         {"ko": "매출  %d",        "en": "Revenue  %d",       "ja": "売上  %d"},
	"rent":            {"ko": "가게세  %d",      "en": "Rent  %d",          "ja": "家賃  %d"},
	"remaining":       {"ko": "남음  %d",        "en": "Left  %d",          "ja": "残り  %d"},
	"passed":          {"ko": "통과! ✅",        "en": "Passed! ✅",        "ja": "クリア! ✅"},
	"gameover_title":  {"ko": "폐업 😢",         "en": "Closed down 😢",    "ja": "閉店 😢"},
	"gameover_day":    {"ko": "%d일차에서 끝",   "en": "Ended on day %d",   "ja": "%d日目で終了"},
	"gameover_reason": {"ko": "매출 %d < 가게세 %d", "en": "Revenue %d < Rent %d", "ja": "売上 %d < 家賃 %d"},
	"to_title":        {"ko": "처음으로",        "en": "To title",          "ja": "タイトルへ"},
	"to_shop":         {"ko": "상점으로",        "en": "To shop",           "ja": "ショップへ"},

	# 상점
	"shop_slot":     {"ko": "슬롯 +1",          "en": "Slot +1",     "ja": "スロット +1"},
	"shop_buffpack": {"ko": "버프 팩",          "en": "Buff Pack",   "ja": "バフパック"},
	"shop_draw":     {"ko": "뽑기",             "en": "Draw",        "ja": "引く"},
	"shop_pick":     {"ko": "선택",             "en": "Pick",        "ja": "選択"},
	"shop_buy":      {"ko": "구매",             "en": "Buy",         "ja": "購入"},
	"shop_start":    {"ko": "영업 시작",        "en": "Open Shop",   "ja": "開店"},
	"shop_owned":    {"ko": "보유 버프",        "en": "Buffs",       "ja": "所持バフ"},
	"shop_pick3":    {"ko": "3개 중 1개 선택",  "en": "Pick 1 of 3", "ja": "3つから1つ選択"},
	"shop_price":    {"ko": "가격 %d",          "en": "Price %d",    "ja": "価格 %d"},

	# 손님
	"customer_wants": {"ko": "뭔가 원함", "en": "Wants something", "ja": "何か欲しい"},
}

## 키의 현재 로케일 텍스트. 없으면 키 그대로(누락 표시).
static func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	return entry.get(locale, entry.get("ko", key))
