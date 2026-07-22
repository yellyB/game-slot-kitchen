class_name IngredientTile
extends Button

var ing_id: String
var _selected := false

func setup(id: String) -> void:
	ing_id = id

func _ready() -> void:
	custom_minimum_size = Vector2(72, 72)
	toggle_mode = false
	_apply_style()

	var icon := Label.new()
	icon.text = str(Ingredients.get_def(ing_id).get("icon", "?"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_theme_font_size_override("font_size", 34)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(icon)

	pressed.connect(func(): Move.on_click(self))


func get_move_payload() -> Dictionary:
	return {"kind": "new", "id": ing_id}

func is_quick() -> bool:
	return true


func set_selected(sel: bool) -> void:
	_selected = sel
	_apply_style()


func _get_drag_data(_at_position: Vector2) -> Variant:
	Move.begin_drag()
	var preview := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Palette.WHITE
	ps.set_corner_radius_all(12)
	ps.set_border_width_all(2)
	ps.border_color = Palette.MAIN
	preview.add_theme_stylebox_override("panel", ps)
	preview.modulate = Color(1, 1, 1, 0.9)
	var lbl := Label.new()
	lbl.text = str(Ingredients.get_def(ing_id).get("icon", "?"))
	lbl.add_theme_font_size_override("font_size", 26)
	preview.add_child(lbl)
	set_drag_preview(preview)
	return get_move_payload()


func _apply_style() -> void:
	var border := Palette.MAIN if _selected else Palette.COCOA_200
	var border_w := 2 if _selected else 1
	add_theme_stylebox_override("normal", UI.card(Palette.COCOA_100, border, border_w))
	add_theme_stylebox_override("hover", UI.card(Palette.ACCENT.lightened(0.35), border, border_w))
	add_theme_stylebox_override("pressed", UI.card(Palette.ACCENT.lightened(0.2), Palette.ACCENT, 2))
	add_theme_stylebox_override("disabled", UI.card(Palette.COCOA_100, Palette.COCOA_200, 1))
