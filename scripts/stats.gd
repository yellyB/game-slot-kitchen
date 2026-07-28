class_name Stats
extends RefCounted

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
