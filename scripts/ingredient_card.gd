class_name IngredientCard
extends Card

var ing_id: String

func setup(id: String) -> void:
	ing_id = id

func is_trashable() -> bool:
	return true

func _preview_text() -> String:
	return str(Ingredients.get_def(ing_id).get("icon", "?"))

func _preview_icon() -> Control:
	return Ingredients.icon_node(ing_id, 44)

func _build_content() -> void:
	add_child(Ingredients.icon_node(ing_id, 48))
