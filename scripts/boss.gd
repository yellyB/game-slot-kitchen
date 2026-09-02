class_name Boss
extends RefCounted

const POOL := [
	{"type": "small_kitchen", "icon": "🔒", "value": 3},
	{"type": "time_short",    "icon": "⏱️", "value": 0.6},
	{"type": "pricey_trip",   "icon": "🥾", "value": 2.0},
	{"type": "slow_cook",     "icon": "🐢", "value": 1.4},
	{"type": "impatient",     "icon": "🏃", "value": 0.6},
]

static var _pending: Dictionary = {}
static var active: Dictionary = {}

static func queue_random() -> Dictionary:
	_pending = POOL[randi() % POOL.size()].duplicate()
	return _pending

static func has_pending() -> bool:
	return not _pending.is_empty()

static func for_week(week_info: Dictionary) -> Dictionary:
	if not bool(week_info.get("is_month_end", false)):
		return {}
	var month := int(week_info.get("month", 1))
	return POOL[(month - 1) % POOL.size()].duplicate()

static func begin_day(week_info := {}) -> void:
	if OS.has_environment("SIM_BOSS"):
		var bt := OS.get_environment("SIM_BOSS")
		active = {"type": bt}
		for p in POOL:
			if p["type"] == bt:
				active = p.duplicate()
		return
	if not _pending.is_empty():
		active = _pending
		_pending = {}
	else:
		active = for_week(week_info)

static func reset() -> void:
	active = {}
	_pending = {}

static func is_active() -> bool:
	return not active.is_empty()

static func kind() -> String:
	return str(active.get("type", ""))

static func day_length_mult() -> float:
	if kind() == "time_short":
		return float(active.get("value", 1.0))
	return 1.0

static func warehouse_mult() -> float:
	if kind() == "pricey_trip":
		return float(active.get("value", 1.0))
	return 1.0

static func locked_slots() -> int:
	if kind() == "small_kitchen":
		return int(active.get("value", 0))
	return 0

static func cook_mult() -> float:
	if kind() == "slow_cook":
		return float(active.get("value", 1.0))
	return 1.0

static func patience_mult() -> float:
	if kind() == "impatient":
		return float(active.get("value", 1.0))
	return 1.0

static func label() -> String:
	return Loc.t("boss." + kind())

static func icon() -> String:
	return str(active.get("icon", "📜"))
