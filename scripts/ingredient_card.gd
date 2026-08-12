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

## 드래그 프리뷰도 손그림 아이콘으로(있으면).
func _preview_icon() -> Control:
	return Ingredients.icon_node(ing_id, 44)

func _build_content() -> void:
	# 아이콘 + 아래 재료 이름.
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	var icon := Ingredients.icon_node(ing_id, 40)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(icon)

	var name_lbl := UI.label(str(Ingredients.get_def(ing_id).get("name", "")), 11, Palette.COCOA_600)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)
