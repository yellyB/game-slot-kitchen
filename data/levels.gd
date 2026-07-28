class_name Levels
extends RefCounted

const DAYS := [
	{"rent": 500,  "per_wave": 2},
	{"rent": 1200, "per_wave": 3},
	{"rent": 2200, "per_wave": 4},
	{"rent": 3500, "per_wave": 5},
	{"rent": 5000, "per_wave": 6},
]

static func count() -> int:
	return DAYS.size()

static func get_day(day: int) -> Dictionary:
	return DAYS[clampi(day - 1, 0, DAYS.size() - 1)]
