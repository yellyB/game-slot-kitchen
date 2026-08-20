class_name Sheet
extends Panel

var _rest_top: float
var _rest_bottom: float
var _rest_left: float
var _rest_right: float
var _rest_captured := false
var _slide_tw: Tween

func _capture_rest() -> void:
	if _rest_captured:
		return
	_rest_top = offset_top
	_rest_bottom = offset_bottom
	_rest_left = offset_left
	_rest_right = offset_right
	_rest_captured = true

func _kill_slide() -> void:
	if _slide_tw != null and _slide_tw.is_valid():
		_slide_tw.kill()

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
	_capture_rest()
	_kill_slide()
	visible = true
	var rt := _rest_top
	var rb := _rest_bottom
	var d := -rt + 20.0
	offset_top = rt + d
	offset_bottom = rb + d
	_slide_tw = create_tween()
	_slide_tw.set_parallel(true)
	_slide_tw.tween_property(self, "offset_top", rt, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tw.tween_property(self, "offset_bottom", rb, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func slide_close() -> void:
	if not visible:
		return
	_kill_slide()
	var rt := _rest_top
	var rb := _rest_bottom
	var d := -rt + 20.0
	_slide_tw = create_tween()
	_slide_tw.set_parallel(true)
	_slide_tw.tween_property(self, "offset_top", rt + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slide_tw.tween_property(self, "offset_bottom", rb + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slide_tw.chain().tween_callback(func():
		visible = false
		offset_top = rt
		offset_bottom = rb)


func slide_open_side() -> void:
	_capture_rest()
	_kill_slide()
	visible = true
	var rl := _rest_left
	var rr := _rest_right
	var d := get_viewport_rect().size.x
	offset_left = rl + d
	offset_right = rr + d
	_slide_tw = create_tween()
	_slide_tw.set_parallel(true)
	_slide_tw.tween_property(self, "offset_left", rl, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tw.tween_property(self, "offset_right", rr, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func slide_close_side() -> void:
	if not visible:
		return
	_kill_slide()
	var rl := _rest_left
	var rr := _rest_right
	var d := get_viewport_rect().size.x
	_slide_tw = create_tween()
	_slide_tw.set_parallel(true)
	_slide_tw.tween_property(self, "offset_left", rl + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slide_tw.tween_property(self, "offset_right", rr + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slide_tw.chain().tween_callback(func():
		visible = false
		offset_left = rl
		offset_right = rr)
