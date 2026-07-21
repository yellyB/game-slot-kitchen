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

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	add_child(v)

	var def := Ingredients.get_def(ing_id)
	var icon := Label.new()
	icon.text = str(def.get("icon", "?"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_font_size_override("font_size", 26)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = str(def.get("name", ing_id))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Palette.GRAY700)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lbl)

	pressed.connect(func(): Move.on_click(self))


# ── 공용 소스 인터페이스 ──────────────────────────────────
func get_move_payload() -> Dictionary:
	return {"kind": "new", "id": ing_id}


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
	var lbl := Label.new()
	lbl.text = str(Ingredients.get_def(ing_id).get("icon", "?"))
	lbl.add_theme_font_size_override("font_size", 26)
	preview.add_child(lbl)
	set_drag_preview(preview)
	return get_move_payload()


func _apply_style() -> void:
	var border := Palette.MAIN if _selected else Palette.GRAY300
	var border_w := 2 if _selected else 1
	add_theme_stylebox_override("normal", _tile_box(Palette.GRAY100, border, border_w))
	add_theme_stylebox_override("hover", _tile_box(Palette.ACCENT.lightened(0.35), border, border_w))
	add_theme_stylebox_override("pressed", _tile_box(Palette.ACCENT.lightened(0.2), Palette.ACCENT, 2))
	add_theme_stylebox_override("disabled", _tile_box(Palette.GRAY100, Palette.GRAY300, 1))


func _tile_box(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(14)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s
