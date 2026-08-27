class_name Levels
extends RefCounted

const WEEKS_PER_MONTH := 4
const RENT_BASE := 6300
const RENT_ONBOARD := [300, 1500, 5000, 12000, 20000, 32000]
const RENT_GROWTH := 1.25
const RENT_ACCEL := 2.50
const RENT_ACCEL_W := 0.02
const WAVE_STEP := 1
const WAVE_CAP := 18

const MONTHS := [
	{"waves": [11, 12, 13, 14]},
	{"waves": [13, 14, 15, 15]},
	{"waves": [15, 16, 16, 17]},
]

static func count() -> int:
	return 1_000_000

static func months() -> int:
	return MONTHS.size()

static func _monthly_rent(mi: int) -> int:
	if mi < RENT_ONBOARD.size():
		return int(RENT_ONBOARD[mi])
	var g := RENT_GROWTH
	if OS.has_environment("SIM_GROWTH"):
		g = float(OS.get_environment("SIM_GROWTH"))
	var a := RENT_ACCEL
	if OS.has_environment("SIM_ACCEL"):
		a = float(OS.get_environment("SIM_ACCEL"))
	return int(round(float(RENT_BASE) * (pow(g, mi) + RENT_ACCEL_W * (pow(a, mi) - 1.0))))

static func _waves(mi: int, wi: int) -> int:
	if mi < MONTHS.size():
		return int((MONTHS[mi]["waves"] as Array)[wi])
	var base := int((MONTHS[MONTHS.size() - 1]["waves"] as Array)[wi])
	return mini(base + WAVE_STEP * (mi - (MONTHS.size() - 1)), WAVE_CAP)

static func get_week(week: int) -> Dictionary:
	var w := maxi(0, week - 1)
	var mi := w / WEEKS_PER_MONTH
	var wi := w % WEEKS_PER_MONTH
	var is_end := wi == WEEKS_PER_MONTH - 1
	var pw := _waves(mi, wi)
	var mr := _monthly_rent(mi)
	if OS.has_environment("SIM_LOAD"):
		var mult := float(OS.get_environment("SIM_LOAD"))
		if mult > 1.0:
			pw = int(round(float(pw) * mult))
	if OS.has_environment("SIM_RENT"):
		mr = int(round(float(mr) * float(OS.get_environment("SIM_RENT"))))
	return {
		"per_wave": pw,
		"month": mi + 1,
		"week_in_month": wi + 1,
		"is_month_end": is_end,
		"monthly_rent": mr,
		"rent": mr if is_end else 0,
		"weeks_left": (WEEKS_PER_MONTH - 1) - wi,
	}

static func get_day(day: int) -> Dictionary:
	return get_week(day)
