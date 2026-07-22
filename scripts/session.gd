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

var _elapsed := 0.0
var _running := false
var _spawn_times: Array[float] = []
var _next_idx := 0


func start_run() -> void:
	cash = Config.START_MONEY
	day = 1
	rent = Config.RENT_START
	cash_changed.emit(cash)
	start_day()


func advance_day() -> void:
	day += 1
	rent = int(round(rent * Config.RENT_GROWTH))
	start_day()


func start_day() -> void:
	day_revenue = 0
	_elapsed = 0.0
	_next_idx = 0
	_build_schedule()
	_running = true
	day_started.emit(day, rent)
	progress.emit(0.0)


## 서빙 매출.
func earn(amount: int) -> void:
	cash += amount
	day_revenue += amount
	cash_changed.emit(cash)


func _process(delta: float) -> void:
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
		summary["won"] = day >= Config.DAYS_TO_WIN
	summary["cash_after"] = cash
	day_ended.emit(summary)


## 웨이브별로 손님 등장 시각을 미리 계산(몰림).
func _build_schedule() -> void:
	_spawn_times.clear()
	var half := (Config.CUSTOMERS_PER_WAVE - 1) * 0.5
	for w in Config.WAVES:
		var center: float = Config.DAY_LENGTH * (w + 0.5) / Config.WAVES
		for k in Config.CUSTOMERS_PER_WAVE:
			var t: float = center + (k - half) * Config.WAVE_SPACING
			_spawn_times.append(clampf(t, 1.0, Config.DAY_LENGTH - 2.0))
	_spawn_times.sort()
