class_name Board
extends CenterContainer
## 슬롯 그리드 — 재료/주문/완성품 칸 + 도구석. 세션마다 슬롯 수만큼 재구성.
## 재료 조회·소비, 빈 칸 조회 담당. (도구석은 그리드 마지막 칸들)

signal tool_tapped(tool: ToolStation)

var slots: Array[Slot] = []
var tools: Array[ToolStation] = []
var now_provider: Callable = func() -> float: return 0.0  ## 게임 클록(초) 공급 — main이 세션에 연결. 완성품 나이 스탬프용.
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

	# 도구석 수 = 기본 + 구조 버프(11: tool_bonus). 슬롯 수는 호출 측이 effective_slots로 전달.
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


## 빈 슬롯 수 — 조리 가속(카드37) 입력.
func empty_slot_count() -> int:
	var n := 0
	for s in slots:
		if s.is_empty():
			n += 1
	return n


## 판매 ctx 집계용 — 슬롯/도구석에 놓인 카드 종류별 개수.
## filled(채운 칸)·empty(빈 슬롯)·orders·dishes·ingr을 sim_core._sale_ctx와 같은 뜻으로 센다.
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
		# BuffCard 등 그 외 카드는 채워진 칸이지만 종류 집계엔 안 셈(버프칸은 별도)
	# 도구석 위 완성품(DONE)도 미서빙 완성품 → dishes에 합산
	for t in tools:
		if t.get_dish() != null:
			dishes += 1
	return {"orders": orders, "dishes": dishes, "ingr": ingr, "empty": empty}


## 서빙 가능한 완성품의 레시피 id 집합(슬롯+도구석). 주문 카드 "서빙 가능" 표시용.
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
