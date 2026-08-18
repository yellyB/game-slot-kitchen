class_name TitleScreen
extends Control
## 시작(타이틀) 화면 — 로고 + [시작]. 앱 실행/재시작 시 게임 위에 덮음.
## [시작] → start_pressed. main이 받아 세션 시작.

signal start_pressed
signal tutorial_pressed

var _start_btn: Button
var _tut_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 400
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg/title_bg.jpg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	start.text = Loc.t("start")
	_start_btn = start
	start.custom_minimum_size = Vector2(180, 56)
	start.add_theme_font_size_override("font_size", 22)
	start.add_theme_color_override("font_color", Palette.WHITE)
	start.add_theme_color_override("font_hover_color", Palette.WHITE)
	start.add_theme_color_override("font_pressed_color", Palette.WHITE)
	start.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	start.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	start.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	start.pressed.connect(func(): start_pressed.emit())
	Audio.attach_click(start)   # 시작 버튼 클릭음
	v.add_child(start)

	# 튜토리얼(핵심 루프 1회 체험) — 본격 게임과 분리, 이 버튼으로만 진입
	var tut := Button.new()
	tut.text = Loc.t("tutorial")
	_tut_btn = tut
	tut.custom_minimum_size = Vector2(180, 48)
	tut.add_theme_font_size_override("font_size", 18)
	tut.add_theme_color_override("font_color", Palette.COCOA_800)
	tut.add_theme_color_override("font_hover_color", Palette.COCOA_800)
	tut.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	tut.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	tut.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	tut.pressed.connect(func(): tutorial_pressed.emit())
	Audio.attach_click(tut)   # 튜토리얼 버튼 클릭음
	v.add_child(tut)

	# 우상단 설정 버튼(⚙️) → 설정 오버레이
	var gear := Button.new()
	gear.text = "⚙️"
	gear.add_theme_font_size_override("font_size", 22)
	gear.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100))
	gear.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	gear.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.offset_left = -60
	gear.offset_right = -16
	gear.offset_top = 16
	gear.offset_bottom = 60
	gear.pressed.connect(_open_settings)
	Audio.attach_click(gear)   # 설정 버튼 클릭음
	add_child(gear)


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	panel.tree_exited.connect(_refresh_texts)   # 설정 닫히면 언어 반영
	add_child(panel)


func _refresh_texts() -> void:
	if is_instance_valid(_start_btn):
		_start_btn.text = Loc.t("start")
	if is_instance_valid(_tut_btn):
		_tut_btn.text = Loc.t("tutorial")
