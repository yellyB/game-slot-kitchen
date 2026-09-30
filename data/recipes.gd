class_name Recipes
extends RefCounted

const BANK := {
	"donut": {
		"coffee":  {"name": "커피",     "icon": "☕", "ingredients": ["bean", "water"], "cook_time": 3.0, "price": 1,  "tier": 1},
		"latte":   {"name": "라떼",     "icon": "🥛", "ingredients": ["bean", "milk"], "cook_time": 4.0, "price": 2,  "tier": 2},
		"glazed":  {"name": "글레이즈드", "icon": "🍩", "ingredients": ["flour", "egg", "sugar"], "cook_time": 5.0, "price": 6,  "tier": 3},
		"choco":   {"name": "초코도넛",  "icon": "🍪", "ingredients": ["flour", "egg", "chocolate"], "cook_time": 5.0, "price": 8,  "tier": 4},
		"tiramisu": {"name": "티라미수",  "icon": "🍮", "ingredients": ["bean", "cream", "sugar"], "cook_time": 6.0, "price": 12, "tier": 5},
		"special": {"name": "초코케이크",  "icon": "🍰", "ingredients": ["flour", "cream", "sugar", "chocolate"], "cook_time": 7.0, "price": 20, "tier": 6},
	},
	"burger": {
		"icecream":     {"name": "아이스크림",   "icon": "🍦", "ingredients": ["cream", "sugar"], "cook_time": 2.0, "price": 1,  "tier": 1},
		"shake":        {"name": "셰이크",       "icon": "🥤", "ingredients": ["milk", "cream"], "cook_time": 2.0, "price": 2,  "tier": 2},
		"burger":       {"name": "버거",         "icon": "🍔", "ingredients": ["bun", "patty"], "cook_time": 3.0, "price": 4,  "tier": 3},
		"cheeseburger": {"name": "치즈버거",     "icon": "🍔", "ingredients": ["bun", "patty", "cheese"], "cook_time": 4.0, "price": 6,  "tier": 4},
		"burgerset":    {"name": "버거세트",     "icon": "🍟", "ingredients": ["bun", "patty", "potato", "cola"], "cook_time": 5.0, "price": 12, "tier": 5},
		"cheeseset":    {"name": "치즈버거세트", "icon": "🍟", "ingredients": ["bun", "patty", "cheese", "potato", "cola"], "cook_time": 6.0, "price": 20, "tier": 6},
	},
}

static func all() -> Dictionary:
	return BANK.get(BuffDefs.current_shop, BANK["donut"])

static func all_ids() -> Array:
	return all().keys()

static func get_def(id: String) -> Dictionary:
	return all().get(id, {})

static func random_id() -> String:
	var ids := all().keys()
	return ids[randi() % ids.size()]


static var _tex_cache := {}
static var _tex_cache_sm := {}

static func tex(id: String, small := false) -> Texture2D:
	var cache: Dictionary = _tex_cache_sm if small else _tex_cache
	if not cache.has(id):
		var dir := "recipes_48" if small else "recipes_128"
		var path := "res://assets/art/%s/%s.png" % [dir, id]
		cache[id] = load(path) if ResourceLoader.exists(path) else null
	return cache[id]

static func icon_node(id: String, px: int) -> Control:
	var t := tex(id, px <= 30)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label(str(get_def(id).get("icon", "?")), px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
