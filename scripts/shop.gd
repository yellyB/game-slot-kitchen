class_name Shop
extends Control
## 인터세션 상점 — 보유 돈 + 슬롯 확장 상품 + [영업 시작].
## 딤 배경 + 입력 차단. 대강 구현(디자인 후 정리).

signal start_business

var session: Session  # main이 add_child 전에 주입
var _cash_label: Label
var _buy_btn: Button

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
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200))
	center.add_child(panel)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pad.add_child(v)

	# 헤더: 🏪 + 보유 돈
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	v.add_child(header)
	header.add_child(UI.label("🏪", 22, Palette.COCOA_800, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var dot := ColorRect.new()
	dot.color = Palette.ACCENT
	dot.custom_minimum_size = Vector2(14, 14)
	var dw := CenterContainer.new()
	dw.add_child(dot)
	header.add_child(dw)
	_cash_label = UI.label("0", 18, Palette.COCOA_800, true)
	header.add_child(_cash_label)

	# 상품: 슬롯 확장
	v.add_child(_slot_product())

	# [영업 시작]
	var start := Button.new()
	start.text = "영업 시작"
	start.custom_minimum_size = Vector2(0, 48)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.add_theme_font_size_override("font_size", 18)
	start.add_theme_color_override("font_color", Palette.WHITE)
	start.add_theme_color_override("font_hover_color", Palette.WHITE)
	start.add_theme_color_override("font_pressed_color", Palette.WHITE)
	start.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	start.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	start.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	start.pressed.connect(func():
		queue_free()
		start_business.emit())
	v.add_child(start)

	_refresh()


func _slot_product() -> Control:
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
	info.add_child(UI.label("슬롯 +1", 18, Palette.COCOA_800, true))
	info.add_child(UI.label("가격 %d" % Config.SLOT_PRICE, 14, Palette.COCOA_600))

	_buy_btn = Button.new()
	_buy_btn.text = "구매"
	_buy_btn.custom_minimum_size = Vector2(72, 40)
	_buy_btn.add_theme_font_size_override("font_size", 15)
	_buy_btn.add_theme_color_override("font_color", Palette.WHITE)
	_buy_btn.add_theme_color_override("font_hover_color", Palette.WHITE)
	_buy_btn.add_theme_stylebox_override("normal", UI.chip(Palette.SUB))
	_buy_btn.add_theme_stylebox_override("hover", UI.chip(Palette.SUB.lightened(0.08)))
	_buy_btn.add_theme_stylebox_override("pressed", UI.chip(Palette.SUB.darkened(0.1)))
	_buy_btn.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_200))
	_buy_btn.pressed.connect(_on_buy)
	row.add_child(_buy_btn)

	return card


func _on_buy() -> void:
	if session.buy_slot():
		_refresh()


func _refresh() -> void:
	_cash_label.text = str(session.cash)
	var can_buy := session.cash >= Config.SLOT_PRICE and session.slots < Config.MAX_SLOTS
	_buy_btn.disabled = not can_buy
	_buy_btn.modulate = Color.WHITE if can_buy else Color(1, 1, 1, 0.5)
