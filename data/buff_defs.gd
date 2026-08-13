class_name BuffDefs
extends RefCounted

const ALL := {
	"cook":       {"card": 1, "icon": "⚡", "mult": {"stat": "cook_mult", "value": 0.75}},
	"patience":   {"card": 2, "icon": "⏳", "mult": {"stat": "patience_mult", "value": 1.10}},
	"day_len":    {"card": 3, "icon": "🕒", "mult": {"stat": "day_mult", "value": 1.07}},
	"wh_chance":  {"card": 4, "icon": "🍀", "trip_free": 0.50},
	"wh_fast":    {"card": 5, "icon": "🏃", "mult": {"stat": "warehouse_mult", "value": 0.34}},
	"rent_down":  {"card": 6, "icon": "🏠", "mult": {"stat": "rent_mult", "value": 0.90}},
	"shop_disc":  {"card": 7, "icon": "🏷️", "blocked": true},
	"pack_more":  {"card": 8, "icon": "🃏", "blocked": true},
	"rent_skip":  {"card": 9, "icon": "🎟️", "rent_skip": true},
	"reveal":     {"card": 10, "icon": "🔮", "blocked": true},

	"buff_slot":  {"card": 11, "icon": "🧩", "structure": {"buff_slot": 1}},
	"tool_slot":  {"card": 12, "icon": "🔥", "structure": {"tool": 1, "slot": 1}},

	"opt_egg":    {"card": 13, "icon": "🥚", "opt_ingredient": "egg"},
	"opt_flour":  {"card": 14, "icon": "🌾", "opt_ingredient": "flour"},

	"dmd_t12":    {"card": 15, "icon": "📈", "demand": {"tiers": [1, 2], "mult": 2.0}},
	"dmd_t34":    {"card": 16, "icon": "📈", "demand": {"tiers": [3, 4], "mult": 2.0}},
	"dmd_t56":    {"card": 17, "icon": "📈", "demand": {"tiers": [5, 6], "mult": 2.0}},
	"dmd_bean":   {"card": 18, "icon": "🌰", "demand": {"ingredient": "bean", "mult": 1.5}},
	"dmd_choco":  {"card": 19, "icon": "🍫", "demand": {"ingredient": "chocolate", "mult": 1.6}},
	"dmd_cream":  {"card": 20, "icon": "🍦", "demand": {"ingredient": "cream", "mult": 1.7}},

	"mp_t12":     {"card": 21, "icon": "💲", "menu_price": {"tiers": [1, 2], "pct": 0.25}},
	"mp_t34":     {"card": 22, "icon": "💲", "menu_price": {"tiers": [3, 4], "pct": 0.15}},
	"mp_t56":     {"card": 23, "icon": "💲", "menu_price": {"tiers": [5, 6], "pct": 0.15}},

	"ramp_t1":    {"card": 24, "icon": "📈", "ramp": {"tier": 1, "value": 0.07}},
	"ramp_t2":    {"card": 25, "icon": "📈", "ramp": {"tier": 2, "value": 0.07}},
	"ramp_t3":    {"card": 26, "icon": "📈", "ramp": {"tier": 3, "value": 0.07}},
	"ramp_t4":    {"card": 27, "icon": "📈", "ramp": {"tier": 4, "value": 0.07}},
	"ramp_t5":    {"card": 28, "icon": "📈", "ramp": {"tier": 5, "value": 0.07}},
	"ramp_t6":    {"card": 29, "icon": "📈", "ramp": {"tier": 6, "value": 0.07}},

	"sc_buff_a":  {"card": 30, "icon": "🧮", "sale": {"type": "count", "per": "buff", "base": 0.0, "step": 0.07}},
	"sc_buff_b":  {"card": 31, "icon": "🧮", "sale": {"type": "count", "per": "buff", "base": 0.10, "step": 0.03}},
	"sc_fill_a":  {"card": 32, "icon": "🧱", "sale": {"type": "count", "per": "filled", "base": 0.0, "step": 0.04}},
	"sc_fill_b":  {"card": 33, "icon": "🧱", "sale": {"type": "count", "per": "filled", "base": 0.10, "step": 0.01}},
	"sc_empt_a":  {"card": 34, "icon": "⬜", "sale": {"type": "count", "per": "empty", "base": 0.0, "step": 0.06}},
	"sc_empt_b":  {"card": 35, "icon": "⬜", "sale": {"type": "count", "per": "empty", "base": 0.10, "step": 0.02}},
	"sale_full":  {"card": 36, "icon": "🈵", "sale": {"type": "full", "pct": 0.15}},
	"cook_empty": {"card": 37, "icon": "💨", "cook_empty": {"step": 0.15}},
	"sc_order":   {"card": 38, "icon": "📝", "sale": {"type": "count", "per": "orders", "base": 0.0, "step": 0.05}},
	"sc_dish":    {"card": 39, "icon": "🍽️", "sale": {"type": "count", "per": "dishes", "base": 0.0, "step": 0.20}},
	"sc_ingr":    {"card": 40, "icon": "🧺", "sale": {"type": "count", "per": "ingr", "base": 0.0, "step": 0.04}},

	"prob_x2":    {"card": 41, "icon": "🎲", "sale": {"type": "prob_double", "chance": 0.08}},
	"rt_streak3": {"card": 42, "icon": "📈", "trigger": {"kind": "streak3", "value": 0.20}},
	"rt_every7":  {"card": 43, "icon": "📈", "trigger": {"kind": "every7", "value": 0.20}},
	"rt_fast3":   {"card": 44, "icon": "📈", "trigger": {"kind": "fast3", "value": 0.12, "window": 3.0}},
	"accum_sale": {"card": 45, "icon": "🪙", "sale": {"type": "accum", "pct": 0.03}},
	"sale_flat3": {"card": 46, "icon": "💰", "sale": {"type": "flat", "pct": 0.09}},
	"prob_bonus": {"card": 47, "icon": "🍀", "sale": {"type": "prob_pct", "chance": 0.20, "pct": 0.30}},
	"sale_risk":  {"card": 48, "icon": "💥", "sale": {"type": "risk", "pct": 0.20, "chance": 0.10, "penalty_pct": 0.30}},
	"no_buy":     {"card": 49, "icon": "🚫", "blocked": true},
	"sale_cash":  {"card": 50, "icon": "🏦", "sale": {"type": "cash", "pct": 0.006}, "economy": {"kind": "rent_penalty", "pct": 0.20}},
	"sale_pat":   {"card": 51, "icon": "⚖️", "sale": {"type": "flat", "pct": 0.25}, "mult": {"stat": "patience_mult", "value": 0.80}},

	"sale_t12":   {"card": 52, "icon": "💰", "sale": {"type": "tier", "tiers": [1, 2], "pct": 0.10}},
	"sale_t34":   {"card": 53, "icon": "💰", "sale": {"type": "tier", "tiers": [3, 4], "pct": 0.10}},
	"sale_t56":   {"card": 54, "icon": "💰", "sale": {"type": "tier", "tiers": [5, 6], "pct": 0.10}},
	"sale_fresh": {"card": 55, "icon": "✨", "sale": {"type": "fresh", "within": 2.0, "pct": 0.20}},
	"sale_fast":  {"card": 56, "icon": "⚡", "sale": {"type": "fast_order", "within": 6.0, "pct": 0.20}},
	"sale_addon": {"card": 57, "icon": "🔊", "sale": {"type": "addon", "pct": 0.30}},

	"auto_serve": {"card": 58, "icon": "🤖", "blocked": true},
	"auto_cook":  {"card": 59, "icon": "🤖", "blocked": true},
	"inst_order": {"card": 60, "icon": "⏭️", "instant": {"kind": "order", "n": 8}},
	"inst_cook":  {"card": 61, "icon": "⏩", "instant": {"kind": "cook", "n": 4}},

	"interest":   {"card": 62, "icon": "🏦", "economy": {"kind": "interest", "pct": 0.04}},
	"settle_100": {"card": 63, "icon": "🏆", "settle": {"kind": "served", "threshold": 1.00, "pct": 0.28}},
	"settle_90":  {"card": 64, "icon": "🥇", "settle": {"kind": "served", "threshold": 0.90, "pct": 0.15}},
	"settle_same":{"card": 65, "icon": "🎯", "settle": {"kind": "samemenu", "threshold": 0.70, "pct": 0.17}},

	"pat_extend": {"card": 66, "icon": "🧘", "patience_flat": 3.0},
	"sale_late":  {"card": 67, "icon": "⌛", "sale": {"type": "late", "after": 25.0, "pct": 0.35}},
	"sale_burn":  {"card": 68, "icon": "🔥", "sale": {"type": "consumed", "pct": 0.40}},
	"sale_crit":  {"card": 69, "icon": "🚨", "sale": {"type": "critical", "pct": 0.20}},

	"pat_down":   {"card": 70, "icon": "💢", "mult": {"stat": "patience_mult", "value": 0.70}},
	"onlost_pay": {"card": 71, "icon": "💸", "onlost": {"money_pct": 0.34}},
	"onlost_x2":  {"card": 72, "icon": "😈", "onlost": {"double_next": true}},
	"settle_leave":{"card": 73, "icon": "🏳️", "settle": {"kind": "leave", "threshold": 0.30, "pct": 0.15}},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func display_name(id: String) -> String:
	return Loc.t("b." + id + ".name")

static func display_label(id: String) -> String:
	return Loc.t("b." + id + ".label")


const _CAT_OVERRIDE := {
	"cook": "cook", "cook_empty": "cook",
	"patience": "time", "day_len": "time", "pat_extend": "time", "pat_down": "time",
	"wh_chance": "time", "wh_fast": "time",
	"rent_down": "money", "rent_skip": "money", "shop_disc": "money", "interest": "money",
	"no_buy": "money", "sale_cash": "money", "onlost_pay": "money", "settle_leave": "money",
	"settle_100": "money", "settle_90": "money", "settle_same": "money",
	"buff_slot": "struct", "tool_slot": "struct", "pack_more": "struct", "reveal": "struct",
	"opt_egg": "struct", "opt_flour": "struct",
	"accum_sale": "growth",
	"prob_x2": "luck", "prob_bonus": "luck", "sale_risk": "luck", "onlost_x2": "luck",
}

static func category(id: String) -> String:
	if _CAT_OVERRIDE.has(id):
		return _CAT_OVERRIDE[id]
	if id.begins_with("dmd_"): return "demand"
	if id.begins_with("ramp_") or id.begins_with("rt_"): return "growth"
	if id.begins_with("auto_") or id.begins_with("inst_"): return "auto"
	if id.begins_with("mp_") or id.begins_with("sc_") or id.begins_with("sale_"): return "sale"
	return "sale"

static var _tex_cache := {}

static func tex(id: String) -> Texture2D:
	var cat := category(id)
	if not _tex_cache.has(cat):
		var path := "res://assets/art/buffs/buff_%s.png" % cat
		_tex_cache[cat] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[cat]

static func icon_node(id: String, px: int) -> Control:
	var t := tex(id)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label(str(get_def(id).get("icon", "?")), px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

static func random_pack(n := 3) -> Array:
	var pool := []
	for id in ALL.keys():
		if not ALL[id].get("blocked", false):
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))
