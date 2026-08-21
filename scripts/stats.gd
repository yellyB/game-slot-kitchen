class_name Stats
extends RefCounted

static func order_patience() -> float:
	return Buffs.mod("patience_mult", Config.PATIENCE_ORDER) + Buffs.patience_flat()

static func dish_patience() -> float:
	return Buffs.mod("patience_mult", Config.PATIENCE_DISH) + Buffs.patience_flat()

static func cook_time(recipe_id: String, filled := 999) -> float:
	var t := Buffs.mod("cook_mult", float(Recipes.get_def(recipe_id).get("cook_time", 5.0)))
	t *= maxf(0.1, 1.0 - Buffs.cook_clean_reduction(filled))
	return maxf(0.1, t)

static func day_length() -> float:
	return Buffs.mod("day_mult", Config.DAY_LENGTH)

static func sell_price(recipe_id: String) -> int:
	return Buffs.menu_price(recipe_id)

static func warehouse_cost() -> float:
	var base := Config.WAREHOUSE_EXIT_COST
	if OS.has_environment("SIM_TRIP"):
		base = float(OS.get_environment("SIM_TRIP"))
	return Buffs.mod("warehouse_mult", base)

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
