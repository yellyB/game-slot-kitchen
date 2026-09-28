class_name Config
extends RefCounted

const BOARD_COLS := 3
const START_SLOTS := 9
const TOOL_COUNT := 2
const MAX_SLOTS := 21

const MAX_QUEUE := 4
const MAX_ORDERS := 6
const SPAWN_GAP_MIN := 1.0
const SPAWN_GAP_MAX := 2.5
const SPAWN_FIRST := 1.0
const SPAWN_LAST_MARGIN := 0.0
const SPAWN_GAP_MONTH_CUT := 0.45

const SPAWN_WEIGHTS := [30, 22, 18, 15, 10, 5]

const PATIENCE_ORDER := 25.0
const PATIENCE_DISH := 35.0
const PATIENCE_LOW_FRAC := 0.3
const PATIENCE_MONTH_CUT := 0.20

const START_MONEY := 0
const CASH_BONUS_REF := 25000
const SLOT_PRICES: Array[int] = [4, 4, 5, 5, 6, 7, 8, 10, 12, 15, 15, 15]
const BUFF_PACK_PRICE := 2
const BUFF_REROLL_BASE := 1
const MAX_BUFFS := 5
const MAX_LIVES := 3
const LIFE_LOSS_MISSES := 1
const WEEK_REWARD_POS: Array[int] = [5, 6, 7, 11]
const WEEK_REWARD_MONTH_INC := 1

static func week_reward(day: int, _served: int) -> int:
	var w := maxi(1, day)
	return WEEK_REWARD_POS[(w - 1) % 4] + ((w - 1) / 4) * WEEK_REWARD_MONTH_INC
const BUFF_SELL_RATIO := 0.2
const MONEY_ABBR_AT := 100000
const SCORE_GATE_FEE_DIV := 100
const SCORE_GATE_FEE_KEEP := 5

const DAY_LENGTH := 90.0
const DAY_INTRO_DELAY := 0.5
const DAY_END_PAUSE := 1.0
const HOURS_WARN_FRAC := 0.8
const WAVES := 3
const WAVE_SPACING := 0.7
const WAREHOUSE_EXIT_COST := 1.5

const SIM_HANDLE_ACCEPT := 0.5
const SIM_HANDLE_COOK := 0.4
const SIM_HANDLE_SERVE := 0.6
const SIM_HANDLE_PLACE := 0.35


static func slot_price(_day: int, bought: int) -> int:
	var b := clampi(bought, 0, SLOT_PRICES.size() - 1)
	return SLOT_PRICES[b]
