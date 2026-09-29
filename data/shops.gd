class_name Shops
extends RefCounted

const ALL := {
	"donut":  {"icon": "🍩", "art": "glazed", "unlocked": true},
	"burger": {"icon": "🍔", "unlocked": true},
	"ramen":  {"icon": "🍜", "unlocked": false},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func is_unlocked(id: String) -> bool:
	return bool(get_def(id).get("unlocked", false))

static func icon_of(id: String) -> String:
	return str(get_def(id).get("icon", "🍽"))

static func name_of(id: String) -> String:
	return Loc.t("shop.%s" % id)

static func desc_of(id: String) -> String:
	return Loc.t("shop.%s.desc" % id)
