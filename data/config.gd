class_name Config
extends RefCounted

const BOARD_COLS := 3
const START_SLOTS := 9
const TOOL_COUNT := 2
const MAX_SLOTS := 10

const MAX_QUEUE := 4
const SPAWN_INTERVAL := 4.0
const SPAWN_FIRST := 5.0
const SPAWN_LAST_MARGIN := 8.0

const SPAWN_WEIGHTS := [30, 22, 18, 15, 10, 5]

const PATIENCE_ORDER := 25.0
const PATIENCE_DISH := 35.0
const PATIENCE_LOW_FRAC := 0.3

const START_MONEY := 0
const SLOT_PRICE := 500
const BUFF_PACK_PRICE := 200
const SHOP_PRICE_GROWTH := 1.65
const MAX_BUFFS := 5

const DAY_LENGTH := 120.0
const WAVES := 3
const WAVE_SPACING := 0.7
const WAREHOUSE_EXIT_COST := 1.5


static func shop_price(base: int, day: int) -> int:
	return int(ceil(base * pow(SHOP_PRICE_GROWTH, day - 1)))
