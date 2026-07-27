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
	"butter":    {"name": "버터",   "icon": "🧈", "unlocked": true},
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
