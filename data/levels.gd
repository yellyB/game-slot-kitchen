class_name Levels
extends RefCounted
## 하루(세션)별 레벨 정의 — 레벨디자인은 이 표를 편집(테스트하며 조정).
## 웨이브는 항상 3번(Config.WAVES). 하루마다 가게세와 웨이브당 손님 수만 변함.
## 금액 최소단위 1원 = 가장 싼 메뉴(커피 1). rent도 같은 스케일.

const DAYS := [
	{"rent": 5,  "per_wave": 2},   # 1일차 (손님 6, 최대매출 ~31) — 여유, 첫 버프
	{"rent": 12, "per_wave": 3},   # 2일차 (손님 9, ~46)
	{"rent": 22, "per_wave": 4},   # 3일차 (손님 12, ~62)
	{"rent": 35, "per_wave": 5},   # 4일차 (손님 15, ~77)
	{"rent": 50, "per_wave": 6},   # 5일차 (손님 18, ~93) — 클리어(절반 이상 서빙 필요)
]

static func count() -> int:
	return DAYS.size()

static func get_day(day: int) -> Dictionary:
	return DAYS[clampi(day - 1, 0, DAYS.size() - 1)]
