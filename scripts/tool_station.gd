class_name ToolStation
extends PanelContainer
## 도구석(🔥). 상태머신 idle → cooking → done.
##  - idle: 탭하면 레시피 팝업 요청(tapped). 재료/카드는 못 들어옴.
##  - cooking: 완성 타이머 진행 + 발광. (조리 B안 = 재료 다 모여야 시작 — 소비는 main)
##  - done: 완성품 DishCard가 위에.

signal tapped(tool: ToolStation)

enum State { IDLE, COOKING, DONE }

var state := State.IDLE
var recipe_id := ""

var _cook_left := 0.0
var _cook_total := 0.0
var _cook_bar: ProgressBar
var _holder: MarginContainer
var _style: StyleBoxFlat
var _glow: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(104, 104)
	_style = _box()
	add_theme_stylebox_override("panel", _style)

	_holder = MarginContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		_holder.add_theme_constant_override("margin_" + side, 6)
	add_child(_holder)

	set_process(false)
	_show_idle()


func is_idle() -> bool:
	return state == State.IDLE


## 완성(DONE) 상태의 완성품 카드(없으면 null).
func get_dish() -> DishCard:
	for ch in _holder.get_children():
		if ch is DishCard:
			return ch
	return null


## 서빙 후 도구석을 idle로 되돌림(완성품 제거).
func reset() -> void:
	_stop_glow()
	_show_idle()


# ── 상태 전환 ─────────────────────────────────────────────
func _show_idle() -> void:
	state = State.IDLE
	recipe_id = ""
	_clear_holder()
	_style.border_color = Palette.SUB
	var lbl := Label.new()
	lbl.text = "🔥"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_holder.add_child(lbl)


## 조리 시작 (재료 소비는 호출 측에서 이미 처리).
func start_cooking(id: String) -> void:
	if state != State.IDLE:
		return
	recipe_id = id
	_cook_total = float(Recipes.get_def(id).get("cook_time", 5.0))
	_cook_left = _cook_total
	state = State.COOKING
	_clear_holder()
	_style.border_color = Palette.ACCENT

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	_holder.add_child(v)

	var dish := Label.new()
	dish.text = str(Recipes.get_def(id).get("icon", "?"))
	dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dish.modulate = Color(1, 1, 1, 0.6)  # 조리 중엔 흐리게
	dish.add_theme_font_size_override("font_size", 30)
	dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dish)

	_cook_bar = ProgressBar.new()
	_cook_bar.min_value = 0
	_cook_bar.max_value = _cook_total
	_cook_bar.value = 0
	_cook_bar.show_percentage = false
	_cook_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cook_bar.custom_minimum_size = Vector2(0, 8)
	_cook_bar.add_theme_stylebox_override("background", _pill(Palette.COCOA_100, Palette.COCOA_200))
	_cook_bar.add_theme_stylebox_override("fill", _pill(Palette.ACCENT))
	v.add_child(_cook_bar)

	set_process(true)
	_start_glow()


func _finish_cooking() -> void:
	state = State.DONE
	set_process(false)
	_stop_glow()
	_style.border_color = Palette.SUCCESS
	_clear_holder()
	var dish := DishCard.new()
	dish.setup(recipe_id)
	dish.tool = self
	dish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dish.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.add_child(dish)


func _process(delta: float) -> void:
	if state != State.COOKING:
		return
	_cook_left -= delta
	_cook_bar.value = _cook_total - _cook_left
	if _cook_left <= 0.0:
		_finish_cooking()


# ── 입력 ──────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if state == State.IDLE:
			tapped.emit(self)
			accept_event()


# ── 발광 (조리 중 은은한 펄스) ────────────────────────────
func _start_glow() -> void:
	_glow = create_tween().set_loops()
	_glow.tween_property(self, "modulate:a", 0.72, 0.5)
	_glow.tween_property(self, "modulate:a", 1.0, 0.5)

func _stop_glow() -> void:
	if _glow:
		_glow.kill()
		_glow = null
	modulate.a = 1.0


# ── 헬퍼 ──────────────────────────────────────────────────
func _clear_holder() -> void:
	for ch in _holder.get_children():
		ch.queue_free()

func _box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("FBE9DA")
	s.set_corner_radius_all(14)
	s.set_border_width_all(2)
	s.border_color = Palette.SUB
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s

func _pill(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s
