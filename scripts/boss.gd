class_name Boss
extends RefCounted

const POOL := [
	{"type": "small_kitchen", "icon": "🔒", "value": 3},
	{"type": "time_short",    "icon": "⏱️", "value": 0.6},
	{"type": "pricey_trip",   "icon": "🥾", "value": 2.0},
]

static var _pending: Dictionary = {}
static var active: Dictionary = {}

static func queue_random() -> Dictionary:
	_pending = POOL[randi() % POOL.size()].duplicate()
	return _pending

static func has_pending() -> bool:
	return not _pending.is_empty()

static func begin_day() -> void:
	active = _pending
	_pending = {}

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

static func label() -> String:
	return Loc.t("boss." + kind())

static func icon() -> String:
	return str(active.get("icon", "📜"))
