class_name BuffDefs
extends RefCounted

const ALL := {
	"cook":      {"name": "조리 속도", "icon": "⚡", "stat": "cook_mult", "value": 0.85, "label": "조리 -15%"},
	"price":     {"name": "판매가",   "icon": "💰", "stat": "price_mult", "value": 1.25, "label": "판매가 +25%"},
	"patience":  {"name": "인내심",   "icon": "⏳", "stat": "patience_mult", "value": 1.25, "label": "인내심 +25%"},
	"warehouse": {"name": "창고 속도", "icon": "🏃", "stat": "warehouse_mult", "value": 0.7, "label": "창고 -30%"},
	"drink_price":  {"name": "커피 매출", "icon": "☕", "stat": "price_mult_drink", "value": 1.6, "label": "커피 +60%"},
	"drink_demand": {"name": "커피 인기", "icon": "📣", "stat": "demand_drink", "value": 3.0, "label": "커피 손님↑"},
	"donut_price":  {"name": "도넛 매출", "icon": "🍩", "stat": "price_mult_donut", "value": 1.4, "label": "도넛 +40%"},
	"donut_demand": {"name": "도넛 인기", "icon": "🎯", "stat": "demand_donut", "value": 3.0, "label": "도넛 손님↑"},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func random_pack(n := 3) -> Array:
	var pool := ALL.keys()
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))
