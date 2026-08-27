class_name SimCore
extends RefCounted

const DT := 0.1

var session: Session
var queue: Array = []
var orders: Array = []
var tools: Array = []
var dishes: Array = []
var ingredients: Array = []

var _busy := 0.0
var _handle := 0.0
var _miss := 0.0
var _now := 0.0
var _served := 0
var _lost := 0
var _last := {}

var _visited_today := 0
var _served_today := 0
var _accepted_today := 0
var _order_lost_today := 0
var _missed_today := 0
var _served_by_menu := {}


func run(buff_loadout: Array = [], run_seed := 0, shop_enabled := true) -> Dictionary:
	seed(run_seed)
	_handle = float(OS.get_environment("SIM_HANDLE")) if OS.has_environment("SIM_HANDLE") else 0.0
	_miss = float(OS.get_environment("SIM_MISS")) if OS.has_environment("SIM_MISS") else 0.0
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_closing.connect(_on_day_closing)
	session.day_ended.connect(func(s): _last = s)

	session.start_run()
	Buffs.clear()
	for b in buff_loadout:
		Buffs.add(b)

	var result := {"won": false, "days": 0, "cash": 0, "served": 0, "lost": 0, "slots": 0, "buffs": 0}
	var safety := 0
	while true:
		_reset_day_consumables()
		while session.is_running():
			_step()
			safety += 1
			if safety > 5_000_000:
				break
		result["days"] = session.day
		if OS.has_environment("SIM_TRACE") and run_seed < int(OS.get_environment("SIM_TRACE")):
			print("[TRACE] d%d m%d/w%d  served=%d miss=%d  slots=%d buffs=%d(%s)  score=%d/%d  pass=%s" % [
				session.day, int(Levels.get_day(session.day).get("month", 0)), int(Levels.get_day(session.day).get("week_in_month", 0)),
				_served_today, _missed_today, session.slots, Buffs.owned().size(), ",".join(Buffs.owned()),
				session.month_score, session.rent if session.rent > 0 else int(round(Buffs.mod("rent_mult", float(Levels.get_day(session.day).get("monthly_rent", 0))))),
				str(_last.get("passed", false))])
		if not _last.get("passed", false):
			break
		if _last.get("won", false):
			result["won"] = true
			break
		if shop_enabled:
			_shop()
		session.advance_day()

	result["cash"] = session.cash
	result["served"] = _served
	result["lost"] = _lost
	result["slots"] = session.slots
	result["buffs"] = Buffs.owned().size()
	session.free()
	return result


func _shop() -> void:
	var progressed := true
	while progressed:
		progressed = false
		if session.slots < Config.MAX_SLOTS \
				and session.cash >= Config.slot_price(session.day, session.slots - Config.START_SLOTS):
			if session.buy_slot():
				progressed = true
		if not Buffs.is_full() and session.slots - Buffs.owned().size() > Config.MAX_ORDERS \
				and session.cash >= Config.BUFF_PACK_PRICE:
			var pack: Array = session.buy_buff_pack()
			if not pack.is_empty():
				var pick := _pick_buff(pack)
				if pick != "":
					Buffs.add(pick)
				progressed = true


func _pick_buff(pack: Array) -> String:
	var best := ""
	var best_score := -999
	for id in pack:
		if Buffs.owned().has(id):
			continue
		var s := _buff_score(id)
		if s > best_score:
			best_score = s
			best = id
	return best

func _buff_score(id: String) -> int:
	var d := BuffDefs.get_def(id)
	if d.get("blocked", false):
		return -100
	if d.has("structure"):
		return 100
	if d.has("trip_free") or d.get("mult", {}).get("stat", "") == "warehouse_mult":
		return 90
	if d.has("settle"):
		return 80
	if d.has("ramp") or d.has("trigger"):
		return 70
	if d.has("economy"):
		return 60
	if d.has("sale"):
		return 50
	if d.has("menu_price"):
		return 45
	if d.has("demand"):
		return 40
	if d.get("mult", {}).get("stat", "") == "cook_mult":
		return 30
	if d.get("mult", {}).get("stat", "") == "patience_mult":
		return 10
	return 20


func _rebuild_tools() -> void:
	tools.clear()
	for i in Config.TOOL_COUNT + Buffs.tool_bonus():
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
		return
	_visited_today += 1
	if _miss > 0.0 and randf() < _miss:
		_lost += 1
		_missed_today += 1
		return
	queue.append({"id": Stats.random_recipe(), "pat": Stats.order_patience()})


func _decay_patience() -> void:
	for i in range(queue.size() - 1, -1, -1):
		queue[i]["pat"] -= DT
		if queue[i]["pat"] <= 0.0:
			queue.remove_at(i)
			_lost += 1
			_missed_today += 1
	for i in range(orders.size() - 1, -1, -1):
		orders[i]["pat"] -= DT
		if orders[i]["pat"] <= 0.0:
			var rid: String = orders[i]["id"]
			orders.remove_at(i)
			_lost += 1
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
	return {
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
	var money_g := int(db["money"]) + Config.WEEK_REWARD_BASE + _served_today * Config.WEEK_REWARD_PER_SERVE
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
		if not _last.get("passed", false):
			break
		if wi + 1 < script.size():
			session.advance_day()
	session.free()
	return out
