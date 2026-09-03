class_name Tutorial
extends Control

signal finished

const RECIPE := "coffee"

enum { S_ACCEPT, S_WAREHOUSE, S_INGREDIENTS, S_COOK, S_SERVE, S_DONE }

var board: Board
var queue_row: HBoxContainer
var warehouse: Warehouse
var cooking: Cooking
var warehouse_btn: Button
var spawn_customer: Callable

var _spot: TutorialSpotlight
var _step := S_ACCEPT
var _prev_move_allowed: Callable
var _order_seen := false


func _ready() -> void:
	z_index = 350
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prev_move_allowed = Move.action_allowed
	Move.action_allowed = _gate
	Move.performed.connect(_on_move_performed)

	_spot = TutorialSpotlight.new()
	add_child(_spot)

	var exit := Button.new()
	exit.text = "✕"
	exit.add_theme_font_size_override("font_size", 16)
	exit.add_theme_color_override("font_color", Palette.COCOA_600)
	exit.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	exit.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	exit.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	exit.anchor_left = 1.0
	exit.anchor_right = 1.0
	exit.offset_left = -52
	exit.offset_right = -12
	exit.offset_top = 12
	exit.offset_bottom = 46
	exit.z_index = 600
	exit.pressed.connect(_finish)
	Audio.attach_click(exit)
	add_child(exit)

	spawn_customer.call()
	_goto_step(S_ACCEPT)


func _gate(payload: Dictionary) -> bool:
	match payload.get("kind"):
		"new":
			return _step == S_INGREDIENTS and _needs_more(str(payload.get("id")))
		"dish":
			return _step == S_SERVE
		_:
			return false


func _needs_more(id: String) -> bool:
	var need := 0
	for iid in Recipes.get_def(RECIPE).get("ingredients", []):
		if iid == id:
			need += 1
	if need == 0:
		return false
	return board.ingredient_counts().get(id, 0) < need


func _on_move_performed() -> void:
	_check_step()


func _process(_delta: float) -> void:
	_check_step()
	_update_spot_target()


func _check_step() -> void:
	match _step:
		S_ACCEPT:
			if _find_order() != null:
				_goto_step(S_WAREHOUSE)
		S_WAREHOUSE:
			if warehouse.visible:
				_goto_step(S_INGREDIENTS)
		S_INGREDIENTS:
			if board.has_ingredients(RECIPE):
				_goto_step(S_COOK)
		S_COOK:
			if _find_dish() != null:
				_goto_step(S_SERVE)
		S_SERVE:
			if _order_seen and _find_order() == null:
				_goto_step(S_DONE)


func _goto_step(s: int) -> void:
	_step = s
	match s:
		S_ACCEPT: _spot.set_message(Loc.t("tut_accept"))
		S_WAREHOUSE: _spot.set_message(Loc.t("tut_warehouse"))
		S_INGREDIENTS: _spot.set_message(Loc.t("tut_ingredients"))
		S_COOK: _spot.set_message(Loc.t("tut_cook"))
		S_SERVE:
			_order_seen = true
			_spot.set_message(Loc.t("tut_serve"))
		S_DONE: _show_done()
	_update_spot_target()


func _current_target() -> Control:
	match _step:
		S_ACCEPT: return _first_customer()
		S_WAREHOUSE: return warehouse_btn
		S_INGREDIENTS: return warehouse if warehouse.visible else warehouse_btn
		S_COOK: return cooking if cooking.visible else board
		S_SERVE: return board
	return null


func _update_spot_target() -> void:
	if _spot != null and _spot.visible:
		_spot.target = _current_target()


func _first_customer() -> Control:
	for c in queue_row.get_children():
		if c is Customer:
			return c
	return null


func _find_order() -> OrderCard:
	for sl in board.slots:
		var c := sl.get_card()
		if c is OrderCard:
			return c
	return null


func _find_dish() -> Control:
	for t in board.tools:
		var d := t.get_dish()
		if d != null and d.recipe_id == RECIPE:
			return d
	for sl in board.slots:
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
	Move.action_allowed = _prev_move_allowed
	finished.emit()
