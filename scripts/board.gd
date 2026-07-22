class_name Board
extends CenterContainer
## 슬롯 그리드 — 재료/주문/완성품 칸 + 도구석. 세션마다 슬롯 수만큼 재구성.
## 재료 조회·소비, 빈 칸 조회 담당. (도구석은 그리드 마지막 칸들)

signal tool_tapped(tool: ToolStation)

var slots: Array[Slot] = []
var tools: Array[ToolStation] = []
var _grid: GridContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = GridContainer.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.columns = Config.BOARD_COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	add_child(_grid)


## 슬롯 수만큼 그리드 재구성(도구석은 마지막 TOOL_COUNT칸).
func rebuild(slot_count: int) -> void:
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	slots.clear()
	tools.clear()

	var total := slot_count + Config.TOOL_COUNT
	for i in total:
		if i < slot_count:
			var slot := Slot.new()
			slots.append(slot)
			_grid.add_child(slot)
		else:
			var tool := ToolStation.new()
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


## 보드에 놓인 재료 개수 (ing_id → 개수).
func ingredient_counts() -> Dictionary:
	var have := {}
	for s in slots:
		var c := s.get_card()
		if c is IngredientCard:
			have[c.ing_id] = have.get(c.ing_id, 0) + 1
	return have


## B안: 필요재료가 보드에 전부 있어야 true.
func has_ingredients(recipe_id: String) -> bool:
	var have := ingredient_counts()
	var need := {}
	for iid in Recipes.get_def(recipe_id).get("ingredients", []):
		need[iid] = need.get(iid, 0) + 1
	for iid in need:
		if have.get(iid, 0) < need[iid]:
			return false
	return true


## 필요재료를 보드에서 소비(제거).
func consume_ingredients(recipe_id: String) -> void:
	for iid in Recipes.get_def(recipe_id).get("ingredients", []):
		for s in slots:
			var c := s.get_card()
			if c is IngredientCard and c.ing_id == iid:
				s.clear()
				break
