class_name OrderCard
extends Card
## 슬롯에 놓인 주문 카드 = 큐에서 이동해 온 손님.
## 손님 얼굴 + 음식 대기 인내심 게이지 + 주문 메뉴(요리 아이콘 + 필요재료 아이콘).
## 음식 대기 인내심이 0이면 카드(=손님) 통째로 사라짐. [[two-phase-patience]]
## 이동은 가능(Card 상속)하나 휴지통엔 못 버림.

signal expired(card: OrderCard)
signal served(card: OrderCard, dish: DishCard)
signal rejected(card: OrderCard)   # 안 맞는 완성품 서빙 시도 → 반려 연출용
signal urged(card: OrderCard)      # 음식대기 인내심 임박(빨강) 진입 1회

var recipe_id: String
var animal := ""   # 손님 동물(큐에서 이어받음). 빈 값이면 랜덤.
var born := 0.0   ## 슬롯에 놓인 게임시각(초). 판매 ctx의 order_age 계산용. main이 스탬프.

var _max := Config.PATIENCE_DISH
var _time_left := Config.PATIENCE_DISH
var _done := false
var _warned := false   # 임박 재촉 1회만
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

## 드래그 프리뷰도 손그림 메뉴(레시피)로 — 있으면 텍스처, 없으면 이모지 폴백.
func _preview_icon() -> Control:
	return Recipes.icon_node(recipe_id, 44)

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

	# 윗줄: [말풍선+메뉴](왼쪽) | [손님](오른쪽) — 손님이 원하는 메뉴를 생각
	if animal == "":
		animal = Customers.random_id()
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 2)
	v.add_child(top)

	# 말풍선(임시 이모지 💭) 위에 메뉴 아이콘 — 추후 손님쪽 향한 말풍선 이미지로 교체
	var bubble := CenterContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var think := UI.label("💭", 32)
	think.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(think)                          # 말풍선(뒤)
	bubble.add_child(Recipes.icon_node(recipe_id, 20))   # 메뉴(앞, 위에 얹힘)
	top.add_child(bubble)

	# 손님 이미지 (오른쪽)
	top.add_child(Customers.icon_node(animal, 30))

	# 아랫줄: 메뉴 만들 재료
	var reqs := HBoxContainer.new()
	reqs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reqs.alignment = BoxContainer.ALIGNMENT_CENTER
	reqs.add_theme_constant_override("separation", 1)
	v.add_child(reqs)
	for iid in def.get("ingredients", []):
		reqs.add_child(Ingredients.icon_node(iid, 22))

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

## 클릭 서빙에서 안 맞는 완성품이 올 때 반려(흔들림+땡). 처리했으면 true. (Move가 조회)
func reject_payload(payload: Dictionary) -> bool:
	if payload.get("kind") == "dish" and not can_accept(payload):
		_reject()
		return true
	return false

## 어떤 완성품이든 드롭은 받음(맞으면 서빙, 틀리면 반려 연출). 재료·기타는 거부.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("kind") == "dish"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if can_accept(data):
		Move.on_drop(self, data)
	else:
		_reject()   # 레시피 안 맞음 → 흔들림 + 😠

## 반려 연출 — 좌우로 흔들림 + 😠(main이 신호 받아 팝).
func _reject() -> void:
	Audio.play("reject")   # 다른 메뉴 서빙 → 반려음
	var bx := position.x
	var tw := create_tween()
	tw.tween_property(self, "position:x", bx + 6.0, 0.05)
	tw.tween_property(self, "position:x", bx - 6.0, 0.05)
	tw.tween_property(self, "position:x", bx + 4.0, 0.05)
	tw.tween_property(self, "position:x", bx, 0.05)
	rejected.emit(self)


## 음식대기 인내심 타이머 정지/재개 — 시트 열림 동안 월드 정지용.
func set_paused(p: bool) -> void:
	if not _done:
		set_process(not p)


## 강제 이탈(디버그 버튼 등) — 자연 인내심 만료와 동일하게 expired 방출.
func force_expire() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	expired.emit(self)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	var col := Palette.DANGER if _time_left <= _max * Config.PATIENCE_LOW_FRAC else Palette.SUB
	if col != _fill:
		_fill = col
		_gauge.add_theme_stylebox_override("fill", UI.chip(col))
		if col == Palette.DANGER and not _warned:   # 임박 진입 → 재촉 1회
			_warned = true
			_urge()
	if _time_left <= 0.0:
		_done = true
		set_process(false)
		expired.emit(self)


## 임박 재촉 — 좌우로 짧게 흔들 + urged 신호(main이 💢 팝).
func _urge() -> void:
	urged.emit(self)
	var bx := position.x
	var tw := create_tween()
	tw.tween_property(self, "position:x", bx + 4.0, 0.05)
	tw.tween_property(self, "position:x", bx - 4.0, 0.05)
	tw.tween_property(self, "position:x", bx + 3.0, 0.05)
	tw.tween_property(self, "position:x", bx, 0.05)
