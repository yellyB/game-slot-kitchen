class_name Levels
extends RefCounted
## 시간 단위: 1라운드 = 1주, 4주 = 1개월(WEEKS_PER_MONTH).
## 매주 마감마다 누적 점수(month_score) ≥ 이번 주 관문이어야 통과. 미달이면 돈으로 통과(정산 팝업).
## 점수는 월초 리셋 → 한 달 누적. 주 관문은 볼록 증가(첫주 최소→월말 최대), 월말(4주차) 관문 = 그 달 목표(monthly_rent).
## **종료: FINAL_MONTH(3개월차) 마지막 주 통과 = 런 승리.** 그 전에 관문 미달+미납이면 파산(실패).
## 보스(계약 갱신): 분기(3개월)마다 월말 심사 — 보스데이.md, 아직 미구현.
## 밸런스 v1(월 구조 전환 첫 튜닝) — 실플레이/시뮬로 보정.

const WEEKS_PER_MONTH := 4
const FINAL_MONTH := 3    # 이 개월차 마지막 주(4주차) 통과 = 런 승리
## 월세 = 볼록 곡선(완만한 기본 복리 + 후반 가속 항). 초반은 거의 그대로(온보딩 보호),
## 중후반은 가파르게 올라 스노우볼을 오래 압박. 실로그(중간빌드 월매출)에 맞춰 튜닝. SIM_GROWTH로 스윕.
##   rent(mi) = BASE × ( GROWTH^mi + ACCEL_W × (ACCEL^mi − 1) )   (mi=0-base 개월)
const RENT_BASE := 4000    # 곡선 기준값(mi>=onboarding 스케일). 온보딩(1~6개월차)은 ONBOARD_GATES로 별도.
# 전역 난이도 — 관문에 곱. 온보딩(초반) 보호를 위해 월별 램프: 1개월 ≈1.0 → 후반 GATE_MULT_MAX로 상승.
const GATE_MULT_MIN := 1.0    # 1개월차 배수(온보딩 — 첫 관문에 1.15 벌점 안 걸림)
const GATE_MULT_MAX := 1.15   # 정착 배수(후반 압박 유지)
const GATE_MULT_RAMP := 3     # 이 개월(0-base) 동안 MIN→MAX 선형 상승, 이후 MAX 고정
# 1~8개월차 주차별 누적 관문 [주1,주2,주3,주4]; 주4=월 목표. m1~m2 실측, m3~m8 추정. 9개월차+는 공식.
const ONBOARD_GATES := [
	[87, 212, 300, 440],
	[220, 480, 880, 1600],
	[1000, 2000, 3600, 6000],
	[1890, 3710, 7250, 14500],
	[3380, 6660, 13000, 26000],
	[5460, 10750, 21000, 42000],
	[7930, 15620, 30500, 61000],
	[11050, 21760, 42500, 85000],
]
# 보스전(4주차) 편중 — 1~3주 관문을 이 배수로 낮추고, 줄인 몫은 4주차 스파이크로 흡수(월 총량 보존).
const PRE_BOSS_MULT := 0.92
const RENT_GROWTH := 1.25   # 기본 복리 — 초반 월세 상향(2개월차 여유 축소). 강빌드 12개월 지점은 ACCEL이 결정
const RENT_ACCEL := 2.50    # 후반 가속 항 복리(볼록) — 시뮬: 강빌드 ~12개월 겨우 통과 후 탈락
const RENT_ACCEL_W := 0.02  # 가속 항 가중(초반 미미 → 후반 지배)
const WAVE_STEP := 1        # 정의 구간 이후 손님 수 월당 증가
const WAVE_CAP := 18        # 손님 수(per_wave) 상한 — 처리량/화면 한계
# 주 관문 = 월 목표의 누적 분배(볼록: 첫주 최소→월말 최대). 7개월차+(ONBOARD_GATES 이후 공식 구간)에만 쓰임.
# 온보딩(1~6개월차)은 ONBOARD_GATES에서 주차 관문을 직접 지정한다.
const WEEK_TARGET_WEIGHTS := [1, 2, 3, 4]

# waves(주차별 손님 수)만 정의 — 월세는 공식(_monthly_rent). 정의 이후는 마지막 달 waves 연장.
const MONTHS := [
	{"waves": [11, 12, 13, 14]},  # 1개월차
	{"waves": [13, 14, 15, 15]},  # 2개월차
	{"waves": [15, 16, 16, 17]},  # 3개월차
]

## 최종 주차(승리 판정용) — 이 주(3개월차 4주차=12주) 통과 시 session의 day>=count()로 런 승리.
static func count() -> int:
	return FINAL_MONTH * WEEKS_PER_MONTH

static func months() -> int:
	return MONTHS.size()

# 후반 난이도 램프(인내심↓·도착밀도↑)의 기준 월 — session.start_day가 매일 갱신.
static var cur_month := 1

## 월별 난이도 계수 — 1개월차 0 → FINAL_MONTH(3)개월차부터 1로 포화(그 사이 선형).
static func difficulty_t() -> float:
	return clampf(float(cur_month - 1) / float(FINAL_MONTH - 1), 0.0, 1.0)

## 손님 인내심 배수 — 후반일수록 짧게(3개월차 = 1 − PATIENCE_MONTH_CUT). Stats에서 곱함.
static func patience_scale() -> float:
	return 1.0 - Config.PATIENCE_MONTH_CUT * difficulty_t()

## 손님 도착 간격 배수 — 후반일수록 촘촘(3개월차 = 1 − SPAWN_GAP_MONTH_CUT). session 스폰에서 곱함.
static func spawn_gap_scale() -> float:
	return 1.0 - Config.SPAWN_GAP_MONTH_CUT * difficulty_t()

## 이 달(0-base)의 관문 난이도 배수 — 온보딩 보호를 위해 MIN→MAX로 선형 램프 후 고정.
static func _gate_mult(mi: int) -> float:
	if mi >= GATE_MULT_RAMP:
		return GATE_MULT_MAX
	return GATE_MULT_MIN + (GATE_MULT_MAX - GATE_MULT_MIN) * float(mi) / float(GATE_MULT_RAMP)

## 이 달(0-base)의 월세 — 볼록 곡선(완만 기본 복리 + 후반 가속). 무한 공식. SIM_GROWTH로 기본 복리 스윕.
static func _monthly_rent(mi: int) -> int:
	if mi < ONBOARD_GATES.size():
		return int((ONBOARD_GATES[mi] as Array)[WEEKS_PER_MONTH - 1])   # 온보딩 월 목표 = 그 달 4주차 관문
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

## 이번 주(0-base wi) 누적 관문 — 월 목표 mr을 WEEK_TARGET_WEIGHTS로 볼록 분배. 월말은 정확히 mr.
static func _week_gate(mr: int, wi: int) -> int:
	if wi >= WEEKS_PER_MONTH - 1:
		return mr
	var total := 0
	for x in WEEK_TARGET_WEIGHTS:
		total += int(x)
	var cum := 0
	for i in wi + 1:
		cum += int(WEEK_TARGET_WEIGHTS[i])
	return int(round(float(mr) * float(cum) / float(total)))


## 주차(1-base) 정보. per_wave·month·week_in_month·is_month_end·monthly_rent·target·rent(주 관문)·weeks_left.
static func get_week(week: int) -> Dictionary:
	var w := maxi(0, week - 1)
	var mi := w / WEEKS_PER_MONTH
	var wi := w % WEEKS_PER_MONTH
	var is_end := wi == WEEKS_PER_MONTH - 1
	var pw := _waves(mi, wi)
	var mr := _monthly_rent(mi)
	var gate := int((ONBOARD_GATES[mi] as Array)[wi]) if mi < ONBOARD_GATES.size() else _week_gate(mr, wi)
	if not is_end:
		gate = int(round(float(gate) * PRE_BOSS_MULT))
	var gm := _gate_mult(mi)                    # 전역 난이도(월별 램프)
	mr = int(round(float(mr) * gm))
	gate = int(round(float(gate) * gm))
	if OS.has_environment("SIM_LOAD"):
		var mult := float(OS.get_environment("SIM_LOAD"))
		if mult > 1.0:
			pw = int(round(float(pw) * mult))
	if OS.has_environment("SIM_RENT"):
		var rmult := float(OS.get_environment("SIM_RENT"))
		mr = int(round(float(mr) * rmult))
		gate = int(round(float(gate) * rmult))
	return {
		"per_wave": pw,
		"month": mi + 1,
		"week_in_month": wi + 1,
		"is_month_end": is_end,
		"monthly_rent": mr,
		"target": gate,
		"rent": gate,
		"weeks_left": (WEEKS_PER_MONTH - 1) - wi,
	}

## 하위호환 별칭 — 기존 호출부(session·sim)가 get_day(day)로 rent/per_wave를 읽음.
static func get_day(day: int) -> Dictionary:
	return get_week(day)
