class_name Session
extends Node
## 하루(세션) 루프 — 영업시간 진행 + 웨이브 스폰 + 가게세/승패 판정 + 경제(돈).
## UI 반응(스폰·패널·보드 리셋)은 main이 신호를 받아 처리.

signal cash_changed(cash: int)
signal progress(t01: float)          # 영업시간 진행 0..1
signal spawn_requested                # 손님 하나 등장
signal day_started(day: int, rent: int)
signal day_closing(s: Session)        # 마감 정산 훅(가게세 차감 전) — 리스너가 earn/차감
signal day_ended(summary: Dictionary) # {day, revenue, rent, cash_after, passed, won}

var cash := 0
var day := 1
var rent := 0
var day_revenue := 0
var month_score := 0   # 이달 누적 매출(점수) — 월초 리셋, 지출과 무관
var run_score := 0     # 런 누적 매출(⭐점수) — 승리 요약용, start_run에서만 리셋
var run_earned := 0    # 런 누적 획득 코인(🪙, 지출 차감 전 gross) — 승리 요약용
var slots := Config.START_SLOTS  # 현재 슬롯 수(상점 확장 + 구조 버프)

var _elapsed := 0.0
var _running := false
var _paused := false   # 시트(창고·조리) 열림 동안 시계 정지
var _day_length := Config.DAY_LENGTH
var _rent_skip_used := false
var _rent_paid := false   # 오늘 가게세 이미 차감했는지(멱등 — 정산 연출/버튼 이중호출 방지)
var _spawn_times: Array[float] = []
var _next_idx := 0


func start_run() -> void:
	cash = Config.START_MONEY
	day = 1
	slots = Config.START_SLOTS
	run_score = 0
	run_earned = 0
	_rent_skip_used = false
	_paused = false
	Buffs.clear()
	cash_changed.emit(cash)
	start_day()


## 상점: 슬롯 +1 구매. 성공 시 true(다음 세션부터 반영).
func buy_slot() -> bool:
	var price := Config.slot_price(day, slots - Config.START_SLOTS)
	if cash < price or slots >= Config.MAX_SLOTS:
		return false
	cash -= price
	slots += 1
	cash_changed.emit(cash)
	return true


## 상점: 버프 팩 구매 → 3개 랜덤 반환(택1은 호출 측). 못 사면 [].
func buy_buff_pack() -> Array:
	var price := Config.BUFF_PACK_PRICE
	if cash < price:   # 가득 차도 뽑기는 허용 — 선택 시 자리 확보(판매)를 요구
		return []
	cash -= price
	cash_changed.emit(cash)
	return BuffDefs.random_pack(3)


func advance_day() -> void:
	day += 1
	start_day()


func start_day() -> void:
	var wk := Levels.get_day(day)
	Boss.begin_day(wk)   # 월말(4주차)=보스전 제약 자동 발동(디버그 예약 우선) — day_length 계산 전에
	# 슬롯 = 기본(상점확장 포함) + 구조 버프(12)
	rent = int(round(Buffs.mod("rent_mult", float(wk.get("rent", 0)))))
	_rent_paid = false
	day_revenue = 0
	if int(wk.get("week_in_month", 1)) == 1:
		month_score = 0
	_elapsed = 0.0
	_next_idx = 0
	_day_length = Stats.day_length()
	# 개장 이자(62)
	var itr := Buffs.day_start_bonus(cash)
	if itr != 0:
		cash += itr
		run_earned += maxi(0, itr)
		cash_changed.emit(cash)
	_build_schedule()
	_running = true
	_paused = false   # 새 하루는 항상 시계 진행 상태로 시작(시트 열린 채 마감돼도 다음날 안 멈춤)
	day_started.emit(day, rent)
	progress.emit(0.0)


func effective_slots() -> int:
	return slots + Buffs.slot_bonus()


## 오늘 경과 시간(초) = 게임 클록. 주문/완성품 나이(order_age·dish_age) 스탬프용.
func now() -> float:
	return _elapsed


## 남은 영업시간(초). 막판 카운트다운용.
func time_left() -> float:
	return maxf(0.0, _day_length - _elapsed)


func is_running() -> bool:
	return _running


# ── 디버그 ────────────────────────────────────────────────
func add_cash(amount: int) -> void:  # 매출 집계 없이 소지금만
	cash += amount
	cash_changed.emit(cash)


func debug_end_soon(remaining := 1.0) -> void:  # 오늘 remaining초 남게
	if not _running:
		return
	_elapsed = maxf(_elapsed, _day_length - remaining)
	progress.emit(clampf(_elapsed / _day_length, 0.0, 1.0))


## 영업시간 소모(창고 트립 비용 등). 시간 넘기면 마감.
func spend_time(seconds: float) -> void:
	if not _running:
		return
	_elapsed += seconds
	progress.emit(clampf(_elapsed / _day_length, 0.0, 1.0))
	if _elapsed >= _day_length:
		_end_day()


## 서빙 매출.
## as_score=true=점수 채널(cash X), false=돈 채널(cash).
func earn(amount: int, as_score := true) -> void:
	if as_score:
		day_revenue += amount
		month_score += amount
		run_score += amount
	else:
		cash += amount
		run_earned += maxi(0, amount)
	cash_changed.emit(cash)


## 가게세 차감 — main이 정산 연출에서 가게세 라인이 뜨는 타이밍에 호출. 하루 1회(멱등).
## 미납 통과(rent_skip)·잔액 부족이면 차감하지 않음.
func pay_rent() -> void:
	if _rent_paid or rent <= 0 or cash < rent:
		return
	if month_score >= rent:   # 점수로 통과 — 미차감
		return
	_rent_paid = true
	cash -= rent
	cash_changed.emit(cash)


func _process(delta: float) -> void:
	tick(delta)


## 하루 진행 1스텝. 실게임은 _process(delta)로, 시뮬은 원하는 dt로 수동 호출.
## 시계 정지/재개 — 시트 열림 동안 하루 진행을 멈춤(트립 비용은 별도로 spend_time에서 유지).
func set_paused(p: bool) -> void:
	_paused = p


func tick(delta: float) -> void:
	if not _running or _paused:
		return
	_elapsed += delta
	progress.emit(clampf(_elapsed / _day_length, 0.0, 1.0))
	while _next_idx < _spawn_times.size() and _spawn_times[_next_idx] <= _elapsed:
		spawn_requested.emit()
		_next_idx += 1
	if _elapsed >= _day_length:
		_end_day()


func _end_day() -> void:
	_running = false
	day_closing.emit(self)   # 정산 훅(리스너가 earn/차감) — 가게세 차감 전
	var passed_by_score := rent > 0 and month_score >= rent
	var passed := passed_by_score or cash >= rent
	if not passed and Buffs.has_effect("rent_skip") and not _rent_skip_used:
		passed = true            # 가게세 통과(9) — 이번 하루는 미납 통과
		_rent_skip_used = true
		Buffs.discard("rent_skip")
	var summary := {
		"day": day,
		"revenue": day_revenue,
		"rent": rent,
		"passed": passed,
		"passed_by_score": passed_by_score,
		"month_score": month_score,
		"run_score": run_score,
		"run_earned": run_earned,
		"won": false,
		"skipped": _rent_skip_used and cash < rent,
		"cash": cash,   # 가게세 차감 전 보유금(정산 팝업 첫 줄)
	}
	# 가게세 차감은 여기서 하지 않고 main이 정산 연출(가게세 라인 등장 타이밍)에서 pay_rent()로 수행.
	# 실패(미납·잔액부족)면 차감하지 않음.
	if passed:
		summary["won"] = day >= Levels.count()
	summary["cash_after"] = cash if passed_by_score else ((cash - rent) if (passed and cash >= rent) else cash)
	day_ended.emit(summary)


## 손님 등장 시각을 하루에 균등 분포(우르르 X). 첫 손님 일찍, 마감 전까지 골고루.
## 총 손님 = per_wave × WAVES × 보스 영업배수 — 단축 영업이면 영업시간과 함께 손님 수도 그만큼 감소(밀도 유지).
func _build_schedule() -> void:
	_spawn_times.clear()
	var total := int(round(float(int(Levels.get_day(day).get("per_wave", 3)) * Config.WAVES) * Boss.day_length_mult()))
	if total <= 0:
		return
	var first := Config.SPAWN_FIRST
	var last := _day_length - Config.SPAWN_LAST_MARGIN
	var span := maxf(1.0, last - first)
	var denom := float(maxi(1, total - 1))   # 첫 손님=first, 마지막=last 포함 균등
	for i in total:
		var t := first + span * float(i) / denom
		_spawn_times.append(clampf(t, 1.0, _day_length - 2.0))
	_spawn_times.sort()
