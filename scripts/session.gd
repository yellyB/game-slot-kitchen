class_name Session
extends Node

signal cash_changed(cash: int)
signal progress(t01: float)
signal spawn_requested
signal day_started(day: int, rent: int)
signal day_closing(s: Session)
signal day_ended(summary: Dictionary)

var cash := 0
var day := 1
var rent := 0
var day_revenue := 0
var month_score := 0
var run_score := 0
var run_earned := 0
var slots := Config.START_SLOTS

var _elapsed := 0.0
var _running := false
var _paused := false
var _day_length := Config.DAY_LENGTH
var _rent_skip_used := false
var _rent_paid := false
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


func buy_slot() -> bool:
	var price := Config.slot_price(day, slots - Config.START_SLOTS)
	if cash < price or slots >= Config.MAX_SLOTS:
		return false
	cash -= price
	slots += 1
	cash_changed.emit(cash)
	return true


func buy_buff_pack() -> Array:
	var price := Config.BUFF_PACK_PRICE
	if cash < price:
		return []
	cash -= price
	cash_changed.emit(cash)
	return BuffDefs.random_pack(3)


func advance_day() -> void:
	day += 1
	start_day()


func start_day() -> void:
	var wk := Levels.get_day(day)
	Boss.begin_day(wk)
	rent = int(round(Buffs.mod("rent_mult", float(wk.get("rent", 0)))))
	_rent_paid = false
	day_revenue = 0
	if int(wk.get("week_in_month", 1)) == 1:
		month_score = 0
	_elapsed = 0.0
	_next_idx = 0
	_day_length = Stats.day_length()
	var itr := Buffs.day_start_bonus(cash)
	if itr != 0:
		cash += itr
		run_earned += maxi(0, itr)
		cash_changed.emit(cash)
	_build_schedule()
	_running = true
	_paused = false
	day_started.emit(day, rent)
	progress.emit(0.0)


func effective_slots() -> int:
	return slots + Buffs.slot_bonus()


func now() -> float:
	return _elapsed


func time_left() -> float:
	return maxf(0.0, _day_length - _elapsed)


func is_running() -> bool:
	return _running


func add_cash(amount: int) -> void:
	cash += amount
	cash_changed.emit(cash)


func debug_end_soon(remaining := 1.0) -> void:
	if not _running:
		return
	_elapsed = maxf(_elapsed, _day_length - remaining)
	progress.emit(clampf(_elapsed / _day_length, 0.0, 1.0))


func spend_time(seconds: float) -> void:
	if not _running:
		return
	_elapsed += seconds
	progress.emit(clampf(_elapsed / _day_length, 0.0, 1.0))
	if _elapsed >= _day_length:
		_end_day()


func earn(amount: int, as_score := true) -> void:
	if as_score:
		day_revenue += amount
		month_score += amount
		run_score += amount
	else:
		cash += amount
		run_earned += maxi(0, amount)
	cash_changed.emit(cash)


func pay_rent() -> void:
	if _rent_paid or rent <= 0 or cash < rent:
		return
	if month_score >= rent:
		return
	_rent_paid = true
	cash -= rent
	cash_changed.emit(cash)


func _process(delta: float) -> void:
	tick(delta)


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
	day_closing.emit(self)
	var passed_by_score := rent > 0 and month_score >= rent
	var passed := passed_by_score or cash >= rent
	if not passed and Buffs.has_effect("rent_skip") and not _rent_skip_used:
		passed = true
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
		"cash": cash,
	}
	if passed:
		summary["won"] = day >= Levels.count()
	summary["cash_after"] = cash if passed_by_score else ((cash - rent) if (passed and cash >= rent) else cash)
	day_ended.emit(summary)


func _build_schedule() -> void:
	_spawn_times.clear()
	var total := int(round(float(int(Levels.get_day(day).get("per_wave", 3)) * Config.WAVES) * Boss.day_length_mult()))
	if total <= 0:
		return
	var first := Config.SPAWN_FIRST
	var last := _day_length - Config.SPAWN_LAST_MARGIN
	var span := maxf(1.0, last - first)
	var denom := float(maxi(1, total - 1))
	for i in total:
		var t := first + span * float(i) / denom
		_spawn_times.append(clampf(t, 1.0, _day_length - 2.0))
	_spawn_times.sort()
