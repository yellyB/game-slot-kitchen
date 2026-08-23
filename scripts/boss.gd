class_name Boss
extends RefCounted
## 보스전(계약 갱신 심사) — 현재 게임 흐름과 격리. 디버그로 "다음날 보스" 예약 → 그날만 제약 1개.
## active가 비어 있으면 완전히 일반날(기존 동작 100% 유지). 세팅은 디버그에서만.
## 제약은 전부 기존 노브 재활용(영업시간·창고비용·슬롯 잠금)이라 상시 코드 경로에 무해하게 얹힘.

# 제약 풀(우선 3종). value = 제약별 파라미터.
const POOL := [
	{"type": "small_kitchen", "icon": "🔒", "value": 3},    # 슬롯 3칸 잠금(작업공간 압박)
	{"type": "time_short",    "icon": "⏱️", "value": 0.6},   # 영업시간 ×0.6(런치 러시)
	{"type": "pricey_trip",   "icon": "🥾", "value": 2.0},   # 창고 트립 비용 ×2(비싼 발품)
]

static var _pending: Dictionary = {}   # 다음날 예약된 제약
static var active: Dictionary = {}      # 이번 날 적용 중인 제약(빈=일반날)

## 디버그: 다음날 보스 예약(랜덤 제약 1개).
static func queue_random() -> Dictionary:
	_pending = POOL[randi() % POOL.size()].duplicate()
	return _pending

static func has_pending() -> bool:
	return not _pending.is_empty()

## 하루 시작 시 1회 호출 — 예약분을 이번 날 active로 승격(1일 한정). 예약 없으면 일반날.
static func begin_day() -> void:
	active = _pending
	_pending = {}

## 새 런/타이틀 복귀 시 초기화 — 예약이 다음 판으로 새는 것 방지.
static func reset() -> void:
	active = {}
	_pending = {}

static func is_active() -> bool:
	return not active.is_empty()

static func kind() -> String:
	return str(active.get("type", ""))

## 영업시간 배수(런치 러시). 일반날/미해당 = 1.0.
static func day_length_mult() -> float:
	if kind() == "time_short":
		return float(active.get("value", 1.0))
	return 1.0

## 창고 트립 비용 배수(비싼 발품). 일반날/미해당 = 1.0.
static func warehouse_mult() -> float:
	if kind() == "pricey_trip":
		return float(active.get("value", 1.0))
	return 1.0

## 잠글 슬롯 수(좁은 주방). 일반날/미해당 = 0.
static func locked_slots() -> int:
	if kind() == "small_kitchen":
		return int(active.get("value", 0))
	return 0

## 현재 제약의 현지화 이름.
static func label() -> String:
	return Loc.t("boss." + kind())

static func icon() -> String:
	return str(active.get("icon", "📜"))
