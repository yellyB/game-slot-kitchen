class_name Levels
extends RefCounted
## 시간 단위: 1라운드 = 1주, 4주 = 1개월(WEEKS_PER_MONTH). 월세는 월말(4주차)에만 지불.
## 1~3주차는 지불 없이 벌어서 누적 → 월말에 월세 이상 보유해야 통과(아니면 폐업).
## **진행에 끝 없음(무한).** 정의된 MONTHS 이후는 공식으로 월세·손님이 계속 escalating.
##   승리 조건 없음 — 월세를 못 내는 순간까지 무한 플레이. (엔딩 컷오프는 나중에.)
## 보스(계약 갱신): 분기(3개월)마다 월말 심사 — 보스데이.md, 아직 미구현.
## 밸런스 v1(월 구조 전환 첫 튜닝) — 실플레이/시뮬로 보정.

const WEEKS_PER_MONTH := 4
const RENT_GROWTH := 1.6    # 정의 구간 이후 월세 복리 증가율(달마다 ×)
const WAVE_STEP := 1        # 정의 구간 이후 손님 수 월당 증가
const WAVE_CAP := 18        # 손님 수(per_wave) 상한 — 처리량/화면 한계

const MONTHS := [
	{"rent": 40000,  "waves": [11, 12, 13, 14]},  # 1개월차 (≈4주치 — 온보딩)
	{"rent": 75000,  "waves": [13, 14, 15, 15]},  # 2개월차
	{"rent": 130000, "waves": [15, 16, 16, 17]},  # 3개월차 (분기말 — 나중 보스 심사 예정)
]

## 무한 진행이라 실질 상한(승리 조건으로 안 쓰임). session의 day>=count()가 절대 참이 안 되게.
static func count() -> int:
	return 1_000_000

static func months() -> int:
	return MONTHS.size()

## 이 달(0-base)의 월세 — 정의 구간은 표, 이후는 마지막 값 × RENT_GROWTH^(초과 월수).
static func _monthly_rent(mi: int) -> int:
	if mi < MONTHS.size():
		return int(MONTHS[mi]["rent"])
	var last := int(MONTHS[MONTHS.size() - 1]["rent"])
	return int(round(float(last) * pow(RENT_GROWTH, mi - (MONTHS.size() - 1))))

## 이 달·주(0-base)의 웨이브당 손님 수 — 정의 이후는 마지막 달에서 월당 +WAVE_STEP(상한 WAVE_CAP).
static func _waves(mi: int, wi: int) -> int:
	if mi < MONTHS.size():
		return int((MONTHS[mi]["waves"] as Array)[wi])
	var base := int((MONTHS[MONTHS.size() - 1]["waves"] as Array)[wi])
	return mini(base + WAVE_STEP * (mi - (MONTHS.size() - 1)), WAVE_CAP)

## 주차(1-base) 정보. per_wave·month·week_in_month·is_month_end·monthly_rent·rent(월말만>0)·weeks_left.
static func get_week(week: int) -> Dictionary:
	var w := maxi(0, week - 1)
	var mi := w / WEEKS_PER_MONTH
	var wi := w % WEEKS_PER_MONTH
	var is_end := wi == WEEKS_PER_MONTH - 1
	var pw := _waves(mi, wi)
	var mr := _monthly_rent(mi)
	if OS.has_environment("SIM_LOAD"):
		var mult := float(OS.get_environment("SIM_LOAD"))
		if mult > 1.0:
			pw = int(round(float(pw) * mult))
	if OS.has_environment("SIM_RENT"):
		mr = int(round(float(mr) * float(OS.get_environment("SIM_RENT"))))
	return {
		"per_wave": pw,
		"month": mi + 1,
		"week_in_month": wi + 1,
		"is_month_end": is_end,
		"monthly_rent": mr,
		"rent": mr if is_end else 0,
		"weeks_left": (WEEKS_PER_MONTH - 1) - wi,
	}

## 하위호환 별칭 — 기존 호출부(session·sim)가 get_day(day)로 rent/per_wave를 읽음.
static func get_day(day: int) -> Dictionary:
	return get_week(day)
