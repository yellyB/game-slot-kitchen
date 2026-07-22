class_name Stats
extends RefCounted

static func order_patience() -> float:
	return Buffs.mod("patience_mult", Config.PATIENCE_ORDER)

static func dish_patience() -> float:
	return Buffs.mod("patience_mult", Config.PATIENCE_DISH)

static func cook_time(recipe_id: String) -> float:
	return Buffs.mod("cook_mult", float(Recipes.get_def(recipe_id).get("cook_time", 5.0)))

static func sell_price(recipe_id: String) -> int:
	var def := Recipes.get_def(recipe_id)
	var p := Buffs.mod("price_mult", float(def.get("price", 0)))
	p = Buffs.mod("price_mult_" + str(def.get("tag", "")), p)
	return int(round(p))

static func warehouse_cost() -> float:
	return Buffs.mod("warehouse_mult", Config.WAREHOUSE_EXIT_COST)

static func random_recipe() -> String:
	var ids := Recipes.all_ids()
	var weights := []
	var total := 0.0
	for id in ids:
		var def := Recipes.get_def(id)
		var tier := int(def.get("tier", 1))
		var base := maxf(1.0, 7.0 - tier)
		var w := Buffs.mod("demand_" + str(def.get("tag", "")), base)
		weights.append(w)
		total += w
	var r := randf() * total
	var acc := 0.0
	for i in ids.size():
		acc += weights[i]
		if r <= acc:
			return ids[i]
	return ids[ids.size() - 1]
