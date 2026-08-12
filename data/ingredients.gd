class_name Ingredients
extends RefCounted

const ALL := {
	"flour":     {"name": "밀가루", "icon": "🌾", "unlocked": true},
	"egg":       {"name": "계란",   "icon": "🥚", "unlocked": true},
	"sugar":     {"name": "설탕",   "icon": "🧂", "unlocked": true},
	"chocolate": {"name": "초콜릿", "icon": "🍫", "unlocked": true},
	"bean":      {"name": "원두",   "icon": "🌰", "unlocked": true},
	"milk":      {"name": "우유",   "icon": "🥛", "unlocked": true},
	"water":     {"name": "물",     "icon": "💧", "unlocked": true},
	"cream":     {"name": "크림",   "icon": "🍦", "unlocked": true},
}

static func unlocked_ids() -> Array:
	var out := []
	for id in ALL:
		if ALL[id]["unlocked"]:
			out.append(id)
	return out

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})


static var _tex_cache := {}

static func tex(id: String) -> Texture2D:
	if not _tex_cache.has(id):
		var path := "res://assets/art/ingredients/%s.png" % id
		_tex_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[id]

static func icon_node(id: String, px: int) -> Control:
	var t := tex(id)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label(str(get_def(id).get("icon", "?")), px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
