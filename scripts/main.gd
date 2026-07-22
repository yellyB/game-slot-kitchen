extends Control
## 메인 게임 화면.
## D1: 정적 레이아웃(상단바·손님 큐·슬롯 그리드·하단 버튼).
## D2: 창고에서 재료 꺼내기 + 슬롯 배치/이동/휴지통 제거.
##     모든 이동은 Move 컨트롤러로 클릭·드래그 공용 처리.
## 비주얼-A: StyleBoxFlat 테마(둥근·팔레트색·그림자)를 코드로.

var _slots: Array[Slot] = []
var _tools: Array[ToolStation] = []

var _warehouse_btn: Button
var _trash_btn: TrashButton
var _warehouse_sheet: Panel
var _tiles: Array[IngredientTile] = []

var _recipe_sheet: Panel
var _recipe_entries: Array[Button] = []
var _active_tool: ToolStation

var _queue_row: HBoxContainer
var _spawn_timer: Timer

var _cash := Config.START_MONEY
var _money_label: Label


func _ready() -> void:
	# 배경 크림 — 빈 곳 클릭 시 선택 해제 캐처
	var bg := ColorRect.new()
	bg.color = Palette.COCOA_50
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_background_input)
	add_child(bg)

	# 바깥 여백 (구조 컨테이너는 클릭 통과 → 빈 곳 클릭이 bg로)
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

	col.add_child(_build_top_bar())
	col.add_child(_build_customer_queue())
	col.add_child(_build_slot_grid())

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	col.add_child(_build_bottom_buttons())

	# 시트는 다른 UI 위에 뜨도록 마지막에 추가
	_warehouse_sheet = _build_warehouse_sheet()
	add_child(_warehouse_sheet)
	_recipe_sheet = _build_recipe_sheet()
	add_child(_recipe_sheet)

	Move.performed.connect(_refresh_tiles)

	# 손님 스포너
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = Config.SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_customer)
	add_child(_spawn_timer)
	_spawn_timer.start()
	_spawn_customer()  # 시작하자마자 첫 손님


# ── 상단바: 일차·돈·가게세 + 영업시간 바 ──────────────────────
func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_box(Palette.WHITE))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pad.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	row.add_child(_label("1일차", 20, true))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	# 돈 (실제 소지금 — 서빙으로 증가)
	var coin := HBoxContainer.new()
	coin.add_theme_constant_override("separation", 4)
	var dot := ColorRect.new()
	dot.color = Palette.ACCENT
	dot.custom_minimum_size = Vector2(14, 14)
	var dot_wrap := CenterContainer.new()
	dot_wrap.add_child(dot)
	coin.add_child(dot_wrap)
	_money_label = _label(_fmt(_cash), 18, true)
	coin.add_child(_money_label)
	row.add_child(coin)

	row.add_child(_money(Palette.DANGER, "300"))  # 가게세 placeholder (단계 6)

	var hours := HBoxContainer.new()
	hours.add_theme_constant_override("separation", 8)
	box.add_child(hours)

	hours.add_child(_label("☀️", 14, false, Palette.COCOA_400))

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 40
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _pill_box(Palette.COCOA_100, Palette.COCOA_200))
	bar.add_theme_stylebox_override("fill", _pill_box(Palette.ACCENT))
	hours.add_child(bar)

	hours.add_child(_label("🌙", 14, false, Palette.COCOA_400))

	return panel


# ── 손님 큐: 가로 카드 자리 ────────────────────────────────
func _build_customer_queue() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_box(Palette.COCOA_100, Palette.COCOA_200))
	panel.custom_minimum_size = Vector2(0, 96)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(pad)

	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 8)
	pad.add_child(_queue_row)

	return panel


# ── 슬롯 그리드: 3×3, 도구석 2 ────────────────────────────
func _build_slot_grid() -> Control:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = Config.BOARD_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)

	for i in range(Config.BOARD_SLOTS):
		if i in Config.TOOL_SLOTS:
			var tool := ToolStation.new()
			tool.tapped.connect(_open_recipe_popup)
			_tools.append(tool)
			grid.add_child(tool)
		else:
			var slot := Slot.new()
			_slots.append(slot)
			grid.add_child(slot)

	return center


# ── 하단 버튼: 창고 · 휴지통 ───────────────────────────────
func _build_bottom_buttons() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)

	_warehouse_btn = _make_bottom_button(Palette.MAIN)
	_warehouse_btn.text = "🏬"
	_warehouse_btn.pressed.connect(_toggle_warehouse)
	row.add_child(_warehouse_btn)

	_trash_btn = TrashButton.new()
	_trash_btn.text = "🗑️"
	_style_bottom_button(_trash_btn, Palette.SUB)
	row.add_child(_trash_btn)

	return row


# ── 창고 하단 시트 ────────────────────────────────────────
func _build_warehouse_sheet() -> Panel:
	var sheet := Panel.new()
	sheet.visible = false
	sheet.anchor_left = 0.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = 8
	sheet.offset_right = -8
	sheet.offset_top = -240
	sheet.offset_bottom = -8

	var box := StyleBoxFlat.new()
	box.bg_color = Palette.WHITE
	box.set_corner_radius_all(18)
	box.set_border_width_all(1)
	box.border_color = Palette.COCOA_200
	box.shadow_color = Color(0.164, 0.129, 0.106, 0.18)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, -2)
	sheet.add_theme_stylebox_override("panel", box)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	sheet.add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	header.add_child(_label("🏬", 20, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Palette.COCOA_600)
	close.add_theme_stylebox_override("normal", _pill_box(Palette.COCOA_100, Palette.COCOA_200))
	close.add_theme_stylebox_override("hover", _pill_box(Palette.COCOA_200))
	close.add_theme_stylebox_override("pressed", _pill_box(Palette.COCOA_200))
	close.pressed.connect(_toggle_warehouse)
	header.add_child(close)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	for id in Ingredients.unlocked_ids():
		var tile := IngredientTile.new()
		tile.setup(id)
		_tiles.append(tile)
		grid.add_child(tile)

	return sheet


# ── 상호작용 ──────────────────────────────────────────────
func _toggle_warehouse() -> void:
	var show := not _warehouse_sheet.visible
	_recipe_sheet.visible = false
	_warehouse_sheet.visible = show
	if show:
		_refresh_tiles()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.background_click()


# ── 손님 / 주문 ───────────────────────────────────────────
func _spawn_customer() -> void:
	if _queue_row.get_child_count() >= Config.MAX_QUEUE:
		return
	var c := Customer.new()
	c.setup(Recipes.random_id())
	c.confirm_pressed.connect(_on_confirm_order)
	c.expired.connect(_on_customer_expired)
	_queue_row.add_child(c)


## 주문 확인 → 손님이 큐에서 사라지고 다음 빈 슬롯의 주문 카드로 "이동".
func _on_confirm_order(customer: Customer) -> void:
	var slot := _first_empty_slot()
	if slot == null:
		Toast.show_msg(self, "빈 칸 없음")
		return
	var order := OrderCard.new()
	order.setup(customer.recipe_id)
	order.expired.connect(_on_order_expired)
	order.served.connect(_on_served)
	slot.place_card(order)
	customer.queue_free()
	_refresh_tiles()


## 주문 대기 인내심 0 → 손님 퇴장 (아직 주문 안 받음).
func _on_customer_expired(customer: Customer) -> void:
	customer.queue_free()


## 음식 대기 인내심 0 → 주문 카드(=손님) 통째로 사라짐, 슬롯 회복.
func _on_order_expired(order: OrderCard) -> void:
	var holder := order.get_parent()
	if holder:
		holder.remove_child(order)
	order.queue_free()
	_refresh_tiles()


## 완성품이 매칭 주문 카드에 서빙됨 → 돈 + 손님 퇴장 + 슬롯/도구 회복.
func _on_served(order: OrderCard, dish: DishCard) -> void:
	var price := int(Recipes.get_def(order.recipe_id).get("price", 0))
	_cash += price
	_money_label.text = _fmt(_cash)
	_spawn_floating("+%d" % price, order.global_position + order.size * 0.5, Palette.ACCENT)

	# 주문 카드(=손님) 제거
	var holder := order.get_parent()
	if holder:
		holder.remove_child(order)
	order.queue_free()

	# 완성품 제거: 도구석 위면 도구 회복(제거 포함), 슬롯에 있으면 슬롯에서 제거
	if dish != null and is_instance_valid(dish):
		if dish.tool != null:
			dish.tool.reset()
		else:
			var dp := dish.get_parent()
			if dp:
				dp.remove_child(dish)
			dish.queue_free()

	_refresh_tiles()


## 인플레이 피드백 — 위로 떠오르며 사라지는 텍스트.
func _spawn_floating(text: String, at_pos: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 100
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	add_child(l)
	l.position = at_pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", at_pos.y - 44, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _first_empty_slot() -> Slot:
	for s in _slots:
		if s.is_empty():
			return s
	return null


# ── 조리 (레시피 팝업 + B안: 재료 다 모여야) ──────────────
func _build_recipe_sheet() -> Panel:
	var sheet := Panel.new()
	sheet.visible = false
	sheet.anchor_left = 0.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = 8
	sheet.offset_right = -8
	sheet.offset_top = -260
	sheet.offset_bottom = -8

	var box := StyleBoxFlat.new()
	box.bg_color = Palette.WHITE
	box.set_corner_radius_all(18)
	box.set_border_width_all(1)
	box.border_color = Palette.COCOA_200
	box.shadow_color = Color(0.164, 0.129, 0.106, 0.18)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, -2)
	sheet.add_theme_stylebox_override("panel", box)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	sheet.add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pad.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	header.add_child(_label("🔥", 20, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Palette.COCOA_600)
	close.add_theme_stylebox_override("normal", _pill_box(Palette.COCOA_100, Palette.COCOA_200))
	close.add_theme_stylebox_override("hover", _pill_box(Palette.COCOA_200))
	close.add_theme_stylebox_override("pressed", _pill_box(Palette.COCOA_200))
	close.pressed.connect(func(): _recipe_sheet.visible = false)
	header.add_child(close)

	for id in Recipes.all_ids():
		var entry := _recipe_entry(id)
		_recipe_entries.append(entry)
		v.add_child(entry)

	return sheet


## 레시피 항목: [요리아이콘] [필요재료 아이콘] … [⏱️ n]. 탭 → 조리 시작.
func _recipe_entry(id: String) -> Button:
	var def := Recipes.get_def(id)
	var entry := Button.new()
	entry.custom_minimum_size = Vector2(0, 52)
	entry.add_theme_stylebox_override("normal", _card_box(Palette.COCOA_100, Palette.COCOA_200))
	entry.add_theme_stylebox_override("hover", _card_box(Palette.ACCENT.lightened(0.35), Palette.ACCENT))
	entry.add_theme_stylebox_override("pressed", _card_box(Palette.ACCENT.lightened(0.2), Palette.ACCENT))
	entry.add_theme_stylebox_override("disabled", _card_box(Palette.COCOA_100, Palette.COCOA_200))
	entry.set_meta("recipe_id", id)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	# 좌우 안쪽 여백
	row.offset_left = 12
	row.offset_right = -12
	entry.add_child(row)

	var dish := Label.new()
	dish.text = str(def.get("icon", "?"))
	dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dish.add_theme_font_size_override("font_size", 24)
	row.add_child(dish)

	for iid in def.get("ingredients", []):
		var mi := Label.new()
		mi.text = str(Ingredients.get_def(iid).get("icon", "?"))
		mi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mi.add_theme_font_size_override("font_size", 18)
		row.add_child(mi)

	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	var timer := _label("⏱️%d" % int(def.get("cook_time", 0)), 16, false, Palette.COCOA_600)
	row.add_child(timer)

	entry.pressed.connect(func(): _select_recipe(id))
	return entry


func _open_recipe_popup(tool: ToolStation) -> void:
	_active_tool = tool
	_warehouse_sheet.visible = false
	_refresh_recipes()
	_recipe_sheet.visible = true


## 재료 충족 여부에 따라 레시피 항목 활성/비활성.
func _refresh_recipes() -> void:
	var have := _ingredient_counts()
	for entry in _recipe_entries:
		var id: String = entry.get_meta("recipe_id")
		var ok := _has_ingredients(id, have)
		entry.disabled = not ok
		entry.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.45)


func _select_recipe(id: String) -> void:
	if _active_tool == null or not _active_tool.is_idle():
		return
	if not _has_ingredients(id, _ingredient_counts()):
		return
	_consume_ingredients(id)
	_active_tool.start_cooking(id)
	_recipe_sheet.visible = false
	_active_tool = null
	_refresh_tiles()


## 보드에 놓인 재료 개수 (ing_id → 개수).
func _ingredient_counts() -> Dictionary:
	var have := {}
	for s in _slots:
		var c := s.get_card()
		if c is IngredientCard:
			have[c.ing_id] = have.get(c.ing_id, 0) + 1
	return have


## B안: 필요재료가 보드에 전부 있어야 true.
func _has_ingredients(recipe_id: String, have: Dictionary) -> bool:
	var need := {}
	for iid in Recipes.get_def(recipe_id).get("ingredients", []):
		need[iid] = need.get(iid, 0) + 1
	for iid in need:
		if have.get(iid, 0) < need[iid]:
			return false
	return true


## 필요재료를 보드에서 소비(제거).
func _consume_ingredients(recipe_id: String) -> void:
	for iid in Recipes.get_def(recipe_id).get("ingredients", []):
		for s in _slots:
			var c := s.get_card()
			if c is IngredientCard and c.ing_id == iid:
				s.clear()
				break


func _board_full() -> bool:
	for s in _slots:
		if s.is_empty():
			return false
	return true


## 빈 슬롯 없으면 창고 타일 비활성(회색).
func _refresh_tiles() -> void:
	var full := _board_full()
	for tile in _tiles:
		tile.disabled = full
		tile.modulate = Color(1, 1, 1, 0.45) if full else Color.WHITE


# ── 공용 헬퍼 ─────────────────────────────────────────────
func _label(text: String, size: int, bold: bool, color: Color = Palette.COCOA_800) -> Label:
	return UI.label(text, size, color, bold)


## *Money* — [색점][숫자] 표시 전용 컴포넌트.
func _money(dot_color: Color, amount: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)

	var dot := ColorRect.new()
	dot.color = dot_color
	dot.custom_minimum_size = Vector2(14, 14)
	var wrap := CenterContainer.new()
	wrap.add_child(dot)
	h.add_child(wrap)

	h.add_child(_label(amount, 18, true))
	return h


func _make_bottom_button(color: Color) -> Button:
	var b := Button.new()
	_style_bottom_button(b, color)
	return b


func _style_bottom_button(b: Button, color: Color) -> void:
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Palette.WHITE)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_stylebox_override("normal", _pill_box(color))
	b.add_theme_stylebox_override("hover", _pill_box(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _pill_box(color.darkened(0.1)))


## 카드/패널·알약 틀 — 공용 UI 위임.
func _card_box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 1) -> StyleBoxFlat:
	return UI.card(bg, border, border_w)


func _pill_box(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	return UI.chip(bg, border)
