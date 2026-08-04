class_name Levels
extends RefCounted
## 하루(세션)별 레벨 정의 — 레벨디자인은 이 표를 편집(테스트하며 조정).
## 웨이브는 항상 3번(Config.WAVES). 하루마다 가게세와 웨이브당 손님 수만 변함.
## 금액 단위: 가장 싼 메뉴(커피)=100. rent도 같은 스케일.

const DAYS := [
	{"rent": 500,   "per_wave": 3},   # 1일차 (손님 9)  — 여유, 돈/성장 버프 담기
	{"rent": 2000,  "per_wave": 5},   # 2일차 (손님 15) — 여유
	{"rent": 6000,  "per_wave": 8},   # 3일차 (손님 24) — 재투자 압박 시작
	{"rent": 13000, "per_wave": 11},  # 4일차 (손님 33) — 빡빡
	{"rent": 20000, "per_wave": 15},  # 5일차 (손님 45) — 생존+처리량 이중 압박(잘못하면 폐업)
]

static func count() -> int:
	return DAYS.size()

static func get_day(day: int) -> Dictionary:
	var d := (DAYS[clampi(day - 1, 0, DAYS.size() - 1)] as Dictionary).duplicate()
	# 시뮬 압박 실험용 손잡이: SIM_LOAD 환경변수로 손님 수 배수(예: SIM_LOAD=3).
	if OS.has_environment("SIM_LOAD"):
		var mult := float(OS.get_environment("SIM_LOAD"))
		if mult > 1.0:
			d["per_wave"] = int(round(float(d.get("per_wave", 3)) * mult))
	if OS.has_environment("SIM_RENT"):   # 가게세 배수 실험 손잡이
		d["rent"] = int(round(float(d.get("rent", 0)) * float(OS.get_environment("SIM_RENT"))))
	return d
