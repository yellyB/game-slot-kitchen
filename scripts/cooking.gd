class_name Cooking
extends Sheet
## 조리 레시피 팝업 + B안 오케스트레이션.
## 도구석 탭 → open_for(tool). 재료 다 있는 레시피만 활성. 선택 시 소비 + 조리 시작.

signal cooked          ## 조리 시작(재료 소비)됨 → 보드 상태 갱신용
signal close_requested ## ✕ 닫기

const ICON := 44           # 메뉴 아이콘 크기
const ING := 32            # 재료 아이콘 크기(작게 — 한 줄에 여러 개 들어가게)
const ENTRY_H := 64        # 레시피 항목 높이(1줄: 메뉴·재료 … 가격·⏱시간)
const ROW_SEP := 8         # 항목 간격
const SHEET_CHROME := 84   # 헤더 + 상하 패딩 여유(시트 높이 계산용)

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
	# 시트 높이 = 레시피 전부 스크롤 없이 수용(위로 늘어남). 개수 늘어도 자동 대응.
	var n := Recipes.all_ids().size()
	offset_top = -(SHEET_CHROME + n * ENTRY_H + maxi(0, n - 1) * ROW_SEP)
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
	list.add_theme_constant_override("separation", ROW_SEP)
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
	entry.custom_minimum_size = Vector2(0, ENTRY_H)
	entry.add_theme_stylebox_override("normal", UI.card(Palette.COCOA_100, Palette.COCOA_200))
	entry.add_theme_stylebox_override("hover", UI.card(Palette.ACCENT.lightened(0.35), Palette.ACCENT))
	entry.add_theme_stylebox_override("pressed", UI.card(Palette.ACCENT.lightened(0.2), Palette.ACCENT))
	entry.add_theme_stylebox_override("disabled", UI.card(Palette.COCOA_100, Palette.COCOA_200))
	entry.set_meta("recipe_id", id)

	# 한 줄: 메뉴 | 재료들 … 가격 | ⏱시간. (재료는 작게 — 4개여도 안 잘림)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 10)
	entry.add_child(row)
	var menu_node := Recipes.icon_node(id, ICON)          # 메뉴(완성 요리)
	row.add_child(menu_node)
	row.add_child(_col_divider())                          # 완성품 | 재료 구분

	# 재료(필요 입력) — 작게. 노드는 _refresh에서 보유여부에 따라 진하게/흐리게.
	var ing := HBoxContainer.new()
	ing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ing.add_theme_constant_override("separation", 4)
	var ing_nodes: Array = []
	for iid in def.get("ingredients", []):
		var node := Ingredients.icon_node(iid, ING)
		ing.add_child(node)
		ing_nodes.append({"node": node, "iid": iid})
	entry.set_meta("ings", ing_nodes)
	row.add_child(ing)

	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var coin_node := _coin(int(def.get("price", 0)))      # 가격
	row.add_child(coin_node)
	# 시간 — 스톱워치 손그림 + 숫자
	var time_node := HBoxContainer.new()
	time_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_node.add_theme_constant_override("separation", 2)
	time_node.add_child(UI.ui_icon("timer", 20))
	time_node.add_child(UI.label(str(int(def.get("cook_time", 0))), 20, Palette.COCOA_600))
	row.add_child(time_node)

	# 제작 불가(비활성) 시 흐리게 할 "제안" 부분 — 재료 아이콘은 보유여부대로 별도 처리.
	entry.set_meta("offer", [menu_node, coin_node, time_node])

	entry.pressed.connect(func(): _select(id))
	return entry


## 가격 표시 — 동전 손그림 + 금액.
func _coin(amount: int) -> Control:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.add_child(UI.ui_icon("coin", 18))
	box.add_child(UI.label(UI.money(amount), 18, Palette.COCOA_800, true))
	return box

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
	var have := board.ingredient_counts()   # ing_id → 보드 위 개수
	for entry in _entries:
		var id: String = entry.get_meta("recipe_id")
		var ok := board.has_ingredients(id)
		entry.disabled = not ok
		entry.modulate = Color.WHITE
		# 제작 불가 → 메뉴·가격·시간(제안)만 흐리게(비활성 표시)
		var offer_a := 1.0 if ok else 0.35
		for n in entry.get_meta("offer", []):
			n.modulate = Color(1, 1, 1, offer_a)
		# 재료별: 보유하면 진하게, 없으면 흐리게 → "뭐가 없어서 못 만드는지" 표시(비활성이어도 유지)
		for it in entry.get_meta("ings", []):
			var present: bool = have.get(it["iid"], 0) > 0
			it["node"].modulate = Color.WHITE if present else Color(1, 1, 1, 0.25)


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
