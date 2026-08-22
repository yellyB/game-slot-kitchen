class_name Levels
extends RefCounted
## 하루(세션)별 레벨 정의 — 레벨디자인은 이 표를 편집(테스트하며 조정).
## 웨이브는 항상 3번(Config.WAVES). 하루마다 가게세와 웨이브당 손님 수만 변함.
## 금액 단위: 가장 싼 메뉴(커피)=100. rent도 같은 스케일.

const DAYS := [
	{"rent": 1800,  "per_wave": 11},  # 1일차 (손님 33) — 온보딩, 사실상 통과
	{"rent": 6000,  "per_wave": 12},  # 2일차 (손님 36)
	{"rent": 9000,  "per_wave": 13},  # 3일차 (손님 39) — 압박 시작
	{"rent": 15000, "per_wave": 13},  # 4일차 (손님 39) — 빡빡
	{"rent": 33000, "per_wave": 14},  # 5일차 (손님 42) — 생존 압박
]
# 튜닝 v2(난이도 (c)하드코어): 1→2일 절벽(1800→9000, 5배)+시작금0으로 초반 현금흐름이 못 따라가
# 3~4일 벽. 2~4일 완만화(2일 9k→6k, 3일 10k→9k, 4일 19k→15k)로 곡선 부드럽게. 5일은 실플레이 후 조정.
# 병행: 슬롯가 하향(3000→1800·×1.6)+버프팩 고정(200)으로 슬롯 확장이 실질 가능해짐(data/config.gd).

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
