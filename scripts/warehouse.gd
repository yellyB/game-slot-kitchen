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

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pad.add_child(v)

	var header := CenterContainer.new()
	v.add_child(header)
	var close := make_close_handle()
	close.pressed.connect(func(): close_requested.emit())
	Audio.attach_click(close)
	header.add_child(close)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	for id in Ingredients.unlocked_ids():
		var tile := IngredientTile.new()
		tile.setup(id)
		_tiles.append(tile)
		grid.add_child(tile)


func refresh(full: bool) -> void:
	var omit := Buffs.omitted_ingredients()
	for tile in _tiles:
		var off := full or omit.has(tile.ing_id)
		tile.disabled = off
		tile.modulate = Color(1, 1, 1, 0.45) if off else Color.WHITE


func place_by_index(idx: int) -> void:
	if idx < 0 or idx >= _tiles.size():
		return
	var tile := _tiles[idx]
	if tile.disabled:
		return
	Move.on_click(tile)
