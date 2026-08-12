class_name DishCard
extends Card

var recipe_id: String
var tool: ToolStation
var born := 0.0

func setup(id: String) -> void:
	recipe_id = id

func is_trashable() -> bool:
	return true

func dispose() -> void:
	if tool != null and is_instance_valid(tool):
		tool.reset()
	else:
		super()

func _preview_text() -> String:
	return str(Recipes.get_def(recipe_id).get("icon", "?"))

func _preview_icon() -> Control:
	return Recipes.icon_node(recipe_id, 44)

func get_move_payload() -> Dictionary:
	return {"kind": "dish", "recipe_id": recipe_id, "card": self}

func set_selected(sel: bool) -> void:
	_style.border_color = Palette.MAIN if sel else Palette.SUCCESS
	_style.set_border_width_all(2)

func _build_content() -> void:
	_style.bg_color = Palette.WHITE
	_style.border_color = Palette.SUCCESS
	_style.set_border_width_all(2)

	add_child(Recipes.icon_node(recipe_id, 48))
