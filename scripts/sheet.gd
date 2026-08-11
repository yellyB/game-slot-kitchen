class_name Sheet
extends Panel

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
