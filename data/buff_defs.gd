class_name BuffDefs
extends RefCounted

const ALL := {
	"cook":       {"card": 1, "icon": "⚡", "mult": {"stat": "cook_mult", "value": 0.71}},
	"patience":   {"card": 2, "icon": "⏳", "mult": {"stat": "patience_mult", "value": 1.35}},
	"day_len":    {"card": 3, "icon": "🕒", "mult": {"stat": "day_mult", "value": 1.29}},
	"wh_chance":  {"card": 4, "icon": "🍀", "trip_free": 0.86},
	"wh_fast":    {"card": 5, "icon": "🏃", "mult": {"stat": "warehouse_mult", "value": 0.08}},
	"rent_down":  {"card": 6, "icon": "🏠", "mult": {"stat": "rent_mult", "value": 0.77}},
	"shop_disc":  {"card": 7, "icon": "🏷️", "blocked": true},
	"pack_more":  {"card": 8, "icon": "🃏", "blocked": true},
	"rent_skip":  {"card": 9, "icon": "🎟️", "rent_skip": true},
	"reveal":     {"card": 10, "icon": "🔮", "blocked": true},

	"buff_slot":  {"card": 11, "icon": "🧩", "structure": {"buff_slot": 1}},
	"tool_slot":  {"card": 12, "icon": "🔥", "structure": {"tool": 1, "slot": 1}},

	"opt_egg":    {"card": 13, "icon": "🥚", "opt_ingredient": "egg"},
	"opt_flour":  {"card": 14, "icon": "🌾", "opt_ingredient": "flour"},
	"opt_bean":   {"card": 15, "icon": "🌰", "opt_ingredient": "bean"},

	"dmd_t12":    {"card": 16, "icon": "📈", "demand": {"tiers": [1, 2], "mult": 1.6}},
	"dmd_t34":    {"card": 17, "icon": "📈", "demand": {"tiers": [3, 4], "mult": 1.6}},
	"dmd_t56":    {"card": 18, "icon": "📈", "demand": {"tiers": [5, 6], "mult": 1.6}},
	"dmd_bean":   {"card": 19, "icon": "🌰", "demand": {"ingredient": "bean", "mult": 1.5}},
	"dmd_choco":  {"card": 20, "icon": "🍫", "demand": {"ingredient": "chocolate", "mult": 1.5}},
	"dmd_cream":  {"card": 21, "icon": "🍦", "demand": {"ingredient": "cream", "mult": 1.5}},

	"mp_t12":     {"card": 22, "icon": "💲", "menu_price": {"tiers": [1, 2], "pct": 1.04}},
	"mp_t34":     {"card": 23, "icon": "💲", "menu_price": {"tiers": [3, 4], "pct": 0.40}},
	"mp_t56":     {"card": 24, "icon": "💲", "menu_price": {"tiers": [5, 6], "pct": 0.90}},

	"ramp_t1":    {"card": 25, "icon": "📈", "ramp": {"tier": 1, "value": 0.21}},
	"ramp_t2":    {"card": 26, "icon": "📈", "ramp": {"tier": 2, "value": 0.21}},
	"ramp_t3":    {"card": 27, "icon": "📈", "ramp": {"tier": 3, "value": 0.21}},
	"ramp_t4":    {"card": 28, "icon": "📈", "ramp": {"tier": 4, "value": 0.21}},
	"ramp_t5":    {"card": 29, "icon": "📈", "ramp": {"tier": 5, "value": 0.45}},
	"ramp_t6":    {"card": 30, "icon": "📈", "ramp": {"tier": 6, "value": 0.55}},

	"sc_buff_a":  {"card": 31, "icon": "🧮", "sale": {"type": "mult_count", "per": "buff", "step": 0.30}},
	"sc_buff_b":  {"card": 32, "icon": "🧮", "sale": {"type": "count", "per": "buff", "base": 0.24, "step": 0.10}},
	"sc_fill_a":  {"card": 33, "icon": "🧱", "sale": {"type": "count", "per": "filled", "base": 0.0, "step": 0.04}},
	"sc_fill_b":  {"card": 34, "icon": "🧱", "sale": {"type": "count", "per": "filled", "base": 0.13, "step": 0.03}},
	"sc_empt_a":  {"card": 35, "icon": "⬜", "sale": {"type": "mult_count", "per": "empty", "step": 0.25}},
	"sc_empt_b":  {"card": 36, "icon": "⬜", "sale": {"type": "count", "per": "empty", "base": 0.17, "step": 0.06}},
	"sale_full":  {"card": 37, "icon": "🈵", "sale": {"type": "mult", "value": 1.4, "when": "board_full"}},
	"cook_empty": {"card": 38, "icon": "💨", "cook_clean": {"max": 0.40, "per": 0.05}},
	"sc_order":   {"card": 39, "icon": "📝", "sale": {"type": "count", "per": "orders", "base": 0.0, "step": 0.08}},
	"sc_dish":    {"card": 40, "icon": "🍽️", "sale": {"type": "mult_count", "per": "dishes", "step": 0.3}},
	"sc_ingr":    {"card": 41, "icon": "🧺", "sale": {"type": "count", "per": "ingr", "base": 0.0, "step": 0.12}},

	"prob_x2":    {"card": 42, "icon": "🎲", "sale": {"type": "prob_double", "chance": 0.40}},
	"rt_streak3": {"card": 43, "icon": "📈", "trigger": {"kind": "streak3", "value": 0.65}},
	"rt_every7":  {"card": 44, "icon": "📈", "trigger": {"kind": "every7", "value": 0.23}},
	"rt_fast3":   {"card": 45, "icon": "📈", "trigger": {"kind": "fast3", "value": 0.45, "window": 3.0}},
	"accum_sale": {"card": 46, "icon": "🪙", "sale": {"type": "accum", "pct": 0.02}},
	"sale_flat3": {"card": 47, "icon": "💰", "sale": {"type": "flat", "pct": 0.34}},
	"prob_bonus": {"card": 48, "icon": "🍀", "sale": {"type": "prob_pct", "chance": 0.20, "pct": 1.20}},
	"sale_risk":  {"card": 49, "icon": "💥", "sale": {"type": "risk", "pct": 0.52, "chance": 0.10}},
	"no_buy":     {"card": 50, "icon": "🚫", "blocked": true},
	"sale_cash":  {"card": 51, "icon": "🏦", "sale": {"type": "cash", "pct": 0.01, "cap": 300}},
	"sale_pat":   {"card": 52, "icon": "⚖️", "sale": {"type": "flat", "pct": 0.29}, "mult": {"stat": "patience_mult", "value": 0.80}},

	"sale_t12":   {"card": 53, "icon": "💰", "sale": {"type": "tier", "tiers": [1, 2], "pct": 0.86}},
	"sale_t34":   {"card": 54, "icon": "💰", "sale": {"type": "tier", "tiers": [3, 4], "pct": 0.40}},
	"sale_t56":   {"card": 55, "icon": "💰", "sale": {"type": "tier", "tiers": [5, 6], "pct": 0.90}},
	"sale_fresh": {"card": 56, "icon": "✨", "sale": {"type": "fresh", "within": 2.0, "pct": 0.34}},
	"sale_fast":  {"card": 57, "icon": "⚡", "sale": {"type": "fast_order", "within": 6.0, "pct": 0.52}},
	"sale_addon": {"card": 58, "icon": "🔊", "sale": {"type": "addon", "pct": 0.69}},

	"mult_all":   {"card": 75, "icon": "✖️", "sale": {"type": "mult", "value": 1.3}},

	"auto_serve": {"card": 59, "icon": "🤖", "blocked": true},
	"auto_cook":  {"card": 60, "icon": "🤖", "blocked": true},
	"inst_order": {"card": 61, "icon": "⏭️", "instant": {"kind": "order", "n": 8}},
	"inst_cook":  {"card": 62, "icon": "⏩", "instant": {"kind": "cook", "n": 4}},

	"interest":   {"card": 63, "icon": "🏦", "economy": {"kind": "interest", "pct": 0.12}},
	"settle_100": {"card": 64, "icon": "🏆", "settle": {"kind": "served", "threshold": 1.00, "pct": 0.75}},
	"settle_90":  {"card": 65, "icon": "🥇", "settle": {"kind": "served", "threshold": 0.90, "pct": 0.50}},
	"settle_same":{"card": 66, "icon": "🎯", "settle": {"kind": "samemenu", "threshold": 0.70, "pct": 0.40}},

	"pat_extend": {"card": 67, "icon": "🧘", "patience_flat": 7.0},
	"sale_late":  {"card": 68, "icon": "⌛", "sale": {"type": "late", "after": 25.0, "pct": 0.69}},
	"sale_burn":  {"card": 69, "icon": "🔥", "sale": {"type": "consumed", "pct": 0.81}},
	"sale_crit":  {"card": 70, "icon": "🚨", "sale": {"type": "critical", "pct": 0.52}},

	"pat_down":   {"card": 71, "icon": "💢", "mult": {"stat": "patience_mult", "value": 0.70}},
	"onlost_pay": {"card": 72, "icon": "💸", "onlost": {"money_pct": 0.69}},
	"onlost_x2":  {"card": 73, "icon": "😈", "onlost": {"double_next": true}},
	"settle_leave":{"card": 74, "icon": "🏳️", "settle": {"kind": "leave", "threshold": 0.30, "pct": 0.35}},
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
	"opt_egg": "struct", "opt_flour": "struct", "opt_bean": "struct",
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

static var _tex_cache_sm := {}

static func tex(id: String, small := false) -> Texture2D:
	var cat := category(id)
	var cache: Dictionary = _tex_cache_sm if small else _tex_cache
	if not cache.has(cat):
		var dir := "buffs_48" if small else "buffs_128"
		var path := "res://assets/art/%s/buff_%s.png" % [dir, cat]
		var base: Texture2D = load(path) if ResourceLoader.exists(path) else null
		cache[cat] = _opaque_crop(base)
	return cache[cat]

static func _opaque_crop(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var img := t.get_image()
	if img == null:
		return t
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.06:
				if x < minx: minx = x
				if x > maxx: maxx = x
				if y < miny: miny = y
				if y > maxy: maxy = y
	if maxx < minx:
		return t
	var m := int(round(float(maxi(maxx - minx + 1, maxy - miny + 1)) * 0.06))
	minx = maxi(0, minx - m)
	miny = maxi(0, miny - m)
	maxx = mini(w - 1, maxx + m)
	maxy = mini(h - 1, maxy + m)
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = Rect2(minx, miny, maxx - minx + 1, maxy - miny + 1)
	return at

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

static func random_pack(n := 3) -> Array:
	var owned := Buffs.owned()
	var pool := []
	for id in ALL.keys():
		if ALL[id].get("blocked", false):
			continue
		if id in owned:
			continue
		pool.append(id)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))
