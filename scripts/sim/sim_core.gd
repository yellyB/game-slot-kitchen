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

var session: Session
var queue: Array = []       # 큐 대기: [{id, pat}]
var orders: Array = []      # 슬롯 주문: [{id, pat, max, born}]
var tools: Array = []       # 도구: [{id, t}]
var dishes: Array = []      # 완성품(미서빙): [{id, born}]
var ingredients: Array = [] # 보드 위 재료 카드(멀티셋): [ingredient_id, ...]

var force_menu := ""        # 세팅 시 모든 손님이 이 메뉴만 주문(메뉴별 효율 측정용)
var _busy := 0.0            # 창고 트립·손동작(핸들링) 등으로 플레이어가 묶인 시간(초)
var _handle := 0.0          # >0이면 현실 모드: 한 스텝에 한 동작 + 동작당 핸들링 타임(SIM_HANDLE)
var _miss := 0.0            # 사람 놓침 확률(현실 모드, SIM_MISS)
var _fumble := 0.0          # 반응/주의 누락 확률(현실 모드, SIM_FUMBLE) — 매 동작 기회에 이 확률로 아무것도 안 함(사람은 매 순간 최적 못 침)
var _now := 0.0
var _served := 0
var _lost := 0
var _lost_miss := 0    # SIM_MISS 응대 실패(주의력 병목)
var _lost_queue := 0   # 큐 대기 만료 = 제때 접수 못 함(접수 병목)
var _lost_order := 0   # 주문 카드 만료 = 제때 조리·서빙 못 함(조리/서빙 병목)
var _lost_qfull := 0   # 큐가 꽉 차 돌려보낸 손님(진단용, _lost엔 미포함)
var _last := {}

# 하루 스코프 집계(정산용)
var _visited_today := 0
var _served_today := 0
var _accepted_today := 0
var _order_lost_today := 0
var _missed_today := 0   # 놓친 손님(대기열+주문 이탈) — 완벽/우수정산 처리율 분모(main과 동치)
var _served_by_menu := {}


## shop_enabled: 하루 사이 상점(슬롯/버프 구매) 활성. 통제된 로드아웃 비교 땐 false로.
func run(buff_loadout: Array = [], run_seed := 0, shop_enabled := true, slots_only := false) -> Dictionary:
	seed(run_seed)
	_handle = float(OS.get_environment("SIM_HANDLE")) if OS.has_environment("SIM_HANDLE") else 0.0
	_miss = float(OS.get_environment("SIM_MISS")) if OS.has_environment("SIM_MISS") else 0.0
	_fumble = float(OS.get_environment("SIM_FUMBLE")) if OS.has_environment("SIM_FUMBLE") else 0.0
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_closing.connect(_on_day_closing)
	session.day_ended.connect(func(s): _last = s)

	session.start_run()   # 내부 Buffs.clear() → 버프는 이 뒤에 세팅
	Buffs.clear()
	for b in buff_loadout:
		Buffs.add(b)

	var result := {"won": false, "days": 0, "cash": 0, "served": 0, "lost": 0, "slots": 0, "buffs": 0, "score": 0}
	# 레버리지 측정용: SIM_MAXDAY까지 죽지 않고 진행하며 총 매출(점수) 누적(SIM_NOFAIL).
	var max_day := int(OS.get_environment("SIM_MAXDAY")) if OS.has_environment("SIM_MAXDAY") else 12   # 기본 지평선=3개월(12주). 실패 주엔 중지(SIM_NOFAIL 미설정 시)
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
		session.pay_rent()   # 현금 통과(점수 미달·현금≥월세) 시 실제로 현금 차감 — 경제 카드가 의미 갖게
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
			session.earn(Config.week_reward(session.day, _served_today), false)   # 실적검사 통과 후 주 클리어 보상
		if shop_enabled:
			_shop(slots_only)            # 벌어서 슬롯/버프 재투자(slots_only=버프 안 삼, 단독 카드 측정용)
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
	session.free()
	return result


## 하루 사이 상점 — 돈은 상점 전용(가게세는 점수로 통과)이라 예비금 없이 다 투자.
## 실플레이 관측: 현금 항상 바닥, 버프칸 가득까지 채움. 슬롯·버프를 살 수 있는 만큼 교대로 산다.
func _shop(slots_only := false) -> void:
	var progressed := true
	while progressed:
		progressed = false
		if session.slots < Config.MAX_SLOTS \
				and session.cash >= Config.slot_price(session.day, session.slots - Config.START_SLOTS):
			if session.buy_slot():
				progressed = true
		if slots_only:
			continue                     # 단독 카드 측정: 슬롯만 성장, 버프 스택 노이즈 배제
		# 버프도 슬롯을 점유 → 주문 처리공간(최소 MAX_ORDERS)이 남을 때만 추가.
		if not Buffs.is_full() and session.slots - Buffs.owned().size() > Config.MAX_ORDERS \
				and session.cash >= Config.BUFF_PACK_PRICE:
			var pack: Array = session.buy_buff_pack()
			if not pack.is_empty():
				var pick := _pick_buff(pack)
				if pick != "":
					Buffs.add(pick)
				progressed = true


## 팩에서 카드 선택. 기본=최고(_buff_score 1위). SIM_PICK_RANK=k면 k번째로 좋은 걸 고름(현실 플레이어 모델).
func _pick_buff(pack: Array) -> String:
	var cands: Array = []
	for id in pack:
		if not Buffs.owned().has(id):
			cands.append({"id": id, "s": _buff_score(id)})
	if cands.is_empty():
		return ""
	cands.sort_custom(func(a, b): return a["s"] > b["s"])
	var rank := int(OS.get_environment("SIM_PICK_RANK")) if OS.has_environment("SIM_PICK_RANK") else 1
	return cands[mini(rank - 1, cands.size() - 1)]["id"]   # k번째(1=최고). 팩이 그보다 적으면 맨 끝(제일 나쁜) 선택

# 실측 카드 효율(Δ점수, 12주 NOFAIL·상점off 단독) — 봇 픽 우선순위. --simbuffs 측정→반영.
const EFF := {"rt_fast3": 11973, "rt_every7": 5829, "rt_streak3": 4694, "ramp_t5": 3243, "ramp_t2": 2988, "ramp_t1": 2861, "ramp_t4": 2849, "sc_ingr": 2676, "ramp_t3": 2669, "sc_order": 2126, "mp_t56": 1938, "sale_t56": 1938, "sale_pat": 1857, "sale_flat3": 1844, "mult_all": 1844, "mp_t12": 1836, "sale_t12": 1836, "ramp_t6": 1798, "sale_t34": 1785, "mp_t34": 1785, "sc_fill_b": 1678, "sale_fresh": 1652, "sale_full": 1633, "sc_fill_a": 1556, "sale_late": 1340, "sale_burn": 1045, "accum_sale": 802, "prob_bonus": 793, "prob_x2": 703, "cook": 618, "tool_slot": 552, "sc_dish": 521, "day_len": 505, "sc_buff_a": 469, "inst_cook": 271, "sc_buff_b": 253, "inst_order": 249, "settle_100": 226, "settle_90": 220, "sale_fast": 175, "sale_risk": 168, "wh_fast": 142, "opt_flour": 142, "wh_chance": 135, "sale_cash": 133, "dmd_t56": 100, "cook_empty": 93, "dmd_cream": 62, "dmd_choco": 26, "sale_crit": 16, "sc_empt_a": 14, "dmd_t34": 7, "buff_slot": 0, "sc_empt_b": -1, "opt_egg": -2, "nest_egg": -14, "rent_skip": -16, "onlost_x2": -23, "onlost_pay": -49, "auto_cook": -57, "interest": -57, "settle_same": -57, "settle_leave": -57, "auto_serve": -57, "settle_perfect": -57, "sale_addon": -57, "rent_down": -57, "shop_disc": -57, "pack_more": -57, "no_buy": -57, "reveal": -57, "serve_tip": -60, "patience": -62, "pat_extend": -63, "pat_down": -68, "dmd_bean": -137, "dmd_t12": -277, "opt_bean": -374}

func _buff_score(id: String) -> int:
	if BuffDefs.get_def(id).get("blocked", false):
		return -9999
	return int(EFF.get(id, 0))   # 실측 효율. 미측정 카드는 0(중립)


func _rebuild_tools() -> void:
	tools.clear()
	for i in maxi(1, Config.TOOL_COUNT + Buffs.tool_bonus()):
		tools.append({"id": "", "t": 0.0})


func _reset_day_consumables() -> void:
	queue.clear()
	orders.clear()
	dishes.clear()
	ingredients.clear()
	Buffs.reset_day()   # #45 적립 하루 리셋
	_rebuild_tools()   # 도구 수 = TOOL_COUNT + 도구버프(상점 구매 반영)
	_busy = 0.0
	_now = 0.0
	_visited_today = 0
	_served_today = 0
	_accepted_today = 0
	_order_lost_today = 0
	_missed_today = 0
	_served_by_menu = {}


## 1스텝: 시간·스폰 → 인내심/조리 진행. 플레이어가 트립 중이면(_busy) 행동 스킵.
## _handle>0(현실 모드): 한 스텝에 한 동작만 + 동작당 손동작 시간(사람 처리량 상한).
## _handle==0(이상 모드): 기존대로 즉시 다중 처리(조리·트립만 시간 소모).
func _step() -> void:
	_now += DT
	session.tick(DT)
	_decay_patience()
	_advance_cooking()
	if _handle > 0.0:
		_step_realistic()
		return
	_serve()                    # 트립 중에도 완성품은 즉시 서빙(유능한 플레이어)
	if _busy > 0.0:
		_busy -= DT
		return
	_start_cooking()
	_accept_from_queue()
	_maybe_fetch()


## 현실 모드 스텝 — 손이 비었을 때만 우선순위 1동작 수행하고 그 손동작 시간만큼 묶인다.
## 우선순위: 서빙 > 조리 시작 > 주문 접수 > 창고 트립. (사람은 동시에 여러 손동작 불가)
func _step_realistic() -> void:
	if _busy > 0.0:
		_busy -= DT
		return
	if _fumble > 0.0 and randf() < _fumble:
		return                       # 반응/주의 누락 — 사람은 매 순간 최적 행동을 못 함
	if _serve_one():
		_busy = Config.SIM_HANDLE_SERVE * _handle
		return
	if _start_cook_one():
		_busy = Config.SIM_HANDLE_COOK * _handle
		return
	if _accept_one():
		_busy = Config.SIM_HANDLE_ACCEPT * _handle
		return
	var grabbed := _maybe_fetch()   # 트립비는 _maybe_fetch가 _busy에 설정 → 재료 배치 시간만 가산
	if grabbed > 0:
		_busy += Config.SIM_HANDLE_PLACE * _handle * float(grabbed)


func _on_spawn() -> void:
	if queue.size() >= Config.MAX_QUEUE:
		_lost_qfull += 1
		return
	_visited_today += 1
	if _miss > 0.0 and randf() < _miss:   # 응대 못 한 손님(처리율 = 1-SIM_MISS)
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


## 현실 모드용 단일 동작 — 완성품↔주문 매칭 1건만 서빙. 성공 시 true.
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


## 현실 모드용 단일 동작 — 유휴 도구 1개에 가장 급한 조리 시작. 성공 시 true.
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


## 현실 모드용 단일 동작 — 가장 급한 대기 손님 1명 접수. 성공 시 true.
func _accept_one() -> bool:
	var cap := _serve_cap()
	var order_cap := mini(Config.MAX_ORDERS, maxi(1, cap - 3))   # 조리·재료 공간 확보(빡빡한 보드 데드락 방지)
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
	if Buffs.consume_instant_order():   # 60
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


## 유휴 도구에 조리 시작 — 필요 재료가 보드에 다 있는 가장 급한 주문부터.
func _start_cooking() -> void:
	var filled := _board_used()   # 작업 카드 수(주문+완성품+재료) — 카드38(깨끗한 주방)
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
			t["t"] = Stats.cook_time(rid, filled)


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
	# 주문 상한 + 물리적 슬롯 여유 + 조리·재료 공간 예비. 나머지 슬롯=재료/완성품용.
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
		if Buffs.consume_instant_order():   # 60
			dishes.append({"id": rid, "born": _now})


## 조리 못 하는 주문이 있고 빈 슬롯이 있으면 창고 트립 1회(영업시간 소모, _busy).
## 급한 주문부터 "완전한 세트"를 채울 만큼만 확보(반쪽 재료 낭비 방지) → 트립당 조리 최대 해금.
## 반환: 이번 트립에 가져온 재료 개수(현실 모드에서 배치 핸들링 타임 계산용). 0=트립 없음.
func _maybe_fetch() -> int:
	var space := _empty_slots()
	if space <= 0:
		return 0
	var avail := _ingredient_counts()   # 보드에 있는 재료(주문에 예약해가며 차감)
	var sorted_orders := orders.duplicate()
	sorted_orders.sort_custom(func(a, b): return a["pat"] < b["pat"])
	var grab: Array = []
	for o in sorted_orders:
		if grab.size() >= space:
			break
		var rid: String = o["id"]
		if _count_dishes(rid) + _count_cooking(rid) >= _count_orders(rid):
			continue                      # 이미 완성/조리중으로 충당
		var trial: Dictionary = avail.duplicate()
		var missing: Array = []
		for ing in Buffs.required_ingredients(rid):
			if int(trial.get(ing, 0)) > 0:
				trial[ing] = int(trial[ing]) - 1   # 보드/기예약분 우선
			else:
				missing.append(ing)
		if grab.size() + missing.size() <= space:   # 완전한 세트가 들어갈 때만 확보(반쪽 X)
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
	var money_g := int(db["money"])   # 주 클리어 보상은 실적검사 통과 후 지급(메인 루프) — 여기선 손절 등만
	if money_g != 0:
		s.earn(money_g, false)


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


## 로그 리플레이 — 주차별 빌드(script[i]={buffs,slots}, 구매비 차감)를 주입해 각 주 재시뮬.
func run_replay(script: Array, seed_v := 0, handle := 0.6) -> Array:
	seed(seed_v)
	_handle = handle
	_miss = float(OS.get_environment("SIM_MISS")) if OS.has_environment("SIM_MISS") else 0.25
	session = Session.new()
	session.spawn_requested.connect(_on_spawn)
	session.day_closing.connect(_on_day_closing)
	session.day_ended.connect(func(s): _last = s)
	session.start_run()   # day 1 running
	Buffs.clear()
	var out: Array = []
	var prev_slots := session.slots
	for wi in script.size():
		var wk: Dictionary = script[wi]
		# 슬롯 증가분 = 상점 구매 → 비용 차감
		var new_slots := int(wk.get("slots", session.slots))
		while prev_slots < new_slots:
			session.cash -= Config.slot_price(session.day, prev_slots - Config.START_SLOTS)
			prev_slots += 1
		session.slots = new_slots
		# 신규 버프 획득 → 팩값 차감
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
		# 빌드는 로그에서 고정 주입 → 시뮬 쪽 점수 미달로 중단하지 않고 전 주를 끝까지 재현(대조용).
		if wi + 1 < script.size():
			session.advance_day()
	session.free()
	return out
