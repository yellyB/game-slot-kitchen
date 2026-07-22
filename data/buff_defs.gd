class_name BuffDefs
extends RefCounted

const ALL := {
	"cook":      {"name": "조리 속도", "icon": "⚡", "stat": "cook_mult", "value": 0.85, "label": "-15%"},
	"price":     {"name": "판매가",   "icon": "💰", "stat": "price_mult", "value": 1.25, "label": "+25%"},
	"patience":  {"name": "인내심",   "icon": "⏳", "stat": "patience_mult", "value": 1.25, "label": "+25%"},
	"warehouse": {"name": "창고 속도", "icon": "🏃", "stat": "warehouse_mult", "value": 0.7, "label": "-30%"},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func random_pack(n := 3) -> Array:
	var pool := ALL.keys()
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))
