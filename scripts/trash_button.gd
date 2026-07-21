class_name TrashButton
extends Button
## 휴지통 — 재료 카드를 드롭하면 제거 신호를 낸다.

signal ingredient_dropped(card: IngredientCard)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "ingredient"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	ingredient_dropped.emit(data.get("card"))
