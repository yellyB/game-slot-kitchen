class_name Board
extends CenterContainer

signal tool_tapped(tool: ToolStation)

var slots: Array[Slot] = []
var tools: Array[ToolStation] = []
var now_provider: Callable = func() -> float: return 0.0
var _grid: GridContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = GridContainer.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.columns = Config.BOARD_COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	add_child(_grid)


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


func consume_ingredients(recipe_id: String) -> void:
	for iid in Recipes.get_def(recipe_id).get("ingredients", []):
		for s in slots:
			var c := s.get_card()
			if c is IngredientCard and c.ing_id == iid:
				s.clear()
				break
