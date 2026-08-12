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
	# 인포그래픽 우선 — 아이콘만(이름 텍스트 없음). 손그림 있으면 텍스처, 없으면 이모지. [[infographic-not-text]]
	add_child(Ingredients.icon_node(ing_id, 48))
