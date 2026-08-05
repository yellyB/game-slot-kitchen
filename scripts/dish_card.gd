class_name DishCard
extends Card
## 완성품 카드 — 도구석 위에 올라감. 이동 소스(payload kind "dish").
## 매칭되는 주문 카드에 올리면 서빙. 슬롯/휴지통엔 못 감(주문 카드만 받음).

var recipe_id: String
var tool: ToolStation  # 이 완성품을 만든 도구석 (슬롯으로 옮기면 그 도구 회복)
var born := 0.0        # 완성된 게임시각(초) — 판매 ctx의 dish_age(신선도 46 등)용

func setup(id: String) -> void:
	recipe_id = id

func is_trashable() -> bool:
	return false

func _preview_text() -> String:
	return str(Recipes.get_def(recipe_id).get("icon", "?"))

## 서빙용 payload — OrderCard가 recipe_id로 매칭.
func get_move_payload() -> Dictionary:
	return {"kind": "dish", "recipe_id": recipe_id, "card": self}

func set_selected(sel: bool) -> void:
	_style.border_color = Palette.MAIN if sel else Palette.SUCCESS
	_style.set_border_width_all(2)

func _build_content() -> void:
	_style.bg_color = Palette.WHITE
	_style.border_color = Palette.SUCCESS
	_style.set_border_width_all(2)

	var icon := Label.new()
	icon.text = str(Recipes.get_def(recipe_id).get("icon", "?"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_theme_font_size_override("font_size", 40)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(icon)
