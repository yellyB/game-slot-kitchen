class_name Customer
extends PanelContainer

signal confirm_pressed(customer: Customer)
signal expired(customer: Customer)
signal urged(customer: Customer)

var recipe_id: String
var animal := ""

var _max := Config.PATIENCE_ORDER
var _time_left := 0.0
var _done := false
var _warned := false
var _fill := Palette.SUCCESS
var _gauge: ProgressBar
var _slide_tw: Tween
var _pulse_tw: Tween

func setup(id: String) -> void:
	recipe_id = id

func _ready() -> void:
	_max = Stats.order_patience()
	_time_left = _max
	custom_minimum_size = Vector2(66, 66)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200, 1, 12))

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 5)
	add_child(pad)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	pad.add_child(v)

	if animal == "":
		animal = Customers.random_id()
	v.add_child(Customers.icon_node(animal, 44))

	_gauge = ProgressBar.new()
	_gauge.min_value = 0
	_gauge.max_value = _max
	_gauge.value = _max
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 8)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	_gauge.add_theme_stylebox_override("fill", UI.chip(_fill))
	v.add_child(_gauge)


func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		confirm_pressed.emit(self)
		accept_event()


func dismiss() -> void:
	_done = true
	set_process(false)
	if _slide_tw != null and _slide_tw.is_valid():
		_slide_tw.kill()
	_stop_pulse()
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_paused(p: bool) -> void:
	if not _done:
		set_process(not p)


func stop_slide() -> void:
	if _slide_tw != null and _slide_tw.is_valid():
		_slide_tw.kill()
	modulate.a = 1.0


func force_expire() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	_stop_pulse()
	expired.emit(self)


func slide_in() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var target := position
	position = target + Vector2(44, 0)
	modulate.a = 0.0
	var tw := create_tween()
	_slide_tw = tw
	tw.set_parallel(true)
	tw.tween_property(self, "position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	_start_idle_pulse()


func _start_idle_pulse() -> void:
	if _done or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	_pulse_tw = create_tween().set_loops()
	_pulse_tw.tween_property(self, "scale", Vector2(1.05, 1.05), 0.55).set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_property(self, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = null
	scale = Vector2.ONE


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	var col := Palette.DANGER if _time_left <= _max * Config.PATIENCE_LOW_FRAC else Palette.SUCCESS
	if col != _fill:
		_fill = col
		_gauge.add_theme_stylebox_override("fill", UI.chip(col))
		if col == Palette.DANGER and not _warned:
			_warned = true
			_urge()
	if _time_left <= 0.0:
		_done = true
		set_process(false)
		_stop_pulse()
		expired.emit(self)


func _urge() -> void:
	urged.emit(self)
	var bx := position.x
	var tw := create_tween()
	tw.tween_property(self, "position:x", bx + 4.0, 0.05)
	tw.tween_property(self, "position:x", bx - 4.0, 0.05)
	tw.tween_property(self, "position:x", bx + 3.0, 0.05)
	tw.tween_property(self, "position:x", bx, 0.05)
