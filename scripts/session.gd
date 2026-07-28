class_name Session
extends Node
## 하루(세션) 루프 — 영업시간 진행 + 웨이브 스폰 + 가게세/승패 판정 + 경제(돈).
## UI 반응(스폰·패널·보드 리셋)은 main이 신호를 받아 처리.

signal cash_changed(cash: int)
signal progress(t01: float)          # 영업시간 진행 0..1
signal spawn_requested                # 손님 하나 등장
signal day_started(day: int, rent: int)
signal day_ended(summary: Dictionary) # {day, revenue, rent, cash_after, passed, won}

var cash := 0
var day := 1
var rent := 0
var day_revenue := 0
var slots := Config.START_SLOTS  # 현재 슬롯 수(상점 확장으로 증가)

var _elapsed := 0.0
var _running := false
var _spawn_times: Array[float] = []
var _next_idx := 0


func start_run() -> void:
	cash = Config.START_MONEY
	day = 1
	slots = Config.START_SLOTS
	Buffs.clear()
	cash_changed.emit(cash)
	start_day()


## 상점: 슬롯 +1 구매. 성공 시 true(다음 세션부터 반영).
func buy_slot() -> bool:
	var price := Config.shop_price(Config.SLOT_PRICE, day)
	if cash < price or slots >= Config.MAX_SLOTS:
		return false
	cash -= price
	slots += 1
	cash_changed.emit(cash)
	return true


## 상점: 버프 팩 구매 → 3개 랜덤 반환(택1은 호출 측). 못 사면 [].
func buy_buff_pack() -> Array:
	var price := Config.shop_price(Config.BUFF_PACK_PRICE, day)
	if cash < price or Buffs.is_full():
		return []
	cash -= price
	cash_changed.emit(cash)
	return BuffDefs.random_pack(3)


func advance_day() -> void:
	day += 1
	start_day()


func start_day() -> void:
	rent = int(Levels.get_day(day).get("rent", 0))
	day_revenue = 0
	_elapsed = 0.0
	_next_idx = 0
	_build_schedule()
	_running = true
	day_started.emit(day, rent)
	progress.emit(0.0)


func is_running() -> bool:
	return _running


# ── 디버그 ────────────────────────────────────────────────
func add_cash(amount: int) -> void:  # 매출 집계 없이 소지금만
	cash += amount
	cash_changed.emit(cash)


func debug_end_soon(remaining := 1.0) -> void:  # 오늘 remaining초 남게
	if not _running:
		return
	_elapsed = maxf(_elapsed, Config.DAY_LENGTH - remaining)
	progress.emit(clampf(_elapsed / Config.DAY_LENGTH, 0.0, 1.0))


## 영업시간 소모(창고 트립 비용 등). 시간 넘기면 마감.
func spend_time(seconds: float) -> void:
	if not _running:
		return
	_elapsed += seconds
	progress.emit(clampf(_elapsed / Config.DAY_LENGTH, 0.0, 1.0))
	if _elapsed >= Config.DAY_LENGTH:
		_end_day()


## 서빙 매출.
func earn(amount: int) -> void:
	cash += amount
	day_revenue += amount
	cash_changed.emit(cash)


func _process(delta: float) -> void:
	tick(delta)


## 하루 진행 1스텝. 실게임은 _process(delta)로, 시뮬은 원하는 dt로 수동 호출.
func tick(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	progress.emit(clampf(_elapsed / Config.DAY_LENGTH, 0.0, 1.0))
	while _next_idx < _spawn_times.size() and _spawn_times[_next_idx] <= _elapsed:
		spawn_requested.emit()
		_next_idx += 1
	if _elapsed >= Config.DAY_LENGTH:
		_end_day()


func _end_day() -> void:
	_running = false
	var passed := cash >= rent
	var summary := {
		"day": day,
		"revenue": day_revenue,
		"rent": rent,
		"passed": passed,
		"won": false,
	}
	if passed:
		cash -= rent
		cash_changed.emit(cash)
		summary["won"] = day >= Levels.count()
	summary["cash_after"] = cash
	day_ended.emit(summary)


## 웨이브별로 손님 등장 시각을 미리 계산(몰림). 웨이브 3 고정, 웨이브당 손님은 레벨별.
func _build_schedule() -> void:
	_spawn_times.clear()
	var per_wave := int(Levels.get_day(day).get("per_wave", 3))
	var half := (per_wave - 1) * 0.5
	for w in Config.WAVES:
		var center: float = Config.DAY_LENGTH * (w + 0.5) / Config.WAVES
		for k in per_wave:
			var t: float = center + (k - half) * Config.WAVE_SPACING
			_spawn_times.append(clampf(t, 1.0, Config.DAY_LENGTH - 2.0))
	_spawn_times.sort()
