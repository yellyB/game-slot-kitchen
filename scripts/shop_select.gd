class_name ShopSelect
extends Control

signal shop_selected(id: String)
signal back_pressed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 410
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
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 16
	back.offset_right = 64
	back.offset_top = 44
	back.offset_bottom = 92
	back.add_child(UI.ui_btn_icon("house", 24))
	back.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	back.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	back.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	back.pressed.connect(func(): back_pressed.emit())
	Audio.attach_click(back)
	add_child(back)


func _card(id: String) -> Button:
	var unlocked := Shops.is_unlocked(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 84)
	b.disabled = not unlocked
	b.add_theme_stylebox_override("disabled", UI.card(Palette.COCOA_100, Palette.COCOA_200, 1))

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cc)

	if not unlocked:
		var lock := UI.ui_icon("slot_lock", 34)
		lock.modulate.a = 0.4
		cc.add_child(lock)
		var soon := UI.label("Coming Soon", 32, Palette.DANGER, true)
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cc.add_child(soon)
		return b

	b.add_theme_stylebox_override("normal", UI.card(Palette.WHITE, Palette.MAIN, 2))
	b.add_theme_stylebox_override("hover", UI.card(Palette.MAIN.lightened(0.85), Palette.MAIN, 2))
	b.add_theme_stylebox_override("pressed", UI.card(Palette.MAIN.lightened(0.78), Palette.MAIN, 2))
	var art := str(Shops.get_def(id).get("art", ""))
	if art != "":
		cc.add_child(Recipes.icon_node(art, 60))
	else:
		cc.add_child(UI.label(Shops.icon_of(id), 48))
	b.pressed.connect(func(): shop_selected.emit(id))
	Audio.attach_click(b)
	return b
