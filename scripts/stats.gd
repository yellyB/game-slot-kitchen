class_name Stats
extends RefCounted
## 게임 수치 단일 관리소. Config 기본값 × 버프를 적용한 "실효 수치"만 반환.
## 버프 존재 확인·적용은 오직 여기(또는 Buffs 훅). 손님·주문·조리·서빙 등은 이 수치만 바라본다.

static func order_patience() -> float:
	return Buffs.mod("patience_mult", Config.PATIENCE_ORDER) + Buffs.patience_flat()

static func dish_patience() -> float:
	return Buffs.mod("patience_mult", Config.PATIENCE_DISH) + Buffs.patience_flat()

## 조리시간 — 카드1(cook_mult) + 카드37(빈 슬롯당 -8%). empty=빈 슬롯 수.
static func cook_time(recipe_id: String, empty := 0) -> float:
	var t := Buffs.mod("cook_mult", float(Recipes.get_def(recipe_id).get("cook_time", 5.0)))
	t *= maxf(0.1, 1.0 - Buffs.cook_empty_step() * float(empty))
	return maxf(0.1, t)

static func day_length() -> float:
	return Buffs.mod("day_mult", Config.DAY_LENGTH)

## 메뉴가격(base + 램프누적 + 등급별 %인상). 판매금 보너스는 Buffs.sale_amount에서.
static func sell_price(recipe_id: String) -> int:
	return Buffs.menu_price(recipe_id)

static func warehouse_cost() -> float:
	var base := Config.WAREHOUSE_EXIT_COST
	if OS.has_environment("SIM_TRIP"):   # 실험용 손잡이: 트립 기본비용 오버라이드
		base = float(OS.get_environment("SIM_TRIP"))
	return Buffs.mod("warehouse_mult", base)

## 손님이 주문할 레시피 뽑기 — 등급 가중(Config.SPAWN_WEIGHTS) × 수요 버프(15~20).
static func random_recipe() -> String:
	var ids := Recipes.all_ids()
	var weights := []
	var total := 0.0
	for id in ids:
		var tier := int(Recipes.get_def(id).get("tier", 1))
		var w := float(Config.SPAWN_WEIGHTS[clampi(tier - 1, 0, Config.SPAWN_WEIGHTS.size() - 1)])
		w *= Buffs.demand_weight(id)
		weights.append(w)
		total += w
	var r := randf() * total
	var acc := 0.0
	for i in ids.size():
		acc += weights[i]
		if r <= acc:
			return ids[i]
	return ids[ids.size() - 1]
