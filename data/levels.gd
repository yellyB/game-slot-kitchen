class_name Levels
extends RefCounted

const DAYS := [
	{"rent": 5,  "per_wave": 2},
	{"rent": 12, "per_wave": 3},
	{"rent": 22, "per_wave": 4},
	{"rent": 35, "per_wave": 5},
	{"rent": 50, "per_wave": 6},
]

static func count() -> int:
	return DAYS.size()

static func get_day(day: int) -> Dictionary:
	return DAYS[clampi(day - 1, 0, DAYS.size() - 1)]
