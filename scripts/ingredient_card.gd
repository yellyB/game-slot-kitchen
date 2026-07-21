class_name IngredientCard
extends PanelContainer
## 슬롯에 놓인 재료 카드. 소스 역할 — 클릭/드래그로 다른 슬롯·휴지통으로 이동.
## 아이콘/이름은 placeholder — 나중에 손그림 TextureRect로 교체.

var ing_id: String
var _style: StyleBoxFlat

func setup(id: String) -> void:
	ing_id = id

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var def := Ingredients.get_def(ing_id)

	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.WHITE
	_style.set_corner_radius_all(12)
	_style.set_border_width_all(1)
	_style.border_color = Palette.GRAY300
	_style.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	_style.shadow_size = 3
	_style.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("panel", _style)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	add_child(v)

	var icon := Label.new()
	icon.text = str(def.get("icon", "?"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_font_size_override("font_size", 30)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = str(def.get("name", ing_id))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lbl)


# ── 공용 소스 인터페이스 ──────────────────────────────────
func get_move_payload() -> Dictionary:
	return {"kind": "move", "card": self}


func set_selected(sel: bool) -> void:
	_style.border_color = Palette.MAIN if sel else Palette.GRAY300
	_style.set_border_width_all(2 if sel else 1)


# ── 클릭 ──────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.on_click(self)
		accept_event()


# ── 드래그 시작 ───────────────────────────────────────────
func _get_drag_data(_at_position: Vector2) -> Variant:
	Move.begin_drag()
	set_drag_preview(_make_preview())
	return get_move_payload()


func _make_preview() -> Control:
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
	lbl.add_theme_font_size_override("font_size", 30)
	preview.add_child(lbl)
	return preview
