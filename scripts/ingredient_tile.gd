class_name IngredientTile
extends Button
## 창고 재료 타일. 소스 역할 — 클릭/드래그로 슬롯에 신규 배치("new").
## 보드가 꽉 차면 main에서 disabled 처리.

var ing_id: String
var _selected := false

func setup(id: String) -> void:
	ing_id = id

func _ready() -> void:
	custom_minimum_size = Vector2(72, 72)
	toggle_mode = false
	_apply_style()

	# 인포그래픽 우선 — 아이콘만(이름 텍스트 없음). 손그림 있으면 텍스처, 없으면 이모지. [[infographic-not-text]]
	var icon := Ingredients.icon_node(ing_id, 44)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(icon)

	pressed.connect(func(): Move.on_click(self))


# ── 공용 소스 인터페이스 ──────────────────────────────────
func get_move_payload() -> Dictionary:
	return {"kind": "new", "id": ing_id}

## 클릭하면 (선택이 아니라) 첫 빈 슬롯에 즉시 배치.
func is_quick() -> bool:
	return true


func set_selected(sel: bool) -> void:
	_selected = sel
	_apply_style()


# ── 드래그 시작 ───────────────────────────────────────────
func _get_drag_data(_at_position: Vector2) -> Variant:
	Move.begin_drag()
	var preview := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Palette.WHITE
	ps.set_corner_radius_all(12)
	ps.set_border_width_all(2)
	ps.border_color = Palette.MAIN
	preview.add_theme_stylebox_override("panel", ps)
	preview.modulate = Color(1, 1, 1, 0.9)
	preview.add_child(Ingredients.icon_node(ing_id, 40))
	set_drag_preview(preview)
	return get_move_payload()


func _apply_style() -> void:
	var border := Palette.MAIN if _selected else Palette.COCOA_200
	var border_w := 2 if _selected else 1
	add_theme_stylebox_override("normal", UI.card(Palette.COCOA_100, border, border_w))
	add_theme_stylebox_override("hover", UI.card(Palette.ACCENT.lightened(0.35), border, border_w))
	add_theme_stylebox_override("pressed", UI.card(Palette.ACCENT.lightened(0.2), Palette.ACCENT, 2))
	add_theme_stylebox_override("disabled", UI.card(Palette.COCOA_100, Palette.COCOA_200, 1))
