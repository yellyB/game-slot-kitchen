class_name Card
extends PanelContainer

var _style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = UI.card(Palette.WHITE, Palette.COCOA_200, 1, 12)
	add_theme_stylebox_override("panel", _style)
	_build_content()


func _build_content() -> void:
	pass

func is_trashable() -> bool:
	return false

func dispose() -> void:
	var holder := get_parent()
	if holder:
		holder.remove_child(self)
	queue_free()

func _preview_text() -> String:
	return "?"


func get_move_payload() -> Dictionary:
	return {"kind": "move", "card": self}


func set_selected(sel: bool) -> void:
	_style.border_color = Palette.MAIN if sel else Palette.COCOA_200
	_style.set_border_width_all(2 if sel else 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.on_click(self)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	Move.begin_drag()
	set_drag_preview(_make_preview())
	return get_move_payload()


func _make_preview() -> Control:
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.MAIN, 2, 12))
	preview.modulate = Color(1, 1, 1, 0.9)
	preview.add_child(UI.label(_preview_text(), 28))
	return preview
