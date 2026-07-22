extends Control
## 메인 게임 화면 — 코디네이터.
## 레이아웃 조립 + 손님 큐/스포너 + 경제(돈·서빙) 담당.
## 슬롯 그리드=Board, 창고=Warehouse, 조리=Cooking, 이동=Move(autoload)로 위임.

var _board: Board
var _warehouse: Warehouse
var _cooking: Cooking

var _warehouse_btn: Button
var _trash_btn: TrashButton

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

	_board = Board.new()
	_board.tool_tapped.connect(_on_tool_tapped)
	col.add_child(_board)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	col.add_child(_build_bottom_buttons())

	# 시트는 다른 UI 위에 뜨도록 마지막에 추가
	_warehouse = Warehouse.new()
	add_child(_warehouse)
	_cooking = Cooking.new()
	add_child(_cooking)
	_cooking.board = _board
	_cooking.cooked.connect(_refresh_warehouse)

	Move.performed.connect(_refresh_warehouse)

	# 손님 스포너
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = Config.SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_customer)
	add_child(_spawn_timer)
	_spawn_timer.start()
	_spawn_customer()


# ── 상단바: 일차·돈·가게세 + 영업시간 바 ──────────────────────
func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.card(Palette.WHITE))

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

	row.add_child(UI.label("1일차", 20, Palette.COCOA_800, true))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	# 돈 (실제 소지금 — 서빙으로 증가)
	var coin := HBoxContainer.new()
	coin.add_theme_constant_override("separation", 4)
	coin.add_child(_dot(Palette.ACCENT))
	_money_label = UI.label(_fmt(_cash), 18, Palette.COCOA_800, true)
	coin.add_child(_money_label)
	row.add_child(coin)

	row.add_child(_money(Palette.DANGER, "300"))  # 가게세 placeholder (단계 6)

	var hours := HBoxContainer.new()
	hours.add_theme_constant_override("separation", 8)
	box.add_child(hours)

	hours.add_child(UI.label("☀️", 14, Palette.COCOA_400))

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 40
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	bar.add_theme_stylebox_override("fill", UI.chip(Palette.ACCENT))
	hours.add_child(bar)

	hours.add_child(UI.label("🌙", 14, Palette.COCOA_400))

	return panel


# ── 손님 큐 ───────────────────────────────────────────────
func _build_customer_queue() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.card(Palette.COCOA_100, Palette.COCOA_200))
	panel.custom_minimum_size = Vector2(0, 96)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(pad)

	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 8)
	pad.add_child(_queue_row)

	return panel


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


# ── 상호작용 ──────────────────────────────────────────────
func _toggle_warehouse() -> void:
	var show := not _warehouse.visible
	_cooking.visible = false
	_warehouse.visible = show
	if show:
		_refresh_warehouse()


func _on_tool_tapped(tool: ToolStation) -> void:
	_warehouse.visible = false
	_cooking.open_for(tool)


func _refresh_warehouse() -> void:
	_warehouse.refresh(_board.is_full())


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
	var slot := _board.first_empty_slot()
	if slot == null:
		Toast.show_msg(self, "빈 칸 없음")
		return
	var order := OrderCard.new()
	order.setup(customer.recipe_id)
	order.expired.connect(_on_order_expired)
	order.served.connect(_on_served)
	slot.place_card(order)
	customer.queue_free()
	_refresh_warehouse()


func _on_customer_expired(customer: Customer) -> void:
	customer.queue_free()


## 음식 대기 인내심 0 → 주문 카드(=손님) 통째로 사라짐, 슬롯 회복.
func _on_order_expired(order: OrderCard) -> void:
	var holder := order.get_parent()
	if holder:
		holder.remove_child(order)
	order.queue_free()
	_refresh_warehouse()


## 완성품이 매칭 주문 카드에 서빙됨 → 돈 + 손님 퇴장 + 슬롯/도구 회복.
func _on_served(order: OrderCard, dish: DishCard) -> void:
	var price := int(Recipes.get_def(order.recipe_id).get("price", 0))
	_cash += price
	_money_label.text = _fmt(_cash)
	_spawn_floating("+%d" % price, order.global_position + order.size * 0.5, Palette.ACCENT)

	var holder := order.get_parent()
	if holder:
		holder.remove_child(order)
	order.queue_free()

	# 완성품 제거: 도구석 위면 도구 회복(제거 포함), 슬롯이면 슬롯에서 제거
	if dish != null and is_instance_valid(dish):
		if dish.tool != null:
			dish.tool.reset()
		else:
			var dp := dish.get_parent()
			if dp:
				dp.remove_child(dish)
			dish.queue_free()

	_refresh_warehouse()


## 인플레이 피드백 — 위로 떠오르며 사라지는 텍스트.
func _spawn_floating(text: String, at_pos: Vector2, color: Color) -> void:
	var l := UI.label(text, 20, color, true)
	l.z_index = 100
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


# ── 공용 헬퍼 ─────────────────────────────────────────────
func _dot(color: Color) -> Control:
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	var wrap := CenterContainer.new()
	wrap.add_child(dot)
	return wrap


## *Money* — [색점][숫자] 표시 전용.
func _money(dot_color: Color, amount: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(_dot(dot_color))
	h.add_child(UI.label(amount, 18, Palette.COCOA_800, true))
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
	b.add_theme_stylebox_override("normal", UI.chip(color))
	b.add_theme_stylebox_override("hover", UI.chip(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", UI.chip(color.darkened(0.1)))
