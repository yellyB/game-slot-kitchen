extends Node
## 활성 버프 상태 (autoload "Buffs"). 보유 버프의 효과를 훅별로 적용.
## 패시브 곱연산은 mod(), 판매 보너스는 sale_amount(), 그 외 개장/마감/이탈/구조 훅 제공.
## 상태: 램프/카운터/스트릭 등은 런 스코프(clear에서 리셋). 일부는 reset_day()로 하루 스코프.

var _owned: Array[String] = []
var _slot_pos: Dictionary = {}   # buff_id → 마지막 배치 슬롯 인덱스. 하루 리빌드 때 이 칸으로 복원(런 스코프).

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
var _mature_age := {}              # 만기 적금(78) — 버프별 획득 후 경과 주


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


## 하루 시작 시 호출 — 하루 스코프 리셋. #45 적립이 런 내내 누적돼 폭주하는 것 방지(매일 초기화).
func reset_day() -> void:
	_accum = 0


func add(id: String) -> void:
	if _owned.size() >= Config.MAX_BUFFS + buff_slot_bonus():
		return
	_owned.append(id)
	if BuffDefs.get_def(id).has("matures"):
		_mature_age[id] = 0
	Codex.discover(id)   # 획득 시 도감 발견 기록(영구 저장)


## 보유 버프 1개 제거(상점 판매/버리기). 슬롯 1칸 회복. 성공 시 true.
## 램프 버프면 그 등급 메뉴의 누적 가격도 리셋 — 안 그러면 팔아도 인상분이 남음.
func remove(id: String) -> bool:
	var idx := _owned.find(id)
	if idx < 0:
		return false
	_owned.remove_at(idx)
	_slot_pos.erase(id)   # 판 버프의 저장 위치도 제거 — 재구매 시 옛 칸으로 안 가게
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


## 버프 카드가 안착한 슬롯 인덱스 기록(드롭·리빌드 배치 시 slot.gd에서 호출).
func set_slot_pos(id: String, idx: int) -> void:
	_slot_pos[id] = idx


## 저장된 슬롯 인덱스(없으면 -1). 하루 시작 배치가 이 칸을 우선 사용, 무효면 first_empty 폴백.
func slot_pos(id: String) -> int:
	return int(_slot_pos.get(id, -1))


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

## 카드38(깨끗한 주방) 조리시간 감소율 — 보드에 놓인 카드(filled)가 적을수록 큼.
## reduction = clamp(max - filled*per, 0, max). filled 기준이라 슬롯 확장과 무관(확장-중립).
func cook_clean_reduction(filled: int) -> float:
	var r := 0.0
	for id in _owned:
		var c: Dictionary = BuffDefs.get_def(id).get("cook_clean", {})
		if not c.is_empty():
			r += maxf(0.0, float(c.get("max", 0.0)) - float(filled) * float(c.get("per", 0.0)))
	return r


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
## 버프 아이콘(이모지) — 이미지 없으니 이모지 사용. 빈 id면 ✨.
static func _buff_icon(id: String) -> String:
	if id == "":
		return "✨"
	return str(BuffDefs.get_def(id).get("icon", "✨"))


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
	var addon_id := ""
	var accum_id := ""
	var double_id := ""
	var mult := 1.0         # 배수 축(곱연산) — "mult" 타입 카드·대박·보복이 곱해서 쌓음(실수)
	var mult_id := ""       # 배수 기여 대표 버프(표시용)
	var breakdown: Array = [{"src": "base", "amount": mp, "recipe": recipe_id, "icon": str(Recipes.get_def(recipe_id).get("icon", "?"))}]   # 기본가(메뉴 아이콘) 먼저

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
			"mult":                       # 배수(곱연산) — 조건 충족 시 실수 배수를 곱함
				var mok := true
				match s.get("when", ""):
					"board_full": mok = int(ctx.get("empty", -1)) == 0
					"critical": mok = float(ctx.get("pat_frac", 1.0)) <= Config.PATIENCE_LOW_FRAC
				if mok:
					mult *= float(s["value"])
					mult_id = id
			"mult_count":                 # 개수 비례 배수 — 대상 1개당 step만큼 배수↑
				var mc := _ctx_count(s.get("per", ""), ctx)
				if mc > 0:
					mult *= 1.0 + float(s["step"]) * float(mc)
					mult_id = id
		# 이 버프의 기여금 — 누적 %로 증분 반올림(합이 총 보너스와 정확히 일치)
		var contrib := 0
		if dpct != 0.0:
			var new_pct := pct + dpct
			contrib += int(round(float(mp) * new_pct)) - int(round(float(mp) * pct))
			pct = new_pct
		if dflat != 0:
			contrib += dflat
			flat += dflat
		if contrib != 0:
			breakdown.append({"src": id, "amount": contrib, "buff": id, "icon": _buff_icon(id)})

	var bonus := int(round(float(mp) * pct)) + flat
	if addon_pct > 0.0:
		var add := int(round(float(bonus) * addon_pct))   # 57: 추가금 재증폭
		bonus += add
		if add != 0:
			breakdown.append({"src": "addon", "amount": add, "buff": addon_id, "icon": _buff_icon(addon_id)})
	var amount := mp + bonus
	if do_double:
		mult *= 2.0
		if mult_id == "":
			mult_id = double_id
	if _double_next:                                     # 72
		mult *= 2.0
		_double_next = false
	if mult > 1.0:
		var before := amount
		amount = int(round(float(amount) * mult))   # 실수 배수 → 반올림
		breakdown.append({"src": "double", "amount": amount - before, "buff": mult_id, "icon": _buff_icon(mult_id)})
	if accum_pct > 0.0:                                  # 45: 현재 적립분 획득 후, 이번 판매금의 %만 누적(복리 차단)
		var payout := _accum
		_accum += int(round(float(amount) * accum_pct))
		amount += payout
		if payout != 0:
			breakdown.append({"src": "accum", "amount": payout, "buff": accum_id, "icon": _buff_icon(accum_id)})
	return {"amount": amount, "penalty": penalty, "discard": discard, "breakdown": breakdown, "mult": mult}


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

## 생략 버프(13~15)로 더는 꺼낼 필요 없는 재료 집합 — 창고 타일 비활성 표시용.
func omitted_ingredients() -> Dictionary:
	var out := {}
	for id in _owned:
		var ing: String = BuffDefs.get_def(id).get("opt_ingredient", "")
		if ing != "":
			out[ing] = true
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

## 서빙 시 팁(76 짤랑이) — 확률 적중 시 즉시 획득할 돈(원). 미보유/미적중이면 0.
func serve_tip() -> int:
	var g := 0
	for id in _owned:
		var t: Dictionary = BuffDefs.get_def(id).get("tip", {})
		if t.is_empty():
			continue
		if randf() < float(t.get("chance", 0.0)):
			g += int(t.get("money", 0))
	return g

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
## 개장 보너스(63 이자). 보유현금 × pct(정액 이율).
func day_start_bonus(cash: int) -> int:
	var g := 0
	var c := float(maxi(0, cash))
	for id in _owned:
		var e: Dictionary = BuffDefs.get_def(id).get("economy", {})
		if e.get("kind", "") == "interest":
			g += int(round(float(e["pct"]) * c))
	return g

## 마감 보너스/차감(63~65,73 정산 + 50 가게세차감). ctx: {served,visited,order_lost,accepted,same_max,day_revenue,cash,rent}
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
	# 만기 적금(78 곗돈) — 얻고 N주 경과 시 파괴되며 정액 지급. 파괴 대상은 destroy로 반환.
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

## 폐기(48) — 소유 목록에서 제거.
func discard(id: String) -> void:
	_owned.erase(id)
