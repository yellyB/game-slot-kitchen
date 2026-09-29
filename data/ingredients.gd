class_name Ingredients
extends RefCounted

const BANK := {
	"donut": {
		"flour":     {"name": "밀가루", "icon": "🌾", "unlocked": true},
		"egg":       {"name": "계란",   "icon": "🥚", "unlocked": true},
		"sugar":     {"name": "설탕",   "icon": "🧂", "unlocked": true},
		"chocolate": {"name": "초콜릿", "icon": "🍫", "unlocked": true},
		"cream":     {"name": "크림",   "icon": "🍦", "unlocked": true},
		"bean":      {"name": "원두",   "icon": "🌰", "unlocked": true},
		"milk":      {"name": "우유",   "icon": "🥛", "unlocked": true},
		"water":     {"name": "물",     "icon": "💧", "unlocked": true},
	},
	"burger": {
		"bun":       {"name": "번",     "icon": "🍞", "unlocked": true},
		"patty":     {"name": "패티",   "icon": "🥩", "unlocked": true},
		"cheese":    {"name": "치즈",   "icon": "🧀", "unlocked": true},
		"potato":    {"name": "감자",   "icon": "🥔", "unlocked": true},
		"cola":      {"name": "콜라",   "icon": "🥤", "unlocked": true},
		"milk":      {"name": "우유",   "icon": "🥛", "unlocked": true},
		"cream":     {"name": "크림",   "icon": "🍦", "unlocked": true},
		"sugar":     {"name": "설탕",   "icon": "🧂", "unlocked": true},
	},
}

static func all() -> Dictionary:
	return BANK.get(BuffDefs.current_shop, BANK["donut"])

static func unlocked_ids() -> Array:
	var out := []
	var tbl := all()
	for id in tbl:
		if tbl[id]["unlocked"]:
			out.append(id)
	return out

static func get_def(id: String) -> Dictionary:
	return all().get(id, {})


static var _tex_cache := {}
static var _tex_cache_sm := {}

static func tex(id: String, small := false) -> Texture2D:
	var cache: Dictionary = _tex_cache_sm if small else _tex_cache
	if not cache.has(id):
		var dir := "ingredients_48" if small else "ingredients_128"
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
