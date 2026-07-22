class_name Toast
extends Control
## 임시 알림 — 잠깐 떴다 사라지는 하단 토스트.
## 대강 구현(기능 위주) — 디자인 확정 후 제대로 정리 예정.
## 사용: Toast.show_msg(parent, "메시지")

var _msg := ""

static func show_msg(parent: Node, msg: String) -> void:
	var t := Toast.new()
	t._msg = msg
	parent.add_child(t)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_bottom = -84  # 하단 버튼 위쪽
	vb.alignment = BoxContainer.ALIGNMENT_END
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(center)

	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", UI.chip(Palette.COCOA_900))
	center.add_child(pill)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 7)
	pad.add_theme_constant_override("margin_bottom", 7)
	pill.add_child(pad)
	pad.add_child(UI.label(_msg, 15, Palette.WHITE))

	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
