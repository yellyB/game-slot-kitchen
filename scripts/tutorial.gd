class_name Tutorial
extends Control
## 게임 내 가이드 오버레이 — 실제 play 화면(Board·Warehouse·Cooking·손님)을 그대로 쓰며
## 그 위에 스포트라이트 + 단계 진행 + 이동 게이트만 얹는다. host(main)가 실제 노드/스폰 콜백을 주입.
## 별도 화면을 새로 만들지 않으므로 "게임 시작 직전에 얹기"가 그대로 가능.
## 끝나면 finished 방출 — 타이틀 복귀/게임 시작은 호출측(main)이 결정.

signal finished

const RECIPE := "coffee"   # 가장 단순한 레시피(원두+물, 3초)

enum { S_ACCEPT, S_WAREHOUSE, S_INGREDIENTS, S_COOK, S_SERVE, S_DONE }

# host(main) 주입 — 실제 게임 컴포넌트/콜백
var board: Board
var queue_row: HBoxContainer
var warehouse: Warehouse
var cooking: Cooking
var warehouse_btn: Button
var spawn_customer: Callable   # 커피 손님 1명 스폰 (main._spawn_customer.bind(RECIPE))

var _spot: TutorialSpotlight
var _step := S_ACCEPT
var _prev_move_allowed: Callable
var _order_seen := false   # 주문이 보드에 올라온 적 있는지(서빙 완료 판정용)


func _ready() -> void:
	z_index = 350
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 루트는 통과 — 스포트라이트 블로커/구멍만 입력 제어

	# 이동 게이트: 정해진 동작만 허용(나머지는 무시). 끝나면 복원.
	_prev_move_allowed = Move.action_allowed
	Move.action_allowed = _gate
	Move.performed.connect(_on_move_performed)

	# 스포트라이트(입력 차단형)
	_spot = TutorialSpotlight.new()
	add_child(_spot)

	# 나가기(X) — 스포트라이트 다음에 추가해 항상 최상단·클릭 가능
	var exit := Button.new()
	exit.text = "✕"
	exit.add_theme_font_size_override("font_size", 16)
	exit.add_theme_color_override("font_color", Palette.COCOA_600)
	exit.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	exit.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	exit.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	exit.anchor_left = 1.0
	exit.anchor_right = 1.0
	exit.offset_left = -52
	exit.offset_right = -12
	exit.offset_top = 12
	exit.offset_bottom = 46
	exit.z_index = 600
	exit.pressed.connect(_finish)
	Audio.attach_click(exit)
	add_child(exit)

	spawn_customer.call()   # 커피 손님 1명(실제 스포너 경유)
	_goto_step(S_ACCEPT)


# ── 동작 게이트 (정해진 것만 허용, 나머지 무시) ──────────────
## Move가 배치 직전 호출. false면 그 배치를 적용하지 않고 무시.
func _gate(payload: Dictionary) -> bool:
	match payload.get("kind"):
		"new":   # 창고 재료 꺼내기 — 재료 단계에서 '필요한 재료·필요 수량'만 허용
			return _step == S_INGREDIENTS and _needs_more(str(payload.get("id")))
		"dish":  # 완성품 서빙 — 서빙 단계에서만
			return _step == S_SERVE
		_:
			return false   # 슬롯↔슬롯 이동 등 그 외는 튜토리얼에서 무시


## 레시피에 필요하고 아직 덜 채운 재료면 true(예: 원두1·물1까지만).
func _needs_more(id: String) -> bool:
	var need := 0
	for iid in Recipes.get_def(RECIPE).get("ingredients", []):
		if iid == id:
			need += 1
	if need == 0:
		return false
	return board.ingredient_counts().get(id, 0) < need


func _on_move_performed() -> void:
	_check_step()


# ── 단계 진행 ─────────────────────────────────────────────
func _process(_delta: float) -> void:
	# 주문 카드 "서빙 가능" 발광은 main의 _refresh_servable이 처리(실제 화면 공용).
	_check_step()
	_update_spot_target()   # 구멍(허용 영역) 매 프레임 갱신(시트 열림 등 반영)


## 상태 기반 단계는 매 프레임 폴링으로 전진(실제 컴포넌트 상태를 관찰).
func _check_step() -> void:
	match _step:
		S_ACCEPT:
			if _find_order() != null:   # 손님 탭 → 주문 카드가 보드에 안착
				_goto_step(S_WAREHOUSE)
		S_WAREHOUSE:
			if warehouse.visible:
				_goto_step(S_INGREDIENTS)
		S_INGREDIENTS:
			if board.has_ingredients(RECIPE):
				_goto_step(S_COOK)
		S_COOK:
			if _find_dish() != null:
				_goto_step(S_SERVE)
		S_SERVE:
			if _order_seen and _find_order() == null:   # 주문이 사라짐 = 서빙 완료(타이머 정지라 만료 없음)
				_goto_step(S_DONE)


func _goto_step(s: int) -> void:
	_step = s
	match s:
		S_ACCEPT: _spot.set_message(Loc.t("tut_accept"))
		S_WAREHOUSE: _spot.set_message(Loc.t("tut_warehouse"))
		S_INGREDIENTS: _spot.set_message(Loc.t("tut_ingredients"))
		S_COOK: _spot.set_message(Loc.t("tut_cook"))
		S_SERVE:
			_order_seen = true
			_spot.set_message(Loc.t("tut_serve"))
		S_DONE: _show_done()
	_update_spot_target()


## 현재 단계에서 클릭 허용할 영역(구멍). 나머지는 스포트라이트가 전부 차단.
func _current_target() -> Control:
	match _step:
		S_ACCEPT: return _first_customer()
		S_WAREHOUSE: return warehouse_btn
		S_INGREDIENTS: return warehouse if warehouse.visible else warehouse_btn
		S_COOK: return cooking if cooking.visible else board
		S_SERVE: return board
	return null


func _update_spot_target() -> void:
	if _spot != null and _spot.visible:
		_spot.target = _current_target()


# ── 실제 보드/큐 상태 조회 ────────────────────────────────
func _first_customer() -> Control:
	for c in queue_row.get_children():
		if c is Customer:
			return c
	return null


func _find_order() -> OrderCard:
	for sl in board.slots:
		var c := sl.get_card()
		if c is OrderCard:
			return c
	return null


## 완성품(도구석 위 우선, 없으면 슬롯) 노드 — 없으면 null.
func _find_dish() -> Control:
	for t in board.tools:
		var d := t.get_dish()
		if d != null and d.recipe_id == RECIPE:
			return d
	for sl in board.slots:
		var c := sl.get_card()
		if c is DishCard and c.recipe_id == RECIPE:
			return c
	return null


# ── 완료 / 종료 ───────────────────────────────────────────
func _show_done() -> void:
	_spot.visible = false
	var dim := ColorRect.new()
	dim.color = Palette.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 520
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var emoji := UI.label("🎉", 64)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(emoji)
	var msg := UI.label(Loc.t("tut_done"), 22, Palette.WHITE, true)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(msg)
	var btn := Button.new()
	btn.text = Loc.t("tut_to_menu")
	btn.custom_minimum_size = Vector2(180, 52)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Palette.WHITE)
	btn.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	btn.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	btn.pressed.connect(_finish)
	Audio.attach_click(btn)
	box.add_child(btn)


func _finish() -> void:
	if Move.performed.is_connected(_on_move_performed):
		Move.performed.disconnect(_on_move_performed)
	Move.action_allowed = _prev_move_allowed  # 게이트 해제(본격 게임 동작 복원)
	finished.emit()
