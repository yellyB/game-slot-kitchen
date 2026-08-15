class_name Warehouse
extends Sheet
## 창고 하단 시트 — 해금된 재료 타일. 아래서 위로 슬라이드(바텀시트).
## 상단 우측(50~90%)에 살짝 튀어나온 손잡이 탭(⌄) → 탭하면 닫힘(dim 탭도 닫힘).
## 보드가 꽉 차면 refresh(true)로 타일 비활성.

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

	# 헤더/닫기(✕)·창고 이모지 없음 — 닫기는 상단 튀어나온 탭이 담당.
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

	# 상단 손잡이 탭 — 우측 50~90%가 위로 살짝 튀어나옴 + 아래쪽 꺽쇠(⌄). 탭 = 닫기.
	var tab := Button.new()
	tab.anchor_left = 0.5
	tab.anchor_right = 0.9
	tab.anchor_top = 0.0
	tab.anchor_bottom = 0.0
	tab.offset_top = -26     # 시트 위로 26px 튀어나옴
	tab.offset_bottom = 10   # 시트 안으로 10px 겹침(연결감)
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


## 위쪽만 둥근 손잡이 스타일(탭·핸들 공용 느낌).
func _tab_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 16
	s.corner_radius_top_right = 16
	return s


## 보드 꽉 차면 타일 비활성(회색).
func refresh(full: bool) -> void:
	for tile in _tiles:
		tile.disabled = full
		tile.modulate = Color(1, 1, 1, 0.45) if full else Color.WHITE
