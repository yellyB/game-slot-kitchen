class_name CodexScreen
extends Control
## 도감 — 버프 카드 순서(card 번호)대로 4×5 그리드, 페이지 넘김.
## 발견(획득 이력) = 아이콘 + 이름 + 설명을 카드에 바로 표시(클릭 불필요).
## 미발견 = 회색 바탕 + ?. 발견 기록은 Codex(영구 저장)에서 조회.

const COLS := 4
const ROWS := 5
const PER := COLS * ROWS   # 페이지당 20칸
const CELL := Vector2(82, 132)

var _ids: Array = []
var _page := 0
var _pages := 1
var _grid: GridContainer
var _page_label: Label
var _prev: Button
var _next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 500
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 페이지 배경(크림) — 팝업이 아니라 화면 전체를 덮는 도감 페이지
	var bg := ColorRect.new()
	bg.color = Palette.COCOA_50
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 16)
	add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	# 헤더: 제목 + (오른쪽) 닫기 ✕
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	v.add_child(header)
	header.add_child(UI.label(Loc.t("codex"), 22, Palette.COCOA_800, true))
	var hgap := Control.new()
	hgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hgap)
	var close := Button.new()
	close.custom_minimum_size = Vector2(36, 36)
	close.add_child(UI.ui_btn_icon("fail_x", 28))   # 텍스트 ✕ → 빨강 X 이미지
	var empty := StyleBoxEmpty.new()   # 감싸는 칩 배경 제거 — X 이미지만
	close.add_theme_stylebox_override("normal", empty)
	close.add_theme_stylebox_override("hover", empty)
	close.add_theme_stylebox_override("pressed", empty)
	close.pressed.connect(queue_free)
	Audio.attach_click(close)
	header.add_child(close)

	# 그리드(상단 고정)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	v.add_child(_grid)

	# 그리드와 네비 사이 여백(네비를 하단으로)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	# 하단 페이지 네비: ◀  1 / N  ▶
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 16)
	v.add_child(nav)
	_prev = _nav_button("◀")
	_prev.pressed.connect(func(): _go(_page - 1))
	nav.add_child(_prev)
	_page_label = UI.label("1 / 1", 18, Palette.COCOA_800, true)
	_page_label.custom_minimum_size = Vector2(70, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_page_label)
	_next = _nav_button("▶")
	_next.pressed.connect(func(): _go(_page + 1))
	nav.add_child(_next)

	# 버프 순서 = card 번호 오름차순
	_ids = BuffDefs.ids()
	_ids.sort_custom(func(a, b): return _card_no(a) < _card_no(b))
	_pages = max(1, int(ceil(float(_ids.size()) / PER)))
	_go(0)


func _card_no(id: String) -> int:
	return int(BuffDefs.get_def(id).get("card", 9999))


func _nav_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(48, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.COCOA_800)
	b.add_theme_color_override("font_hover_color", Palette.COCOA_800)
	b.add_theme_color_override("font_disabled_color", Palette.COCOA_400)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_100))
	Audio.attach_click(b)
	return b


func _go(page: int) -> void:
	_page = clampi(page, 0, _pages - 1)
	_render()


func _render() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var start := _page * PER
	for i in range(start, min(start + PER, _ids.size())):
		_grid.add_child(_make_cell(_ids[i]))
	_page_label.text = "%d / %d" % [_page + 1, _pages]
	_prev.disabled = _page <= 0
	_next.disabled = _page >= _pages - 1


## 한 칸 — 발견이면 아이콘+이름+설명(연분홍 카드, 클릭 불필요), 미발견이면 회색+?.
func _make_cell(id: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CELL
	card.clip_contents = true   # 긴 설명이 카드 밖으로 넘치지 않게
	var found := Codex.is_discovered(id)
	# 그림자 끔 — 둥근 모서리 아래로 회색 뾰족이가 삐져나오는 현상 제거.
	var sb := UI.card(Palette.MAIN.lightened(0.82), Palette.MAIN, 2) if found else UI.card(Palette.COCOA_100, Palette.COCOA_200, 1)
	sb.shadow_size = 0
	card.add_theme_stylebox_override("panel", sb)

	if found:
		var pad := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			pad.add_theme_constant_override("margin_" + side, 5)
		card.add_child(pad)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(box)
		var icon := BuffDefs.icon_node(id, 30)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		var nm := UI.label(BuffDefs.display_name(id), 11, Palette.MAIN, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # 글자단위 — 앱/에디터 줄바꿈 일관(단어단위 시 줄 늘어남)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(nm)
		var desc := UI.label(BuffDefs.display_label(id), 9, Palette.COCOA_600)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # 글자단위
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(desc)
	else:
		var q := UI.label("?", 34, Palette.COCOA_400, true)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(q)
	return card
