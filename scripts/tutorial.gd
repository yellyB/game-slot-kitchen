class_name Tutorial
extends Control
## 독립 튜토리얼 — 손님 1명(커피) 대상 핵심 루프(접수→재료→조리→서빙) 가이드.
## 본격 게임(세션/경제)과 완전 분리. 메인 메뉴 [튜토리얼]로만 진입, 끝나면 finished 방출.
## 컴포넌트(Board·Warehouse·Cooking)는 재사용하되 타이머(인내심)는 꺼서 압박 없이 진행.

signal finished

const RECIPE := "coffee"   # 가장 단순한 레시피(원두🌰+물💧, 3초)

enum { S_ACCEPT, S_WAREHOUSE, S_INGREDIENTS, S_COOK, S_SERVE, S_DONE }

var _board: Board
var _warehouse: Warehouse
var _cooking: Cooking
var _backdrop: ColorRect
var _queue_row: HBoxContainer
var _wh_btn: Button
var _customer: Customer
var _order: OrderCard
var _spot: TutorialSpotlight
var _step := S_ACCEPT
var _prev_move_target: Callable
var _clock := 0.0   # 자체 클록(완성품 born 스탬프용)


func _ready() -> void:
	z_index = 350
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	Buffs.clear()   # 튜토리얼은 버프 없는 깨끗한 상태(도구 수·조리시간 고정)

	var bg := ColorRect.new()
	bg.color = Palette.COCOA_50
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	# 상단: 타이틀 + 나가기(X)
	var top := HBoxContainer.new()
	top.add_child(UI.label("🎓 " + Loc.t("tutorial"), 18, Palette.COCOA_800, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var exit := Button.new()
	exit.text = "✕"
	exit.add_theme_font_size_override("font_size", 16)
	exit.add_theme_color_override("font_color", Palette.COCOA_600)
	exit.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	exit.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	exit.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	exit.pressed.connect(_finish)
	Audio.attach_click(exit)
	top.add_child(exit)
	col.add_child(top)

	# 손님 큐
	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 8)
	_queue_row.custom_minimum_size = Vector2(0, 96)
	col.add_child(_queue_row)

	# 보드
	_board = Board.new()
	_board.now_provider = _now
	_board.tool_tapped.connect(_on_tool_tapped)
	col.add_child(_board)
	_board.rebuild(4)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	# 하단 창고 버튼
	_wh_btn = Button.new()
	_wh_btn.text = "🏬"
	_wh_btn.custom_minimum_size = Vector2(0, 56)
	_wh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wh_btn.add_theme_font_size_override("font_size", 24)
	_wh_btn.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	_wh_btn.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	_wh_btn.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	_wh_btn.pressed.connect(_toggle_warehouse)
	col.add_child(_wh_btn)

	# 시트 백드롭 + 창고 + 조리
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.164, 0.129, 0.106, 0.28)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	_warehouse = Warehouse.new()
	_warehouse.close_requested.connect(_close_sheets)
	add_child(_warehouse)
	_cooking = Cooking.new()
	_cooking.board = _board
	_cooking.close_requested.connect(_close_sheets)
	_cooking.cooked.connect(_on_cooked)
	add_child(_cooking)

	# Move 전역 타깃을 튜토리얼 보드로(끝나면 복원). 배치 성공 감지도 구독.
	_prev_move_target = Move.default_target
	Move.default_target = func(_p): return _board.first_empty_slot()
	Move.performed.connect(_on_move_performed)

	# 스포트라이트(최상단)
	_spot = TutorialSpotlight.new()
	add_child(_spot)

	_spawn_customer()
	_goto_step(S_ACCEPT)


func _now() -> float:
	return _clock


# ── 손님 / 주문 ───────────────────────────────────────────
func _spawn_customer() -> void:
	_customer = Customer.new()
	_customer.setup(RECIPE)
	_customer.confirm_pressed.connect(_on_confirm)
	_queue_row.add_child(_customer)
	_customer.set_process(false)   # 인내심 정지(압박 없음)
	_customer.slide_in()


func _on_confirm(customer: Customer) -> void:
	if _order != null:
		return
	var slot := _board.first_empty_slot()
	if slot == null:
		return
	_order = OrderCard.new()
	_order.setup(RECIPE)
	_order.born = _now()
	_order.served.connect(_on_served)
	customer.queue_free()
	_customer = null
	slot.place_card(_order)
	_order.set_process(false)   # 음식 대기 인내심 정지
	if _step == S_ACCEPT:
		_goto_step(S_WAREHOUSE)


func _on_served(_order_card: OrderCard, _dish: DishCard) -> void:
	if _step != S_DONE:
		_goto_step(S_DONE)


# ── 창고 / 조리 시트 ──────────────────────────────────────
func _toggle_warehouse() -> void:
	if _warehouse.visible:
		_close_sheets()
	else:
		_cooking.visible = false
		_warehouse.visible = true
		_backdrop.visible = true
		_warehouse.refresh(_board.is_full())


func _on_tool_tapped(tool: ToolStation) -> void:
	_warehouse.visible = false
	_backdrop.visible = true
	_cooking.open_for(tool)


func _on_cooked() -> void:
	_close_sheets()   # 조리 시작 → 시트 닫고 완성 대기(도구석 위에서 3초)


func _close_sheets() -> void:
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_close_sheets()


func _on_move_performed() -> void:
	_check_step()


# ── 단계 진행 ─────────────────────────────────────────────
func _process(_delta: float) -> void:
	_clock += _delta
	# 주문 카드 "서빙 가능" 발광
	if _order != null and is_instance_valid(_order):
		_order.set_servable(_board.available_dish_ids().has(RECIPE))
	_check_step()


## 상태 기반 단계는 매 프레임 폴링으로 전진(신호 기반은 각 핸들러에서 처리).
func _check_step() -> void:
	match _step:
		S_WAREHOUSE:
			if _warehouse.visible:
				_goto_step(S_INGREDIENTS)
		S_INGREDIENTS:
			if _board.has_ingredients(RECIPE):
				_close_sheets()   # 재료 다 모임 → 창고 자동 닫고 조리 단계로
				_goto_step(S_COOK)
		S_COOK:
			var dish := _find_dish()
			if dish != null:
				_goto_step(S_SERVE)


func _goto_step(s: int) -> void:
	_step = s
	match s:
		S_ACCEPT:
			_spot.show_step(_customer, Loc.t("tut_accept"))
		S_WAREHOUSE:
			_spot.show_step(_wh_btn, Loc.t("tut_warehouse"))
		S_INGREDIENTS:
			_spot.show_step(_warehouse, Loc.t("tut_ingredients"))
		S_COOK:
			var tool: Control = _board.tools[0] if _board.tools.size() > 0 else null
			_spot.show_step(tool, Loc.t("tut_cook"))
		S_SERVE:
			_spot.show_step(_find_dish(), Loc.t("tut_serve"))
		S_DONE:
			_show_done()


## 완성품(도구석 위 우선, 없으면 슬롯) 노드 — 없으면 null.
func _find_dish() -> Control:
	for t in _board.tools:
		var d := t.get_dish()
		if d != null and d.recipe_id == RECIPE:
			return d
	for sl in _board.slots:
		var c := sl.get_card()
		if c is DishCard and c.recipe_id == RECIPE:
			return c
	return null


# ── 완료 / 종료 ───────────────────────────────────────────
func _show_done() -> void:
	_spot.visible = false
	var dim := ColorRect.new()
	dim.color = Palette.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 520
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var emoji := UI.label("🎉", 64)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(emoji)
	var msg := UI.label(Loc.t("tut_done"), 22, Palette.WHITE, true)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(msg)
	var btn := Button.new()
	btn.text = Loc.t("tut_to_menu")
	btn.custom_minimum_size = Vector2(180, 52)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Palette.WHITE)
	btn.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	btn.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	btn.pressed.connect(_finish)
	Audio.attach_click(btn)
	box.add_child(btn)


func _finish() -> void:
	if Move.performed.is_connected(_on_move_performed):
		Move.performed.disconnect(_on_move_performed)
	Move.default_target = _prev_move_target   # 본격 게임 상태 복원
	Move.clear()
	finished.emit()
