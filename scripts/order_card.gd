class_name OrderCard
extends Card

var recipe_id: String

func setup(id: String) -> void:
	recipe_id = id

func is_trashable() -> bool:
	return false

func _preview_text() -> String:
	return str(Recipes.get_def(recipe_id).get("icon", "?"))

func _build_content() -> void:
	_style.bg_color = Color("FFF7E6")
	_style.border_color = Palette.ACCENT

	var def := Recipes.get_def(recipe_id)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	add_child(v)

	var icon := Label.new()
	icon.text = str(def.get("icon", "?"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_font_size_override("font_size", 24)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = str(def.get("name", recipe_id))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lbl)

	var reqs := HBoxContainer.new()
	reqs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reqs.alignment = BoxContainer.ALIGNMENT_CENTER
	reqs.add_theme_constant_override("separation", 1)
	v.add_child(reqs)
	for iid in def.get("ingredients", []):
		var mi := Label.new()
		mi.text = str(Ingredients.get_def(iid).get("icon", "?"))
		mi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mi.add_theme_font_size_override("font_size", 14)
		reqs.add_child(mi)
