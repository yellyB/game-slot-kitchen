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

var _visited_today := 0
var _accepted_today := 0
var _served_today := 0
var _order_lost_today := 0
var _served_by_menu := {}

var _day_label: Label
var _money_label: Label
var _rent_label: Label
var _last_cash := 0
var _expect_fly := false
var _hours_bar: ProgressBar
var _hours_glow: Tween
var _hours_warning := false
var _blackout: ColorRect
var _last_countdown := 0
const COUNTDOWN_FROM := 5


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
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_board)

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
	_session.day_closing.connect(_on_day_closing)
	_session.day_ended.connect(_on_day_ended)
	add_child(_session)

	_board.now_provider = _session.now

	_title = TitleScreen.new()
	_title.start_pressed.connect(_start_game)
	_title.tutorial_pressed.connect(_start_tutorial)
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


func _on_home_pressed() -> void:
	Modal.open(self) \
		.title(Loc.t("home_title")) \
		.row(Loc.t("home_warn"), Palette.COCOA_600) \
		.button(Loc.t("go_home"), _go_home) \
		.button(Loc.t("cancel"), func(): pass)


func _go_home() -> void:
	_session.set_process(false)
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false
	_clear_blackout()
	for s in _board.slots:
		s.clear()
	for t in _board.tools:
		t.reset()
	for c in _queue_row.get_children():
		c.queue_free()
	for ch in get_children():
		if ch is Shop or ch is Modal:
			ch.queue_free()
	_show_title()


func _start_game() -> void:
	_title.hide()
	_session.start_run()


func _show_title() -> void:
	_title.show()


func _start_tutorial() -> void:
	_title.hide()
	var tut := Tutorial.new()
	tut.finished.connect(func():
		tut.queue_free()
		_show_title())
	add_child(tut)


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

	var home := Button.new()
	home.text = "🏠"
	home.add_theme_font_size_override("font_size", 16)
	home.custom_minimum_size = Vector2(34, 34)
	home.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	home.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	home.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	home.pressed.connect(_on_home_pressed)
	Audio.attach_click(home)
	row.add_child(home)

	_day_label = UI.label(Loc.t("day_n") % 1, 20, Palette.COCOA_800, true)
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
	row.add_child(_debug_btn("돈-5만", func(): _session.add_cash(-50000)))
	row.add_child(_debug_btn("즉시종료", func(): _session.debug_end_soon(1.0)))
	row.add_child(_debug_btn("손님내보냄", _debug_kick_customer))
	return row


func _debug_kick_customer() -> void:
	for s in _board.slots:
		var c := s.get_card()
		if c is OrderCard:
			(c as OrderCard).force_expire()
			return
	for ch in _queue_row.get_children():
		if ch is Customer:
			(ch as Customer).force_expire()
			return


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
	_backdrop.visible = true
	_warehouse.slide_open()
	Audio.play("door_open")
	_refresh_warehouse()


func _on_tool_tapped(tool: ToolStation) -> void:
	_warehouse.visible = false
	_backdrop.visible = true
	_cooking.open_for(tool)


func _close_sheets() -> void:
	if _warehouse.visible:
		_session.spend_time(Stats.warehouse_cost())
		Audio.play("door_close")
		_warehouse.slide_close()
	if _cooking.visible:
		_cooking.slide_close()
	_backdrop.visible = false


func _on_cooked() -> void:
	_close_sheets()
	_refresh_warehouse()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_close_sheets()


func _refresh_warehouse() -> void:
	_warehouse.refresh(_board.is_full())


func _process(_delta: float) -> void:
	_refresh_servable()


func _refresh_servable() -> void:
	if _board == null:
		return
	var ready := _board.available_dish_ids()
	for s in _board.slots:
		var c := s.get_card()
		if c is OrderCard:
			c.set_servable(ready.has(c.recipe_id))


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
	c.urged.connect(_on_urged)
	_queue_row.add_child(c)
	c.slide_in()
	Audio.play("customer_in")
	_visited_today += 1


func _on_confirm_order(customer: Customer) -> void:
	if _board.slot_counts()["orders"] >= Config.MAX_ORDERS:
		Toast.show_msg(self, Loc.t("orders_full"))
		return
	var slot := _board.first_empty_slot()
	if slot == null:
		Toast.show_msg(self, Loc.t("no_empty_slot"))
		return
	var rid := customer.recipe_id
	var order := OrderCard.new()
	order.setup(rid)
	order.born = _session.now()
	order.expired.connect(_on_order_expired)
	order.served.connect(_on_served)
	order.rejected.connect(_on_order_rejected)
	order.urged.connect(_on_urged)
	var from_pos := customer.global_position + customer.size * 0.5
	customer.dismiss()
	_fly_order_to_slot(order, slot, from_pos)
	get_tree().create_timer(0.36).timeout.connect(func():
		if is_instance_valid(customer):
			customer.queue_free())
	_accepted_today += 1
	if Buffs.consume_instant_order():
		_produce_dish(rid)
	_refresh_warehouse()


func _produce_dish(rid: String) -> void:
	for t in _board.tools:
		if t.is_idle():
			t.produce_instant(rid)
			return
	var s := _board.first_empty_slot()
	if s == null:
		return
	var dish := DishCard.new()
	dish.setup(rid)
	dish.born = _session.now()
	s.place_card(dish)


func _on_urged(card: Control) -> void:
	if not is_instance_valid(card):
		return
	_spawn_pop("💢", card.global_position + Vector2(card.size.x * 0.5, -8))


func _on_customer_expired(customer: Customer) -> void:
	_spawn_pop("😠", customer.global_position + customer.size * 0.5)
	_detach_and_fade(customer)


func _on_order_expired(order: OrderCard) -> void:
	var gain := Buffs.on_lost(order.recipe_id)
	if gain != 0:
		_expect_fly = true
		_session.earn(gain)
		_expect_fly = false
		_fly_gain(gain, order.global_position + order.size * 0.5, Palette.SUB)
	_order_lost_today += 1
	_spawn_pop("😠", order.global_position + order.size * 0.5)
	_detach_and_fade(order)
	_refresh_warehouse()


func _on_order_rejected(order: OrderCard) -> void:
	_spawn_pop("😠", order.global_position + order.size * 0.5)


func _on_served(order: OrderCard, dish: DishCard) -> void:
	Audio.play("serve")
	var rid := order.recipe_id
	var ctx := _sale_ctx(order, dish)
	var res := Buffs.sale_amount(rid, ctx)
	var amount := int(res["amount"])
	_expect_fly = true
	_session.earn(amount)
	_expect_fly = false
	var penalty := int(res.get("penalty", 0))
	if penalty != 0:
		_session.add_cash(-penalty)
	var discard_id := str(res.get("discard", ""))
	if discard_id != "":
		Buffs.discard(discard_id)
		_remove_buff_card(discard_id)
	Buffs.on_serve(rid, ctx)
	_served_today += 1
	_served_by_menu[rid] = int(_served_by_menu.get(rid, 0)) + 1

	var serve_pos := order.global_position + order.size * 0.5
	_fly_gain(amount, serve_pos)
	_spawn_pop("😊", serve_pos + Vector2(0, -18))

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


func _sale_ctx(order: OrderCard, dish: DishCard) -> Dictionary:
	var counts := _board.slot_counts()
	var orders: int = counts["orders"]
	var dishes: int = counts["dishes"]
	var ingr: int = counts["ingr"]
	var empty: int = counts["empty"]
	var now := _session.now()
	var dish_born := dish.born if (dish != null and is_instance_valid(dish)) else now
	return {
		"filled": orders + dishes + ingr,
		"empty": empty,
		"orders": orders,
		"dishes": dishes,
		"ingr": ingr,
		"buffs": Buffs.owned().size(),
		"now": now,
		"dish_age": now - dish_born,
		"order_age": now - order.born,
		"pat_frac": order.pat_frac(),
		"cash": _session.cash,
		"day_revenue": _session.day_revenue,
	}


func _remove_buff_card(buff_id: String) -> void:
	for s in _board.slots:
		var c := s.get_card()
		if c is BuffCard and c.buff_id == buff_id:
			s.clear()
			return


func _on_day_closing(s: Session) -> void:
	var same_max := 0
	for k in _served_by_menu:
		same_max = maxi(same_max, int(_served_by_menu[k]))
	var ctx := {
		"served": _served_today,
		"visited": _visited_today,
		"accepted": _accepted_today,
		"order_lost": _order_lost_today,
		"same_max": same_max,
		"day_revenue": s.day_revenue,
		"cash": s.cash,
		"rent": s.rent,
	}
	var bonus := Buffs.day_end_bonus(ctx)
	if bonus != 0:
		s.earn(bonus)


func _detach_and_fade(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var gpos := card.global_position
	var sz := card.size
	var holder := card.get_parent()
	if holder:
		holder.remove_child(card)
	add_child(card)
	card.top_level = true
	card.global_position = gpos
	card.size = sz
	card.z_index = 90
	card.pivot_offset = sz * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(card.queue_free)


func _fly_order_to_slot(card: OrderCard, slot: Slot, from_pos: Vector2) -> void:
	slot.place_card(card, false, false)
	if not is_instance_valid(card) or card.get_parent() == null:
		return
	var rect := slot.card_rect()
	var dest := rect.position
	var sz := rect.size
	card.modulate.a = 0.0

	var ghost := OrderCard.new()
	ghost.setup(card.recipe_id)
	add_child(ghost)
	ghost.set_process(false)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.top_level = true
	ghost.z_index = 95
	ghost.size = sz
	ghost.pivot_offset = sz * 0.5
	ghost.global_position = from_pos - sz * 0.5
	ghost.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "global_position", dest, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(ghost):
			ghost.queue_free()
		if is_instance_valid(card):
			card.modulate.a = 1.0
			card.pop_in()
		Audio.play("card_place"))


func _spawn_pop(text: String, at_pos: Vector2) -> void:
	var l := UI.label(text, 30)
	l.z_index = 101
	l.pivot_offset = Vector2(15, 15)
	add_child(l)
	l.position = at_pos - Vector2(15, 15)
	l.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2(1.3, 1.3), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 22, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


func _dot(color: Color) -> Control:
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	var wrap := CenterContainer.new()
	wrap.add_child(dot)
	return wrap


func _on_cash_changed(cash: int) -> void:
	var delta := cash - _last_cash
	_last_cash = cash
	_money_label.text = UI.money(cash)
	if delta > 0 and not _expect_fly:
		_pop_label(_money_label)
		Audio.play("coins")
	elif delta < 0:
		_spawn_loss(-delta)
		Audio.play("coins")


func _fade_to_black(cb: Callable) -> void:
	_clear_blackout()
	_blackout = ColorRect.new()
	_blackout.color = Palette.COCOA_900
	_blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blackout.modulate.a = 0.0
	_blackout.z_index = 290
	_blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blackout)
	var tw := create_tween()
	tw.tween_property(_blackout, "modulate:a", 0.82, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(cb)


func _clear_blackout() -> void:
	if _blackout != null and is_instance_valid(_blackout):
		_blackout.queue_free()
	_blackout = null


func _spawn_confetti(count := 46) -> void:
	var vp := get_viewport_rect().size
	var colors := [Palette.MAIN, Palette.SUB, Palette.ACCENT, Palette.SUCCESS, Palette.DANGER]
	for i in count:
		var p := ColorRect.new()
		p.color = colors[i % colors.size()]
		p.size = Vector2(8, 12)
		p.z_index = 350
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.pivot_offset = p.size * 0.5
		add_child(p)
		p.position = Vector2(randf_range(vp.x * 0.15, vp.x * 0.85), -20.0)
		var tw := create_tween()
		tw.set_parallel(true)
		var fall := randf_range(vp.y * 0.55, vp.y * 0.95)
		var drift := randf_range(-90.0, 90.0)
		var dur := randf_range(1.0, 1.8)
		tw.tween_property(p, "position", p.position + Vector2(drift, fall), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "rotation", randf_range(-6.0, 6.0), dur)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(p.queue_free)


func _show_day_banner(day: int) -> void:
	var l := UI.label(Loc.t("day_n") % day, 48, Palette.COCOA_800, true)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	l.z_index = 200
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	await get_tree().process_frame
	if not is_instance_valid(l):
		return
	var vp := get_viewport_rect().size
	l.pivot_offset = l.size * 0.5
	l.position = (vp - l.size) * 0.5 - Vector2(0, vp.y * 0.12)
	l.scale = Vector2(0.6, 0.6)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func _spawn_loss(amount: int) -> void:
	if amount <= 0:
		return
	var l := UI.label("-" + UI.money(amount), 18, Palette.DANGER, true)
	l.z_index = 100
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	add_child(l)
	var start := _money_label.global_position + Vector2(0, _money_label.size.y + 2)
	l.position = start
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", start.y + 26, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


func _pop_label(lbl: Control) -> void:
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _fly_gain(amount: int, from_pos: Vector2, color := Palette.SUCCESS) -> void:
	if amount == 0:
		return
	var l := UI.label("+" + UI.money(amount), 20, color, true)
	l.z_index = 100
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	add_child(l)
	l.position = from_pos
	await get_tree().process_frame
	if not is_instance_valid(l):
		return
	l.pivot_offset = l.size * 0.5
	var target := _money_label.global_position + _money_label.size * 0.5 - l.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "scale", Vector2(0.55, 0.55), 0.45).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if is_instance_valid(l):
			l.queue_free()
		_pop_label(_money_label)
		Audio.play("coins"))


func _on_progress(t01: float) -> void:
	_hours_bar.value = t01 * 100.0
	if t01 >= Config.HOURS_WARN_FRAC and not _hours_warning:
		_hours_warning = true
		_hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.DANGER))
		_hours_glow = create_tween().set_loops()
		_hours_glow.tween_property(_hours_bar, "modulate:a", 0.45, 0.35).set_trans(Tween.TRANS_SINE)
		_hours_glow.tween_property(_hours_bar, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	var left := _session.time_left()
	if left > 0.0 and left <= COUNTDOWN_FROM:
		var sec := int(ceil(left))
		if sec != _last_countdown:
			_last_countdown = sec
			_countdown_pop(sec)
	else:
		_last_countdown = 0


func _countdown_pop(sec: int) -> void:
	var l := UI.label(str(sec), 46, Palette.DANGER, true)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	l.z_index = 200
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	await get_tree().process_frame
	if not is_instance_valid(l):
		return
	var vp := get_viewport_rect().size
	l.pivot_offset = l.size * 0.5
	l.position = (vp - l.size) * 0.5 - Vector2(0, vp.y * 0.15)
	l.scale = Vector2(1.6, 1.6)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.1)
	tw.tween_interval(0.25)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func _reset_hours_bar() -> void:
	if _hours_glow != null:
		_hours_glow.kill()
		_hours_glow = null
	_hours_bar.modulate.a = 1.0
	_hours_warning = false
	_hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.ACCENT))


func _on_day_started(day: int, rent: int) -> void:
	_day_label.text = Loc.t("day_n") % day
	_session.set_process(false)
	get_tree().create_timer(Config.DAY_INTRO_DELAY).timeout.connect(func():
		if not is_inside_tree() or _title.visible:
			return
		_session.set_process(true)
		_show_day_banner(day)
		Audio.play("day_start"))
	_rent_label.text = UI.money(rent)
	_hours_bar.value = 0
	_reset_hours_bar()
	_last_countdown = 0
	_clear_blackout()
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false
	_visited_today = 0
	_accepted_today = 0
	_served_today = 0
	_order_lost_today = 0
	_served_by_menu = {}
	Buffs.reset_day()
	Move.clear()
	_board.rebuild(_session.effective_slots() + Buffs.buff_slot_bonus())
	for id in Buffs.owned():
		var slot := _board.first_empty_slot()
		if slot:
			var bc := BuffCard.new()
			bc.setup(id)
			slot.place_card(bc, false)
	for c in _queue_row.get_children():
		c.queue_free()
	_refresh_warehouse()


func _clear_play_field() -> void:
	for s in _board.slots:
		if s.get_card() is BuffCard:
			continue
		s.clear()
	for t in _board.tools:
		t.reset()
	for c in _queue_row.get_children():
		c.queue_free()


func _dayend_sequence() -> void:
	_freeze_field()
	await get_tree().create_timer(Config.DAY_END_PAUSE).timeout
	await _pop_clear_slots()
	for t in _board.tools:
		t.reset()
	for c in _queue_row.get_children():
		c.queue_free()


func _freeze_field() -> void:
	for s in _board.slots:
		var c := s.get_card()
		if c != null:
			c.set_process(false)
	for t in _board.tools:
		t.set_process(false)
	for c in _queue_row.get_children():
		c.set_process(false)


func _pop_clear_slots() -> void:
	var cards: Array = []
	for s in _board.slots:
		var c := s.get_card()
		if c != null and not (c is BuffCard):
			cards.append(c)
	if cards.is_empty():
		return
	var last: Tween = null
	var i := 0
	for c in cards:
		c.set_process(false)
		if c.has_method("set_servable"):
			c.set_servable(false)
		c.pivot_offset = c.size * 0.5
		var tw := create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(c, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2(0.05, 0.05), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.16)
		last = tw
		i += 1
	if last != null:
		await last.finished
	for s in _board.slots:
		if not (s.get_card() is BuffCard):
			s.clear()


func _on_day_ended(summary: Dictionary) -> void:
	if summary["won"]:
		_clear_play_field()
		Modal.open(self) \
			.title(Loc.t("win_title")) \
			.stamp_row(Loc.t("win_days") % Levels.count(), Palette.SUCCESS, 0.15) \
			.button(Loc.t("to_title"), _show_title)
		_spawn_confetti()
		get_tree().create_timer(0.5).timeout.connect(_spawn_confetti.bind(46))
	elif summary["passed"]:
		await _dayend_sequence()
		Modal.open(self) \
			.title(Loc.t("day_closed") % summary["day"]) \
			.count_row(Loc.t("revenue"), summary["revenue"]) \
			.count_row(Loc.t("rent"), summary["rent"], Palette.DANGER) \
			.sep() \
			.count_row(Loc.t("remaining"), summary["cash_after"], Palette.COCOA_800) \
			.stamp_row(Loc.t("passed"), Palette.SUCCESS) \
			.button(Loc.t("to_shop"), _open_shop)
	else:
		_clear_play_field()
		_fade_to_black(func():
			Modal.open(self) \
				.title(Loc.t("gameover_title")) \
				.row(Loc.t("gameover_day") % summary["day"]) \
				.row(Loc.t("gameover_reason") % [UI.money(summary["revenue"]), UI.money(summary["rent"])], Palette.DANGER) \
				.button(Loc.t("to_title"), _show_title))


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
