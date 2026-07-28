class_name Recipes
extends RefCounted

const ALL := {
	"coffee":  {"name": "커피",     "icon": "☕", "ingredients": ["bean", "water"], "cook_time": 3.0, "price": 100,  "tier": 1},
	"latte":   {"name": "라떼",     "icon": "🥛", "ingredients": ["bean", "milk"], "cook_time": 4.0, "price": 200,  "tier": 2},
	"glazed":  {"name": "글레이즈드", "icon": "🍩", "ingredients": ["flour", "egg", "sugar"], "cook_time": 5.0, "price": 600,  "tier": 3},
	"choco":   {"name": "초코도넛",  "icon": "🍪", "ingredients": ["flour", "egg", "chocolate"], "cook_time": 5.0, "price": 800,  "tier": 4},
	"tiramisu": {"name": "티라미수",  "icon": "🍮", "ingredients": ["bean", "cream", "sugar"], "cook_time": 6.0, "price": 1200, "tier": 5},
	"special": {"name": "초코케이크",  "icon": "🍰", "ingredients": ["flour", "cream", "sugar", "chocolate"], "cook_time": 7.0, "price": 2000, "tier": 6},
}

static func all_ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func random_id() -> String:
	var ids := ALL.keys()
	return ids[randi() % ids.size()]
