class_name SimCore
extends RefCounted
## 헤드리스 시뮬레이션 v2 — 한 판(전 일차)을 dt 스텝으로 돌려 지표 반환.
## 실게임 Session(하루 루프·경제·스폰·승패) 재사용 + 손님 생애주기 + 재료 fetch(창고 트립).
##
## v2 병목 모델: 조리하려면 재료 카드가 보드에 다 있어야 함(조리 B안). 재료는 창고 트립으로
##   가져오며 트립은 영업시간을 소모(Stats.warehouse_cost). 트립 동안 플레이어는 다른 행동 불가
##   (_busy). 슬롯은 주문·재료·완성품·버프가 공유 → 공간/처리량 압박 발생.
## 미지원(blocked): 상점(7,8,49)·대기열 공개(10)·자동서빙(58,59)·45 초기화 — 버프.md 표 참고.

const DT := 0.1
const SLOT_RESERVE := 3   # 재료 놓을 공간 확보용 — 주문 접수 시 남겨두는 슬롯

var session: Session
var queue: Array = []       # 큐 대기: [{id, pat}]
var orders: Array = []      # 슬롯 주문: [{id, pat, max, born}]
var tools: Array = []       # 도구: [{id, t}]
var dishes: Array = []      # 완성품(미서빙): [{id, born}]
var ingredients: Array = [] # 보드 위 재료 카드(멀티셋): [ingredient_id, ...]

var _busy := 0.0            # 창고 트립 등으로 플레이어가 묶인 시간(초)
var _now := 0.0
var _served := 0
var _lost := 0
var _last := {}

# 하루 스코프 집계(정산용)
var _visited_today := 0
var _served_today := 0
var _accepted_today := 0
var _order_lost_today := 0
var _served_by_menu := {}


func run(buff_loadout: Array = [], run_seed := 0) -> Dictionary:
	seed(run_seed)
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_closing.connect(_on_day_closing)
	session.day_ended.connect(func(s): _last = s)

	session.start_run()   # 내부 Buffs.clear() → 버프는 이 뒤에 세팅
	Buffs.clear()
	for b in buff_loadout:
		Buffs.add(b)
	_rebuild_tools()

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


func _rebuild_tools() -> void:
	tools.clear()
	for i in Config.TOOL_COUNT + Buffs.tool_bonus():
		tools.append({"id": "", "t": 0.0})


func _reset_day_consumables() -> void:
	queue.clear()
	orders.clear()
	dishes.clear()
	ingredients.clear()
	for t in tools:
		t["id"] = ""
		t["t"] = 0.0
	_busy = 0.0
	_now = 0.0
	_visited_today = 0
	_served_today = 0
	_accepted_today = 0
	_order_lost_today = 0
	_served_by_menu = {}


## 1스텝: 시간·스폰 → 인내심/조리 진행. 플레이어가 트립 중이면(_busy) 행동 스킵.
func _step() -> void:
	_now += DT
	session.tick(DT)
	_decay_patience()
	_advance_cooking()
	if _busy > 0.0:
		_busy -= DT
		return
	_serve()
	_start_cooking()
	_accept_from_queue()
	_maybe_fetch()


func _on_spawn() -> void:
	if queue.size() >= Config.MAX_QUEUE:
		return
	queue.append({"id": Stats.random_recipe(), "pat": Stats.order_patience()})
	_visited_today += 1


func _decay_patience() -> void:
	for i in range(queue.size() - 1, -1, -1):
		queue[i]["pat"] -= DT
		if queue[i]["pat"] <= 0.0:
			queue.remove_at(i)
			_lost += 1
	for i in range(orders.size() - 1, -1, -1):
		orders[i]["pat"] -= DT
		if orders[i]["pat"] <= 0.0:
			var rid: String = orders[i]["id"]
			orders.remove_at(i)
			_lost += 1
			_order_lost_today += 1
			var gain := Buffs.on_lost(rid)
			if gain != 0:
				session.earn(gain)


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


## 유휴 도구에 조리 시작 — 필요 재료가 보드에 다 있는 가장 급한 주문부터.
func _start_cooking() -> void:
	var empty := _empty_slots()
	for t in tools:
		if t["id"] != "":
			continue
		var rid := _pick_cookable()
		if rid == "":
			continue
		for ing in Buffs.required_ingredients(rid):   # 재료 소모(보드에서 제거)
			ingredients.erase(ing)
		if Buffs.on_cook_start():                       # 61: 즉시완료
			dishes.append({"id": rid, "born": _now})
		else:
			t["id"] = rid
			t["t"] = Stats.cook_time(rid, empty)


## 조리 가능(재료 충족 & 아직 완성/조리중으로 안 덮인) 주문 중 가장 급한 레시피.
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
	# 재료 놓을 공간(SLOT_RESERVE) 남기고 접수 — 데드락(주문으로 슬롯 꽉참) 방지.
	while not queue.is_empty() and _board_used() < cap - SLOT_RESERVE:
		var best := 0
		for i in queue.size():
			if queue[i]["pat"] < queue[best]["pat"]:
				best = i
		var rid: String = queue[best]["id"]
		orders.append({"id": rid, "pat": Stats.dish_patience(), "max": Stats.dish_patience(), "born": _now})
		queue.remove_at(best)
		_accepted_today += 1
		if Buffs.consume_instant_order():   # 60
			dishes.append({"id": rid, "born": _now})


## 조리 못 하는 주문이 있고 빈 슬롯이 있으면 창고 트립 1회(영업시간 소모, _busy).
func _maybe_fetch() -> void:
	if _empty_slots() <= 0:
		return
	var need := _needed_ingredients()   # 미충족 주문들에 필요한 재료(보드분 차감)
	if need.is_empty():
		return
	var space := _empty_slots()
	for ing in need:
		var cnt: int = need[ing]
		while cnt > 0 and space > 0:
			ingredients.append(ing)
			space -= 1
			cnt -= 1
	# 트립 비용(영업시간) — 이 시간만큼 플레이어가 묶임(_busy). 카드4면 확률적 무료.
	var cost := Stats.warehouse_cost()
	if Buffs.trip_free_chance() > 0.0 and randf() < Buffs.trip_free_chance():
		cost = 0.0
	_busy = cost


# ── 재료 집계 헬퍼 ────────────────────────────────────────
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
	# 소모 반영(같은 스텝 여러 도구 대비)
	for ing in req:
		avail[ing] = int(avail[ing]) - req[ing]
	return true

## 미충족(완성/조리중으로 안 덮인) 주문들의 필요 재료 - 보드 재료.
func _needed_ingredients() -> Dictionary:
	var need := {}
	for rid in _distinct_order_ids():
		var unc := _count_orders(rid) - _count_dishes(rid) - _count_cooking(rid)
		if unc <= 0:
			continue
		for ing in Buffs.required_ingredients(rid):
			need[ing] = int(need.get(ing, 0)) + unc
	for ing in ingredients:                # 이미 보드에 있는 재료 차감
		if need.has(ing):
			need[ing] = int(need[ing]) - 1
	var out := {}
	for ing in need:
		if int(need[ing]) > 0:
			out[ing] = int(need[ing])
	return out


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
		"accepted": _accepted_today,
		"order_lost": _order_lost_today,
		"same_max": same_max,
		"day_revenue": s.day_revenue,
		"cash": s.cash,
		"rent": s.rent,
	}
	var bonus := Buffs.day_end_bonus(ctx)
	if bonus != 0:
		s.earn(bonus)


# ── 유틸 ──────────────────────────────────────────────────
func _distinct_order_ids() -> Array:
	var seen := {}
	for o in orders:
		seen[o["id"]] = true
	return seen.keys()

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
