class_name OrderCard
extends Card

signal expired(card: OrderCard)
signal served(card: OrderCard, dish: DishCard)
signal rejected(card: OrderCard)
signal urged(card: OrderCard)

var recipe_id: String
var animal := ""
var born := 0.0

var _max := Config.PATIENCE_DISH
var _time_left := Config.PATIENCE_DISH
var _done := false
var _warned := false
var _fill := Palette.SUB
var _gauge: ProgressBar
var _servable := false
var _glow: Tween

func setup(id: String) -> void:
	recipe_id = id

func is_trashable() -> bool:
	return false

func pat_frac() -> float:
	return clampf(_time_left / maxf(0.001, _max), 0.0, 1.0)

func _preview_text() -> String:
	return str(Recipes.get_def(recipe_id).get("icon", "?"))

func _preview_icon() -> Control:
	return Recipes.icon_node(recipe_id, 44)

func _build_content() -> void:
	_style.bg_color = Palette.TICKET
	_style.border_color = Palette.ACCENT

	var def := Recipes.get_def(recipe_id)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	add_child(v)

	if animal == "":
		animal = Customers.random_id()
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 2)
	v.add_child(top)

	var bubble := CenterContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(UI.ui_icon("bubble", 38))
	bubble.add_child(Recipes.icon_node(recipe_id, 20))
	top.add_child(bubble)

	top.add_child(Customers.icon_node(animal, 30))

	var reqs := HBoxContainer.new()
	reqs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reqs.alignment = BoxContainer.ALIGNMENT_CENTER
	reqs.add_theme_constant_override("separation", 1)
	v.add_child(reqs)
	for iid in def.get("ingredients", []):
		reqs.add_child(Ingredients.icon_node(iid, 22))

	_gauge = ProgressBar.new()
	_gauge.min_value = 0
	_max = Stats.dish_patience()
	_time_left = _max
	_gauge.max_value = _max
	_gauge.value = _max
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 6)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	_gauge.add_theme_stylebox_override("fill", UI.chip(_fill))
	v.add_child(_gauge)


func set_servable(on: bool) -> void:
	if on == _servable:
		return
	_servable = on
	if on:
		_style.bg_color = Palette.SUCCESS
		pivot_offset = size * 0.5
		_glow = create_tween().set_loops()
		_glow.tween_property(self, "scale", Vector2(1.07, 1.07), 0.35).set_trans(Tween.TRANS_SINE)
		_glow.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	else:
		if _glow != null:
			_glow.kill()
			_glow = null
		scale = Vector2.ONE
		_style.bg_color = Palette.TICKET


func can_accept(payload: Dictionary) -> bool:
	return payload.get("kind") == "dish" and str(payload.get("recipe_id")) == recipe_id

func accept(payload: Dictionary) -> void:
	served.emit(self, payload.get("card"))

func reject_payload(payload: Dictionary) -> bool:
	if payload.get("kind") == "dish" and not can_accept(payload):
		_reject()
		return true
	return false

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("kind") == "dish"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if can_accept(data):
		Move.on_drop(self, data)
	else:
		_reject()

func _reject() -> void:
	Audio.play("reject")
	var bx := position.x
	var tw := create_tween()
	tw.tween_property(self, "position:x", bx + 6.0, 0.05)
	tw.tween_property(self, "position:x", bx - 6.0, 0.05)
	tw.tween_property(self, "position:x", bx + 4.0, 0.05)
	tw.tween_property(self, "position:x", bx, 0.05)
	rejected.emit(self)


func set_paused(p: bool) -> void:
	if _done:
		return
	set_process(not p)
	if _glow != null and _glow.is_valid():
		if p:
			_glow.pause()
		else:
			_glow.play()


func force_expire() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	expired.emit(self)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	var col := Palette.DANGER if _time_left <= _max * Config.PATIENCE_LOW_FRAC else Palette.SUB
	if col != _fill:
		_fill = col
		_gauge.add_theme_stylebox_override("fill", UI.chip(col))
		if col == Palette.DANGER and not _warned:
			_warned = true
			_urge()
	if _time_left <= 0.0:
		_done = true
		set_process(false)
		expired.emit(self)


func _urge() -> void:
	urged.emit(self)
	var bx := position.x
	var tw := create_tween()
	tw.tween_property(self, "position:x", bx + 4.0, 0.05)
	tw.tween_property(self, "position:x", bx - 4.0, 0.05)
	tw.tween_property(self, "position:x", bx + 3.0, 0.05)
	tw.tween_property(self, "position:x", bx, 0.05)
