class_name BuffCard
extends Card

var buff_id: String

func setup(id: String) -> void:
	buff_id = id

func is_trashable() -> bool:
	return false

func set_selected(sel: bool) -> void:
	_style.set_border_width_all(3 if sel else 2)

func _build_content() -> void:
	_style.bg_color = Palette.MAIN.lightened(0.82)
	_style.border_color = Palette.MAIN
	_style.set_border_width_all(2)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	add_child(v)

	v.add_child(BuffDefs.icon_node(buff_id, 36))

	var lbl := UI.label(BuffDefs.display_label(buff_id), 12, Palette.MAIN)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2.ZERO
	v.add_child(lbl)
