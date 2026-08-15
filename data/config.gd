class_name Config
extends RefCounted

const BOARD_COLS := 3
const START_SLOTS := 9
const TOOL_COUNT := 2
const MAX_SLOTS := 21

const MAX_QUEUE := 4
const MAX_ORDERS := 6
const SPAWN_INTERVAL := 4.0
const SPAWN_FIRST := 1.0
const SPAWN_LAST_MARGIN := 8.0

const SPAWN_WEIGHTS := [30, 22, 18, 15, 10, 5]

const PATIENCE_ORDER := 25.0
const PATIENCE_DISH := 35.0
const PATIENCE_LOW_FRAC := 0.3

const START_MONEY := 0
const SLOT_PRICE := 500
const BUFF_PACK_PRICE := 200
const SHOP_PRICE_GROWTH := 1.65
const SLOT_PRICE_STEP := 2.0
const MAX_BUFFS := 5
const MONEY_ABBR_AT := 100000

const DAY_LENGTH := 90.0
const DAY_INTRO_DELAY := 0.5
const DAY_END_PAUSE := 1.0
const HOURS_WARN_FRAC := 0.8
const WAVES := 3
const WAVE_SPACING := 0.7
const WAREHOUSE_EXIT_COST := 1.5


static func shop_price(base: int, day: int) -> int:
	return int(ceil(base * pow(SHOP_PRICE_GROWTH, day - 1)))

static func slot_price(_day: int, bought: int) -> int:
	return int(ceil(SLOT_PRICE * pow(SLOT_PRICE_STEP, max(0, bought))))
