class_name Customer
extends PanelContainer
## 대기열(큐)의 손님. 메뉴 비공개 — 원하는 메뉴는 안 보여줌.
## 카드 전체 탭 = 주문 접수(버튼 없음). 은은한 콩콩으로 "누를 수 있음"을 알림.
## 접수 → 슬롯에 주문 카드 생성, 손님은 큐에서 사라짐(주문 카드로 "이동").
## 인내심(주문 대기)은 여기서만 닳음. 0이면 퇴장. 음식 대기는 OrderCard 담당. [[two-phase-patience]]

signal confirm_pressed(customer: Customer)
signal expired(customer: Customer)
signal urged(customer: Customer)   # 인내심 임박(빨강) 진입 1회

var recipe_id: String
var animal := ""   # 손님 동물 종류(빈 값이면 랜덤). 주문 확인 시 주문서로 이어짐.

var _max := Config.PATIENCE_ORDER
var _time_left := 0.0
var _done := false
var _warned := false   # 임박 재촉 1회만
var _fill := Palette.SUCCESS
var _gauge: ProgressBar
var _slide_tw: Tween   # 등장 슬라이드 — 즉시 접수(dismiss) 시 죽여야 페이드인이 안 덮음
var _pulse_tw: Tween   # 은은한 콩콩(누를 수 있음 신호). 접수·이탈 시 정지.

func setup(id: String) -> void:
	recipe_id = id

func _ready() -> void:
	_max = Stats.order_patience()
	_time_left = _max
	# 확인 버튼 없이 카드 전체 탭으로 접수 → 버튼 높이만큼 카드도 낮아짐(얼굴+게이지).
	custom_minimum_size = Vector2(66, 66)
	mouse_filter = Control.MOUSE_FILTER_STOP   # 카드 전체가 탭 받음
	add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200, 1, 12))

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 탭이 카드(self)로 내려가게
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 5)
	add_child(pad)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	pad.add_child(v)

	# 얼굴 — 랜덤 동물 손님(상반신). 메뉴는 숨김.
	if animal == "":
		animal = Customers.random_id()
	v.add_child(Customers.icon_node(animal, 44))

	_gauge = ProgressBar.new()
	_gauge.min_value = 0
	_gauge.max_value = _max
	_gauge.value = _max
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 8)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 탭이 게이지에 안 막히게
	_gauge.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	_gauge.add_theme_stylebox_override("fill", UI.chip(_fill))
	v.add_child(_gauge)


## 카드 전체 탭 = 주문 접수(창고 재료 탭처럼 첫 빈 슬롯으로 자동). main이 _on_confirm_order 처리.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		confirm_pressed.emit(self)
		accept_event()


## 주문 접수됨 — 자리는 유지하되 사라진 척(투명·입력차단). 뒤 손님이 즉시 안 밀리게.
## 호출측이 주문서 날아가기 착지 후 queue_free.
func dismiss() -> void:
	_done = true
	set_process(false)
	if _slide_tw != null and _slide_tw.is_valid():
		_slide_tw.kill()                          # 등장 페이드인 중단(안 그러면 a=0을 덮어씀)
	_stop_pulse()
	modulate.a = 0.0                              # 레이아웃 자리 유지(visible=false와 달리 공간 남김)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 접수 후 추가 탭 차단


## 인내심 타이머 정지/재개 — 시트 열림 동안 월드 정지용.
func set_paused(p: bool) -> void:
	if not _done:
		set_process(not p)


## 등장 슬라이드 중단 — 큐 재정렬과 위치 충돌 방지.
func stop_slide() -> void:
	if _slide_tw != null and _slide_tw.is_valid():
		_slide_tw.kill()
	modulate.a = 1.0   # 페이드인 도중이었으면 즉시 완전 불투명(회색 잔상 방지)


## 강제 이탈(디버그 버튼 등) — 자연 인내심 만료와 동일하게 expired 방출.
func force_expire() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	_stop_pulse()
	expired.emit(self)


## 큐 등장 연출 — 오른쪽에서 스윽 슬라이드 인 + 페이드. 배치 확정 후 호출.
func slide_in() -> void:
	await get_tree().process_frame   # HBox 정렬 끝나 최종 위치 확보
	if not is_inside_tree():
		return
	var target := position
	position = target + Vector2(44, 0)   # 오른쪽 바깥에서 진입
	modulate.a = 0.0
	var tw := create_tween()
	_slide_tw = tw
	tw.set_parallel(true)
	tw.tween_property(self, "position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	_start_idle_pulse()


## 은은한 콩콩 — "누를 수 있음" 신호. scale라 큐 레이아웃 위치와 충돌 없음.
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
		if col == Palette.DANGER and not _warned:   # 임박 진입 → 재촉 1회
			_warned = true
			_urge()
	if _time_left <= 0.0:
		_done = true
		set_process(false)
		_stop_pulse()
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
