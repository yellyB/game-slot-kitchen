class_name SimCore
extends RefCounted
## 헤드리스 시뮬레이션 — 한 판(전 일차)을 dt 스텝으로 빠르게 돌려 지표 반환.
## 실게임의 Session(하루 루프·경제·스폰·승패)을 그대로 재사용하고,
## 손님 생애주기(큐→주문→조리→서빙)만 순수 데이터로 얹는다. UI 없음.
##
## v1 단순화: 재료 꺼내는 시간(창고 트립)은 무시(재료 항상 있다고 가정).
##   → 조리 처리량·인내심·서빙·경제 위주. 트립 비용은 v2에서 추가.
## 수치는 전부 Stats 경유(버프 자동 반영). 버프 로드아웃은 run()에서 전역 Buffs에 세팅.

const DT := 0.1

var session: Session
var queue: Array = []    # 큐 대기: [{id, pat}]  (주문 대기 인내심)
var orders: Array = []   # 슬롯 주문: [{id, pat}] (음식 대기 인내심)
var tools: Array = []    # 도구: [{id, t}]  (id=="" 유휴)
var dishes: Array = []   # 완성품(미서빙): [id]

var _served := 0
var _lost := 0
var _last := {}


## 한 판 실행. buff_loadout=보유 버프 id 배열, run_seed=RNG 시드.
## 반환: {won, days, cash, served, lost}
func run(buff_loadout: Array = [], run_seed := 0) -> Dictionary:
	seed(run_seed)
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_ended.connect(func(s): _last = s)

	tools.clear()
	for i in Config.TOOL_COUNT:
		tools.append({"id": "", "t": 0.0})

	session.start_run()   # 내부에서 Buffs.clear() 호출하므로, 버프는 이 뒤에 세팅
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


func _reset_day_consumables() -> void:
	queue.clear()
	orders.clear()
	dishes.clear()
	for t in tools:
		t["id"] = ""
		t["t"] = 0.0


## 시뮬 1스텝: 시간 진행 → 인내심/조리 진행 → 탐욕 플레이어 행동.
func _step() -> void:
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


## 완성품을 매칭되는 가장 급한 주문에 서빙 → 돈.
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


## 유휴 도구에 "가장 급하고 아직 준비 안 된" 주문의 레시피를 조리 시작.
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
	# 주문 급한 순으로 보되, 이미 완성품/조리중으로 충당되는 레시피는 건너뜀.
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
	var cap := session.slots - Buffs.owned().size()   # 버프가 슬롯 점유
	while not queue.is_empty() and orders.size() < cap:
		# 가장 급한(인내심 낮은) 큐 손님부터 접수
		var best := 0
		for i in queue.size():
			if queue[i]["pat"] < queue[best]["pat"]:
				best = i
		orders.append({"id": queue[best]["id"], "pat": Stats.dish_patience()})
		queue.remove_at(best)


# ── 유틸 ──────────────────────────────────────────────────
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
