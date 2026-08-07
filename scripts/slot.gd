class_name Slot
extends PanelContainer

var _holder: MarginContainer

func _ready() -> void:
	custom_minimum_size = Vector2(104, 104)
	add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200, 1))

	_holder = MarginContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		_holder.add_theme_constant_override("margin_" + side, 6)
	add_child(_holder)


func is_empty() -> bool:
	return _get_card() == null


func _get_card() -> Card:
	for ch in _holder.get_children():
		if ch is Card:
			return ch
	return null


func get_card() -> Card:
	return _get_card()


func clear() -> void:
	var c := _get_card()
	if c:
		_holder.remove_child(c)
		c.queue_free()


func place_new(id: String) -> void:
	var card := IngredientCard.new()
	card.setup(id)
	place_card(card)


func place_card(card: Card, play_sfx := true) -> void:
	if not is_empty() or card == null:
		return
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.add_child(card)
	card.pop_in()
	if play_sfx:
		Audio.play("card_place")


func take_card(card: Card) -> void:
	if not is_empty() or card == null or not is_instance_valid(card):
		return
	var prev := card.get_parent()
	if prev:
		prev.remove_child(card)
	_holder.add_child(card)
	card.pop_in()
	Audio.play("card_place")
	var dc := card as DishCard
	if dc != null and dc.tool != null:
		var t := dc.tool
		dc.tool = null
		t.reset()


func can_accept(payload: Dictionary) -> bool:
	if not is_empty():
		return false
	var k = payload.get("kind")
	return k == "new" or k == "move" or k == "dish"


func accept(payload: Dictionary) -> void:
	match payload.get("kind"):
		"new":
			place_new(str(payload.get("id")))
		"move", "dish":
			take_card(payload.get("card"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.on_click(self)
		accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)
