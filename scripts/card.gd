class_name Card
extends PanelContainer

var _style: StyleBoxFlat
var _wrap: Control
var _holder: Control
var _content_min := Vector2.ZERO
var _scale_to_width := false
var _fit_bottom_reserve := 0.0

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
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.modulate.a = 0.0
	wrap.add_child(holder)
	for ch in built:
		remove_child(ch)
		holder.add_child(ch)
	add_child(wrap)
	_wrap = wrap
	_holder = holder
	resized.connect(func(): _fit_wrap.call_deferred())
	_setup_fit()


func _setup_fit() -> void:
	for _i in 8:
		await get_tree().process_frame
		if _holder == null or not is_instance_valid(_holder):
			return
		for ch in _holder.get_children():
			if ch is Control:
				_content_min = _content_min.max((ch as Control).get_combined_minimum_size())
	if _content_min.x <= 0.0 and _content_min.y <= 0.0:
		_holder.modulate.a = 1.0
		return
	for ch in _holder.get_children():
		if ch is Control:
			(ch as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_wrap()
	_holder.modulate.a = 1.0


const _FIT_MARGIN := 0.9

func _fit_wrap() -> void:
	if _wrap == null or not is_instance_valid(_wrap) or _holder == null:
		return
	if _content_min.x <= 0.0 and _content_min.y <= 0.0:
		return
	var avail := _wrap.size - Vector2(0, _fit_bottom_reserve)
	if avail.x <= 0.0 or avail.y <= 0.0:
		return
	var cmin_x := _content_min.x if _scale_to_width else minf(_content_min.x, avail.x)
	var target := Vector2(maxf(cmin_x, avail.x), maxf(_content_min.y, avail.y))
	_holder.size = target
	_holder.position = (avail - target) * 0.5
	_holder.pivot_offset = target * 0.5
	var raw := minf(avail.x / cmin_x, avail.y / _content_min.y)
	var s := minf(1.0, raw * _FIT_MARGIN)
	_holder.scale = Vector2(s, s)


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
	modulate.a = 0.0
	var prev := Vector2.ZERO
	for _i in 8:
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
		if size.x > 0.0 and size.y > 0.0 and size == prev:
			break
		prev = size
	pivot_offset = size * 0.5
	scale = Vector2(0.6, 0.6)
	modulate.a = 1.0
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
