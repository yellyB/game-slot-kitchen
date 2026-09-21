class_name BuffSheet
extends Sheet
## 보유 버프 리스트 서랍(바텀시트) — 레시피/창고 시트와 동일 패턴.
## 열 때마다 현재 보유 버프로 목록 재구성. 상점에선 항목마다 [팔기] 버튼(on_sell 콜백), 플레이에선 보기 전용.
## 보유 0개면 열지 않음 — 여는 버튼 쪽에서 disabled 처리.

signal close_requested

var on_sell: Callable   # 상점에서만 주입([팔기] 버튼 → 판매 확인). 비어있으면 보기 전용.

const ROW_H := 66.0     # 항목 1개 예상 높이(계산용) — 스크롤 없이 잘 보이게 여유
const ROW_SEP := 8.0
const CHROME := 64.0    # 패딩(28) + 닫기핸들(26) + separation(10)
const TOP_KEEP := 120.0 # 화면 위 남길 여백(상단바 노출) — 넘으면 스크롤

var _list: VBoxContainer
var _count: Label

func _ready() -> void:
	visible = false
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 8
	offset_right = -8
	offset_top = -320
	offset_bottom = -8
	add_theme_stylebox_override("panel", UI.sheet())

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pad.add_child(v)

	# 헤더 — 상단 가운데 닫기 핸들(넓은 알약 + 아래 꺾쇠 ∨, 창고·조리 서랍과 동일).
	var header := CenterContainer.new()
	v.add_child(header)
	var close := make_close_handle()
	close.pressed.connect(func(): close_requested.emit())
	Audio.attach_click(close)   # 닫기 클릭음
	header.add_child(close)

	# 보유/상한(n/5) — 헤더 위 우상단 오버레이(닫기 핸들 중앙정렬 유지).
	_count = UI.label("", 14, Palette.MAIN, true)
	_count.anchor_left = 1.0
	_count.anchor_right = 1.0
	_count.offset_left = -74
	_count.offset_right = -16
	_count.offset_top = 12
	_count.offset_bottom = 34
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_count)

	# 목록 — 개수만큼 높이 늘고(open에서 계산), 화면 넘치면 스크롤로 흡수.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


## 현재 보유 버프로 목록 재구성 후 슬라이드 업.
## 시트 높이 = 보유 개수에 맞춤(적으면 낮게, 많으면 높게). 상한 넘으면 그 높이서 스크롤.
func open() -> void:
	rebuild()
	var n := Buffs.owned().size()
	var want := CHROME + n * ROW_H + maxf(0.0, n - 1) * ROW_SEP
	var cap := get_viewport_rect().size.y - TOP_KEEP
	offset_top = -minf(want, cap)
	_rest_top = offset_top       # 가변 높이라 매번 rest 갱신 후 슬라이드
	_rest_bottom = offset_bottom
	_rest_captured = true        # slide_open의 최초 1회 캡처 건너뛰고 위 값 사용
	slide_open()   # Sheet 베이스 — 아래서 슬라이드 업


## 보유 버프 항목 재구성(판매 후에도 호출).
func rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for id in Buffs.owned():
		_list.add_child(_entry(id))
	_count.text = "%d/%d" % [Buffs.owned().size(), Config.MAX_BUFFS + Buffs.buff_slot_bonus()]


## 버프 항목 한 줄: [아이콘] 이름 / 설명 … (상점이면 우측에 [팔기] 버튼).
func _entry(id: String) -> Control:
	var sellable := on_sell.is_valid()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 52)
	card.add_theme_stylebox_override("panel", UI.card(Palette.MAIN.lightened(0.82), Palette.MAIN))

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 6)
	card.add_child(pad)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)

	row.add_child(BuffDefs.icon_node(id, 34))   # 카테고리 아이콘(손그림)

	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 1)
	row.add_child(texts)
	texts.add_child(UI.label(BuffDefs.display_name(id), 14, Palette.COCOA_800, true))
	var desc := UI.label(BuffDefs.display_label(id), 12, Palette.MAIN)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2.ZERO
	texts.add_child(desc)

	if sellable:
		var sell_btn := Button.new()   # [팔기] → 판매 확인 팝업(on_sell)
		sell_btn.text = Loc.t("buff_sell")
		sell_btn.add_theme_font_size_override("font_size", 13)
		sell_btn.add_theme_color_override("font_color", Palette.WHITE)
		sell_btn.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
		sell_btn.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
		sell_btn.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
		sell_btn.custom_minimum_size = Vector2(64, 34)
		sell_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sell_btn.pressed.connect(func(): on_sell.call(id))
		Audio.attach_click(sell_btn)
		row.add_child(sell_btn)
	return card
