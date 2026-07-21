extends Control
## 메인 게임 화면.
## D1: 정적 레이아웃(상단바·손님 큐·슬롯 그리드·하단 버튼).
## D2: 창고에서 재료 꺼내기 + 슬롯 배치/이동/휴지통 제거.
##     모든 이동은 Move 컨트롤러로 클릭·드래그 공용 처리.
## 비주얼-A: StyleBoxFlat 테마(둥근·팔레트색·그림자)를 코드로.

const GRID_COLS := 3
const GRID_SLOTS := 9
const TOOL_SLOTS := [2, 8]  # 도구석(🔥) 위치 (우상·우하) — 재료 못 들어옴
const MAX_QUEUE := 4         # 손님 큐 최대
const SPAWN_INTERVAL := 4.0  # 손님 등장 간격(초) — 나중에 config.gd/웨이브(D6)로

var _slots: Array[Slot] = []

var _warehouse_btn: Button
var _trash_btn: TrashButton
var _warehouse_sheet: Panel
var _tiles: Array[IngredientTile] = []

var _queue_row: HBoxContainer
var _spawn_timer: Timer


func _ready() -> void:
	# 배경 크림 — 빈 곳 클릭 시 선택 해제 캐처
	var bg := ColorRect.new()
	bg.color = Palette.BG_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_background_input)
	add_child(bg)

	# 바깥 여백 (구조 컨테이너는 클릭 통과 → 빈 곳 클릭이 bg로)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(_build_top_bar())
	col.add_child(_build_customer_queue())
	col.add_child(_build_slot_grid())

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	col.add_child(_build_bottom_buttons())

	# 창고 시트는 다른 UI 위에 뜨도록 마지막에 추가
	_warehouse_sheet = _build_warehouse_sheet()
	add_child(_warehouse_sheet)

	Move.performed.connect(_refresh_tiles)

	# 손님 스포너
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_customer)
	add_child(_spawn_timer)
	_spawn_timer.start()
	_spawn_customer()  # 시작하자마자 첫 손님


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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	row.add_child(_label("1일차", 20, true))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	row.add_child(_money(Palette.ACCENT, "1,200"))
	row.add_child(_money(Palette.DANGER, "300"))

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

	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 8)
	pad.add_child(_queue_row)

	return panel


# ── 슬롯 그리드: 3×3, 도구석 2 ────────────────────────────
func _build_slot_grid() -> Control:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)

	for i in range(GRID_SLOTS):
		var slot := Slot.new()
		slot.setup(i in TOOL_SLOTS)
		_slots.append(slot)
		grid.add_child(slot)

	return center


# ── 하단 버튼: 창고 · 휴지통 ───────────────────────────────
func _build_bottom_buttons() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)

	_warehouse_btn = _make_bottom_button(Palette.MAIN)
	_warehouse_btn.text = "🏬 창고"
	_warehouse_btn.pressed.connect(_toggle_warehouse)
	row.add_child(_warehouse_btn)

	_trash_btn = TrashButton.new()
	_trash_btn.text = "🗑️ 휴지통"
	_style_bottom_button(_trash_btn, Palette.SUB)
	row.add_child(_trash_btn)

	return row


# ── 창고 하단 시트 ────────────────────────────────────────
func _build_warehouse_sheet() -> Panel:
	var sheet := Panel.new()
	sheet.visible = false
	sheet.anchor_left = 0.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = 8
	sheet.offset_right = -8
	sheet.offset_top = -240
	sheet.offset_bottom = -8

	var box := StyleBoxFlat.new()
	box.bg_color = Palette.WHITE
	box.set_corner_radius_all(18)
	box.set_border_width_all(1)
	box.border_color = Palette.GRAY300
	box.shadow_color = Color(0.164, 0.129, 0.106, 0.18)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, -2)
	sheet.add_theme_stylebox_override("panel", box)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	sheet.add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	header.add_child(_label("🏬 창고", 18, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var close := Button.new()
	close.text = "닫기"
	close.add_theme_font_size_override("font_size", 14)
	close.add_theme_color_override("font_color", Palette.GRAY700)
	close.add_theme_stylebox_override("normal", _pill_box(Palette.GRAY100, Palette.GRAY300))
	close.add_theme_stylebox_override("hover", _pill_box(Palette.GRAY300))
	close.add_theme_stylebox_override("pressed", _pill_box(Palette.GRAY300))
	close.pressed.connect(_toggle_warehouse)
	header.add_child(close)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	for id in Ingredients.unlocked_ids():
		var tile := IngredientTile.new()
		tile.setup(id)
		_tiles.append(tile)
		grid.add_child(tile)

	return sheet


# ── 상호작용 ──────────────────────────────────────────────
func _toggle_warehouse() -> void:
	_warehouse_sheet.visible = not _warehouse_sheet.visible
	if _warehouse_sheet.visible:
		_refresh_tiles()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.background_click()


# ── 손님 / 주문 ───────────────────────────────────────────
func _spawn_customer() -> void:
	if _queue_row.get_child_count() >= MAX_QUEUE:
		return
	var c := Customer.new()
	c.setup(Recipes.random_id())
	c.note_tapped.connect(_on_note_tapped)
	c.expired.connect(_on_customer_expired)
	_queue_row.add_child(c)


## 쪽지 탭 → 주문서 티켓을 다음 빈 슬롯에. 손님은 큐에 그대로.
func _on_note_tapped(customer: Customer) -> void:
	if customer.order_taken:
		return
	var slot := _first_empty_slot()
	if slot == null:
		return  # 빈 슬롯 없음 (나중에 Toast)
	var ticket := OrderCard.new()
	ticket.setup(customer.recipe_id)
	slot.place_card(ticket)
	customer.mark_order_taken()
	_refresh_tiles()


## 인내심 0 → 손님 퇴장 (손실 처리는 D5/D6에서).
func _on_customer_expired(customer: Customer) -> void:
	customer.queue_free()


func _first_empty_slot() -> Slot:
	for s in _slots:
		if s.is_empty():
			return s
	return null


func _board_full() -> bool:
	for s in _slots:
		if s.is_empty():
			return false
	return true


## 빈 슬롯 없으면 창고 타일 비활성(회색).
func _refresh_tiles() -> void:
	var full := _board_full()
	for tile in _tiles:
		tile.disabled = full
		tile.modulate = Color(1, 1, 1, 0.45) if full else Color.WHITE


# ── 공용 헬퍼 ─────────────────────────────────────────────
func _label(text: String, size: int, bold: bool, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _make_bottom_button(color: Color) -> Button:
	var b := Button.new()
	_style_bottom_button(b, color)
	return b


func _style_bottom_button(b: Button, color: Color) -> void:
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.WHITE)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_stylebox_override("normal", _pill_box(color))
	b.add_theme_stylebox_override("hover", _pill_box(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _pill_box(color.darkened(0.1)))


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
