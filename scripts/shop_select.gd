class_name ShopSelect
extends Control
## 가게 선택 화면 — [시작](튜토리얼 완료 후) 표시. 해금 가게 탭 → shop_selected(id).
## 잠금 가게(준비중)는 회색+🔒로 표시, 탭 불가. 뒤로가기 → back_pressed(타이틀 복귀).

signal shop_selected(id: String)
signal back_pressed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 410   # 타이틀(400) 위
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var bg := ColorRect.new()
	bg.color = Palette.COCOA_50
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)

	var title := UI.label(Loc.t("shop_select_title"), 24, Palette.COCOA_800, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)

	for id in Shops.ids():
		v.add_child(_card(id))

	# 홈(뒤로) — 좌상단 고정
	var back := Button.new()
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 16    # 좌측 여백
	back.offset_right = 64   # 16 + 버튼 48
	back.offset_top = 44     # 노치/상태바 여유
	back.offset_bottom = 92
	back.add_child(UI.ui_btn_icon("house", 24))
	back.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	back.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	back.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	back.pressed.connect(func(): back_pressed.emit())
	Audio.attach_click(back)
	add_child(back)


## 가게 카드 — 해금=탭 가능(핑크 테두리), 잠금=회색+🔒+"준비중".
func _card(id: String) -> Button:
	var unlocked := Shops.is_unlocked(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 84)
	b.disabled = not unlocked
	b.add_theme_stylebox_override("disabled", UI.card(Palette.COCOA_100, Palette.COCOA_200, 1))

	# 이미지 하나만 가운데 — 이름·설명 없음. 잠금=자물쇠, 해금=가게 아이콘.
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cc)

	if not unlocked:
		cc.add_child(UI.ui_icon("slot_lock", 34))
		return b

	b.add_theme_stylebox_override("normal", UI.card(Palette.WHITE, Palette.MAIN, 2))
	b.add_theme_stylebox_override("hover", UI.card(Palette.MAIN.lightened(0.85), Palette.MAIN, 2))
	b.add_theme_stylebox_override("pressed", UI.card(Palette.MAIN.lightened(0.78), Palette.MAIN, 2))
	var art := str(Shops.get_def(id).get("art", ""))
	if art != "":
		cc.add_child(Recipes.icon_node(art, 60))   # 완성품 손그림(도넛=glazed), 없으면 이모지 폴백
	else:
		cc.add_child(UI.label(Shops.icon_of(id), 48))
	b.pressed.connect(func(): shop_selected.emit(id))
	Audio.attach_click(b)
	return b
