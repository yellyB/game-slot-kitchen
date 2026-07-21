class_name IngredientCard
extends PanelContainer
## 슬롯에 놓이는 재료 카드. 휴지통으로 드래그하면 제거된다.
## 아이콘/이름은 placeholder — 나중에 손그림 TextureRect로 교체.

var ing_id: String

func setup(id: String) -> void:
	ing_id = id

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var def := Ingredients.get_def(ing_id)

	var s := StyleBoxFlat.new()
	s.bg_color = Palette.WHITE
	s.set_corner_radius_all(12)
	s.set_border_width_all(1)
	s.border_color = Palette.GRAY300
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("panel", s)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	add_child(v)

	var icon := Label.new()
	icon.text = str(def.get("icon", "?"))
	icon.add_theme_font_size_override("font_size", 30)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = str(def.get("name", ing_id))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lbl)

## 드래그 시작 — 휴지통(TrashButton)이 받아 제거.
func _get_drag_data(_at_position: Vector2) -> Variant:
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
	lbl.add_theme_font_size_override("font_size", 30)
	preview.add_child(lbl)

	set_drag_preview(preview)
	return {"type": "ingredient", "card": self, "id": ing_id}
