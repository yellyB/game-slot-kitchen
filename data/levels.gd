class_name Levels
extends RefCounted

const DAYS := [
	{"rent": 1800,  "per_wave": 11},
	{"rent": 9000,  "per_wave": 12},
	{"rent": 14000, "per_wave": 13},
	{"rent": 28000, "per_wave": 13},
	{"rent": 50000, "per_wave": 14},
]

static func count() -> int:
	return DAYS.size()

static func get_day(day: int) -> Dictionary:
	var d := (DAYS[clampi(day - 1, 0, DAYS.size() - 1)] as Dictionary).duplicate()
	if OS.has_environment("SIM_LOAD"):
		var mult := float(OS.get_environment("SIM_LOAD"))
		if mult > 1.0:
			d["per_wave"] = int(round(float(d.get("per_wave", 3)) * mult))
	if OS.has_environment("SIM_RENT"):
		d["rent"] = int(round(float(d.get("rent", 0)) * float(OS.get_environment("SIM_RENT"))))
	return d
