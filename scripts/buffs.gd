extends Node
## 활성 버프 상태 (autoload "Buffs"). 보유 버프의 효과를 훅별로 적용.
## 패시브 곱연산은 mod(), 판매 보너스는 sale_amount(), 그 외 개장/마감/이탈/구조 훅 제공.
## 상태: 램프/카운터/스트릭 등은 런 스코프(clear에서 리셋). 일부는 reset_day()로 하루 스코프.

var _owned: Array[String] = []

# 런 스코프 상태(clear에서 리셋)
var _ramp_bonus: Dictionary = {}   # recipe_id → 메뉴가격 누적(원, 정수). 24~29·42~44.
var _serve_count := 0              # 누적 서빙 수 (43·60)
var _cook_count := 0               # 누적 조리 시작 수 (61)
var _streak_id := ""               # 연속 같은메뉴 (42)
var _streak_n := 0
var _serve_times: Array[float] = []  # 최근 서빙 시각 (44)
var _accum := 0                    # 적립 누적액(원) (45)
var _double_next := false          # 다음 획득 2배 (72)
var _instant_order := false        # 다음 주문 즉시완료 대기 (60)


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


# ── 패시브 곱연산 게이트웨이 ──────────────────────────────
## base에 stat 곱연산 버프(mult 필드)를 전부 곱해 반환.
##   stat: cook_mult · patience_mult · day_mult · rent_mult
func mod(stat: String, base: float) -> float:
	var m := 1.0
	for id in _owned:
		var mult: Dictionary = BuffDefs.get_def(id).get("mult", {})
		if mult.get("stat", "") == stat:
			m *= float(mult.get("value", 1.0))
	return base * m


# ── 구조(11,12) ───────────────────────────────────────────
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


# ── 인내심 가산(66) / 조리 빈슬롯 가속(37) ────────────────
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


# ── 수요 가중(15~20) ──────────────────────────────────────
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


# ── 메뉴가격(base + 램프누적 + 등급별%인상) ───────────────
func ramp_bonus(recipe_id: String) -> int:
	return int(_ramp_bonus.get(recipe_id, 0))

func menu_price(recipe_id: String) -> int:
	var def := Recipes.get_def(recipe_id)
	var base := float(def.get("price", 0))
	var tier := int(def.get("tier", 0))
	var mp := base + float(ramp_bonus(recipe_id))   # 24~29·42~44 누적
	var tp := 0.0
	for id in _owned:                                # 21~23 등급별 %인상
		var m: Dictionary = BuffDefs.get_def(id).get("menu_price", {})
		if not m.is_empty() and tier in m.get("tiers", []):
			tp += float(m.get("pct", 0.0))
	return int(round(mp * (1.0 + tp)))


# ── 판매 금액 계산(판매금/추가금 전 카드) ─────────────────
## ctx: {filled,empty,orders,dishes,buffs,now,dish_age,order_age,pat_frac,cash,day_revenue}
## 반환: {amount:int, penalty:int, discard:String}  (penalty·discard는 sim이 처리)
func sale_amount(recipe_id: String, ctx: Dictionary) -> Dictionary:
	var mp := menu_price(recipe_id)
	var tier := int(Recipes.get_def(recipe_id).get("tier", 0))
	var pct := 0.0          # 메뉴가격에 곱할 추가 %(합연산)
	var flat := 0           # 정액 추가금(원)
	var addon_pct := 0.0    # 앰프(57): 추가금 재증폭
	var do_double := false  # 41 확률 2배
	var accum_pct := 0.0    # 45 이번 판매 적립율
	var penalty := 0
	var discard := ""

	for id in _owned:
		var s: Dictionary = BuffDefs.get_def(id).get("sale", {})
		if s.is_empty():
			continue
		match s.get("type", ""):
			"flat":
				pct += float(s["pct"])
			"tier":
				if tier in s.get("tiers", []):
					pct += float(s["pct"])
			"count":
				pct += float(s.get("base", 0.0)) + float(s.get("step", 0.0)) * float(_ctx_count(s.get("per", ""), ctx))
			"full":
				if int(ctx.get("empty", -1)) == 0:
					pct += float(s["pct"])
			"prob_double":
				if randf() < float(s.get("chance", 0.0)):
					do_double = true
			"prob_pct":
				if randf() < float(s.get("chance", 0.0)):
					pct += float(s["pct"])
			"cash":
				flat += int(round(float(ctx.get("cash", 0)) * float(s["pct"])))
			"risk":
				pct += float(s["pct"])
				if randf() < float(s.get("chance", 0.0)):
					discard = id
					penalty += int(round(float(ctx.get("day_revenue", 0)) * float(s.get("penalty_pct", 0.0))))
			"fresh":
				if float(ctx.get("dish_age", 1e9)) <= float(s["within"]):
					pct += float(s["pct"])
			"fast_order":
				if float(ctx.get("order_age", 1e9)) <= float(s["within"]):
					pct += float(s["pct"])
			"late":
				if float(ctx.get("order_age", 0.0)) >= float(s["after"]):
					pct += float(s["pct"])
			"consumed":
				pct += float(s["pct"]) * (1.0 - float(ctx.get("pat_frac", 1.0)))
			"critical":
				if float(ctx.get("pat_frac", 1.0)) <= Config.PATIENCE_LOW_FRAC:
					pct += float(s["pct"])
			"addon":
				addon_pct += float(s["pct"])
			"accum":
				flat += _accum                       # 적립분 먼저 획득
				accum_pct += float(s["pct"])

	var bonus := int(round(float(mp) * pct)) + flat
	if addon_pct > 0.0:
		bonus += int(round(float(bonus) * addon_pct))   # 57: 추가금 재증폭
	var amount := mp + bonus
	if do_double:
		amount *= 2
	if _double_next:                                     # 72
		amount *= 2
		_double_next = false
	if accum_pct > 0.0:                                  # 45: 획득 후 누적
		_accum += int(round(float(amount) * accum_pct))
	return {"amount": amount, "penalty": penalty, "discard": discard}


func _ctx_count(per: String, ctx: Dictionary) -> int:
	match per:
		"buff": return int(ctx.get("buffs", 0))
		"filled": return int(ctx.get("filled", 0))
		"empty": return int(ctx.get("empty", 0))
		"orders": return int(ctx.get("orders", 0))
		"dishes": return int(ctx.get("dishes", 0))
		"ingr": return int(ctx.get("ingr", 0))
	return 0


# ── 재료 fetch(v2): 필요 재료 필터(13,14) / 트립 무료 확률(4) ──
## 조리에 실제로 필요한 재료 — 계란/밀가루 생략 버프면 제외.
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

## 창고 트립이 공짜(시간 0)일 확률 — 카드4(30%). 여러 장이면 최대값.
func trip_free_chance() -> float:
	var c := 0.0
	for id in _owned:
		c = maxf(c, float(BuffDefs.get_def(id).get("trip_free", 0.0)))
	return c


# ── 서빙/조리 이벤트 훅 ───────────────────────────────────
## 판매 직후 호출 — 램프(24~29)·트리거(42~44)·카운터 갱신. "판매 후 누적".
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

## 조리 시작 시 호출 — 61(6번째마다 즉시완료)이면 true.
func on_cook_start() -> bool:
	_cook_count += 1
	for id in _owned:
		var ins: Dictionary = BuffDefs.get_def(id).get("instant", {})
		if not ins.is_empty() and ins.get("kind", "") == "cook" and _cook_count % int(ins["n"]) == 0:
			return true
	return false

## 60: 다음 주문 즉시완료 대기 소비.
func consume_instant_order() -> bool:
	if _instant_order:
		_instant_order = false
		return true
	return false


# ── 손님 이탈(71,72) ──────────────────────────────────────
## 주문 낸 손님이 못 받고 떠날 때 호출 → 즉시 획득할 보상액(원). 72는 다음 획득 2배 예약.
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


# ── 개장/마감 정산(62 / 63~65,73,50) ──────────────────────
## 개장 보너스(62 이자). cash 기준.
func day_start_bonus(cash: int) -> int:
	var g := 0
	for id in _owned:
		var e: Dictionary = BuffDefs.get_def(id).get("economy", {})
		if e.get("kind", "") == "interest":
			g += int(round(float(cash) * float(e["pct"])))
	return g

## 마감 보너스/차감(63~65,73 정산 + 50 가게세차감). ctx: {served,visited,order_lost,accepted,same_max,day_revenue,cash,rent}
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

## 폐기(48) — 소유 목록에서 제거.
func discard(id: String) -> void:
	_owned.erase(id)
