class_name Board
extends CenterContainer
## 슬롯 그리드(3×3) — 재료/주문/완성품 칸 + 도구석 2.
## 재료 조회·소비, 빈 칸 조회 담당.

signal tool_tapped(tool: ToolStation)

var slots: Array[Slot] = []
var tools: Array[ToolStation] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = Config.BOARD_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)

	for i in range(Config.BOARD_SLOTS):
		if i in Config.TOOL_SLOTS:
			var tool := ToolStation.new()
			tool.tapped.connect(tool_tapped.emit)
			tools.append(tool)
			grid.add_child(tool)
		else:
			var slot := Slot.new()
			slots.append(slot)
			grid.add_child(slot)


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
