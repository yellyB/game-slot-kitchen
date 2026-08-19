class_name Sheet
extends Panel

func make_close_handle() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(80, 26)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	b.draw.connect(_draw_down_chevron.bind(b))
	return b


func _draw_down_chevron(b: Button) -> void:
	var w := 16.0
	var h := 7.0
	var th := 3.0
	var cx := b.size.x * 0.5
	var cy := b.size.y * 0.5
	var l := Vector2(cx - w * 0.5, cy - h * 0.5)
	var m := Vector2(cx, cy + h * 0.5)
	var r := Vector2(cx + w * 0.5, cy - h * 0.5)
	b.draw_polyline(PackedVector2Array([l, m, r]), Palette.COCOA_600, th, true)


func slide_open() -> void:
	visible = true
	var rt := offset_top
	var rb := offset_bottom
	var d := -rt + 20.0
	offset_top = rt + d
	offset_bottom = rb + d
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset_top", rt, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "offset_bottom", rb, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func slide_close() -> void:
	if not visible:
		return
	var rt := offset_top
	var rb := offset_bottom
	var d := -rt + 20.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset_top", rt + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "offset_bottom", rb + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		visible = false
		offset_top = rt
		offset_bottom = rb)


func slide_open_side() -> void:
	visible = true
	var rl := offset_left
	var rr := offset_right
	var d := get_viewport_rect().size.x
	offset_left = rl + d
	offset_right = rr + d
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset_left", rl, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "offset_right", rr, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func slide_close_side() -> void:
	if not visible:
		return
	var rl := offset_left
	var rr := offset_right
	var d := get_viewport_rect().size.x
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset_left", rl + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "offset_right", rr + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		visible = false
		offset_left = rl
		offset_right = rr)
