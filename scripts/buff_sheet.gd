class_name BuffSheet
extends Sheet
## 보유 버프 리스트 서랍(바텀시트) — 레시피/창고 시트와 동일 패턴.
## 열 때마다 현재 보유 버프로 목록 재구성. 상점에선 항목 탭 = 판매(on_sell 콜백), 플레이에선 보기 전용.
## 보유 0개면 열지 않음 — 여는 버튼 쪽에서 disabled 처리.

signal close_requested

var on_sell: Callable   # 상점에서만 주입(항목 탭 → 판매 확인). 비어있으면 보기 전용.

var _list: VBoxContainer

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

	# 목록 — 보유 버프가 많아도 스크롤로 흡수(시트 높이 고정).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


## 현재 보유 버프로 목록 재구성 후 슬라이드 업.
func open() -> void:
	rebuild()
	slide_open()   # Sheet 베이스 — 아래서 슬라이드 업


## 보유 버프 항목 재구성(판매 후에도 호출).
func rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for id in Buffs.owned():
		_list.add_child(_entry(id))


## 버프 항목 한 줄: [아이콘] 이름 / 설명 … (상점이면 우측에 판매 코인 힌트, 탭=판매).
func _entry(id: String) -> Control:
	var sellable := on_sell.is_valid()
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 52)
	card.add_theme_stylebox_override("panel", UI.card(Palette.MAIN.lightened(0.82), Palette.MAIN))
	if sellable:
		card.mouse_filter = Control.MOUSE_FILTER_STOP   # 항목 탭 = 판매(확인 후)
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				on_sell.call(id))

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
		var coin := UI.ui_icon("coin", 16)   # 탭하면 팔림(코인 힌트)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(coin)
	return card
