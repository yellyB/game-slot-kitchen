class_name CodexScreen
extends Control

const COLS := 4
const ROWS := 5
const PER := COLS * ROWS
const CELL := Vector2(82, 132)

var _ids: Array = []
var _page := 0
var _pages := 1
var _grid: GridContainer
var _page_label: Label
var _prev: Button
var _next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 500
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Palette.COCOA_50
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 16)
	add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	v.add_child(header)
	header.add_child(UI.label(Loc.t("codex"), 22, Palette.COCOA_800, true))
	var hgap := Control.new()
	hgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hgap)
	var close := Button.new()
	close.custom_minimum_size = Vector2(36, 36)
	close.add_child(UI.ui_btn_icon("fail_x", 28))
	var empty := StyleBoxEmpty.new()
	close.add_theme_stylebox_override("normal", empty)
	close.add_theme_stylebox_override("hover", empty)
	close.add_theme_stylebox_override("pressed", empty)
	close.pressed.connect(queue_free)
	Audio.attach_click(close)
	header.add_child(close)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	v.add_child(_grid)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 16)
	v.add_child(nav)
	_prev = _nav_button("◀")
	_prev.pressed.connect(func(): _go(_page - 1))
	nav.add_child(_prev)
	_page_label = UI.label("1 / 1", 18, Palette.COCOA_800, true)
	_page_label.custom_minimum_size = Vector2(70, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_page_label)
	_next = _nav_button("▶")
	_next.pressed.connect(func(): _go(_page + 1))
	nav.add_child(_next)

	_ids = BuffDefs.ids()
	_ids.sort_custom(func(a, b): return _card_no(a) < _card_no(b))
	_pages = max(1, int(ceil(float(_ids.size()) / PER)))
	_go(0)


func _card_no(id: String) -> int:
	return int(BuffDefs.get_def(id).get("card", 9999))


func _nav_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(48, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.COCOA_800)
	b.add_theme_color_override("font_hover_color", Palette.COCOA_800)
	b.add_theme_color_override("font_disabled_color", Palette.COCOA_400)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_100))
	Audio.attach_click(b)
	return b


func _go(page: int) -> void:
	_page = clampi(page, 0, _pages - 1)
	_render()


func _render() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var start := _page * PER
	for i in range(start, min(start + PER, _ids.size())):
		_grid.add_child(_make_cell(_ids[i]))
	_page_label.text = "%d / %d" % [_page + 1, _pages]
	_prev.disabled = _page <= 0
	_next.disabled = _page >= _pages - 1


func _make_cell(id: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CELL
	card.clip_contents = true
	var found := Codex.is_discovered(id)
	var sb := UI.card(Palette.MAIN.lightened(0.82), Palette.MAIN, 2) if found else UI.card(Palette.COCOA_100, Palette.COCOA_200, 1)
	sb.shadow_size = 0
	card.add_theme_stylebox_override("panel", sb)

	if found:
		var pad := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			pad.add_theme_constant_override("margin_" + side, 5)
		card.add_child(pad)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(box)
		var icon := BuffDefs.icon_node(id, 30)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		var nm := UI.label(BuffDefs.display_name(id), 11, Palette.MAIN, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(nm)
		var desc := UI.label(BuffDefs.display_label(id), 9, Palette.COCOA_600)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(desc)
	else:
		var q := UI.label("?", 34, Palette.COCOA_400, true)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(q)
	return card
