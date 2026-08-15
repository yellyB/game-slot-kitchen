class_name Warehouse
extends Sheet
## 창고 하단 시트 — 해금된 재료 타일. 타일은 Move 소스(드래그/클릭으로 슬롯 배치).
## 보드가 꽉 차면 refresh(true)로 타일 비활성.

signal close_requested

var _tiles: Array[IngredientTile] = []

func _ready() -> void:
	visible = false
	# 하단 가로 바(기존 크기) — 단, 슬라이드는 오른쪽→왼쪽(서랍). 크기/위치는 예전 그대로.
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
	v.add_theme_constant_override("separation", 12)
	pad.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	header.add_child(UI.label("🏬", 20, Palette.COCOA_800, true))
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

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	for id in Ingredients.unlocked_ids():
		var tile := IngredientTile.new()
		tile.setup(id)
		_tiles.append(tile)
		grid.add_child(tile)


## 창고는 세로 시트가 아니라 우측 서랍 → 기본 슬라이드를 가로 슬라이드로 대체.
func slide_open() -> void:
	slide_open_side()

func slide_close() -> void:
	slide_close_side()


## 보드 꽉 차면 타일 비활성(회색).
func refresh(full: bool) -> void:
	for tile in _tiles:
		tile.disabled = full
		tile.modulate = Color(1, 1, 1, 0.45) if full else Color.WHITE
