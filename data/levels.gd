class_name Levels
extends RefCounted

const WEEKS_PER_MONTH := 4
const RENT_BASE := 4000
const GATE_MULT_MIN := 1.0
const GATE_MULT_MAX := 1.15
const GATE_MULT_RAMP := 3
const ONBOARD_GATES := [
	[87, 212, 300, 440],
	[220, 480, 880, 1600],
	[910, 1790, 3500, 7000],
	[1890, 3710, 7250, 14500],
	[3380, 6660, 13000, 26000],
	[5460, 10750, 21000, 42000],
	[7930, 15620, 30500, 61000],
	[11050, 21760, 42500, 85000],
]
const PRE_BOSS_MULT := 0.92
const RENT_GROWTH := 1.25
const RENT_ACCEL := 2.50
const RENT_ACCEL_W := 0.02
const WAVE_STEP := 1
const WAVE_CAP := 18
const WEEK_TARGET_WEIGHTS := [1, 2, 3, 4]

const MONTHS := [
	{"waves": [11, 12, 13, 14]},
	{"waves": [13, 14, 15, 15]},
	{"waves": [15, 16, 16, 17]},
]

static func count() -> int:
	return 1_000_000

static func months() -> int:
	return MONTHS.size()

static func _gate_mult(mi: int) -> float:
	if mi >= GATE_MULT_RAMP:
		return GATE_MULT_MAX
	return GATE_MULT_MIN + (GATE_MULT_MAX - GATE_MULT_MIN) * float(mi) / float(GATE_MULT_RAMP)

static func _monthly_rent(mi: int) -> int:
	if mi < ONBOARD_GATES.size():
		return int((ONBOARD_GATES[mi] as Array)[WEEKS_PER_MONTH - 1])
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

static func _week_gate(mr: int, wi: int) -> int:
	if wi >= WEEKS_PER_MONTH - 1:
		return mr
	var total := 0
	for x in WEEK_TARGET_WEIGHTS:
		total += int(x)
	var cum := 0
	for i in wi + 1:
		cum += int(WEEK_TARGET_WEIGHTS[i])
	return int(round(float(mr) * float(cum) / float(total)))


static func get_week(week: int) -> Dictionary:
	var w := maxi(0, week - 1)
	var mi := w / WEEKS_PER_MONTH
	var wi := w % WEEKS_PER_MONTH
	var is_end := wi == WEEKS_PER_MONTH - 1
	var pw := _waves(mi, wi)
	var mr := _monthly_rent(mi)
	var gate := int((ONBOARD_GATES[mi] as Array)[wi]) if mi < ONBOARD_GATES.size() else _week_gate(mr, wi)
	if not is_end:
		gate = int(round(float(gate) * PRE_BOSS_MULT))
	var gm := _gate_mult(mi)
	mr = int(round(float(mr) * gm))
	gate = int(round(float(gate) * gm))
	if OS.has_environment("SIM_LOAD"):
		var mult := float(OS.get_environment("SIM_LOAD"))
		if mult > 1.0:
			pw = int(round(float(pw) * mult))
	if OS.has_environment("SIM_RENT"):
		var rmult := float(OS.get_environment("SIM_RENT"))
		mr = int(round(float(mr) * rmult))
		gate = int(round(float(gate) * rmult))
	return {
		"per_wave": pw,
		"month": mi + 1,
		"week_in_month": wi + 1,
		"is_month_end": is_end,
		"monthly_rent": mr,
		"target": gate,
		"rent": gate,
		"weeks_left": (WEEKS_PER_MONTH - 1) - wi,
	}

static func get_day(day: int) -> Dictionary:
	return get_week(day)
