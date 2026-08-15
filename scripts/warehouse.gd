class_name Warehouse
extends Sheet

signal close_requested

var _tiles: Array[IngredientTile] = []

func _ready() -> void:
	visible = false
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 8
	offset_right = -8
	offset_top = -240
	offset_bottom = -8
	add_theme_stylebox_override("panel", UI.sheet())

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	add_child(pad)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	pad.add_child(grid)

	for id in Ingredients.unlocked_ids():
		var tile := IngredientTile.new()
		tile.setup(id)
		_tiles.append(tile)
		grid.add_child(tile)

	var tab := Button.new()
	tab.anchor_left = 0.5
	tab.anchor_right = 0.9
	tab.anchor_top = 0.0
	tab.anchor_bottom = 0.0
	tab.offset_top = -26
	tab.offset_bottom = 10
	tab.text = "⌄"
	tab.add_theme_font_size_override("font_size", 22)
	tab.add_theme_color_override("font_color", Palette.WHITE)
	tab.add_theme_color_override("font_hover_color", Palette.WHITE)
	tab.add_theme_color_override("font_pressed_color", Palette.WHITE)
	tab.add_theme_stylebox_override("normal", _tab_style(Palette.MAIN))
	tab.add_theme_stylebox_override("hover", _tab_style(Palette.MAIN.lightened(0.08)))
	tab.add_theme_stylebox_override("pressed", _tab_style(Palette.MAIN.darkened(0.1)))
	tab.pressed.connect(func(): close_requested.emit())
	Audio.attach_click(tab)
	add_child(tab)


func _tab_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 16
	s.corner_radius_top_right = 16
	return s


func refresh(full: bool) -> void:
	for tile in _tiles:
		tile.disabled = full
		tile.modulate = Color(1, 1, 1, 0.45) if full else Color.WHITE
