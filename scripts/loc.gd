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

	"day_n":         {"ko": "%d일차",   "en": "Day %d",  "ja": "%d日目"},
	"no_empty_slot": {"ko": "빈 칸 없음", "en": "No empty slot", "ja": "空きスロットなし"},

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

	"shop_slot":     {"ko": "슬롯 +1",          "en": "Slot +1",     "ja": "スロット +1"},
	"shop_buffpack": {"ko": "버프 팩",          "en": "Buff Pack",   "ja": "バフパック"},
	"shop_draw":     {"ko": "뽑기",             "en": "Draw",        "ja": "引く"},
	"shop_pick":     {"ko": "선택",             "en": "Pick",        "ja": "選択"},
	"shop_buy":      {"ko": "구매",             "en": "Buy",         "ja": "購入"},
	"shop_start":    {"ko": "영업 시작",        "en": "Open Shop",   "ja": "開店"},
	"shop_owned":    {"ko": "보유 버프",        "en": "Buffs",       "ja": "所持バフ"},
	"shop_pick3":    {"ko": "3개 중 1개 선택",  "en": "Pick 1 of 3", "ja": "3つから1つ選択"},
	"shop_price":    {"ko": "가격 %d",          "en": "Price %d",    "ja": "価格 %d"},

	"customer_wants": {"ko": "뭔가 원함", "en": "Wants something", "ja": "何か欲しい"},
}

static func t(key: String) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	return entry.get(locale, entry.get("ko", key))
