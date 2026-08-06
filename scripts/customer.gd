class_name Customer
extends PanelContainer
## 대기열(큐)의 손님. 메뉴 비공개 — "뭔가 원함(💭)" + 주문확인 버튼(📋)만.
## 주문 확인 → 슬롯에 주문 카드 생성, 손님은 큐에서 사라짐(주문 카드로 "이동").
## 인내심(주문 대기)은 여기서만 닳음. 0이면 퇴장. 음식 대기는 OrderCard 담당. [[two-phase-patience]]

signal confirm_pressed(customer: Customer)
signal expired(customer: Customer)

var recipe_id: String

var _max := Config.PATIENCE_ORDER
var _time_left := 0.0
var _done := false
var _fill := Palette.SUCCESS
var _gauge: ProgressBar

func setup(id: String) -> void:
	recipe_id = id

func _ready() -> void:
	_max = Stats.order_patience()
	_time_left = _max
	custom_minimum_size = Vector2(66, 92)
	add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200, 1, 12))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 5)
	add_child(pad)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	pad.add_child(v)

	# 얼굴 + "뭔가 원함" 힌트(💭) — 메뉴 숨김
	var face := UI.label("🙋💭", 20)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(face)

	_gauge = ProgressBar.new()
	_gauge.min_value = 0
	_gauge.max_value = _max
	_gauge.value = _max
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 8)
	_gauge.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	_gauge.add_theme_stylebox_override("fill", UI.chip(_fill))
	v.add_child(_gauge)

	# 주문 확인 버튼 (아이콘)
	var confirm := Button.new()
	confirm.text = "📋"
	confirm.add_theme_font_size_override("font_size", 15)
	confirm.add_theme_stylebox_override("normal", UI.chip(Palette.ACCENT))
	confirm.add_theme_stylebox_override("hover", UI.chip(Palette.ACCENT.lightened(0.12)))
	confirm.add_theme_stylebox_override("pressed", UI.chip(Palette.ACCENT.darkened(0.1)))
	confirm.pressed.connect(func(): confirm_pressed.emit(self))
	v.add_child(confirm)


## 큐 등장 연출 — 오른쪽에서 스윽 슬라이드 인 + 페이드. 배치 확정 후 호출.
func slide_in() -> void:
	await get_tree().process_frame   # HBox 정렬 끝나 최종 위치 확보
	if not is_inside_tree():
		return
	var target := position
	position = target + Vector2(44, 0)   # 오른쪽 바깥에서 진입
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	var col := Palette.DANGER if _time_left <= _max * Config.PATIENCE_LOW_FRAC else Palette.SUCCESS
	if col != _fill:
		_fill = col
		_gauge.add_theme_stylebox_override("fill", UI.chip(col))
	if _time_left <= 0.0:
		_done = true
		set_process(false)
		expired.emit(self)
