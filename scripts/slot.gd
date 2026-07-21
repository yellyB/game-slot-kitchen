class_name Slot
extends PanelContainer

var is_tool := false
var _holder: MarginContainer

func setup(tool: bool) -> void:
	is_tool = tool

func _ready() -> void:
	custom_minimum_size = Vector2(104, 104)
	add_theme_stylebox_override("panel", _box())

	_holder = MarginContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		_holder.add_theme_constant_override("margin_" + side, 6)
	add_child(_holder)

	if is_tool:
		var lbl := Label.new()
		lbl.text = "🔥"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Palette.SUB)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_holder.add_child(lbl)


func is_empty() -> bool:
	return not is_tool and _get_card() == null


func _get_card() -> IngredientCard:
	for ch in _holder.get_children():
		if ch is IngredientCard:
			return ch
	return null


func place_new(id: String) -> void:
	if not is_empty():
		return
	var card := IngredientCard.new()
	card.setup(id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.add_child(card)


func take_card(card: IngredientCard) -> void:
	if not is_empty() or card == null or not is_instance_valid(card):
		return
	var prev := card.get_parent()
	if prev:
		prev.remove_child(card)
	_holder.add_child(card)


func can_accept(payload: Dictionary) -> bool:
	if is_tool or not is_empty():
		return false
	return payload.get("kind") == "new" or payload.get("kind") == "move"


func accept(payload: Dictionary) -> void:
	match payload.get("kind"):
		"new":
			place_new(str(payload.get("id")))
		"move":
			take_card(payload.get("card"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.on_click(self)
		accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)


func _box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(14)
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	if is_tool:
		s.bg_color = Color("FBE9DA")
		s.set_border_width_all(2)
		s.border_color = Palette.SUB
	else:
		s.bg_color = Palette.WHITE
		s.set_border_width_all(1)
		s.border_color = Palette.GRAY300
	return s
