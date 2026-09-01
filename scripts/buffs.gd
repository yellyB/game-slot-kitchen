extends Node

var _owned: Array[String] = []
var _slot_pos: Dictionary = {}

var _ramp_bonus: Dictionary = {}
var _serve_count := 0
var _cook_count := 0
var _streak_id := ""
var _streak_n := 0
var _serve_times: Array[float] = []
var _accum := 0
var _double_next := false
var _instant_order := false
var _mature_age := {}


func clear() -> void:
	_owned.clear()
	_slot_pos.clear()
	_ramp_bonus.clear()
	_serve_count = 0
	_cook_count = 0
	_streak_id = ""
	_streak_n = 0
	_serve_times.clear()
	_accum = 0
	_double_next = false
	_instant_order = false
	_mature_age.clear()


func reset_day() -> void:
	_accum = 0


func add(id: String) -> void:
	if _owned.size() >= Config.MAX_BUFFS + buff_slot_bonus():
		return
	_owned.append(id)
	if BuffDefs.get_def(id).has("matures"):
		_mature_age[id] = 0
	Codex.discover(id)


func remove(id: String) -> bool:
	var idx := _owned.find(id)
	if idx < 0:
		return false
	_owned.remove_at(idx)
	_slot_pos.erase(id)
	var r: Dictionary = BuffDefs.get_def(id).get("ramp", {})
	if not r.is_empty():
		var tier := int(r.get("tier", 0))
		for rid in Recipes.ALL:
			if int(Recipes.ALL[rid].get("tier", -1)) == tier:
				_ramp_bonus.erase(rid)
	return true


func is_full() -> bool:
	return _owned.size() >= Config.MAX_BUFFS + buff_slot_bonus()


func owned() -> Array[String]:
	return _owned


func set_slot_pos(id: String, idx: int) -> void:
	_slot_pos[id] = idx


func slot_pos(id: String) -> int:
	return int(_slot_pos.get(id, -1))


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

func cook_clean_reduction(filled: int) -> float:
	var r := 0.0
	for id in _owned:
		var c: Dictionary = BuffDefs.get_def(id).get("cook_clean", {})
		if not c.is_empty():
			r += maxf(0.0, float(c.get("max", 0.0)) - float(filled) * float(c.get("per", 0.0)))
	return r


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
			tp += float(m.get("pct", 0.0)) - 1.0
	return int(round(mp * (1.0 + tp)))


static func _buff_icon(id: String) -> String:
	if id == "":
		return "✨"
	return str(BuffDefs.get_def(id).get("icon", "✨"))


func _sale_order() -> Array:
	var positioned: Array = []
	var loose: Array = []
	for id in _owned:
		if slot_pos(id) >= 0:
			positioned.append(id)
		else:
			loose.append(id)
	positioned.sort_custom(func(a, b): return slot_pos(a) < slot_pos(b))
	positioned.append_array(loose)
	return positioned


func sale_amount(recipe_id: String, ctx: Dictionary) -> Dictionary:
	var rdef := Recipes.get_def(recipe_id)
	var mp := float(rdef.get("price", 0)) + float(ramp_bonus(recipe_id))
	var tier := int(rdef.get("tier", 0))
	var running := mp
	var penalty := 0
	var discard := ""
	var mult := 1.0
	var mult_id := ""
	var accum_pct := 0.0
	var accum_id := ""
	var breakdown: Array = [{"src": "base", "amount": int(round(mp)), "recipe": recipe_id, "icon": str(rdef.get("icon", "?"))}]

	for id in _sale_order():
		var def_b: Dictionary = BuffDefs.get_def(id)
		var before := running
		var mpd: Dictionary = def_b.get("menu_price", {})
		if not mpd.is_empty():
			if tier in mpd.get("tiers", []):
				running += mp * (float(mpd.get("pct", 1.0)) - 1.0)
		else:
			var s: Dictionary = def_b.get("sale", {})
			match s.get("type", ""):
				"flat":
					running += mp * (float(s["pct"]) - 1.0)
				"tier":
					if tier in s.get("tiers", []):
						running += mp * (float(s["pct"]) - 1.0)
				"count":
					running += mp * (float(s.get("base", 0.0)) + float(s.get("step", 0.0)) * float(_ctx_count(s.get("per", ""), ctx)))
				"full":
					if int(ctx.get("empty", -1)) == 0:
						running += mp * (float(s["value"] if s.has("value") else s["pct"]) - 1.0)
				"prob_double":
					if randf() < float(s.get("chance", 0.0)):
						running *= 2.0
						mult *= 2.0
						mult_id = id
				"prob_pct":
					if randf() < float(s.get("chance", 0.0)):
						running += mp * (float(s["pct"]) - 1.0)
				"risk":
					running *= float(s["pct"])
					if randf() < float(s.get("chance", 0.0)):
						discard = id
						penalty += int(round(float(ctx.get("day_revenue", 0)) * float(s.get("penalty_pct", 0.0))))
				"fresh":
					if float(ctx.get("dish_age", 1e9)) <= float(s["within"]):
						running += mp * (float(s["pct"]) - 1.0)
				"fast_order":
					if float(ctx.get("order_age", 1e9)) <= float(s["within"]):
						running += mp * (float(s["pct"]) - 1.0)
				"late":
					if float(ctx.get("order_age", 0.0)) >= float(s["after"]):
						running += mp * (float(s["pct"]) - 1.0)
				"consumed":
					running += mp * (float(s["pct"]) - 1.0) * (1.0 - float(ctx.get("pat_frac", 1.0)))
				"critical":
					if float(ctx.get("pat_frac", 1.0)) <= Config.PATIENCE_LOW_FRAC:
						running += mp * (float(s["pct"]) - 1.0)
				"addon":
					running += (running - mp) * float(s["pct"])
				"accum":
					accum_pct += float(s["pct"])
					accum_id = id
				"mult":
					var mok := true
					match s.get("when", ""):
						"board_full": mok = int(ctx.get("empty", -1)) == 0
						"critical": mok = float(ctx.get("pat_frac", 1.0)) <= Config.PATIENCE_LOW_FRAC
					if mok:
						running *= float(s["value"])
						mult *= float(s["value"])
						mult_id = id
				"mult_count":
					var mc := _ctx_count(s.get("per", ""), ctx)
					var mf := float(s.get("base", 1.0)) + float(s["step"]) * float(mc)
					if mf != 1.0:
						running *= mf
						mult *= mf
						mult_id = id
				"exp_count":
					var ec := _ctx_count(s.get("per", ""), ctx)
					var ef := pow(1.0 + float(s.get("rate", 0.0)), float(ec))
					if ef != 1.0:
						running *= ef
						mult *= ef
						mult_id = id
		var delta := int(round(running)) - int(round(before))
		if delta != 0:
			breakdown.append({"src": id, "amount": delta, "buff": id, "icon": _buff_icon(id)})

	if _double_next:
		var before2 := running
		running *= 2.0
		mult *= 2.0
		_double_next = false
		var d2 := int(round(running)) - int(round(before2))
		if d2 != 0:
			breakdown.append({"src": "double", "amount": d2, "buff": mult_id, "icon": _buff_icon(mult_id)})

	var amount := int(round(running))
	if accum_pct > 0.0:
		var payout := _accum
		_accum += int(round(float(amount) * accum_pct))
		amount += payout
		if payout != 0:
			breakdown.append({"src": "accum", "amount": payout, "buff": accum_id, "icon": _buff_icon(accum_id)})
	return {"amount": amount, "penalty": penalty, "discard": discard, "breakdown": breakdown, "mult": mult}


func _ctx_count(per: String, ctx: Dictionary) -> int:
	var n := 0
	match per:
		"buff": n = int(ctx.get("buffs", 0))
		"filled": n = int(ctx.get("filled", 0))
		"empty": n = int(ctx.get("empty", 0))
		"orders": n = int(ctx.get("orders", 0))
		"dishes": n = int(ctx.get("dishes", 0))
		"ingr": n = int(ctx.get("ingr", 0))
	return mini(n, Config.COUNT_CAP)


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

func omitted_ingredients() -> Dictionary:
	var out := {}
	for id in _owned:
		var ing: String = BuffDefs.get_def(id).get("opt_ingredient", "")
		if ing != "":
			out[ing] = true
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
	var cap := int(Recipes.get_def(recipe_id).get("price", 0)) * Config.RAMP_CAP_MULT
	_ramp_bonus[recipe_id] = mini(int(_ramp_bonus.get(recipe_id, 0)) + inc, cap)

func serve_tip() -> int:
	var g := 0
	for id in _owned:
		var t: Dictionary = BuffDefs.get_def(id).get("tip", {})
		if t.is_empty():
			continue
		if randf() < float(t.get("chance", 0.0)):
			g += int(t.get("money", 0))
	return g

func on_cook_start() -> bool:
	_cook_count += 1
	for id in _owned:
		var ins: Dictionary = BuffDefs.get_def(id).get("instant", {})
		if not ins.is_empty() and ins.get("kind", "") == "cook" and _cook_count % int(ins["n"]) == 0:
			return true
	return false

func has_instant_order() -> bool:
	return _instant_order

func consume_instant_order() -> bool:
	if _instant_order:
		_instant_order = false
		return true
	return false


func on_lost(_recipe_id: String) -> int:
	var gain := 0
	for id in _owned:
		var ol: Dictionary = BuffDefs.get_def(id).get("onlost", {})
		if ol.is_empty():
			continue
		if ol.has("money"):
			if randf() < float(ol.get("chance", 1.0)):
				gain += int(ol["money"])
		if ol.get("double_next", false):
			_double_next = true
	return gain


func day_start_bonus(cash: int) -> int:
	var g := 0
	var c := float(maxi(0, cash))
	for id in _owned:
		var e: Dictionary = BuffDefs.get_def(id).get("economy", {})
		if e.get("kind", "") == "interest":
			g += int(round(float(e["pct"]) * c))
	return g

func day_end_bonus(ctx: Dictionary) -> Dictionary:
	var score_g := 0
	var money_g := 0
	var served := int(ctx.get("served", 0))
	var missed := int(ctx.get("missed", 0))
	var visited := int(ctx.get("visited", 0))
	var served_ratio := 1.0 if visited == 0 else float(visited - missed) / float(visited)
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
						if st.has("money"):
							money_g += int(st["money"])
						else:
							score_g += int(round(float(day_rev) * float(st["pct"])))
				"samemenu":
					if same_ratio >= float(st["threshold"]):
						score_g += int(round(float(day_rev) * float(st["pct"])))
				"leave":
					if leave_ratio >= float(st["threshold"]):
						if st.has("money"):
							money_g += int(st["money"])
						else:
							money_g += int(round(float(ctx.get("cash", 0)) * float(st["pct"])))
		var e: Dictionary = BuffDefs.get_def(id).get("economy", {})
		if e.get("kind", "") == "rent_penalty":
			money_g -= int(round(float(ctx.get("rent", 0)) * float(e["pct"])))
	var destroy_ids: Array = []
	for id in _owned:
		var mt: Dictionary = BuffDefs.get_def(id).get("matures", {})
		if mt.is_empty():
			continue
		_mature_age[id] = int(_mature_age.get(id, 0)) + 1
		if _mature_age[id] >= int(mt.get("weeks", 0)):
			money_g += int(mt.get("money", 0))
			destroy_ids.append(id)
	for id in destroy_ids:
		_owned.erase(id)
		_mature_age.erase(id)
	return {"score": score_g, "money": money_g, "destroy": destroy_ids}

func discard(id: String) -> void:
	_owned.erase(id)
