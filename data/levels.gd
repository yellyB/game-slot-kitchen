class_name Levels
extends RefCounted
## 하루(세션)별 레벨 정의 — 레벨디자인은 이 표를 편집(테스트하며 조정).
## 웨이브는 항상 3번(Config.WAVES). 하루마다 가게세와 웨이브당 손님 수만 변함.
## 금액 최소단위 1원 = 가장 싼 메뉴(커피 1). rent도 같은 스케일.

const DAYS := [
	{"rent": 3,  "per_wave": 2},   # 1일차 (손님 6)
	{"rent": 7,  "per_wave": 3},   # 2일차 (손님 9)
	{"rent": 12, "per_wave": 4},   # 3일차 (손님 12)
	{"rent": 18, "per_wave": 5},   # 4일차 (손님 15)
	{"rent": 26, "per_wave": 6},   # 5일차 (손님 18) — 클리어
]

static func count() -> int:
	return DAYS.size()

static func get_day(day: int) -> Dictionary:
	return DAYS[clampi(day - 1, 0, DAYS.size() - 1)]
