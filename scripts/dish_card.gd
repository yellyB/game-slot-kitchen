class_name DishCard
extends PanelContainer
## 완성품 카드 — 도구석 위에 올라감. 단계 4에선 표시 전용.
## (서빙은 단계 5 — 그때 이동 소스로 확장)

var recipe_id: String

func setup(id: String) -> void:
	recipe_id = id

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.WHITE
	s.set_corner_radius_all(12)
	s.set_border_width_all(2)
	s.border_color = Palette.SUCCESS
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("panel", s)

	var icon := Label.new()
	icon.text = str(Recipes.get_def(recipe_id).get("icon", "?"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_theme_font_size_override("font_size", 40)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(icon)
