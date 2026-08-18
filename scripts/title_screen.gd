class_name TitleScreen
extends Control

signal start_pressed
signal tutorial_pressed

const TITLE_TEXT := "Slot Kitchen"

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

	var logo_wrap := Control.new()
	logo_wrap.custom_minimum_size = Vector2(0, 96)
	var logo := UI.label("🍩", 80)
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_wrap.add_child(logo)
	v.add_child(logo_wrap)
	_bob(logo)

	var title := _make_title(TITLE_TEXT)
	v.add_child(title)
	_pulse(title)

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
	Audio.attach_click(start)
	v.add_child(start)

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
	Audio.attach_click(tut)
	v.add_child(tut)

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
	Audio.attach_click(gear)
	add_child(gear)


const _TITLE_COLORS := [Palette.MAIN, Palette.ACCENT, Palette.MAIN, Palette.ACCENT]
const _TITLE_MAX_W := 330.0
const _TITLE_BASE := 58

func _make_title(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 1)
	var size := _fit_size(text)
	var idx := 0
	for ch in text:
		if ch == " ":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(size * 0.32, 0)
			row.add_child(gap)
			continue
		row.add_child(_glyph(ch, _TITLE_COLORS[idx % _TITLE_COLORS.size()], idx, size))
		idx += 1
	return row

func _fit_size(text: String) -> int:
	var visible := text.replace(" ", "").length()
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _TITLE_BASE).x
	w += visible * (_TITLE_BASE * 0.18)
	var size := _TITLE_BASE
	if w > _TITLE_MAX_W:
		size = int(_TITLE_MAX_W / w * _TITLE_BASE)
	return clampi(size, 26, _TITLE_BASE)

func _glyph(ch: String, color: Color, idx: int, size: int) -> Label:
	var l := UI.label(ch, size, color, true)
	var outline := maxi(6, int(size * 0.24))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Palette.COCOA_900)
	l.add_theme_color_override("font_shadow_color", Color(0.164, 0.129, 0.106, 0.28))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, int(size * 0.09)))
	l.add_theme_constant_override("shadow_outline_size", outline)
	l.rotation_degrees = -5.0 if idx % 2 == 0 else 5.0
	l.resized.connect(func(): l.pivot_offset = l.size * 0.5)
	return l

func _bob(node: Control) -> void:
	var t := create_tween().set_loops()
	t.tween_property(node, "position:y", -7.0, 0.75).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position:y", 7.0, 0.75).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _pulse(node: Control) -> void:
	node.resized.connect(func(): node.pivot_offset = node.size * 0.5)
	var t := create_tween().set_loops()
	t.tween_property(node, "scale", Vector2(1.04, 1.04), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	panel.tree_exited.connect(_refresh_texts)
	add_child(panel)


func _refresh_texts() -> void:
	if is_instance_valid(_start_btn):
		_start_btn.text = Loc.t("start")
	if is_instance_valid(_tut_btn):
		_tut_btn.text = Loc.t("tutorial")
