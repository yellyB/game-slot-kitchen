class_name OrderCard
extends Card
## 슬롯에 놓인 주문 카드 = 큐에서 이동해 온 손님.
## 손님 얼굴 + 음식 대기 인내심 게이지 + 주문 메뉴(요리 아이콘 + 필요재료 아이콘).
## 음식 대기 인내심이 0이면 카드(=손님) 통째로 사라짐. [[two-phase-patience]]
## 이동은 가능(Card 상속)하나 휴지통엔 못 버림.

signal expired(card: OrderCard)

var recipe_id: String

var _time_left := Config.PATIENCE_DISH
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
	# 주문 카드 느낌: 크림빛 배경 + 액센트 테두리
	_style.bg_color = Color("FFF7E6")
	_style.border_color = Palette.ACCENT

	var def := Recipes.get_def(recipe_id)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	add_child(v)

	# 손님 얼굴
	var face := Label.new()
	face.text = "🙋"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_font_size_override("font_size", 16)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(face)

	# 주문 메뉴: 요리 아이콘
	var dish := Label.new()
	dish.text = str(def.get("icon", "?"))
	dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dish.add_theme_font_size_override("font_size", 22)
	dish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dish)

	# 필요재료 아이콘들
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

	# 음식 대기 인내심 게이지
	_gauge = ProgressBar.new()
	_gauge.min_value = 0
	_gauge.max_value = Config.PATIENCE_DISH
	_gauge.value = Config.PATIENCE_DISH
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 6)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_theme_stylebox_override("background", _pill(Palette.COCOA_100, Palette.COCOA_200))
	_gauge.add_theme_stylebox_override("fill", _pill(_fill))
	v.add_child(_gauge)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	var col := Palette.DANGER if _time_left <= Config.PATIENCE_DISH * Config.PATIENCE_LOW_FRAC else Palette.SUB
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
