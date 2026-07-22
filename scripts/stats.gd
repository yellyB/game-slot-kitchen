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
	return int(round(Buffs.mod("price_mult", Recipes.get_def(recipe_id).get("price", 0))))

static func warehouse_cost() -> float:
	return Buffs.mod("warehouse_mult", Config.WAREHOUSE_EXIT_COST)
