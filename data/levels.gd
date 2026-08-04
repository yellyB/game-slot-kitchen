class_name Levels
extends RefCounted

const DAYS := [
	{"rent": 500,  "per_wave": 3},
	{"rent": 1200, "per_wave": 5},
	{"rent": 2200, "per_wave": 8},
	{"rent": 3500, "per_wave": 11},
	{"rent": 5000, "per_wave": 15},
]

static func count() -> int:
	return DAYS.size()

static func get_day(day: int) -> Dictionary:
	var d := (DAYS[clampi(day - 1, 0, DAYS.size() - 1)] as Dictionary).duplicate()
	if OS.has_environment("SIM_LOAD"):
		var mult := float(OS.get_environment("SIM_LOAD"))
		if mult > 1.0:
			d["per_wave"] = int(round(float(d.get("per_wave", 3)) * mult))
	return d
