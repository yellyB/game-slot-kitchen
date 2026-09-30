class_name Shops
extends RefCounted

const ALL := {
	"donut":  {"icon": "🍩", "art": "glazed", "unlocked": true,
		"econ": {"patience_order": 25, "patience_dish": 35}},
	"burger": {"icon": "🍔", "unlock_after_clear": true,
		"econ": {"patience_order": 20, "patience_dish": 28, "spawn_gap_mult": 0.85}},
	"ramen":  {"icon": "🍜", "unlocked": false},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func is_unlocked(id: String) -> bool:
	var d := get_def(id)
	if d.get("unlock_after_clear", false):
		return FileAccess.file_exists("user://cleared.flag")
	return bool(d.get("unlocked", false))

static func econ(key: String, default := 1.0) -> float:
	return float(get_def(BuffDefs.current_shop).get("econ", {}).get(key, default))

static func patience_order() -> float:
	return econ("patience_order", Config.PATIENCE_ORDER)

static func patience_dish() -> float:
	return econ("patience_dish", Config.PATIENCE_DISH)

static func icon_of(id: String) -> String:
	return str(get_def(id).get("icon", "🍽"))

static func name_of(id: String) -> String:
	return Loc.t("shop.%s" % id)

static func desc_of(id: String) -> String:
	return Loc.t("shop.%s.desc" % id)
