class_name Stats
extends RefCounted
## 게임 수치 단일 관리소. Config 기본값 × 버프를 적용한 "실효 수치"만 반환.
## 버프 존재 확인·적용은 오직 여기서. 손님·주문·조리·서빙 등은 이 수치만 바라본다.

static func order_patience() -> float:
	return Buffs.mod("patience_mult", Config.PATIENCE_ORDER)

static func dish_patience() -> float:
	return Buffs.mod("patience_mult", Config.PATIENCE_DISH)

static func cook_time(recipe_id: String) -> float:
	return Buffs.mod("cook_mult", float(Recipes.get_def(recipe_id).get("cook_time", 5.0)))

static func sell_price(recipe_id: String) -> int:
	return int(round(Buffs.mod("price_mult", float(Recipes.get_def(recipe_id).get("price", 0)))))

static func warehouse_cost() -> float:
	return Buffs.mod("warehouse_mult", Config.WAREHOUSE_EXIT_COST)

## 손님이 주문할 레시피 뽑기 — 등급별 가중(Config.SPAWN_WEIGHTS)으로 등장 확률 결정.
## 높은 등급(비싼 메뉴)일수록 가중이 낮아 드물게 등장.
static func random_recipe() -> String:
	var ids := Recipes.all_ids()
	var weights := []
	var total := 0.0
	for id in ids:
		var tier := int(Recipes.get_def(id).get("tier", 1))
		var w := float(Config.SPAWN_WEIGHTS[clampi(tier - 1, 0, Config.SPAWN_WEIGHTS.size() - 1)])
		weights.append(w)
		total += w
	var r := randf() * total
	var acc := 0.0
	for i in ids.size():
		acc += weights[i]
		if r <= acc:
			return ids[i]
	return ids[ids.size() - 1]
