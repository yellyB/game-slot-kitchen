class_name Modal
extends Control
## 중앙 패널 모달 (딤 배경 + 입력 차단). 결과·게임오버·승리 공용.
## 대강 구현(기능 위주) — 디자인 확정 후 정리.

var _body: VBoxContainer

static func open(parent: Node) -> Modal:
	var m := Modal.new()
	parent.add_child(m)
	return m

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤 입력 차단

	var dim := ColorRect.new()
	dim.color = Palette.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200))
	center.add_child(panel)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(pad)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	pad.add_child(_body)


func title(text: String) -> Modal:
	_body.add_child(_centered(UI.label(text, 22, Palette.COCOA_800, true)))
	return self


func row(text: String, color := Palette.COCOA_800) -> Modal:
	_body.add_child(_centered(UI.label(text, 16, color)))
	return self


## 숫자 카운트업 행 — fmt(단일 %d)의 숫자를 0에서 value까지 촤르륵 세어 올림.
func count_row(fmt: String, value: int, color := Palette.COCOA_800) -> Modal:
	var l := _centered(UI.label(fmt % 0, 16, color))
	_body.add_child(l)
	var tw := create_tween()
	tw.tween_method(func(v: float): l.text = fmt % int(round(v)), 0.0, float(value), 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return self


## 도장 찍듯 팡 등장하는 강조 행 — delay(카운트업 종료 즈음) 후 스케일 팝 + 페이드인.
func stamp_row(text: String, color := Palette.SUCCESS, delay := 0.55) -> Modal:
	var l := _centered(UI.label(text, 20, color, true))
	_body.add_child(l)
	l.modulate.a = 0.0
	l.scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): l.pivot_offset = l.size * 0.5)   # 레이아웃 후 중앙 피벗
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(l, "scale", Vector2(1.25, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	return self


func sep() -> Modal:
	var line := ColorRect.new()
	line.color = Palette.COCOA_200
	line.custom_minimum_size = Vector2(0, 1)
	_body.add_child(line)
	return self


func button(text: String, cb: Callable) -> Modal:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.WHITE)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	b.pressed.connect(func():
		queue_free()
		cb.call())
	_body.add_child(b)
	return self


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
