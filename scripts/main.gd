extends Control

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
	if OS.is_debug_build():
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

	Move.performed.connect(_refresh_warehouse)
	Move.default_target = func(_payload): return _board.first_empty_slot()

	_session = Session.new()
	_session.cash_changed.connect(_on_cash_changed)
	_session.progress.connect(_on_progress)
	_session.spawn_requested.connect(_spawn_customer)
	_session.day_started.connect(_on_day_started)
	_session.day_ended.connect(_on_day_ended)
	add_child(_session)

	_title = TitleScreen.new()
	_title.start_pressed.connect(_start_game)
	add_child(_title)

	if OS.is_debug_build() and "--test" in OS.get_cmdline_user_args():
		await TestHarness.new().run(self)

	if "--sim" in OS.get_cmdline_user_args():
		var batch := SimBatch.new()
		var n := 200
		print("\n[SIM] ===== 생존 시뮬 (판당 5일, %d회, 상점 ON) =====" % n)
		var s := batch.run(n, [], true)
		print("[SIM] 승률 %.1f%%  최종현금 %.0f  서빙 %.1f  놓침 %.1f  슬롯 %.1f  버프 %.1f  일수 %.1f" % [
			s["win_rate"] * 100.0, s["avg_cash"], s["avg_served"], s["avg_lost"],
			s["avg_slots"], s["avg_buffs"], s["avg_days"]])
		get_tree().quit()


func _start_game() -> void:
	_title.hide()
	_session.start_run()


func _show_title() -> void:
	_title.show()


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

	var coin := HBoxContainer.new()
	coin.add_theme_constant_override("separation", 4)
	coin.add_child(_dot(Palette.ACCENT))
	_money_label = UI.label("0", 18, Palette.COCOA_800, true)
	coin.add_child(_money_label)
	row.add_child(coin)

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


func _spawn_customer() -> void:
	if _queue_row.get_child_count() >= Config.MAX_QUEUE:
		return
	var c := Customer.new()
	c.setup(Stats.random_recipe())
	c.confirm_pressed.connect(_on_confirm_order)
	c.expired.connect(_on_customer_expired)
	_queue_row.add_child(c)


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


func _on_order_expired(order: OrderCard) -> void:
	var holder := order.get_parent()
	if holder:
		holder.remove_child(order)
	order.queue_free()
	_refresh_warehouse()


func _on_served(order: OrderCard, dish: DishCard) -> void:
	var price := Stats.sell_price(order.recipe_id)
	_session.earn(price)
	_spawn_floating("+%d" % price, order.global_position + order.size * 0.5, Palette.ACCENT)

	var holder := order.get_parent()
	if holder:
		holder.remove_child(order)
	order.queue_free()

	if dish != null and is_instance_valid(dish):
		if dish.tool != null:
			dish.tool.reset()
		else:
			var dp := dish.get_parent()
			if dp:
				dp.remove_child(dish)
			dish.queue_free()

	_refresh_warehouse()


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


func _dot(color: Color) -> Control:
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	var wrap := CenterContainer.new()
	wrap.add_child(dot)
	return wrap


func _on_cash_changed(cash: int) -> void:
	_money_label.text = _fmt(cash)


func _on_progress(t01: float) -> void:
	_hours_bar.value = t01 * 100.0


func _on_day_started(day: int, rent: int) -> void:
	_day_label.text = "%d일차" % day
	_rent_label.text = _fmt(rent)
	_hours_bar.value = 0
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false
	Move.clear()
	_board.rebuild(_session.slots)
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
