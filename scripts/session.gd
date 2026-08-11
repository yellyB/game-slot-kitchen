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
var slots := Config.START_SLOTS

var _elapsed := 0.0
var _running := false
var _day_length := Config.DAY_LENGTH
var _rent_skip_used := false
var _spawn_times: Array[float] = []
var _next_idx := 0


func start_run() -> void:
	cash = Config.START_MONEY
	day = 1
	slots = Config.START_SLOTS
	_rent_skip_used = false
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
	rent = int(round(Buffs.mod("rent_mult", float(Levels.get_day(day).get("rent", 0)))))
	day_revenue = 0
	_elapsed = 0.0
	_next_idx = 0
	_day_length = Stats.day_length()
	var itr := Buffs.day_start_bonus(cash)
	if itr != 0:
		cash += itr
		cash_changed.emit(cash)
	_build_schedule()
	_running = true
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


func earn(amount: int) -> void:
	cash += amount
	day_revenue += amount
	cash_changed.emit(cash)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _running:
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
	var passed := cash >= rent
	if not passed and Buffs.has_effect("rent_skip") and not _rent_skip_used:
		passed = true
		_rent_skip_used = true
		Buffs.discard("rent_skip")
	var summary := {
		"day": day,
		"revenue": day_revenue,
		"rent": rent,
		"passed": passed,
		"won": false,
		"skipped": _rent_skip_used and cash < rent,
	}
	if passed and cash >= rent:
		cash -= rent
		cash_changed.emit(cash)
	if passed:
		summary["won"] = day >= Levels.count()
	summary["cash_after"] = cash
	day_ended.emit(summary)


func _build_schedule() -> void:
	_spawn_times.clear()
	var total := int(Levels.get_day(day).get("per_wave", 3)) * Config.WAVES
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
