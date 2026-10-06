class_name TitleScreen
extends Control

signal start_pressed
signal tutorial_pressed
signal dbg_lives_pressed

const TITLE_TEXT := "Slot Kitchen"
const BuildInfo := preload("res://scripts/build_info.gd")

var _start_btn: Button
var _codex_btn: Button
var _dbg_lives_btn: Button

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

	var title := _make_title(TITLE_TEXT)
	v.add_child(title)
	_pulse(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	v.add_child(spacer)

	var start := Button.new()
	_start_btn = start
	start.custom_minimum_size = Vector2(180, 56)
	start.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	start.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	start.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	start.draw.connect(_draw_play_triangle.bind(start))
	start.pressed.connect(func(): start_pressed.emit())
	Audio.attach_click(start)
	v.add_child(start)

	var codex := Button.new()
	codex.text = Loc.t("codex")
	_codex_btn = codex
	codex.custom_minimum_size = Vector2(180, 48)
	codex.add_theme_font_size_override("font_size", 18)
	codex.add_theme_color_override("font_color", Palette.COCOA_800)
	codex.add_theme_color_override("font_hover_color", Palette.COCOA_800)
	codex.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	codex.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	codex.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	codex.pressed.connect(_open_codex)
	Audio.attach_click(codex)
	v.add_child(codex)

	if OS.is_debug_build():
		var dbg := Button.new()
		_dbg_lives_btn = dbg
		dbg.custom_minimum_size = Vector2(180, 40)
		dbg.add_theme_font_size_override("font_size", 14)
		dbg.add_theme_color_override("font_color", Palette.COCOA_800)
		dbg.add_theme_color_override("font_hover_color", Palette.COCOA_800)
		dbg.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
		dbg.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
		dbg.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
		dbg.pressed.connect(func(): dbg_lives_pressed.emit())
		Audio.attach_click(dbg)
		v.add_child(dbg)

	var gear := Button.new()
	gear.add_child(UI.ui_btn_icon("settings", 30))
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

	var ver := UI.label(BuildInfo.label(), 13, Palette.COCOA_600)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -220
	ver.offset_right = -14
	ver.offset_top = -44
	ver.offset_bottom = -20
	add_child(ver)


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

func _pulse(node: Control) -> void:
	node.resized.connect(func(): node.pivot_offset = node.size * 0.5)
	var t := create_tween().set_loops()
	t.tween_property(node, "scale", Vector2(1.04, 1.04), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_dbg_lives(on: bool) -> void:
	if is_instance_valid(_dbg_lives_btn):
		_dbg_lives_btn.text = "🐞 목숨 ON" if on else "🐞 목숨 OFF"


func _open_codex() -> void:
	add_child(CodexScreen.new())


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	panel.tree_exited.connect(_refresh_texts)
	add_child(panel)


func _draw_play_triangle(btn: Button) -> void:
	var s := btn.size
	var w := 22.0
	var h := 24.0
	var cx := s.x * 0.5 + w / 6.0
	var cy := s.y * 0.5
	var pts := PackedVector2Array([
		Vector2(cx - w * 0.5, cy - h * 0.5),
		Vector2(cx - w * 0.5, cy + h * 0.5),
		Vector2(cx + w * 0.5, cy),
	])
	btn.draw_colored_polygon(pts, Palette.WHITE)


func _refresh_texts() -> void:
	if is_instance_valid(_codex_btn):
		_codex_btn.text = Loc.t("codex")
