class_name SimCore
extends RefCounted
## 헤드리스 시뮬레이션 — 한 판(전 일차)을 dt 스텝으로 빠르게 돌려 지표 반환.
## 실게임 Session(하루 루프·경제·스폰·승패)을 재사용하고, 손님 생애주기(큐→주문→조리→서빙)를
## 순수 데이터로 얹는다. 버프 효과는 Stats/Buffs 훅으로 반영(판매금·수요·정산·이탈·구조·자동화).
##
## v1 단순화: 재료 꺼내는 시간(창고 트립)은 무시(재료 항상 있음). → 조리/인내심/서빙/경제 위주.
##   재료·상점·정보성 카드는 버프.md '시뮬 미지원' 표 참고(blocked).

const DT := 0.1

var session: Session
var queue: Array = []    # 큐 대기: [{id, pat}]  (주문 대기 인내심)
var orders: Array = []   # 슬롯 주문: [{id, pat, max, born}] (음식 대기 인내심 + 접수시각)
var tools: Array = []    # 도구: [{id, t}]  (id=="" 유휴)
var dishes: Array = []   # 완성품(미서빙): [{id, born}]

var _now := 0.0          # 하루 내 경과(초) — 신선도/주문경과 타임스탬프용
var _served := 0
var _lost := 0
var _last := {}

# 하루 스코프 집계(정산용) — _reset_day_consumables에서 리셋
var _visited_today := 0
var _served_today := 0
var _accepted_today := 0
var _order_lost_today := 0
var _served_by_menu := {}


## 한 판 실행. buff_loadout=보유 버프 id 배열, run_seed=RNG 시드.
## 반환: {won, days, cash, served, lost}
func run(buff_loadout: Array = [], run_seed := 0) -> Dictionary:
	seed(run_seed)
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_closing.connect(_on_day_closing)
	session.day_ended.connect(func(s): _last = s)

	session.start_run()   # 내부에서 Buffs.clear() 호출하므로, 버프는 이 뒤에 세팅
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
			break                       # 가게세 못 냄 → 게임오버
		if _last.get("won", false):
			result["won"] = true
			break                        # 마지막날 통과 → 승리
		session.advance_day()            # 다음날 (상점은 v1 생략)

	result["cash"] = session.cash
	result["served"] = _served
	result["lost"] = _lost
	session.free()   # 트리에 없는 Node라 수동 해제(누수 방지)
	return result


func _rebuild_tools() -> void:
	tools.clear()
	for i in Config.TOOL_COUNT + Buffs.tool_bonus():   # 도구+1 버프(12)
		tools.append({"id": "", "t": 0.0})


func _reset_day_consumables() -> void:
	queue.clear()
	orders.clear()
	dishes.clear()
	for t in tools:
		t["id"] = ""
		t["t"] = 0.0
	_now = 0.0
	_visited_today = 0
	_served_today = 0
	_accepted_today = 0
	_order_lost_today = 0
	_served_by_menu = {}


## 시뮬 1스텝: 시간 진행 → 인내심/조리 진행 → 탐욕 플레이어 행동.
func _step() -> void:
	_now += DT
	session.tick(DT)          # 시간·스폰(_on_spawn)·마감 처리
	_decay_patience()
	_advance_cooking()
	_serve()
	_start_cooking()
	_accept_from_queue()


func _on_spawn() -> void:
	if queue.size() >= Config.MAX_QUEUE:
		return                # 큐 꽉 참 → 스폰 무시(게임과 동일)
	queue.append({"id": Stats.random_recipe(), "pat": Stats.order_patience()})
	_visited_today += 1


func _decay_patience() -> void:
	for i in range(queue.size() - 1, -1, -1):
		queue[i]["pat"] -= DT
		if queue[i]["pat"] <= 0.0:
			queue.remove_at(i)
			_lost += 1                    # 큐에서 이탈(주문 전) — onlost 대상 아님
	for i in range(orders.size() - 1, -1, -1):
		orders[i]["pat"] -= DT
		if orders[i]["pat"] <= 0.0:
			var rid: String = orders[i]["id"]
			orders.remove_at(i)
			_lost += 1
			_order_lost_today += 1
			var gain := Buffs.on_lost(rid)   # 71·72: 이탈 보상/다음획득2배
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


## 완성품을 매칭되는 가장 급한 주문에 서빙 → 돈(판매 파이프라인) + 이벤트 훅.
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
		var res := Buffs.sale_amount(rid, ctx)     # 판매금/추가금 전 카드
		session.earn(int(res["amount"]))
		if int(res.get("penalty", 0)) != 0:
			session.add_cash(-int(res["penalty"]))  # 48 폐기 페널티
		if res.get("discard", "") != "":
			Buffs.discard(res["discard"])
		Buffs.on_serve(rid, ctx)                    # 램프/트리거/카운터(판매 후 누적)
		orders.remove_at(best)
		dishes.remove_at(di)
		_served += 1
		_served_today += 1
		_served_by_menu[rid] = int(_served_by_menu.get(rid, 0)) + 1


## 판매 컨텍스트(판매금 카드용).
func _sale_ctx(order: Dictionary, dish: Dictionary) -> Dictionary:
	var filled := orders.size() + dishes.size()
	var cap := _serve_cap()
	var mx := float(order.get("max", 1.0))
	return {
		"filled": filled,
		"empty": maxi(0, cap - filled),
		"orders": orders.size(),
		"dishes": dishes.size(),
		"buffs": Buffs.owned().size(),
		"now": _now,
		"dish_age": _now - float(dish.get("born", _now)),
		"order_age": _now - float(order.get("born", _now)),
		"pat_frac": clampf(float(order["pat"]) / maxf(0.001, mx), 0.0, 1.0),
		"cash": session.cash,
		"day_revenue": session.day_revenue,
	}


## 유휴 도구에 "가장 급하고 아직 준비 안 된" 주문의 레시피를 조리 시작.
## 61(즉시조리)이면 도구 안 쓰고 즉시 완성품 생성.
func _start_cooking() -> void:
	var empty := maxi(0, _serve_cap() - (orders.size() + dishes.size()))
	for t in tools:
		if t["id"] != "":
			continue
		var rid := _pick_recipe_to_cook()
		if rid == "":
			break
		if Buffs.on_cook_start():        # 61: 6번째 조리마다 즉시완료
			dishes.append({"id": rid, "born": _now})
		else:
			t["id"] = rid
			t["t"] = Stats.cook_time(rid, empty)   # 37: 빈슬롯당 조리 가속


func _pick_recipe_to_cook() -> String:
	# 주문 급한 순으로 보되, 이미 완성품/조리중으로 충당되는 레시피는 건너뜀.
	var sorted_orders := orders.duplicate()
	sorted_orders.sort_custom(func(a, b): return a["pat"] < b["pat"])
	for o in sorted_orders:
		var rid: String = o["id"]
		var have := _count_dishes(rid) + _count_cooking(rid)
		var need := _count_orders(rid)
		if have < need:
			return rid
	return ""


func _accept_from_queue() -> void:
	var cap := _serve_cap()
	while not queue.is_empty() and orders.size() + dishes.size() < cap:
		var best := 0
		for i in queue.size():
			if queue[i]["pat"] < queue[best]["pat"]:
				best = i
		var rid: String = queue[best]["id"]
		orders.append({"id": rid, "pat": Stats.dish_patience(), "max": Stats.dish_patience(), "born": _now})
		queue.remove_at(best)
		_accepted_today += 1
		if Buffs.consume_instant_order():   # 60: 다음 주문 즉시완료(완성품 생성)
			dishes.append({"id": rid, "born": _now})


## 서빙 슬롯 용량 = 유효 슬롯(구조 버프 포함) - 버프 점유(버프칸 버프로 경감).
func _serve_cap() -> int:
	var occupied := maxi(0, Buffs.owned().size() - Buffs.buff_slot_bonus())
	return maxi(1, session.effective_slots() - occupied)


## 마감 정산(63~65,73,50) — 하루 집계로 보너스/차감 계산 후 반영(가게세 차감 전).
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
