extends Node

var _owned: Array[String] = []

var _ramp_bonus: Dictionary = {}
var _serve_count := 0
var _cook_count := 0
var _streak_id := ""
var _streak_n := 0
var _serve_times: Array[float] = []
var _accum := 0
var _double_next := false
var _instant_order := false


func clear() -> void:
	_owned.clear()
	_ramp_bonus.clear()
	_serve_count = 0
	_cook_count = 0
	_streak_id = ""
	_streak_n = 0
	_serve_times.clear()
	_accum = 0
	_double_next = false
	_instant_order = false


func reset_day() -> void:
	_accum = 0


func add(id: String) -> void:
	if _owned.size() >= Config.MAX_BUFFS + buff_slot_bonus():
		return
	_owned.append(id)


func is_full() -> bool:
	return _owned.size() >= Config.MAX_BUFFS + buff_slot_bonus()


func owned() -> Array[String]:
	return _owned


func has_effect(id: String) -> bool:
	return _owned.has(id)


func mod(stat: String, base: float) -> float:
	var m := 1.0
	for id in _owned:
		var mult: Dictionary = BuffDefs.get_def(id).get("mult", {})
		if mult.get("stat", "") == stat:
			m *= float(mult.get("value", 1.0))
	return base * m


func buff_slot_bonus() -> int:
	return _struct_sum("buff_slot")

func tool_bonus() -> int:
	return _struct_sum("tool")

func slot_bonus() -> int:
	return _struct_sum("slot")

func _struct_sum(key: String) -> int:
	var n := 0
	for id in _owned:
		n += int(BuffDefs.get_def(id).get("structure", {}).get(key, 0))
	return n


func patience_flat() -> float:
	var s := 0.0
	for id in _owned:
		s += float(BuffDefs.get_def(id).get("patience_flat", 0.0))
	return s

func cook_empty_step() -> float:
	var s := 0.0
	for id in _owned:
		s += float(BuffDefs.get_def(id).get("cook_empty", {}).get("step", 0.0))
	return s


func demand_weight(recipe_id: String) -> float:
	var w := 1.0
	var def := Recipes.get_def(recipe_id)
	var tier := int(def.get("tier", 0))
	var ingredients: Array = def.get("ingredients", [])
	for id in _owned:
		var d: Dictionary = BuffDefs.get_def(id).get("demand", {})
		if d.is_empty():
			continue
		if d.has("tiers") and tier in d["tiers"]:
			w *= float(d.get("mult", 1.0))
		elif d.has("ingredient") and d["ingredient"] in ingredients:
			w *= float(d.get("mult", 1.0))
	return w


func ramp_bonus(recipe_id: String) -> int:
	return int(_ramp_bonus.get(recipe_id, 0))

func menu_price(recipe_id: String) -> int:
	var def := Recipes.get_def(recipe_id)
	var base := float(def.get("price", 0))
	var tier := int(def.get("tier", 0))
	var mp := base + float(ramp_bonus(recipe_id))
	var tp := 0.0
	for id in _owned:
		var m: Dictionary = BuffDefs.get_def(id).get("menu_price", {})
		if not m.is_empty() and tier in m.get("tiers", []):
			tp += float(m.get("pct", 0.0))
	return int(round(mp * (1.0 + tp)))


static func _buff_icon(id: String) -> String:
	if id == "":
		return "✨"
	return str(BuffDefs.get_def(id).get("icon", "✨"))


func sale_amount(recipe_id: String, ctx: Dictionary) -> Dictionary:
	var mp := menu_price(recipe_id)
	var tier := int(Recipes.get_def(recipe_id).get("tier", 0))
	var pct := 0.0
	var flat := 0
	var addon_pct := 0.0
	var do_double := false
	var accum_pct := 0.0
	var penalty := 0
	var discard := ""
	var addon_id := ""
	var accum_id := ""
	var double_id := ""
	var breakdown: Array = [{"src": "base", "amount": mp, "icon": str(Recipes.get_def(recipe_id).get("icon", "?"))}]

	for id in _owned:
		var s: Dictionary = BuffDefs.get_def(id).get("sale", {})
		if s.is_empty():
			continue
		var dpct := 0.0
		var dflat := 0
		match s.get("type", ""):
			"flat":
				dpct = float(s["pct"])
			"tier":
				if tier in s.get("tiers", []):
					dpct = float(s["pct"])
			"count":
				dpct = float(s.get("base", 0.0)) + float(s.get("step", 0.0)) * float(_ctx_count(s.get("per", ""), ctx))
			"full":
				if int(ctx.get("empty", -1)) == 0:
					dpct = float(s["pct"])
			"prob_double":
				if randf() < float(s.get("chance", 0.0)):
					do_double = true
					double_id = id
			"prob_pct":
				if randf() < float(s.get("chance", 0.0)):
					dpct = float(s["pct"])
			"cash":
				dflat = int(round(float(ctx.get("cash", 0)) * float(s["pct"])))
			"risk":
				dpct = float(s["pct"])
				if randf() < float(s.get("chance", 0.0)):
					discard = id
					penalty += int(round(float(ctx.get("day_revenue", 0)) * float(s.get("penalty_pct", 0.0))))
			"fresh":
				if float(ctx.get("dish_age", 1e9)) <= float(s["within"]):
					dpct = float(s["pct"])
			"fast_order":
				if float(ctx.get("order_age", 1e9)) <= float(s["within"]):
					dpct = float(s["pct"])
			"late":
				if float(ctx.get("order_age", 0.0)) >= float(s["after"]):
					dpct = float(s["pct"])
			"consumed":
				dpct = float(s["pct"]) * (1.0 - float(ctx.get("pat_frac", 1.0)))
			"critical":
				if float(ctx.get("pat_frac", 1.0)) <= Config.PATIENCE_LOW_FRAC:
					dpct = float(s["pct"])
			"addon":
				addon_pct += float(s["pct"])
				addon_id = id
			"accum":
				accum_pct += float(s["pct"])
				accum_id = id
		var contrib := 0
		if dpct != 0.0:
			var new_pct := pct + dpct
			contrib += int(round(float(mp) * new_pct)) - int(round(float(mp) * pct))
			pct = new_pct
		if dflat != 0:
			contrib += dflat
			flat += dflat
		if contrib != 0:
			breakdown.append({"src": id, "amount": contrib, "icon": _buff_icon(id)})

	var bonus := int(round(float(mp) * pct)) + flat
	if addon_pct > 0.0:
		var add := int(round(float(bonus) * addon_pct))
		bonus += add
		if add != 0:
			breakdown.append({"src": "addon", "amount": add, "icon": _buff_icon(addon_id)})
	var amount := mp + bonus
	var mult := 1
	if do_double:
		mult *= 2
	if _double_next:
		mult *= 2
		_double_next = false
	if mult > 1:
		var before := amount
		amount *= mult
		breakdown.append({"src": "double", "amount": amount - before, "icon": _buff_icon(double_id)})
	if accum_pct > 0.0:
		var payout := _accum
		_accum += int(round(float(amount) * accum_pct))
		amount += payout
		if payout != 0:
			breakdown.append({"src": "accum", "amount": payout, "icon": _buff_icon(accum_id)})
	return {"amount": amount, "penalty": penalty, "discard": discard, "breakdown": breakdown}


func _ctx_count(per: String, ctx: Dictionary) -> int:
	match per:
		"buff": return int(ctx.get("buffs", 0))
		"filled": return int(ctx.get("filled", 0))
		"empty": return int(ctx.get("empty", 0))
		"orders": return int(ctx.get("orders", 0))
		"dishes": return int(ctx.get("dishes", 0))
		"ingr": return int(ctx.get("ingr", 0))
	return 0


func required_ingredients(recipe_id: String) -> Array:
	var out: Array = []
	var skip := {}
	for id in _owned:
		var ing: String = BuffDefs.get_def(id).get("opt_ingredient", "")
		if ing != "":
			skip[ing] = true
	for ing in Recipes.get_def(recipe_id).get("ingredients", []):
		if not skip.has(ing):
			out.append(ing)
	return out

func trip_free_chance() -> float:
	var c := 0.0
	for id in _owned:
		c = maxf(c, float(BuffDefs.get_def(id).get("trip_free", 0.0)))
	return c


func on_serve(recipe_id: String, ctx: Dictionary) -> void:
	var def := Recipes.get_def(recipe_id)
	var tier := int(def.get("tier", 0))
	var base := float(def.get("price", 0))
	var now := float(ctx.get("now", 0.0))
	_serve_count += 1
	if recipe_id == _streak_id:
		_streak_n += 1
	else:
		_streak_id = recipe_id
		_streak_n = 1
	_serve_times.append(now)
	if _serve_times.size() > 8:
		_serve_times = _serve_times.slice(_serve_times.size() - 8)

	for id in _owned:
		var d := BuffDefs.get_def(id)
		var r: Dictionary = d.get("ramp", {})
		if not r.is_empty() and int(r["tier"]) == tier:
			_add_ramp(recipe_id, int(round(base * float(r["value"]))))
		var t: Dictionary = d.get("trigger", {})
		if not t.is_empty():
			var inc := int(round(base * float(t["value"])))
			match t.get("kind", ""):
				"streak3":
					if _streak_n > 0 and _streak_n % 3 == 0:
						_add_ramp(recipe_id, inc)
				"every7":
					if _serve_count % 7 == 0:
						_add_ramp(recipe_id, inc)
				"fast3":
					var win := float(t.get("window", 5.0))
					if _serve_times.size() >= 3 and now - _serve_times[_serve_times.size() - 3] <= win:
						_add_ramp(recipe_id, inc)
		var ins: Dictionary = d.get("instant", {})
		if not ins.is_empty() and ins.get("kind", "") == "order" and _serve_count % int(ins["n"]) == 0:
			_instant_order = true

func _add_ramp(recipe_id: String, inc: int) -> void:
	_ramp_bonus[recipe_id] = int(_ramp_bonus.get(recipe_id, 0)) + inc

func on_cook_start() -> bool:
	_cook_count += 1
	for id in _owned:
		var ins: Dictionary = BuffDefs.get_def(id).get("instant", {})
		if not ins.is_empty() and ins.get("kind", "") == "cook" and _cook_count % int(ins["n"]) == 0:
			return true
	return false

func consume_instant_order() -> bool:
	if _instant_order:
		_instant_order = false
		return true
	return false


func on_lost(recipe_id: String) -> int:
	var gain := 0
	var mp := menu_price(recipe_id)
	for id in _owned:
		var ol: Dictionary = BuffDefs.get_def(id).get("onlost", {})
		if ol.is_empty():
			continue
		if ol.has("money_pct"):
			gain += int(round(float(mp) * float(ol["money_pct"])))
		if ol.get("double_next", false):
			_double_next = true
	return gain


func day_start_bonus(cash: int) -> int:
	var g := 0
	for id in _owned:
		var e: Dictionary = BuffDefs.get_def(id).get("economy", {})
		if e.get("kind", "") == "interest":
			g += int(round(float(cash) * float(e["pct"])))
	return g

func day_end_bonus(ctx: Dictionary) -> int:
	var g := 0
	var visited := maxi(1, int(ctx.get("visited", 0)))
	var served := int(ctx.get("served", 0))
	var served_ratio := float(served) / float(visited)
	var accepted := maxi(1, int(ctx.get("accepted", 0)))
	var leave_ratio := float(ctx.get("order_lost", 0)) / float(accepted)
	var same_ratio := 0.0
	if served > 0:
		same_ratio = float(ctx.get("same_max", 0)) / float(served)
	var day_rev := int(ctx.get("day_revenue", 0))
	for id in _owned:
		var st: Dictionary = BuffDefs.get_def(id).get("settle", {})
		if not st.is_empty():
			match st.get("kind", ""):
				"served":
					if served_ratio >= float(st["threshold"]):
						g += int(round(float(day_rev) * float(st["pct"])))
				"samemenu":
					if same_ratio >= float(st["threshold"]):
						g += int(round(float(day_rev) * float(st["pct"])))
				"leave":
					if leave_ratio >= float(st["threshold"]):
						g += int(round(float(ctx.get("cash", 0)) * float(st["pct"])))
		var e: Dictionary = BuffDefs.get_def(id).get("economy", {})
		if e.get("kind", "") == "rent_penalty":
			g -= int(round(float(ctx.get("rent", 0)) * float(e["pct"])))
	return g

func discard(id: String) -> void:
	_owned.erase(id)
