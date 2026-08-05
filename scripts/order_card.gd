class_name OrderCard
extends Card
## 슬롯에 놓인 주문 카드 = 큐에서 이동해 온 손님.
## 손님 얼굴 + 음식 대기 인내심 게이지 + 주문 메뉴(요리 아이콘 + 필요재료 아이콘).
## 음식 대기 인내심이 0이면 카드(=손님) 통째로 사라짐. [[two-phase-patience]]
## 이동은 가능(Card 상속)하나 휴지통엔 못 버림.

signal expired(card: OrderCard)
signal served(card: OrderCard, dish: DishCard)

var recipe_id: String
var born := 0.0   ## 슬롯에 놓인 게임시각(초). 판매 ctx의 order_age 계산용. main이 스탬프.

var _max := Config.PATIENCE_DISH
var _time_left := Config.PATIENCE_DISH
var _done := false
var _fill := Palette.SUB
var _gauge: ProgressBar
var _servable := false
var _glow: Tween

func setup(id: String) -> void:
	recipe_id = id

func is_trashable() -> bool:
	return false

## 남은 음식대기 인내심 비율(0..1) — 판매 ctx의 pat_frac(41·43·소진 카드)용.
func pat_frac() -> float:
	return clampf(_time_left / maxf(0.001, _max), 0.0, 1.0)

func _preview_text() -> String:
	return str(Recipes.get_def(recipe_id).get("icon", "?"))

func _build_content() -> void:
	# 주문 카드 느낌: 크림빛 배경 + 액센트 테두리
	_style.bg_color = Palette.TICKET
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
	_max = Stats.dish_patience()
	_time_left = _max
	_gauge.max_value = _max
	_gauge.value = _max
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 6)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	_gauge.add_theme_stylebox_override("fill", UI.chip(_fill))
	v.add_child(_gauge)


## 매칭 완성품이 보드에 있으면 초록 테두리 + 은은한 펄스로 "지금 서빙 가능" 표시.
func set_servable(on: bool) -> void:
	if on == _servable:
		return
	_servable = on
	if on:
		# 조리 글로우(알파 fade)·테두리 대신: 배경 초록(팔레트색) + 스케일 바운스(콩콩).
		_style.bg_color = Palette.SUCCESS
		pivot_offset = size * 0.5   # 중앙 기준 스케일
		_glow = create_tween().set_loops()
		_glow.tween_property(self, "scale", Vector2(1.07, 1.07), 0.35).set_trans(Tween.TRANS_SINE)
		_glow.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	else:
		if _glow != null:
			_glow.kill()
			_glow = null
		scale = Vector2.ONE
		_style.bg_color = Palette.TICKET


# ── 서빙 타깃 (완성품 받기, 클릭·드래그 공용) ─────────────
func can_accept(payload: Dictionary) -> bool:
	return payload.get("kind") == "dish" and str(payload.get("recipe_id")) == recipe_id

func accept(payload: Dictionary) -> void:
	served.emit(self, payload.get("card"))

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	var col := Palette.DANGER if _time_left <= _max * Config.PATIENCE_LOW_FRAC else Palette.SUB
	if col != _fill:
		_fill = col
		_gauge.add_theme_stylebox_override("fill", UI.chip(col))
	if _time_left <= 0.0:
		_done = true
		set_process(false)
		expired.emit(self)
