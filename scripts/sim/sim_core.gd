class_name SimCore
extends RefCounted

const DT := 0.1

var session: Session
var queue: Array = []
var orders: Array = []
var tools: Array = []
var dishes: Array = []
var ingredients: Array = []

var force_menu := ""
var _busy := 0.0
var _handle := 0.0
var _miss := 0.0
var _fumble := 0.0
var _now := 0.0
var _served := 0
var _lost := 0
var _lost_miss := 0
var _lost_queue := 0
var _lost_order := 0
var _lost_qfull := 0
var _last := {}

var _visited_today := 0
var _served_today := 0
var _accepted_today := 0
var _order_lost_today := 0
var _missed_today := 0
var _served_by_menu := {}

var _ctx_sum := {"filled": 0.0, "empty": 0.0, "orders": 0.0, "dishes": 0.0, "ingr": 0.0, "buffs": 0.0}
var _ctx_n := 0


func run(buff_loadout: Array = [], run_seed := 0, shop_enabled := true, slots_only := false) -> Dictionary:
	seed(run_seed)
	_handle = float(OS.get_environment("SIM_HANDLE")) if OS.has_environment("SIM_HANDLE") else 0.0
	_miss = float(OS.get_environment("SIM_MISS")) if OS.has_environment("SIM_MISS") else 0.0
	_fumble = float(OS.get_environment("SIM_FUMBLE")) if OS.has_environment("SIM_FUMBLE") else 0.0
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_closing.connect(_on_day_closing)
	session.day_ended.connect(func(s): _last = s)

	session.start_run()
	Buffs.clear()
	for b in buff_loadout:
		Buffs.add(b)

	var result := {"won": false, "days": 0, "cash": 0, "served": 0, "lost": 0, "slots": 0, "buffs": 0, "score": 0}
	var max_day := int(OS.get_environment("SIM_MAXDAY")) if OS.has_environment("SIM_MAXDAY") else 12
	var no_fail := OS.has_environment("SIM_NOFAIL")
	var total_score := 0
	var safety := 0
	while true:
		_reset_day_consumables()
		while session.is_running():
			_step()
			safety += 1
			if safety > 5_000_000:
				break
		session.pay_rent()
		result["days"] = session.day
		total_score += int(_last.get("revenue", 0))
		if OS.has_environment("SIM_TRACE") and run_seed < int(OS.get_environment("SIM_TRACE")):
			print("[TRACE] d%d m%d/w%d  served=%d miss=%d  slots=%d buffs=%d(%s)  score=%d/%d  pass=%s" % [
				session.day, int(Levels.get_day(session.day).get("month", 0)), int(Levels.get_day(session.day).get("week_in_month", 0)),
				_served_today, _missed_today, session.slots, Buffs.owned().size(), ",".join(Buffs.owned()),
				session.month_score, session.rent if session.rent > 0 else int(round(Buffs.mod("rent_mult", float(Levels.get_day(session.day).get("monthly_rent", 0))))),
				str(_last.get("passed", false))])
		if max_day > 0 and session.day >= max_day:
			break
		if not no_fail and not _last.get("passed", false):
			break
		if _last.get("won", false):
			result["won"] = true
			break
		if _last.get("passed", false):
			session.earn(Config.week_reward(session.day, _served_today), false)
		if shop_enabled:
			_shop(slots_only)
		session.advance_day()

	result["score"] = total_score
	result["cash"] = session.cash
	result["served"] = _served
	result["lost"] = _lost
	result["lost_miss"] = _lost_miss
	result["lost_queue"] = _lost_queue
	result["lost_order"] = _lost_order
	result["lost_qfull"] = _lost_qfull
	result["slots"] = session.slots
	result["buffs"] = Buffs.owned().size()
	for k in _ctx_sum:
		result["ctx_" + k] = float(_ctx_sum[k]) / float(maxi(_ctx_n, 1))
	session.free()
	return result


func _shop(slots_only := false) -> void:
	var progressed := true
	while progressed:
		progressed = false
		if session.slots < Config.MAX_SLOTS \
				and session.cash >= Config.slot_price(session.day, session.slots - Config.START_SLOTS):
			if session.buy_slot():
				progressed = true
		if slots_only:
			continue
		if not Buffs.is_full() and session.slots - Buffs.owned().size() > Config.MAX_ORDERS \
				and session.cash >= Config.BUFF_PACK_PRICE:
			var pack: Array = session.buy_buff_pack()
			if not pack.is_empty():
				var pick := _pick_buff(pack)
				if pick != "":
					Buffs.add(pick)
				progressed = true


func _pick_buff(pack: Array) -> String:
	var cands: Array = []
	for id in pack:
		if not Buffs.owned().has(id):
			cands.append({"id": id, "s": _buff_score(id)})
	if cands.is_empty():
		return ""
	cands.sort_custom(func(a, b): return a["s"] > b["s"])
	var rank := int(OS.get_environment("SIM_PICK_RANK")) if OS.has_environment("SIM_PICK_RANK") else 2
	return cands[mini(rank - 1, cands.size() - 1)]["id"]

const EFF := {"ramp_lo": 11178, "ramp_mid": 11333, "ramp_hi": 13030, "rt_every7": 7164, "sc_ingr": 5221, "mp_t56": 5435, "sale_t56": 5435, "sc_order": 2879, "sale_pat": 4881, "sale_flat3": 4883, "mult_all": 4883, "rt_fast3": 928, "mp_t12": 3535, "sale_t12": 3535, "mp_t34": 4236, "sale_t34": 4236, "sale_fresh": 862, "sc_fill_b": 1490, "sc_fill_a": 1514, "sale_full": 778, "rt_streak3": 590, "sale_late": 548, "sale_burn": 496, "accum_sale": 431, "prob_bonus": 430, "prob_x2": 358, "sc_buff_a": 308, "sc_dish": 1420, "sc_buff_b": 161, "settle_100": 184, "sale_risk": 160, "cook": 145, "tool_slot": 137, "day_len": 132, "settle_90": 124, "inst_cook": 111, "sale_fast": 104, "inst_order": 90, "sale_cash": 77, "wh_fast": 68, "wh_chance": 67, "dmd_t56": 52, "cook_empty": 45, "dmd_cream": 43, "sc_empt_a": 1292, "opt_flour": 34, "sc_empt_b": 728, "dmd_choco": 9, "buff_slot": 0, "opt_egg": -5, "nest_egg": -8, "rent_skip": -15, "onlost_x2": -15, "sale_crit": -15, "dmd_t34": -18, "reveal": -21, "pack_more": -21, "shop_disc": -21, "rent_down": -21, "sale_addon": -21, "no_buy": -21, "settle_perfect": -21, "auto_serve": -21, "auto_cook": -21, "interest": -21, "pat_down": -21, "settle_same": -21, "settle_leave": -21, "onlost_pay": -22, "serve_tip": -23, "pat_extend": -24, "patience": -26, "dmd_bean": -90, "opt_bean": -120, "dmd_t12": -145}

func _buff_score(id: String) -> int:
	if BuffDefs.get_def(id).get("blocked", false):
		return -9999
	return int(EFF.get(id, 0))


func _rebuild_tools() -> void:
	tools.clear()
	for i in maxi(1, Config.TOOL_COUNT + Buffs.tool_bonus()):
		tools.append({"id": "", "t": 0.0})


func _reset_day_consumables() -> void:
	queue.clear()
	orders.clear()
	dishes.clear()
	ingredients.clear()
	Buffs.reset_day()
	_rebuild_tools()
	_busy = 0.0
	_now = 0.0
	_visited_today = 0
	_served_today = 0
	_accepted_today = 0
	_order_lost_today = 0
	_missed_today = 0
	_served_by_menu = {}


func _step() -> void:
	_now += DT
	session.tick(DT)
	_decay_patience()
	_advance_cooking()
	if _handle > 0.0:
		_step_realistic()
		return
	_serve()
	if _busy > 0.0:
		_busy -= DT
		return
	_start_cooking()
	_accept_from_queue()
	_maybe_fetch()


func _step_realistic() -> void:
	if _busy > 0.0:
		_busy -= DT
		return
	if _fumble > 0.0 and randf() < _fumble:
		return
	if _serve_one():
		_busy = Config.SIM_HANDLE_SERVE * _handle
		return
	if _start_cook_one():
		_busy = Config.SIM_HANDLE_COOK * _handle
		return
	if _accept_one():
		_busy = Config.SIM_HANDLE_ACCEPT * _handle
		return
	var grabbed := _maybe_fetch()
	if grabbed > 0:
		_busy += Config.SIM_HANDLE_PLACE * _handle * float(grabbed)


func _on_spawn() -> void:
	if queue.size() >= Config.MAX_QUEUE:
		_lost_qfull += 1
		return
	_visited_today += 1
	if _miss > 0.0 and randf() < _miss:
		_lost += 1
		_lost_miss += 1
		_missed_today += 1
		return
	queue.append({"id": force_menu if force_menu != "" else Stats.random_recipe(), "pat": Stats.order_patience()})


func _decay_patience() -> void:
	for i in range(queue.size() - 1, -1, -1):
		queue[i]["pat"] -= DT
		if queue[i]["pat"] <= 0.0:
			queue.remove_at(i)
			_lost += 1
			_lost_queue += 1
			_missed_today += 1
	for i in range(orders.size() - 1, -1, -1):
		orders[i]["pat"] -= DT
		if orders[i]["pat"] <= 0.0:
			var rid: String = orders[i]["id"]
			orders.remove_at(i)
			_lost += 1
			_lost_order += 1
			_order_lost_today += 1
			_missed_today += 1
			var gain := Buffs.on_lost(rid)
			if gain != 0:
				session.earn(gain, false)


func _advance_cooking() -> void:
	for t in tools:
		if t["id"] == "":
			continue
		t["t"] -= DT
		if t["t"] <= 0.0:
			dishes.append({"id": t["id"], "born": _now})
			t["id"] = ""
			t["t"] = 0.0


func _serve() -> void:
	for di in range(dishes.size() - 1, -1, -1):
		var rid: String = dishes[di]["id"]
		var best := -1
		var best_pat := 1e9
		for oi in orders.size():
			if orders[oi]["id"] == rid and orders[oi]["pat"] < best_pat:
				best = oi
				best_pat = orders[oi]["pat"]
		if best < 0:
			continue
		var o: Dictionary = orders[best]
		var ctx := _sale_ctx(o, dishes[di])
		var res := Buffs.sale_amount(rid, ctx)
		session.earn(int(res["amount"]))
		var tip := Buffs.serve_tip()
		if tip > 0:
			session.earn(tip, false)
		if int(res.get("penalty", 0)) != 0:
			session.add_cash(-int(res["penalty"]))
		if res.get("discard", "") != "":
			Buffs.discard(res["discard"])
		Buffs.on_serve(rid, ctx)
		orders.remove_at(best)
		dishes.remove_at(di)
		_served += 1
		_served_today += 1
		_served_by_menu[rid] = int(_served_by_menu.get(rid, 0)) + 1


func _serve_one() -> bool:
	for di in range(dishes.size() - 1, -1, -1):
		var rid: String = dishes[di]["id"]
		var best := -1
		var best_pat := 1e9
		for oi in orders.size():
			if orders[oi]["id"] == rid and orders[oi]["pat"] < best_pat:
				best = oi
				best_pat = orders[oi]["pat"]
		if best < 0:
			continue
		var o: Dictionary = orders[best]
		var ctx := _sale_ctx(o, dishes[di])
		var res := Buffs.sale_amount(rid, ctx)
		session.earn(int(res["amount"]))
		var tip := Buffs.serve_tip()
		if tip > 0:
			session.earn(tip, false)
		if int(res.get("penalty", 0)) != 0:
			session.add_cash(-int(res["penalty"]))
		if res.get("discard", "") != "":
			Buffs.discard(res["discard"])
		Buffs.on_serve(rid, ctx)
		orders.remove_at(best)
		dishes.remove_at(di)
		_served += 1
		_served_today += 1
		_served_by_menu[rid] = int(_served_by_menu.get(rid, 0)) + 1
		return true
	return false


func _start_cook_one() -> bool:
	var filled := _board_used()
	for t in tools:
		if t["id"] != "":
			continue
		var rid := _pick_cookable()
		if rid == "":
			return false
		for ing in Buffs.required_ingredients(rid):
			ingredients.erase(ing)
		if Buffs.on_cook_start():
			dishes.append({"id": rid, "born": _now})
		else:
			t["id"] = rid
			t["t"] = Stats.cook_time(rid, filled)
		return true
	return false


func _accept_one() -> bool:
	var cap := _serve_cap()
	var order_cap := mini(Config.MAX_ORDERS, maxi(1, cap - 3))
	if queue.is_empty() or orders.size() >= order_cap or _board_used() >= cap:
		return false
	var best := 0
	for i in queue.size():
		if queue[i]["pat"] < queue[best]["pat"]:
			best = i
	var rid: String = queue[best]["id"]
	orders.append({"id": rid, "pat": Stats.dish_patience(), "max": Stats.dish_patience(), "born": _now})
	queue.remove_at(best)
	_accepted_today += 1
	if Buffs.consume_instant_order():
		dishes.append({"id": rid, "born": _now})
	return true


func _sale_ctx(order: Dictionary, dish: Dictionary) -> Dictionary:
	var cap := _serve_cap()
	var filled := orders.size() + dishes.size() + ingredients.size()
	var mx := float(order.get("max", 1.0))
	var c := {
		"filled": filled,
		"empty": maxi(0, cap - filled),
		"orders": orders.size(),
		"dishes": dishes.size(),
		"ingr": ingredients.size(),
		"buffs": Buffs.owned().size(),
		"now": _now,
		"dish_age": _now - float(dish.get("born", _now)),
		"order_age": _now - float(order.get("born", _now)),
		"pat_frac": clampf(float(order["pat"]) / maxf(0.001, mx), 0.0, 1.0),
		"cash": session.cash,
		"day_revenue": session.day_revenue,
	}
	for k in _ctx_sum:
		_ctx_sum[k] = float(_ctx_sum[k]) + float(c[k])
	_ctx_n += 1
	return c


func _start_cooking() -> void:
	var filled := _board_used()
	for t in tools:
		if t["id"] != "":
			continue
		var rid := _pick_cookable()
		if rid == "":
			continue
		for ing in Buffs.required_ingredients(rid):
			ingredients.erase(ing)
		if Buffs.on_cook_start():
			dishes.append({"id": rid, "born": _now})
		else:
			t["id"] = rid
			t["t"] = Stats.cook_time(rid, filled)


func _pick_cookable() -> String:
	var avail := _ingredient_counts()
	var sorted_orders := orders.duplicate()
	sorted_orders.sort_custom(func(a, b): return a["pat"] < b["pat"])
	for o in sorted_orders:
		var rid: String = o["id"]
		if _count_dishes(rid) + _count_cooking(rid) >= _count_orders(rid):
			continue
		if _has_ingredients(rid, avail):
			return rid
	return ""


func _accept_from_queue() -> void:
	var cap := _serve_cap()
	var order_cap := mini(Config.MAX_ORDERS, maxi(1, cap - 3))
	while not queue.is_empty() and orders.size() < order_cap and _board_used() < cap:
		var best := 0
		for i in queue.size():
			if queue[i]["pat"] < queue[best]["pat"]:
				best = i
		var rid: String = queue[best]["id"]
		orders.append({"id": rid, "pat": Stats.dish_patience(), "max": Stats.dish_patience(), "born": _now})
		queue.remove_at(best)
		_accepted_today += 1
		if Buffs.consume_instant_order():
			dishes.append({"id": rid, "born": _now})


func _maybe_fetch() -> int:
	var space := _empty_slots()
	if space <= 0:
		return 0
	var avail := _ingredient_counts()
	var sorted_orders := orders.duplicate()
	sorted_orders.sort_custom(func(a, b): return a["pat"] < b["pat"])
	var grab: Array = []
	for o in sorted_orders:
		if grab.size() >= space:
			break
		var rid: String = o["id"]
		if _count_dishes(rid) + _count_cooking(rid) >= _count_orders(rid):
			continue
		var trial: Dictionary = avail.duplicate()
		var missing: Array = []
		for ing in Buffs.required_ingredients(rid):
			if int(trial.get(ing, 0)) > 0:
				trial[ing] = int(trial[ing]) - 1
			else:
				missing.append(ing)
		if grab.size() + missing.size() <= space:
			avail = trial
			grab.append_array(missing)
	if grab.is_empty():
		return 0
	for ing in grab:
		ingredients.append(ing)
	var cost := Stats.warehouse_cost()
	if Buffs.trip_free_chance() > 0.0 and randf() < Buffs.trip_free_chance():
		cost = 0.0
	_busy = cost
	return grab.size()


func _ingredient_counts() -> Dictionary:
	var c := {}
	for ing in ingredients:
		c[ing] = int(c.get(ing, 0)) + 1
	return c

func _has_ingredients(rid: String, avail: Dictionary) -> bool:
	var req := {}
	for ing in Buffs.required_ingredients(rid):
		req[ing] = int(req.get(ing, 0)) + 1
	for ing in req:
		if int(avail.get(ing, 0)) < req[ing]:
			return false
	for ing in req:
		avail[ing] = int(avail[ing]) - req[ing]
	return true

func _serve_cap() -> int:
	var occupied := maxi(0, Buffs.owned().size() - Buffs.buff_slot_bonus())
	return maxi(1, session.effective_slots() - occupied)

func _board_used() -> int:
	return orders.size() + dishes.size() + ingredients.size()

func _empty_slots() -> int:
	return maxi(0, _serve_cap() - _board_used())


func _on_day_closing(s: Session) -> void:
	var same_max := 0
	for k in _served_by_menu:
		same_max = maxi(same_max, int(_served_by_menu[k]))
	var ctx := {
		"served": _served_today,
		"visited": _visited_today,
		"missed": _missed_today,
		"accepted": _accepted_today,
		"order_lost": _order_lost_today,
		"same_max": same_max,
		"day_revenue": s.day_revenue,
		"cash": s.cash,
		"rent": s.rent,
	}
	var db := Buffs.day_end_bonus(ctx)
	if int(db["score"]) != 0:
		s.earn(int(db["score"]), true)
	var money_g := int(db["money"])
	if money_g != 0:
		s.earn(money_g, false)


func _count_dishes(rid: String) -> int:
	var n := 0
	for d in dishes:
		if d["id"] == rid:
			n += 1
	return n

func _count_cooking(rid: String) -> int:
	var n := 0
	for t in tools:
		if t["id"] == rid:
			n += 1
	return n

func _count_orders(rid: String) -> int:
	var n := 0
	for o in orders:
		if o["id"] == rid:
			n += 1
	return n


func run_replay(script: Array, seed_v := 0, handle := 0.6) -> Array:
	seed(seed_v)
	_handle = handle
	_miss = float(OS.get_environment("SIM_MISS")) if OS.has_environment("SIM_MISS") else 0.25
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_closing.connect(_on_day_closing)
	session.day_ended.connect(func(s): _last = s)
	session.start_run()
	Buffs.clear()
	var out: Array = []
	var prev_slots := session.slots
	for wi in script.size():
		var wk: Dictionary = script[wi]
		var new_slots := int(wk.get("slots", session.slots))
		while prev_slots < new_slots:
			session.cash -= Config.slot_price(session.day, prev_slots - Config.START_SLOTS)
			prev_slots += 1
		session.slots = new_slots
		for b in wk.get("buffs", []):
			if not Buffs.owned().has(b):
				session.cash -= Config.BUFF_PACK_PRICE
				Buffs.add(b)
		if session.cash < 0:
			session.cash = 0
		_reset_day_consumables()
		var safety := 0
		while session.is_running():
			_step()
			safety += 1
			if safety > 2_000_000:
				break
		out.append({
			"week": wi + 1, "served": _served_today, "accepted": _accepted_today,
			"lost": _missed_today, "revenue": int(_last.get("revenue", 0)),
			"cash": session.cash, "rent": int(_last.get("rent", 0)),
			"passed": bool(_last.get("passed", false)),
		})
		if wi + 1 < script.size():
			session.advance_day()
	session.free()
	return out
