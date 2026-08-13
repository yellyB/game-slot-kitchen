class_name Card
extends PanelContainer

var _style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_style = UI.card(Palette.WHITE, Palette.COCOA_200, 1, 12)
	_style.shadow_size = 0
	add_theme_stylebox_override("panel", _style)
	_build_content()
	_wrap_content()


func _wrap_content() -> void:
	var built := get_children()
	if built.is_empty():
		return
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in built:
		remove_child(ch)
		wrap.add_child(ch)
		if ch is Control:
			(ch as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wrap)


func _build_content() -> void:
	pass

func is_trashable() -> bool:
	return false

func dispose() -> void:
	var holder := get_parent()
	if holder:
		holder.remove_child(self)
	queue_free()

func pop_in() -> void:
	scale = Vector2(0.6, 0.6)
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

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


func _preview_icon() -> Control:
	var lbl := UI.label(_preview_text(), 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _make_preview() -> Control:
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.MAIN, 2, 12))
	preview.modulate = Color(1, 1, 1, 0.92)
	preview.custom_minimum_size = size * 0.9
	var ic := _preview_icon()
	ic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(ic)
	return preview
