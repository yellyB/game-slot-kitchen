class_name IngredientCard
extends Card
## 슬롯에 놓인 재료 카드. 이동·드래그·클릭은 Card 베이스에서 제공.
## 재료만 휴지통에 버릴 수 있다.

var ing_id: String

func setup(id: String) -> void:
	ing_id = id

func is_trashable() -> bool:
	return true

func _preview_text() -> String:
	return str(Ingredients.get_def(ing_id).get("icon", "?"))

func _build_content() -> void:
	# 인포그래픽 우선 — 아이콘만(이름 텍스트 없음). [[infographic-not-text]]
	var icon := Label.new()
	icon.text = str(Ingredients.get_def(ing_id).get("icon", "?"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_font_size_override("font_size", 40)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(icon)
