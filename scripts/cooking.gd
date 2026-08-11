class_name Cooking
extends Sheet
## 조리 레시피 팝업 + B안 오케스트레이션.
## 도구석 탭 → open_for(tool). 재료 다 있는 레시피만 활성. 선택 시 소비 + 조리 시작.

signal cooked          ## 조리 시작(재료 소비)됨 → 보드 상태 갱신용
signal close_requested ## ✕ 닫기

var board: Board  # main이 주입
var _entries: Array[Button] = []
var _active_tool: ToolStation

func _ready() -> void:
	visible = false
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 8
	offset_right = -8
	offset_top = -400   # 메뉴 6개 목록 (넘치면 스크롤)
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

	var header := HBoxContainer.new()
	v.add_child(header)
	header.add_child(UI.label("🔥", 20, Palette.COCOA_800, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Palette.COCOA_600)
	close.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	close.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	close.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	close.pressed.connect(func(): close_requested.emit())
	Audio.attach_click(close)   # X 닫기 클릭음
	header.add_child(close)

	# 레시피 목록 (많으면 스크롤)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for id in Recipes.all_ids():
		var entry := _entry(id)
		_entries.append(entry)
		list.add_child(entry)


func open_for(tool: ToolStation) -> void:
	_active_tool = tool
	_refresh()
	slide_open()   # Sheet 베이스 — 아래서 슬라이드 업


## 레시피 항목: [요리] [필요재료…] … [⏱️n]. 탭 → 조리.
func _entry(id: String) -> Button:
	var def := Recipes.get_def(id)
	var entry := Button.new()
	entry.custom_minimum_size = Vector2(0, 52)
	entry.add_theme_stylebox_override("normal", UI.card(Palette.COCOA_100, Palette.COCOA_200))
	entry.add_theme_stylebox_override("hover", UI.card(Palette.ACCENT.lightened(0.35), Palette.ACCENT))
	entry.add_theme_stylebox_override("pressed", UI.card(Palette.ACCENT.lightened(0.2), Palette.ACCENT))
	entry.add_theme_stylebox_override("disabled", UI.card(Palette.COCOA_100, Palette.COCOA_200))
	entry.set_meta("recipe_id", id)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	row.offset_left = 12
	row.offset_right = -12
	entry.add_child(row)

	row.add_child(UI.label(str(def.get("icon", "?")), 24))
	for iid in def.get("ingredients", []):
		row.add_child(UI.label(str(Ingredients.get_def(iid).get("icon", "?")), 18))

	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	row.add_child(UI.label("⏱️%d" % int(def.get("cook_time", 0)), 16, Palette.COCOA_600))

	entry.pressed.connect(func(): _select(id))
	return entry


func _refresh() -> void:
	for entry in _entries:
		var id: String = entry.get_meta("recipe_id")
		var ok := board.has_ingredients(id)
		entry.disabled = not ok
		entry.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.45)


func _select(id: String) -> void:
	if _active_tool == null or not _active_tool.is_idle():
		return
	if not board.has_ingredients(id):
		return
	board.consume_ingredients(id)
	# 재료 소비 후의 빈 슬롯 수 = 카드37(빈 슬롯당 조리 가속) 입력.
	var empty := board.empty_slot_count()
	_active_tool.start_cooking(id, empty)
	Audio.play("cook_start")   # 조리 시작음(팝)
	_active_tool = null
	cooked.emit()  # main이 닫기 + 갱신
