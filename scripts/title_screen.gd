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

	# 로고(도넛) — 통통 위아래로 튀는 아이들 모션(플레인 Control로 감싸 VBox 레이아웃과 분리)
	var logo_wrap := Control.new()
	logo_wrap.custom_minimum_size = Vector2(0, 96)
	var logo := UI.label("🍩", 80)
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_wrap.add_child(logo)
	v.add_child(logo_wrap)
	_bob(logo)

	# 게임 타이틀 — 글자별 브랜드 컬러 + 진한 코코아 외곽선 + 부드러운 그림자로 로고화
	var title := _make_title("슬롯 키친")
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


# 글자별 색 — 딸기핑크·크림옐로 교차(따뜻한 도넛 카페 톤). 공백은 건너뜀.
const _TITLE_COLORS := [Palette.MAIN, Palette.ACCENT, Palette.MAIN, Palette.ACCENT]

## 타이틀을 글자 단위 라벨로 쪼개 컬러/외곽선/그림자/기울기를 개별 부여 → 로고 느낌.
func _make_title(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 1)
	var idx := 0
	for ch in text:
		if ch == " ":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(18, 0)
			row.add_child(gap)
			continue
		row.add_child(_glyph(ch, _TITLE_COLORS[idx % _TITLE_COLORS.size()], idx))
		idx += 1
	return row

## 한 글자 라벨 — 굵게 + 진한 코코아 외곽선 + 아래 그림자 + 좌우로 살짝 기울임.
func _glyph(ch: String, color: Color, idx: int) -> Label:
	var l := UI.label(ch, 58, color, true)
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Palette.COCOA_900)
	l.add_theme_color_override("font_shadow_color", Color(0.164, 0.129, 0.106, 0.28))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.add_theme_constant_override("shadow_outline_size", 14)
	l.rotation_degrees = -5.0 if idx % 2 == 0 else 5.0
	l.resized.connect(func(): l.pivot_offset = l.size * 0.5)   # 제자리 회전 위해 중앙 피벗
	return l

## 도넛 로고 — 위아래로 통통(무한 루프).
func _bob(node: Control) -> void:
	var t := create_tween().set_loops()
	t.tween_property(node, "position:y", -7.0, 0.75).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position:y", 7.0, 0.75).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## 타이틀 — 은은한 숨쉬기 스케일(무한 루프).
func _pulse(node: Control) -> void:
	node.resized.connect(func(): node.pivot_offset = node.size * 0.5)
	var t := create_tween().set_loops()
	t.tween_property(node, "scale", Vector2(1.04, 1.04), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	panel.tree_exited.connect(_refresh_texts)   # 설정 닫히면 언어 반영
	add_child(panel)


func _refresh_texts() -> void:
	if is_instance_valid(_start_btn):
		_start_btn.text = Loc.t("start")
	if is_instance_valid(_tut_btn):
		_tut_btn.text = Loc.t("tutorial")
