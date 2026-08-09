class_name Shop
extends Control
## 인터세션 상점 — 보유 돈 + 슬롯 확장 + 버프 팩(카드깡) + 보유 버프 + [영업 시작].
## 딤 배경 + 입력 차단. 대강 구현(디자인 후 정리).

signal start_business

var session: Session  # main이 add_child 전에 주입
var _cash_label: Label
var _buy_slot_btn: Button
var _draw_btn: Button
var _owned_row: HBoxContainer
var _drew := false   # 이번 상점 방문에서 이미 뽑았는지(방문당 1회). 다음날 재진입 시 새 인스턴스로 리셋.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Palette.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200))
	center.add_child(panel)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	# 헤더: 🏪 + 보유 돈
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	v.add_child(header)
	header.add_child(UI.label("🏪", 22, Palette.COCOA_800, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	header.add_child(_dot(Palette.ACCENT))
	_cash_label = UI.label("0", 18, Palette.COCOA_800, true)
	header.add_child(_cash_label)

	# 상품: 슬롯 확장 / 버프 팩
	_buy_slot_btn = _product(v, Loc.t("shop_slot"), Loc.t("shop_price") % UI.money(Config.shop_price(Config.SLOT_PRICE, session.day)), Loc.t("shop_buy"), Palette.SUB, _on_buy_slot)
	_draw_btn = _product(v, Loc.t("shop_buffpack"), Loc.t("shop_price") % UI.money(Config.shop_price(Config.BUFF_PACK_PRICE, session.day)), Loc.t("shop_draw"), Palette.MAIN, _on_draw)

	# 보유 버프
	v.add_child(UI.label(Loc.t("shop_owned"), 13, Palette.COCOA_600))
	_owned_row = HBoxContainer.new()
	_owned_row.add_theme_constant_override("separation", 6)
	_owned_row.custom_minimum_size = Vector2(0, 30)
	v.add_child(_owned_row)

	# [영업 시작]
	var start := Button.new()
	start.text = Loc.t("shop_start")
	start.custom_minimum_size = Vector2(0, 48)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.add_theme_font_size_override("font_size", 18)
	start.add_theme_color_override("font_color", Palette.WHITE)
	start.add_theme_color_override("font_hover_color", Palette.WHITE)
	start.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	start.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	start.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	start.pressed.connect(func():
		queue_free()
		start_business.emit())
	Audio.attach_click(start)   # 영업 시작 버튼 클릭음
	v.add_child(start)

	_refresh()


## 상품 카드 (이름/가격/버튼). 버튼 반환.
func _product(parent: Node, title: String, price: String, btn_text: String, btn_color: Color, cb: Callable) -> Button:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.card(Palette.COCOA_100, Palette.COCOA_200))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	card.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	info.add_child(UI.label(title, 18, Palette.COCOA_800, true))
	info.add_child(UI.label(price, 14, Palette.COCOA_600))
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(72, 40)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Palette.WHITE)
	btn.add_theme_color_override("font_hover_color", Palette.WHITE)
	btn.add_theme_stylebox_override("normal", UI.chip(btn_color))
	btn.add_theme_stylebox_override("hover", UI.chip(btn_color.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", UI.chip(btn_color.darkened(0.1)))
	btn.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_200))
	btn.pressed.connect(cb)
	Audio.attach_click(btn)   # 구매 버튼 클릭음
	row.add_child(btn)
	parent.add_child(card)
	return btn


func _on_buy_slot() -> void:
	if session.buy_slot():
		_refresh()


func _on_draw() -> void:
	if _drew:
		return   # 방문당 1회만
	var pack := session.buy_buff_pack()
	if pack.is_empty():
		return
	_drew = true
	_refresh()
	_show_pack(pack)


## 버프 팩 개봉 — 3개 중 1개 택(드래프트), 나머지 버림.
func _show_pack(pack: Array) -> void:
	Audio.play("pack_open")   # 카드팩 개봉 순간
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 10
	add_child(overlay)

	var od := ColorRect.new()
	od.color = Palette.DIM
	od.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(od)

	var oc := CenterContainer.new()
	oc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(oc)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	oc.add_child(box)
	var t := UI.label(Loc.t("shop_pick3"), 18, Palette.WHITE, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var choices: Array = []
	var i := 0
	for id in pack:
		var choice := _pack_choice(id, choices, overlay)
		row.add_child(choice)
		choices.append(choice)
		_reveal_choice(choice, i)   # 하나씩 팝하며 개봉
		i += 1


## 개봉 연출 — 카드가 작게/투명하게 시작해 순서대로 튀며 나타남.
func _reveal_choice(card: Control, idx: int) -> void:
	card.scale = Vector2(0.2, 0.2)
	card.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tw := create_tween()
	tw.tween_interval(idx * 0.5)   # 스태거(하나씩 이어서 개봉)
	tw.tween_callback(func(): Audio.play("card_slide"))   # 꺼내지는 순간(등장 시작)
	# 0.2 → 1.3(잠시 크게) → 1.0(원래 크기). 한 카드 ~1초로 천천히.
	tw.tween_property(card, "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.35)
	tw.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pack_choice(id: String, choices: Array, overlay: Control) -> Control:
	var def := BuffDefs.get_def(id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(92, 0)   # 세 후보 동일 고정폭(라벨 autowrap과 함께 폭 안정화)
	card.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.MAIN, 2))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	card.add_child(pad)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	pad.add_child(v)
	var icon := UI.label(str(def.get("icon", "?")), 30)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)
	var nm := UI.label(BuffDefs.display_name(id), 13, Palette.COCOA_800)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.custom_minimum_size = Vector2.ZERO
	v.add_child(nm)
	var lb := UI.label(BuffDefs.display_label(id), 12, Palette.MAIN)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.custom_minimum_size = Vector2.ZERO
	v.add_child(lb)
	var pick := Button.new()
	pick.text = Loc.t("shop_pick")
	pick.add_theme_font_size_override("font_size", 13)
	pick.add_theme_color_override("font_color", Palette.WHITE)
	pick.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	pick.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	pick.pressed.connect(func(): _pick_chosen(card, id, choices, overlay))
	Audio.attach_click(pick)   # 뽑기 버튼 클릭음
	v.add_child(pick)
	return card


## 버프 선택 — 고른 카드 팡(크게) + 나머지 쪼그라들며 사라짐, 그 후 오버레이 닫기.
func _pick_chosen(chosen: Control, id: String, choices: Array, overlay: Control) -> void:
	if overlay.get_meta("picked", false):
		return   # 중복 선택 방지
	overlay.set_meta("picked", true)
	Buffs.add(id)
	for c in choices:
		if not is_instance_valid(c):
			continue
		c.pivot_offset = c.size * 0.5
		if c == chosen:
			var tw := create_tween()
			tw.tween_property(c, "scale", Vector2(1.4, 1.4), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "modulate:a", 0.0, 0.24).set_delay(0.12)
		else:
			var tw2 := create_tween()
			tw2.set_parallel(true)
			tw2.tween_property(c, "scale", Vector2(0.5, 0.5), 0.25).set_ease(Tween.EASE_IN)
			tw2.tween_property(c, "modulate:a", 0.0, 0.25)
	await get_tree().create_timer(0.42).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()
	_refresh()


func _refresh() -> void:
	_cash_label.text = UI.money(session.cash)
	var can_slot := session.cash >= Config.shop_price(Config.SLOT_PRICE, session.day) and session.slots < Config.MAX_SLOTS
	_buy_slot_btn.disabled = not can_slot
	_buy_slot_btn.modulate = Color.WHITE if can_slot else Color(1, 1, 1, 0.5)
	var can_draw := not _drew and session.cash >= Config.shop_price(Config.BUFF_PACK_PRICE, session.day) and not Buffs.is_full()
	_draw_btn.disabled = not can_draw
	_draw_btn.modulate = Color.WHITE if can_draw else Color(1, 1, 1, 0.5)

	for c in _owned_row.get_children():
		c.queue_free()
	for id in Buffs.owned():
		_owned_row.add_child(_owned_chip(id))


func _owned_chip(id: String) -> Control:
	var def := BuffDefs.get_def(id)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.chip(Palette.MAIN.lightened(0.82), Palette.MAIN))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 3)
	pad.add_theme_constant_override("margin_bottom", 3)
	chip.add_child(pad)
	pad.add_child(UI.label("%s %s" % [def.get("icon", "?"), BuffDefs.display_label(id)], 13, Palette.COCOA_800))
	return chip


func _dot(color: Color) -> Control:
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	var wrap := CenterContainer.new()
	wrap.add_child(dot)
	return wrap
