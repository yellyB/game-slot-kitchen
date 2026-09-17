class_name Modal
extends Control
## 중앙 패널 모달 (딤 배경 + 입력 차단). 결과·게임오버·승리 공용.
## 대강 구현(기능 위주) — 디자인 확정 후 정리.

const SECTION_GAP := 22   # 내용영역 ↔ 버튼영역 표준 간격(정산·마감·실패 팝업 공용)

var _body: VBoxContainer
var _panel: PanelContainer
var _center: CenterContainer
var _pinned := false

static func open(parent: Node) -> Modal:
	var m := Modal.new()
	parent.add_child(m)
	return m

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤 입력 차단

	var dim := ColorRect.new()
	dim.color = Palette.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_center = center

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200))
	center.add_child(panel)
	_panel = panel

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(pad)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	pad.add_child(_body)


func title(text: String, color := Palette.COCOA_800, size := 22) -> Modal:
	_body.add_child(_centered(UI.label(text, size, color, true)))
	return self


func row(text: String, color := Palette.COCOA_800) -> Modal:
	_body.add_child(_centered(UI.label(text, 16, color)))
	return self


## 숫자 카운트업 행 — fmt(단일 %s)의 금액을 0에서 value까지 촤르륵 세어 올림(UI.money 포맷).
func count_row(fmt: String, value: int, color := Palette.COCOA_800) -> Modal:
	var l := _centered(UI.label(fmt % UI.money(0), 16, color))
	_body.add_child(l)
	var tw := create_tween()
	tw.tween_method(func(v: float): l.text = fmt % UI.money(int(round(v))), 0.0, float(value), 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return self


## 도장 찍듯 팡 등장하는 강조 행 — delay(카운트업 종료 즈음) 후 스케일 팝 + 페이드인.
func stamp_row(text: String, color := Palette.SUCCESS, delay := 0.55, size := 20) -> Modal:
	var l := _centered(UI.label(text, size, color, true))
	_body.add_child(l)
	l.modulate.a = 0.0
	l.scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): l.pivot_offset = l.size * 0.5)   # 레이아웃 후 중앙 피벗
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(l, "scale", Vector2(1.25, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	return self


## 임의 컨트롤을 본문에 추가(정산 순차 페이드인 등 커스텀 연출용 — 호출측이 애니 직접 제어).
func add_row(ctrl: Control) -> Modal:
	_body.add_child(ctrl)
	return self


## 본문 행 간격(px) — 기본 10. 촘촘히 붙이고 싶을 때(정산 등).
func gap(px: int) -> Modal:
	_body.add_theme_constant_override("separation", px)
	return self


## 고정 높이 빈 간격 행.
func space(px: int) -> Modal:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, px)
	_body.add_child(s)
	return self


## 내용영역 ↔ 버튼영역 표준 간격 — 팝업 간 구조 통일용(SECTION_GAP 한 곳으로 관리).
func section_gap() -> Modal:
	return space(SECTION_GAP)


## 패널을 지금 위치에 고정 — 이후 add_row는 중앙 재정렬 없이 아래로만 높이가 늘어남.
## (CenterContainer에서 빼내 self 자식으로 옮기고 현재 좌표에 앵커. 폭은 그대로라 가로 중앙 유지.)
func pin_top() -> void:
	if _pinned or _panel == null or not is_instance_valid(_panel):
		return
	_pinned = true
	var gpos := _panel.global_position
	_center.remove_child(_panel)
	add_child(_panel)
	_panel.global_position = gpos


func sep() -> Modal:
	var line := ColorRect.new()
	line.color = Palette.COCOA_200
	line.custom_minimum_size = Vector2(0, 1)
	_body.add_child(line)
	return self


func button(text: String, cb: Callable) -> Modal:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.WHITE)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
	b.pressed.connect(func():
		queue_free()
		cb.call())
	Audio.attach_click(b)   # 모달 액션 버튼(하루 종료 후 상점으로 등) 클릭음
	_body.add_child(b)
	return self


## 확인창 아이콘 버튼 행 — [빨강X 취소][초록체크 확인] 나란히, 칩 배경 없음.
## cancel_cb 생략 시 취소는 그냥 닫기.
func icon_confirm(confirm_cb: Callable, cancel_cb := Callable()) -> Modal:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.add_child(_icon_btn("fail_x", cancel_cb))
	row.add_child(_icon_btn("pass_check", confirm_cb))
	_body.add_child(row)
	return self


func _icon_btn(icon: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.add_child(UI.ui_btn_icon(icon, 44))
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", empty)
	b.add_theme_stylebox_override("pressed", empty)
	b.pressed.connect(func():
		queue_free()
		if cb.is_valid():
			cb.call())
	Audio.attach_click(b)
	return b


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
