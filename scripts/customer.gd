class_name Customer
extends PanelContainer

signal note_tapped(customer: Customer)
signal expired(customer: Customer)

enum Phase { WAITING_ORDER, WAITING_DISH }

const PATIENCE_ORDER := 15.0
const PATIENCE_DISH := 20.0
const LOW_FRAC := 0.3

var recipe_id: String
var order_taken := false

var _phase := Phase.WAITING_ORDER
var _time_left := PATIENCE_ORDER
var _max := PATIENCE_ORDER
var _done := false
var _fill_color := Palette.SUCCESS

var _gauge: ProgressBar
var _note: Button

func setup(id: String) -> void:
	recipe_id = id

func _ready() -> void:
	custom_minimum_size = Vector2(64, 76)
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.WHITE
	s.set_corner_radius_all(12)
	s.set_border_width_all(1)
	s.border_color = Palette.GRAY300
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("panel", s)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 5)
	add_child(pad)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	pad.add_child(v)

	var face := Label.new()
	face.text = "🙋"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_font_size_override("font_size", 22)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(face)

	_gauge = ProgressBar.new()
	_gauge.min_value = 0
	_gauge.max_value = _max
	_gauge.value = _time_left
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 8)
	_gauge.add_theme_stylebox_override("background", _pill(Palette.GRAY100, Palette.GRAY300))
	_gauge.add_theme_stylebox_override("fill", _pill(_fill_color))
	v.add_child(_gauge)

	_note = Button.new()
	_note.text = "📝"
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", Palette.TEXT)
	_note.add_theme_stylebox_override("normal", _pill(Palette.ACCENT))
	_note.add_theme_stylebox_override("hover", _pill(Palette.ACCENT.lightened(0.12)))
	_note.add_theme_stylebox_override("pressed", _pill(Palette.ACCENT.darkened(0.1)))
	_note.add_theme_stylebox_override("disabled", _pill(Palette.GRAY100, Palette.GRAY300))
	_note.pressed.connect(func(): note_tapped.emit(self))
	v.add_child(_note)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	_refresh_fill()
	if _time_left <= 0.0:
		_done = true
		set_process(false)
		expired.emit(self)


func mark_order_taken() -> void:
	order_taken = true
	_note.disabled = true
	_note.text = "✅"

	_phase = Phase.WAITING_DISH
	_max = PATIENCE_DISH
	_time_left = PATIENCE_DISH
	_gauge.max_value = _max
	_gauge.value = _time_left
	_refresh_fill()


func _refresh_fill() -> void:
	var base := Palette.SUCCESS if _phase == Phase.WAITING_ORDER else Palette.SUB
	var col := Palette.DANGER if _time_left <= _max * LOW_FRAC else base
	if col != _fill_color:
		_fill_color = col
		_gauge.add_theme_stylebox_override("fill", _pill(col))


func _pill(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s
