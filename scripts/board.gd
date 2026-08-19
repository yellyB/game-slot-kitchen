class_name Board
extends CenterContainer

signal tool_tapped(tool: ToolStation)

const BASE_SLOT := 104.0
const MAX_COLS := 5
const SEP := 8.0

var slots: Array[Slot] = []
var tools: Array[ToolStation] = []
var now_provider: Callable = func() -> float: return 0.0
var _grid: GridContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = GridContainer.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.columns = Config.BOARD_COLS
	_grid.add_theme_constant_override("h_separation", SEP)
	_grid.add_theme_constant_override("v_separation", SEP)
	add_child(_grid)
	resized.connect(_relayout)


func rebuild(slot_count: int) -> void:
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	slots.clear()
	tools.clear()

	var tool_count := Config.TOOL_COUNT + Buffs.tool_bonus()
	var total := slot_count + tool_count
	for i in total:
		if i < slot_count:
			var slot := Slot.new()
			slots.append(slot)
			_grid.add_child(slot)
		else:
			var tool := ToolStation.new()
			tool.now_provider = now_provider
			tool.tapped.connect(tool_tapped.emit)
			tools.append(tool)
			_grid.add_child(tool)
	_relayout()


func _relayout() -> void:
	var total := slots.size() + tools.size()
	if total == 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	var best_cols := Config.BOARD_COLS
	var best_edge := 0.0
	for cols in range(Config.BOARD_COLS, MAX_COLS + 1):
		var rows := int(ceil(float(total) / cols))
		var edge_w := (size.x - (cols - 1) * SEP) / cols
		var edge_h := (size.y - (rows - 1) * SEP) / rows
		var edge := minf(edge_w, edge_h)
		if edge > best_edge:
			best_edge = edge
			best_cols = cols
	best_edge = clampf(best_edge, 1.0, BASE_SLOT)
	_grid.columns = best_cols
	var s := Vector2(best_edge, best_edge)
	for ch in _grid.get_children():
		(ch as Control).custom_minimum_size = s


func shake_slots() -> void:
	for s in slots:
		_shake(s)

func _shake(n: Control) -> void:
	var base := n.position.x
	var a := 5.0
	var t := n.create_tween()
	t.tween_property(n, "position:x", base - a, 0.05).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:x", base + a, 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:x", base - a, 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:x", base + a, 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:x", base, 0.05).set_trans(Tween.TRANS_SINE)
	var f := n.create_tween()
	f.tween_property(n, "modulate", Palette.DANGER, 0.06).set_trans(Tween.TRANS_SINE)
	f.tween_property(n, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)


func first_empty_slot() -> Slot:
	for s in slots:
		if s.is_empty():
			return s
	return null


func is_full() -> bool:
	for s in slots:
		if s.is_empty():
			return false
	return true


func empty_slot_count() -> int:
	var n := 0
	for s in slots:
		if s.is_empty():
			n += 1
	return n


func slot_counts() -> Dictionary:
	var orders := 0
	var dishes := 0
	var ingr := 0
	var empty := 0
	for s in slots:
		var c := s.get_card()
		if c == null:
			empty += 1
		elif c is OrderCard:
			orders += 1
		elif c is DishCard:
			dishes += 1
		elif c is IngredientCard:
			ingr += 1
	for t in tools:
		if t.get_dish() != null:
			dishes += 1
	return {"orders": orders, "dishes": dishes, "ingr": ingr, "empty": empty}


func available_dish_ids() -> Dictionary:
	var ids := {}
	for s in slots:
		var c := s.get_card()
		if c is DishCard:
			ids[c.recipe_id] = true
	for t in tools:
		var d := t.get_dish()
		if d != null:
			ids[d.recipe_id] = true
	return ids


func ingredient_counts() -> Dictionary:
	var have := {}
	for s in slots:
		var c := s.get_card()
		if c is IngredientCard:
			have[c.ing_id] = have.get(c.ing_id, 0) + 1
	return have


func has_ingredients(recipe_id: String) -> bool:
	var have := ingredient_counts()
	var need := {}
	for iid in Recipes.get_def(recipe_id).get("ingredients", []):
		need[iid] = need.get(iid, 0) + 1
	for iid in need:
		if have.get(iid, 0) < need[iid]:
			return false
	return true


func take_ingredient_cards(recipe_id: String) -> Array:
	var out: Array = []
	for iid in Recipes.get_def(recipe_id).get("ingredients", []):
		for s in slots:
			var c := s.get_card()
			if c is IngredientCard and (c as IngredientCard).ing_id == iid:
				out.append({"card": c, "gpos": c.global_position, "size": c.size})
				var holder := c.get_parent()
				if holder:
					holder.remove_child(c)
				break
	return out
