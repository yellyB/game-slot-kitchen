class_name OrderCard
extends Card

signal expired(card: OrderCard)

const PATIENCE_DISH := 60.0
const LOW_FRAC := 0.3

var recipe_id: String

var _time_left := PATIENCE_DISH
var _done := false
var _fill := Palette.SUB
var _gauge: ProgressBar

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

	var face := Label.new()
	face.text = "🙋"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_font_size_override("font_size", 16)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(face)

	var dish := Label.new()
	dish.text = str(def.get("icon", "?"))
	dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dish.add_theme_font_size_override("font_size", 22)
	dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dish)

	var reqs := HBoxContainer.new()
	reqs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reqs.alignment = BoxContainer.ALIGNMENT_CENTER
	reqs.add_theme_constant_override("separation", 1)
	v.add_child(reqs)
	for iid in def.get("ingredients", []):
		var mi := Label.new()
		mi.text = str(Ingredients.get_def(iid).get("icon", "?"))
		mi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mi.add_theme_font_size_override("font_size", 13)
		reqs.add_child(mi)

	_gauge = ProgressBar.new()
	_gauge.min_value = 0
	_gauge.max_value = PATIENCE_DISH
	_gauge.value = PATIENCE_DISH
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 6)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_theme_stylebox_override("background", _pill(Palette.GRAY100, Palette.GRAY300))
	_gauge.add_theme_stylebox_override("fill", _pill(_fill))
	v.add_child(_gauge)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	var col := Palette.DANGER if _time_left <= PATIENCE_DISH * LOW_FRAC else Palette.SUB
	if col != _fill:
		_fill = col
		_gauge.add_theme_stylebox_override("fill", _pill(col))
	if _time_left <= 0.0:
		_done = true
		set_process(false)
		expired.emit(self)


func _pill(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s
