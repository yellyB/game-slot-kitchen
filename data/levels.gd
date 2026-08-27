class_name Levels
extends RefCounted
## 시간 단위: 1라운드 = 1주, 4주 = 1개월(WEEKS_PER_MONTH). 월세는 월말(4주차)에만 지불.
## 1~3주차는 지불 없이 벌어서 누적 → 월말에 월세 이상 보유해야 통과(아니면 폐업).
## **진행에 끝 없음(무한).** 정의된 MONTHS 이후는 공식으로 월세·손님이 계속 escalating.
##   승리 조건 없음 — 월세를 못 내는 순간까지 무한 플레이. (엔딩 컷오프는 나중에.)
## 보스(계약 갱신): 분기(3개월)마다 월말 심사 — 보스데이.md, 아직 미구현.
## 밸런스 v1(월 구조 전환 첫 튜닝) — 실플레이/시뮬로 보정.

const WEEKS_PER_MONTH := 4
## 월세 = 볼록 곡선(완만한 기본 복리 + 후반 가속 항). 초반은 거의 그대로(온보딩 보호),
## 중후반은 가파르게 올라 스노우볼을 오래 압박. 실로그(중간빌드 월매출)에 맞춰 튜닝. SIM_GROWTH로 스윕.
##   rent(mi) = BASE × ( GROWTH^mi + ACCEL_W × (ACCEL^mi − 1) )   (mi=0-base 개월)
const RENT_BASE := 400    # 곡선 기준값(mi>=onboarding 스케일). 초반은 RENT_ONBOARD로 별도.
# 1~6개월차 월세 — 6개월 아크 명시값(게임 엔딩=6개월 전제). 7개월차+는 아래 곡선 공식.
#   실플레이(#2134) 기준 각 월말 여유(직전현금÷월세) ~1.3~1.8배 유지하도록 튜닝.
#   월1 25k(온보딩, 여유 1.3배) → 월2부터 성장세에 맞춰 상향.
const RENT_ONBOARD := [250, 550, 800, 1100, 1500, 1950]
const RENT_GROWTH := 1.25   # 기본 복리 — 초반 월세 상향(2개월차 여유 축소). 강빌드 12개월 지점은 ACCEL이 결정
const RENT_ACCEL := 2.50    # 후반 가속 항 복리(볼록) — 시뮬: 강빌드 ~12개월 겨우 통과 후 탈락
const RENT_ACCEL_W := 0.02  # 가속 항 가중(초반 미미 → 후반 지배)
const WAVE_STEP := 1        # 정의 구간 이후 손님 수 월당 증가
const WAVE_CAP := 18        # 손님 수(per_wave) 상한 — 처리량/화면 한계

# waves(주차별 손님 수)만 정의 — 월세는 공식(_monthly_rent). 정의 이후는 마지막 달 waves 연장.
const MONTHS := [
	{"waves": [11, 12, 13, 14]},  # 1개월차
	{"waves": [13, 14, 15, 15]},  # 2개월차
	{"waves": [15, 16, 16, 17]},  # 3개월차
]

## 무한 진행이라 실질 상한(승리 조건으로 안 쓰임). session의 day>=count()가 절대 참이 안 되게.
static func count() -> int:
	return 1_000_000

static func months() -> int:
	return MONTHS.size()

## 이 달(0-base)의 월세 — 볼록 곡선(완만 기본 복리 + 후반 가속). 무한 공식. SIM_GROWTH로 기본 복리 스윕.
static func _monthly_rent(mi: int) -> int:
	if mi < RENT_ONBOARD.size():
		return int(RENT_ONBOARD[mi])   # 온보딩 램프 — 곡선과 분리(후반 압박 유지하며 초반 관문만 완화)
	var g := RENT_GROWTH
	if OS.has_environment("SIM_GROWTH"):
		g = float(OS.get_environment("SIM_GROWTH"))
	var a := RENT_ACCEL
	if OS.has_environment("SIM_ACCEL"):
		a = float(OS.get_environment("SIM_ACCEL"))
	return int(round(float(RENT_BASE) * (pow(g, mi) + RENT_ACCEL_W * (pow(a, mi) - 1.0))))

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
