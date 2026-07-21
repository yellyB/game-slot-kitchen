class_name IngredientCard
extends Card

var ing_id: String

func setup(id: String) -> void:
	ing_id = id

func is_trashable() -> bool:
	return true

func _preview_text() -> String:
	return str(Ingredients.get_def(ing_id).get("icon", "?"))

func _build_content() -> void:
	var icon := Label.new()
	icon.text = str(Ingredients.get_def(ing_id).get("icon", "?"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_font_size_override("font_size", 40)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(icon)
