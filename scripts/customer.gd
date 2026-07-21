class_name Customer
extends PanelContainer
## 대기열(큐)의 손님. 메뉴는 비공개 — "뭔가 원함(💭)" + 주문확인 버튼(📋)만.
## 주문 확인 → 슬롯에 주문 카드가 생기고 손님은 큐에서 사라짐(주문 카드로 "이동").
##
## 인내심(주문 대기)은 여기서만 닳음. 0이면 퇴장(주문 못 받음).
## 음식 대기 인내심은 OrderCard가 담당(별개 타이머). [[two-phase-patience]]

signal confirm_pressed(customer: Customer)
signal expired(customer: Customer)

const PATIENCE_ORDER := 15.0  # 주문 대기 (초) — 나중에 config.gd로
const LOW_FRAC := 0.3

var recipe_id: String

var _time_left := PATIENCE_ORDER
var _done := false
var _fill := Palette.SUCCESS
var _gauge: ProgressBar

func setup(id: String) -> void:
	recipe_id = id

func _ready() -> void:
	custom_minimum_size = Vector2(66, 92)
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

	# 얼굴 + "뭔가 원함" 힌트(💭) — 메뉴는 숨김
	var face := Label.new()
	face.text = "🙋💭"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_font_size_override("font_size", 20)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(face)

	_gauge = ProgressBar.new()
	_gauge.min_value = 0
	_gauge.max_value = PATIENCE_ORDER
	_gauge.value = PATIENCE_ORDER
	_gauge.show_percentage = false
	_gauge.custom_minimum_size = Vector2(0, 8)
	_gauge.add_theme_stylebox_override("background", _pill(Palette.GRAY100, Palette.GRAY300))
	_gauge.add_theme_stylebox_override("fill", _pill(_fill))
	v.add_child(_gauge)

	# 주문 확인 버튼 (아이콘)
	var confirm := Button.new()
	confirm.text = "📋"
	confirm.add_theme_font_size_override("font_size", 16)
	confirm.add_theme_stylebox_override("normal", _pill(Palette.ACCENT))
	confirm.add_theme_stylebox_override("hover", _pill(Palette.ACCENT.lightened(0.12)))
	confirm.add_theme_stylebox_override("pressed", _pill(Palette.ACCENT.darkened(0.1)))
	confirm.pressed.connect(func(): confirm_pressed.emit(self))
	v.add_child(confirm)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	_gauge.value = _time_left
	var col := Palette.DANGER if _time_left <= PATIENCE_ORDER * LOW_FRAC else Palette.SUCCESS
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
