class_name Board
extends CenterContainer
## 슬롯 그리드 — 재료/주문/완성품 칸 + 도구석. 세션마다 슬롯 수만큼 재구성.
## 재료 조회·소비, 빈 칸 조회 담당. (도구석은 그리드 마지막 칸들)

signal tool_tapped(tool: ToolStation)

const BASE_SLOT := 104.0   ## 슬롯 기본 한 변(px). 공간이 남으면 이 크기, 부족하면 자동 축소.
const MAX_COLS := 5        ## 가로 확장 상한(칸 늘리기 시 열 수 한도).
const SEP := 8.0           ## 슬롯 간격(h/v 공통).

var slots: Array[Slot] = []
var tools: Array[ToolStation] = []
var now_provider: Callable = func() -> float: return 0.0  ## 게임 클록(초) 공급 — main이 세션에 연결. 완성품 나이 스탬프용.
var _grid: GridContainer
var _shake_tw := {}   ## 슬롯별 진행 중 흔들림 트윈 — 반복 흔들림 시 겹침(왼쪽 드리프트) 방지

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = GridContainer.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.columns = Config.BOARD_COLS
	_grid.add_theme_constant_override("h_separation", SEP)
	_grid.add_theme_constant_override("v_separation", SEP)
	add_child(_grid)
	resized.connect(_relayout)   # 가용 공간 바뀌면 열 수·슬롯 크기 재계산


## 슬롯 수만큼 그리드 재구성(도구석은 마지막 TOOL_COUNT칸).
func rebuild(slot_count: int) -> void:
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	slots.clear()
	tools.clear()
	_shake_tw.clear()   # 이전 슬롯(해제됨) 흔들림 트윈 참조 정리

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
	_relayout()


## 가용 공간(남는 세로 + 가로)에 맞춰 열 수와 슬롯 한 변을 정한다.
## - 슬롯이 늘어 세로가 부족하면 먼저 열을 늘려(3→4→5) 행을 줄이고, 그래도 부족하면 슬롯을 축소.
## - 공간이 넉넉하면 기본 열(BOARD_COLS)·기본 크기(BASE_SLOT) 유지.
func _relayout() -> void:
	var total := slots.size() + tools.size()
	if total == 0 or size.x <= 0.0 or size.y <= 0.0:
		return
	# 후보 열 수마다 (가로·세로 모두 맞는) 슬롯 한 변을 구해, 가장 큰 변을 주는 열 수 선택.
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


## 거부 피드백 — 슬롯들이 좌우로 2회 왕복하며 흔들림(자리 없음/주문 꽉 참 시).
func shake_slots() -> void:
	for s in slots:
		_shake(s)

func _shake(n: Control) -> void:
	# 진행 중 흔들림이 있으면 죽이고 저장된 진짜 원위치로 복귀 — 안 그러면 중간 위치를
	# base로 캡처해 반복 시 슬롯이 왼쪽으로 누적 드리프트함.
	if _shake_tw.has(n) and _shake_tw[n] != null and (_shake_tw[n] as Tween).is_valid():
		(_shake_tw[n] as Tween).kill()
		n.position.x = n.get_meta("shake_base_x", n.position.x)
	else:
		n.set_meta("shake_base_x", n.position.x)   # 흔들림 없을 때의 위치 = 진짜 원위치
	var base: float = n.get_meta("shake_base_x")
	n.position.x = base
	n.modulate = Color.WHITE   # 플래시 중첩 방지(항상 흰색에서 시작)
	var a := 5.0   # 흔들림 진폭(px)
	var t := n.create_tween()
	_shake_tw[n] = t
	t.tween_property(n, "position:x", base - a, 0.05).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:x", base + a, 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:x", base - a, 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:x", base + a, 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:x", base, 0.05).set_trans(Tween.TRANS_SINE)
	# 에러 빨강 플래시 — 접수 불가(보드 꽉참) 원인을 카운트다운 흔들림과 구분(A안).
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
## 레시피 필요 재료 카드들을 슬롯에서 떼어(제거만, free 안 함) 반환 — 조리 연출(도구석으로 날림)용.
## 떼기 전에 global_position을 캡처해 함께 반환(떼면 좌표가 로컬로 붕괴되므로).
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
