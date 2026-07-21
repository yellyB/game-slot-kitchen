class_name TrashButton
extends Button

signal ingredient_dropped(card: IngredientCard)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "ingredient"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	ingredient_dropped.emit(data.get("card"))
