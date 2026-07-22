class_name TitleScreen
extends Control
## 시작(타이틀) 화면 — 로고 + [시작]. 앱 실행/재시작 시 게임 위에 덮음.
## [시작] → start_pressed. main이 받아 세션 시작.

signal start_pressed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 400
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Palette.COCOA_50
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)

	var logo := UI.label("🍩", 72)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(logo)

	var title := UI.label("슬롯 키친", 34, Palette.COCOA_800, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	v.add_child(spacer)

	var start := Button.new()
	start.text = "시작"
	start.custom_minimum_size = Vector2(180, 56)
	start.add_theme_font_size_override("font_size", 22)
	start.add_theme_color_override("font_color", Palette.WHITE)
	start.add_theme_color_override("font_hover_color", Palette.WHITE)
	start.add_theme_color_override("font_pressed_color", Palette.WHITE)
	start.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	start.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	start.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	start.pressed.connect(func(): start_pressed.emit())
	v.add_child(start)
