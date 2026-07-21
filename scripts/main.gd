extends Control

const GRID_COLS := 3
const GRID_SLOTS := 9
const TOOL_SLOTS := [2, 8]

var _slot_holders: Array[MarginContainer] = []
var _slot_is_tool: Array[bool] = []

var _warehouse_btn: Button
var _trash_btn: TrashButton
var _warehouse_sheet: Panel
var _tiles: Array[Button] = []


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG_CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(_build_top_bar())
	col.add_child(_build_customer_queue())
	col.add_child(_build_slot_grid())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	col.add_child(_build_bottom_buttons())

	_warehouse_sheet = _build_warehouse_sheet()
	add_child(_warehouse_sheet)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_box(Palette.WHITE))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pad.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	row.add_child(_label("1일차", 20, true))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	row.add_child(_money(Palette.ACCENT, "1,200"))
	row.add_child(_money(Palette.DANGER, "300"))

	var hours := HBoxContainer.new()
	hours.add_theme_constant_override("separation", 8)
	box.add_child(hours)

	hours.add_child(_label("낮", 14, false, Palette.GRAY500))

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 40
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _pill_box(Palette.GRAY100, Palette.GRAY300))
	bar.add_theme_stylebox_override("fill", _pill_box(Palette.ACCENT))
	hours.add_child(bar)

	hours.add_child(_label("밤", 14, false, Palette.GRAY500))

	return panel


func _build_customer_queue() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_box(Palette.GRAY100, Palette.GRAY300))
	panel.custom_minimum_size = Vector2(0, 96)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pad.add_child(row)

	for i in range(3):
		row.add_child(_customer_placeholder())

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	return panel


func _customer_placeholder() -> Control:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", _card_box(Palette.WHITE, Palette.GRAY300))
	c.custom_minimum_size = Vector2(60, 76)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)

	var face := _label("🙋", 22, false)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(face)

	var note := _label("📝", 16, false, Palette.GRAY500)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)

	return c


func _build_slot_grid() -> Control:
	var center := CenterContainer.new()

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)

	for i in range(GRID_SLOTS):
		grid.add_child(_slot(i in TOOL_SLOTS))

	return center


func _slot(is_tool: bool) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(104, 104)
	if is_tool:
		slot.add_theme_stylebox_override("panel", _card_box(Color("FBE9DA"), Palette.SUB, 2))
	else:
		slot.add_theme_stylebox_override("panel", _card_box(Palette.WHITE, Palette.GRAY300))

	var holder := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		holder.add_theme_constant_override("margin_" + side, 6)
	slot.add_child(holder)

	if is_tool:
		var lbl := _label("🔥", 28, false, Palette.SUB)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(lbl)

	_slot_holders.append(holder)
	_slot_is_tool.append(is_tool)
	return slot


func _build_bottom_buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	_warehouse_btn = _make_bottom_button(Palette.MAIN)
	_warehouse_btn.text = "🏬 창고"
	_warehouse_btn.pressed.connect(_toggle_warehouse)
	row.add_child(_warehouse_btn)

	_trash_btn = TrashButton.new()
	_trash_btn.text = "🗑️ 휴지통"
	_style_bottom_button(_trash_btn, Palette.SUB)
	_trash_btn.ingredient_dropped.connect(_on_trash_drop)
	row.add_child(_trash_btn)

	return row


func _build_warehouse_sheet() -> Panel:
	var sheet := Panel.new()
	sheet.visible = false
	sheet.anchor_left = 0.0
	sheet.anchor_right = 1.0
	sheet.anchor_top = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = 8
	sheet.offset_right = -8
	sheet.offset_top = -240
	sheet.offset_bottom = -8

	var box := StyleBoxFlat.new()
	box.bg_color = Palette.WHITE
	box.set_corner_radius_all(18)
	box.set_border_width_all(1)
	box.border_color = Palette.GRAY300
	box.shadow_color = Color(0.164, 0.129, 0.106, 0.18)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, -2)
	sheet.add_theme_stylebox_override("panel", box)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	sheet.add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	header.add_child(_label("🏬 창고", 18, true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var close := Button.new()
	close.text = "닫기"
	close.add_theme_font_size_override("font_size", 14)
	close.add_theme_color_override("font_color", Palette.GRAY700)
	close.add_theme_stylebox_override("normal", _pill_box(Palette.GRAY100, Palette.GRAY300))
	close.add_theme_stylebox_override("hover", _pill_box(Palette.GRAY300))
	close.add_theme_stylebox_override("pressed", _pill_box(Palette.GRAY300))
	close.pressed.connect(_toggle_warehouse)
	header.add_child(close)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	for id in Ingredients.unlocked_ids():
		var tile := _ingredient_tile(id)
		_tiles.append(tile)
		grid.add_child(tile)

	return sheet


func _ingredient_tile(id: String) -> Button:
	var def := Ingredients.get_def(id)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(72, 72)
	tile.add_theme_stylebox_override("normal", _card_box(Palette.GRAY100, Palette.GRAY300))
	tile.add_theme_stylebox_override("hover", _card_box(Palette.ACCENT.lightened(0.35), Palette.ACCENT))
	tile.add_theme_stylebox_override("pressed", _card_box(Palette.ACCENT.lightened(0.2), Palette.ACCENT))
	tile.add_theme_stylebox_override("disabled", _card_box(Palette.GRAY100, Palette.GRAY300))

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	tile.add_child(v)

	var icon := _label(str(def.get("icon", "?")), 26, false)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)

	var name_lbl := _label(str(def.get("name", id)), 12, false, Palette.GRAY700)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)

	tile.pressed.connect(func(): _place_ingredient(id))
	return tile


func _toggle_warehouse() -> void:
	_warehouse_sheet.visible = not _warehouse_sheet.visible
	if _warehouse_sheet.visible:
		_refresh_tiles()


func _place_ingredient(id: String) -> void:
	var idx := _first_empty_slot()
	if idx == -1:
		return
	var card := IngredientCard.new()
	card.setup(id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_holders[idx].add_child(card)
	_refresh_tiles()


func _on_trash_drop(card: IngredientCard) -> void:
	if card == null or not is_instance_valid(card):
		return
	var holder := card.get_parent()
	if holder:
		holder.remove_child(card)
	card.queue_free()
	_refresh_tiles()


func _first_empty_slot() -> int:
	for i in _slot_holders.size():
		if not _slot_is_tool[i] and _slot_holders[i].get_child_count() == 0:
			return i
	return -1


func _refresh_tiles() -> void:
	var full := _first_empty_slot() == -1
	for tile in _tiles:
		tile.disabled = full
		tile.modulate = Color(1, 1, 1, 0.45) if full else Color.WHITE


func _label(text: String, size: int, bold: bool, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 0)
	return l


func _money(dot_color: Color, amount: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)

	var dot := ColorRect.new()
	dot.color = dot_color
	dot.custom_minimum_size = Vector2(14, 14)
	var wrap := CenterContainer.new()
	wrap.add_child(dot)
	h.add_child(wrap)

	h.add_child(_label(amount, 18, true))
	return h


func _make_bottom_button(color: Color) -> Button:
	var b := Button.new()
	_style_bottom_button(b, color)
	return b


func _style_bottom_button(b: Button, color: Color) -> void:
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.WHITE)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_stylebox_override("normal", _pill_box(color))
	b.add_theme_stylebox_override("hover", _pill_box(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _pill_box(color.darkened(0.1)))


func _card_box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(14)
	s.set_content_margin_all(0)
	if border.a > 0.0:
		s.set_border_width_all(border_w)
		s.border_color = border
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s


func _pill_box(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s
