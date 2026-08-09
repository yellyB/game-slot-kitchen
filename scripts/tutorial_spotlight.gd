class_name TutorialSpotlight
extends Control
## 튜토리얼 스포트라이트 — 대상 주위를 딤(구멍) 처리 + 펄스 링 + 말풍선.
## 입력은 통과(MOUSE_FILTER_IGNORE) — 통제된 시나리오라 하드 게이팅 없이 시선만 유도.

const DIM := Color(0.164, 0.129, 0.106, 0.62)
const PAD := 8.0

var target: Control            ## 강조 대상(없으면 전체 딤)
var _msg_pill: PanelContainer
var _msg_label: Label
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 500

	_msg_pill = PanelContainer.new()
	_msg_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_pill.add_theme_stylebox_override("panel", UI.chip(Palette.COCOA_900))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 9)
	pad.add_theme_constant_override("margin_bottom", 9)
	_msg_pill.add_child(pad)
	_msg_label = UI.label("", 16, Palette.WHITE, true)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad.add_child(_msg_label)
	add_child(_msg_pill)


## 대상과 안내 문구 지정(대상 null이면 전체 딤 + 중앙 문구).
func show_step(t: Control, msg: String) -> void:
	target = t
	_msg_label.text = msg
	_msg_pill.visible = msg != ""
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_place_message()


func _hole() -> Rect2:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return Rect2()
	return target.get_global_rect().grow(PAD)


func _draw() -> void:
	var r := _hole()
	if r.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, size), DIM)
		return
	# 구멍 주변 4분할 딤
	var bottom_h := maxf(0.0, size.y - r.end.y)
	draw_rect(Rect2(0, 0, size.x, maxf(0.0, r.position.y)), DIM)          # 위
	draw_rect(Rect2(0, r.end.y, size.x, bottom_h), DIM)                   # 아래
	draw_rect(Rect2(0, r.position.y, maxf(0.0, r.position.x), r.size.y), DIM)  # 왼
	draw_rect(Rect2(r.end.x, r.position.y, maxf(0.0, size.x - r.end.x), r.size.y), DIM)  # 오
	# 펄스 링
	var a: float = 0.55 + 0.35 * sin(_t * 4.0)
	draw_rect(r, Color(Palette.ACCENT, a), false, 3.0)


func _place_message() -> void:
	if not is_instance_valid(_msg_pill) or not _msg_pill.visible:
		return
	var pill := _msg_pill.size
	var r := _hole()
	var pos: Vector2
	if r.size == Vector2.ZERO:
		pos = (size - pill) * 0.5
	else:
		var cx := r.position.x + r.size.x * 0.5 - pill.x * 0.5
		var below := r.end.y + 12.0
		if below + pill.y > size.y - 12.0:   # 구멍이 아래쪽이면 위로
			pos = Vector2(cx, r.position.y - pill.y - 12.0)
		else:
			pos = Vector2(cx, below)
	pos.x = clampf(pos.x, 12.0, maxf(12.0, size.x - pill.x - 12.0))
	pos.y = clampf(pos.y, 12.0, maxf(12.0, size.y - pill.y - 12.0))
	_msg_pill.position = pos
