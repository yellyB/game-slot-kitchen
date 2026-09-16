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

	var back := Button.new()
	back.custom_minimum_size = Vector2(0, 44)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.add_child(UI.ui_btn_icon("house", 26))
	back.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	back.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	back.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	back.pressed.connect(func(): back_pressed.emit())
	Audio.attach_click(back)
	v.add_child(back)


## 가게 카드 — 해금=탭 가능(핑크 테두리), 잠금=회색+🔒+"준비중".
func _card(id: String) -> Button:
	var unlocked := Shops.is_unlocked(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 84)
	b.disabled = not unlocked
	if unlocked:
		b.add_theme_stylebox_override("normal", UI.card(Palette.WHITE, Palette.MAIN, 2))
		b.add_theme_stylebox_override("hover", UI.card(Palette.MAIN.lightened(0.85), Palette.MAIN, 2))
		b.add_theme_stylebox_override("pressed", UI.card(Palette.MAIN.lightened(0.78), Palette.MAIN, 2))
	b.add_theme_stylebox_override("disabled", UI.card(Palette.COCOA_100, Palette.COCOA_200, 1))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	# 잠금 = 정체 숨김("뭔가 온다" 정도만): 아이콘·이름 미공개.
	var icon := UI.label(Shops.icon_of(id) if unlocked else "❓", 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate.a = 1.0 if unlocked else 0.5
	row.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	texts.add_child(UI.label(Shops.name_of(id) if unlocked else "???", 20, Palette.COCOA_800 if unlocked else Palette.COCOA_600, true))
	if unlocked:
		texts.add_child(UI.label(Shops.desc_of(id), 13, Palette.COCOA_600))   # 잠금은 설명 없음(정체·상태 미공개)

	if not unlocked:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
		var lock := UI.ui_icon("slot_lock", 30)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock)
	else:
		b.pressed.connect(func(): shop_selected.emit(id))
		Audio.attach_click(b)
	return b
