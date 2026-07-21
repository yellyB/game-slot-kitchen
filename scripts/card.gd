class_name Card
extends PanelContainer

var _style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.WHITE
	_style.set_corner_radius_all(12)
	_style.set_border_width_all(1)
	_style.border_color = Palette.COCOA_200
	_style.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	_style.shadow_size = 3
	_style.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("panel", _style)
	_build_content()


func _build_content() -> void:
	pass

func is_trashable() -> bool:
	return false

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
	var ps := StyleBoxFlat.new()
	ps.bg_color = Palette.WHITE
	ps.set_corner_radius_all(12)
	ps.set_border_width_all(2)
	ps.border_color = Palette.MAIN
	preview.add_theme_stylebox_override("panel", ps)
	preview.modulate = Color(1, 1, 1, 0.9)
	var lbl := Label.new()
	lbl.text = _preview_text()
	lbl.add_theme_font_size_override("font_size", 28)
	preview.add_child(lbl)
	return preview
