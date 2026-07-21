extends Control
## 메인 게임 화면 — D1: 정적 레이아웃 (클릭 동작 없음).
## 상단바 / 손님 큐 / 슬롯 그리드(3×3, 도구석 2) / 하단 버튼.
## 비주얼-A: StyleBoxFlat 테마(둥근·팔레트색·그림자)를 코드로.

const GRID_COLS := 3
const GRID_SLOTS := 9
const TOOL_SLOTS := [2, 8]  # 도구석(🔥) 위치 (우상·우하)

func _ready() -> void:
	# 배경 크림
	var bg := ColorRect.new()
	bg.color = Palette.BG_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 바깥 여백
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(_build_top_bar())
	col.add_child(_build_customer_queue())
	col.add_child(_build_slot_grid())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	col.add_child(_build_bottom_buttons())


# ── 상단바: 일차·돈·가게세 + 영업시간 바 ──────────────────────
func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_box(Palette.WHITE))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pad.add_child(box)

	# 1행: 일차 · 돈 · 가게세
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var day := _label("1일차", 20, true)
	row.add_child(day)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	row.add_child(_money(Palette.ACCENT, "1,200"))   # 돈 🪙
	row.add_child(_money(Palette.DANGER, "300"))      # 가게세 🏠

	# 2행: 영업시간 진행 바 (해 → 달)
	var hours := HBoxContainer.new()
	hours.add_theme_constant_override("separation", 8)
	box.add_child(hours)

	hours.add_child(_label("낮", 14, false, Palette.GRAY500))

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 40
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _pill_box(Palette.GRAY100, Palette.GRAY300))
	bar.add_theme_stylebox_override("fill", _pill_box(Palette.ACCENT))
	hours.add_child(bar)

	hours.add_child(_label("밤", 14, false, Palette.GRAY500))

	return panel


# ── 손님 큐: 가로 카드 자리 ────────────────────────────────
func _build_customer_queue() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_box(Palette.GRAY100, Palette.GRAY300))
	panel.custom_minimum_size = Vector2(0, 96)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pad.add_child(row)

	for i in range(3):
		row.add_child(_customer_placeholder())

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	return panel


func _customer_placeholder() -> Control:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", _card_box(Palette.WHITE, Palette.GRAY300))
	c.custom_minimum_size = Vector2(60, 76)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)

	var face := _label("🙋", 22, false)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(face)

	var note := _label("📝", 16, false, Palette.GRAY500)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)

	return c


# ── 슬롯 그리드: 3×3, 도구석 2 ────────────────────────────
func _build_slot_grid() -> Control:
	var center := CenterContainer.new()

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)

	for i in range(GRID_SLOTS):
		grid.add_child(_slot(i in TOOL_SLOTS))

	return center


func _slot(is_tool: bool) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(104, 104)
	if is_tool:
		slot.add_theme_stylebox_override("panel", _card_box(Color("FBE9DA"), Palette.SUB, 2))
	else:
		slot.add_theme_stylebox_override("panel", _card_box(Palette.WHITE, Palette.GRAY300))

	if is_tool:
		var lbl := _label("🔥", 28, false, Palette.SUB)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(lbl)
	return slot


# ── 하단 버튼: 창고 · 휴지통 ───────────────────────────────
func _build_bottom_buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	row.add_child(_bottom_button("🏬 창고", Palette.MAIN))
	row.add_child(_bottom_button("🗑️ 휴지통", Palette.SUB))
	return row


func _bottom_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.WHITE)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_stylebox_override("normal", _pill_box(color))
	b.add_theme_stylebox_override("hover", _pill_box(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _pill_box(color.darkened(0.1)))
	return b


# ── 공용 헬퍼 ─────────────────────────────────────────────
func _label(text: String, size: int, bold: bool, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 0)
	return l


## *Money* — [색점][숫자] 표시 전용 컴포넌트.
func _money(dot_color: Color, amount: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)

	var dot := ColorRect.new()
	dot.color = dot_color
	dot.custom_minimum_size = Vector2(14, 14)
	var wrap := CenterContainer.new()
	wrap.add_child(dot)
	h.add_child(wrap)

	h.add_child(_label(amount, 18, true))
	return h


## 카드/패널 틀: 둥근 + 테두리 + 그림자.
func _card_box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(14)
	s.set_content_margin_all(0)
	if border.a > 0.0:
		s.set_border_width_all(border_w)
		s.border_color = border
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s


## 알약형(둥근) 틀 — 버튼·게이지.
func _pill_box(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s
