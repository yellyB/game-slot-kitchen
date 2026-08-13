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
	offset_top = -480   # 메뉴 6개가 스크롤 없이 다 보이는 높이
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

	# 레시피 목록 — 스크롤 없이 전부 표시(시트 높이로 수용)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	v.add_child(list)

	for id in Recipes.all_ids():
		var entry := _entry(id)
		_entries.append(entry)
		list.add_child(entry)


func open_for(tool: ToolStation) -> void:
	_active_tool = tool
	_refresh()
	slide_open()   # Sheet 베이스 — 아래서 슬라이드 업


## 레시피 항목: [필요재료…] → [완성요리] … [⏱️n]. 탭 → 조리.
## 재료(입력)와 완성품(결과)을 화살표로 구분 — 요리를 재료로 착각 안 하게.
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
	row.add_theme_constant_override("separation", 6)
	row.offset_left = 12
	row.offset_right = -12
	entry.add_child(row)

	# 1) 메뉴(완성 요리)
	var menu := CenterContainer.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.custom_minimum_size = Vector2(52, 0)
	menu.add_child(Recipes.icon_node(id, 36))
	row.add_child(menu)
	row.add_child(_col_divider())

	# 2) 재료(필요 입력) — 가운데 가변폭 칸
	var ing := HBoxContainer.new()
	ing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ing.alignment = BoxContainer.ALIGNMENT_CENTER
	ing.add_theme_constant_override("separation", 6)
	for iid in def.get("ingredients", []):
		ing.add_child(Ingredients.icon_node(iid, 24))
	row.add_child(ing)
	row.add_child(_col_divider())

	# 3) 걸리는 시간
	var time := CenterContainer.new()
	time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time.custom_minimum_size = Vector2(52, 0)
	time.add_child(UI.label("⏱️%d" % int(def.get("cook_time", 0)), 16, Palette.COCOA_600))
	row.add_child(time)

	entry.pressed.connect(func(): _select(id))
	return entry

## 항목 내 세로 구분선 — 메뉴 | 재료 | 시간 구획.
func _col_divider() -> Control:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_top", 9)
	m.add_theme_constant_override("margin_bottom", 9)
	var line := ColorRect.new()
	line.color = Palette.COCOA_200
	line.custom_minimum_size = Vector2(1.5, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(line)
	return m


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
	var tool := _active_tool
	var cards := board.take_ingredient_cards(id)   # 슬롯에서 떼기(연출 후 제거)
	# 재료 소비 후의 빈 슬롯 수 = 카드37(빈 슬롯당 조리 가속) 입력.
	var empty := board.empty_slot_count()
	tool.start_cooking(id, empty)
	Audio.play("cook_start")   # 조리 시작음(팝)
	_active_tool = null
	cooked.emit()  # main이 닫기 + 갱신
	_fly_ingredients_to(cards, tool)   # 재료 카드가 도구석으로 날아가 사라짐


## 소비된 재료 카드들이 도구석으로 날아가 축소·페이드(순차 스태거). 최상위로 옮겨 시트 위에서도 보이게.
func _fly_ingredients_to(cards: Array, tool: ToolStation) -> void:
	if not is_instance_valid(tool):
		return
	var target := tool.global_position + tool.size * 0.5
	for i in cards.size():
		var it: Dictionary = cards[i]
		var c: Control = it["card"]
		if not is_instance_valid(c):
			continue
		var gpos: Vector2 = it["gpos"]
		var sz: Vector2 = it["size"]
		get_tree().root.add_child(c)
		c.top_level = true
		c.z_index = 400
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.global_position = gpos
		c.pivot_offset = sz * 0.5
		var delay := i * 0.05
		var tw := c.create_tween()
		tw.set_parallel(true)
		tw.tween_property(c, "global_position", target - sz * 0.5, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(delay)
		tw.tween_property(c, "scale", Vector2(0.2, 0.2), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(delay)
		tw.tween_property(c, "modulate:a", 0.0, 0.1).set_delay(delay + 0.24)
		tw.chain().tween_callback(c.queue_free)
