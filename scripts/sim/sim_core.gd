class_name SimCore
extends RefCounted

const DT := 0.1

var session: Session
var queue: Array = []
var orders: Array = []
var tools: Array = []
var dishes: Array = []

var _served := 0
var _lost := 0
var _last := {}


func run(buff_loadout: Array = [], run_seed := 0) -> Dictionary:
	seed(run_seed)
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_ended.connect(func(s): _last = s)

	tools.clear()
	for i in Config.TOOL_COUNT:
		tools.append({"id": "", "t": 0.0})

	session.start_run()
	Buffs.clear()
	for b in buff_loadout:
		Buffs.add(b)

	var result := {"won": false, "days": 0, "cash": 0, "served": 0, "lost": 0}
	var safety := 0
	while true:
		_reset_day_consumables()
		while session.is_running():
			_step()
			safety += 1
			if safety > 5_000_000:
				break
		result["days"] = session.day
		if not _last.get("passed", false):
			break
		if _last.get("won", false):
			result["won"] = true
			break
		session.advance_day()

	result["cash"] = session.cash
	result["served"] = _served
	result["lost"] = _lost
	session.free()
	return result


func _reset_day_consumables() -> void:
	queue.clear()
	orders.clear()
	dishes.clear()
	for t in tools:
		t["id"] = ""
		t["t"] = 0.0


func _step() -> void:
	session.tick(DT)
	_decay_patience()
	_advance_cooking()
	_serve()
	_start_cooking()
	_accept_from_queue()


func _on_spawn() -> void:
	if queue.size() >= Config.MAX_QUEUE:
		return
	queue.append({"id": Stats.random_recipe(), "pat": Stats.order_patience()})


func _decay_patience() -> void:
	for i in range(queue.size() - 1, -1, -1):
		queue[i]["pat"] -= DT
		if queue[i]["pat"] <= 0.0:
			queue.remove_at(i)
			_lost += 1
	for i in range(orders.size() - 1, -1, -1):
		orders[i]["pat"] -= DT
		if orders[i]["pat"] <= 0.0:
			orders.remove_at(i)
			_lost += 1


func _advance_cooking() -> void:
	for t in tools:
		if t["id"] == "":
			continue
		t["t"] -= DT
		if t["t"] <= 0.0:
			dishes.append(t["id"])
			t["id"] = ""
			t["t"] = 0.0


func _serve() -> void:
	for di in range(dishes.size() - 1, -1, -1):
		var rid: String = dishes[di]
		var best := -1
		var best_pat := 1e9
		for oi in orders.size():
			if orders[oi]["id"] == rid and orders[oi]["pat"] < best_pat:
				best = oi
				best_pat = orders[oi]["pat"]
		if best >= 0:
			session.earn(Stats.sell_price(rid))
			orders.remove_at(best)
			dishes.remove_at(di)
			_served += 1


func _start_cooking() -> void:
	for t in tools:
		if t["id"] != "":
			continue
		var rid := _pick_recipe_to_cook()
		if rid == "":
			break
		t["id"] = rid
		t["t"] = Stats.cook_time(rid)


func _pick_recipe_to_cook() -> String:
	var sorted_orders := orders.duplicate()
	sorted_orders.sort_custom(func(a, b): return a["pat"] < b["pat"])
	for o in sorted_orders:
		var rid: String = o["id"]
		var have := _count(dishes, rid) + _count_cooking(rid)
		var need := _count_orders(rid)
		if have < need:
			return rid
	return ""


func _accept_from_queue() -> void:
	var cap := session.slots - Buffs.owned().size()
	while not queue.is_empty() and orders.size() < cap:
		var best := 0
		for i in queue.size():
			if queue[i]["pat"] < queue[best]["pat"]:
				best = i
		orders.append({"id": queue[best]["id"], "pat": Stats.dish_patience()})
		queue.remove_at(best)


func _count(arr: Array, rid: String) -> int:
	var n := 0
	for x in arr:
		if x == rid:
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
