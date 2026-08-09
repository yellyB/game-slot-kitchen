class_name Tutorial
extends Control

signal finished

const RECIPE := "coffee"

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
var _clock := 0.0


func _ready() -> void:
	z_index = 350
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	Buffs.clear()

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

	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 8)
	_queue_row.custom_minimum_size = Vector2(0, 96)
	col.add_child(_queue_row)

	_board = Board.new()
	_board.now_provider = _now
	_board.tool_tapped.connect(_on_tool_tapped)
	col.add_child(_board)
	_board.rebuild(4)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

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

	_prev_move_target = Move.default_target
	Move.default_target = func(_p): return _board.first_empty_slot()
	Move.performed.connect(_on_move_performed)

	_spot = TutorialSpotlight.new()
	add_child(_spot)

	_spawn_customer()
	_goto_step(S_ACCEPT)


func _now() -> float:
	return _clock


func _spawn_customer() -> void:
	_customer = Customer.new()
	_customer.setup(RECIPE)
	_customer.confirm_pressed.connect(_on_confirm)
	_queue_row.add_child(_customer)
	_customer.set_process(false)
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
	_order.set_process(false)
	if _step == S_ACCEPT:
		_goto_step(S_WAREHOUSE)


func _on_served(_order_card: OrderCard, _dish: DishCard) -> void:
	if _step != S_DONE:
		_goto_step(S_DONE)


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
	_close_sheets()


func _close_sheets() -> void:
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_close_sheets()


func _on_move_performed() -> void:
	_check_step()


func _process(_delta: float) -> void:
	_clock += _delta
	if _order != null and is_instance_valid(_order):
		_order.set_servable(_board.available_dish_ids().has(RECIPE))
	_check_step()


func _check_step() -> void:
	match _step:
		S_WAREHOUSE:
			if _warehouse.visible:
				_goto_step(S_INGREDIENTS)
		S_INGREDIENTS:
			if _board.has_ingredients(RECIPE):
				_close_sheets()
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
	Move.default_target = _prev_move_target
	Move.clear()
	finished.emit()
