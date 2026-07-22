extends Control
## 메인 게임 화면 — 코디네이터.
## 레이아웃 조립 + 손님 큐/스포너 + 경제(돈·서빙) 담당.
## 슬롯 그리드=Board, 창고=Warehouse, 조리=Cooking, 이동=Move(autoload)로 위임.

var _board: Board
var _warehouse: Warehouse
var _cooking: Cooking
var _backdrop: ColorRect
var _session: Session
var _title: TitleScreen

var _warehouse_btn: Button
var _trash_btn: TrashButton

var _queue_row: HBoxContainer

var _day_label: Label
var _money_label: Label
var _rent_label: Label
var _hours_bar: ProgressBar


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
	if OS.is_debug_build():   # 운영(릴리스) 빌드에선 디버그 바 숨김
		col.add_child(_build_debug())
	col.add_child(_build_customer_queue())

	_board = Board.new()
	_board.tool_tapped.connect(_on_tool_tapped)
	col.add_child(_board)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	col.add_child(_build_bottom_buttons())

	# 시트 백드롭 — 시트 열리면 뒤쪽(보드·큐·버튼) 입력 차단, 바깥 탭 = 닫기
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.164, 0.129, 0.106, 0.28)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	# 시트는 백드롭 위에
	_warehouse = Warehouse.new()
	_warehouse.close_requested.connect(_close_sheets)
	add_child(_warehouse)
	_cooking = Cooking.new()
	_cooking.board = _board
	_cooking.close_requested.connect(_close_sheets)
	_cooking.cooked.connect(_on_cooked)
	add_child(_cooking)

	Move.performed.connect(_refresh_warehouse)
	# quick 동작(창고 클릭)의 기본 타깃 = 첫 빈 슬롯
	Move.default_target = func(_payload): return _board.first_empty_slot()

	# 세션(하루 루프)
	_session = Session.new()
	_session.cash_changed.connect(_on_cash_changed)
	_session.progress.connect(_on_progress)
	_session.spawn_requested.connect(_spawn_customer)
	_session.day_started.connect(_on_day_started)
	_session.day_ended.connect(_on_day_ended)
	add_child(_session)

	# 시작(타이틀) 화면 — 앱 실행 시 게임 위에 덮음. [시작] → 게임 시작.
	_title = TitleScreen.new()
	_title.start_pressed.connect(_start_game)
	add_child(_title)


func _start_game() -> void:
	_title.hide()
	_session.start_run()


func _show_title() -> void:
	_title.show()


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

	_day_label = UI.label("1일차", 20, Palette.COCOA_800, true)
	row.add_child(_day_label)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	# 돈 (소지금)
	var coin := HBoxContainer.new()
	coin.add_theme_constant_override("separation", 4)
	coin.add_child(_dot(Palette.ACCENT))
	_money_label = UI.label("0", 18, Palette.COCOA_800, true)
	coin.add_child(_money_label)
	row.add_child(coin)

	# 가게세
	var rentbox := HBoxContainer.new()
	rentbox.add_theme_constant_override("separation", 4)
	rentbox.add_child(_dot(Palette.DANGER))
	_rent_label = UI.label("0", 18, Palette.COCOA_800, true)
	rentbox.add_child(_rent_label)
	row.add_child(rentbox)

	var hours := HBoxContainer.new()
	hours.add_theme_constant_override("separation", 8)
	box.add_child(hours)

	hours.add_child(UI.label("☀️", 14, Palette.COCOA_400))

	_hours_bar = ProgressBar.new()
	_hours_bar.min_value = 0
	_hours_bar.max_value = 100
	_hours_bar.value = 0
	_hours_bar.show_percentage = false
	_hours_bar.custom_minimum_size = Vector2(0, 14)
	_hours_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hours_bar.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	_hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.ACCENT))
	hours.add_child(_hours_bar)

	hours.add_child(UI.label("🌙", 14, Palette.COCOA_400))

	return panel


# ── 디버그 바 (개발용) ────────────────────────────────────
func _build_debug() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UI.label("🐞", 14, Palette.COCOA_400))
	row.add_child(_debug_btn("돈+10만", func(): _session.add_cash(100000)))
	row.add_child(_debug_btn("즉시종료", func(): _session.debug_end_soon(1.0)))
	return row


func _debug_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Palette.COCOA_800)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	b.pressed.connect(cb)
	return b


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
	if _warehouse.visible:
		_close_sheets()
	else:
		_open_warehouse()


func _open_warehouse() -> void:
	_cooking.visible = false
	_warehouse.visible = true
	_backdrop.visible = true
	_refresh_warehouse()


func _on_tool_tapped(tool: ToolStation) -> void:
	_warehouse.visible = false
	_backdrop.visible = true
	_cooking.open_for(tool)


func _close_sheets() -> void:
	# 창고 퇴장 = 트립 비용(영업시간 3초 소모). 세션 진행 중일 때만(spend_time가 가드).
	if _warehouse.visible:
		_session.spend_time(Stats.warehouse_cost())
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false


func _on_cooked() -> void:
	_close_sheets()
	_refresh_warehouse()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_close_sheets()


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
	var price := Stats.sell_price(order.recipe_id)
	_session.earn(price)
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


# ── 세션 반응 ─────────────────────────────────────────────
func _on_cash_changed(cash: int) -> void:
	_money_label.text = _fmt(cash)


func _on_progress(t01: float) -> void:
	_hours_bar.value = t01 * 100.0


func _on_day_started(day: int, rent: int) -> void:
	_day_label.text = "%d일차" % day
	_rent_label.text = _fmt(rent)
	_hours_bar.value = 0
	# 새 세션 시작 — 시트 강제 닫기(트립 비용 없음)
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false
	# 슬롯 수만큼 보드 재구성(상점 확장 반영), 큐 비움
	Move.clear()
	_board.rebuild(_session.slots)
	# 보유 버프는 슬롯을 점유(배치형) — 작업공간과 트레이드오프
	for id in Buffs.owned():
		var slot := _board.first_empty_slot()
		if slot:
			var bc := BuffCard.new()
			bc.setup(id)
			slot.place_card(bc)
	for c in _queue_row.get_children():
		c.queue_free()
	_refresh_warehouse()


func _on_day_ended(summary: Dictionary) -> void:
	if summary["won"]:
		Modal.open(self) \
			.title("승리! 🎉") \
			.row("%d일 완주" % Levels.count(), Palette.SUCCESS) \
			.button("처음으로", _show_title)
	elif summary["passed"]:
		Modal.open(self) \
			.title("%d일차 마감" % summary["day"]) \
			.row("매출  %d" % summary["revenue"]) \
			.row("가게세  %d" % summary["rent"], Palette.DANGER) \
			.sep() \
			.row("남음  %d" % summary["cash_after"], Palette.COCOA_800) \
			.row("통과! ✅", Palette.SUCCESS) \
			.button("상점으로", _open_shop)
	else:
		Modal.open(self) \
			.title("폐업 😢") \
			.row("%d일차에서 끝" % summary["day"]) \
			.row("매출 %d < 가게세 %d" % [summary["revenue"], summary["rent"]], Palette.DANGER) \
			.button("처음으로", _show_title)


## 결과 → 인터세션 상점 (슬롯 확장 등) → [영업 시작] → 다음 세션.
func _open_shop() -> void:
	var shop := Shop.new()
	shop.session = _session
	shop.start_business.connect(_session.advance_day)
	add_child(shop)


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
