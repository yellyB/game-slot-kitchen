class_name TutorialSpotlight
extends Control
## 튜토리얼 스포트라이트 — 대상(구멍) 외 영역을 실제로 입력 차단 + 딤 + 펄스 링 + 말풍선.
## 구멍 주변을 4개의 STOP 블로커로 덮어, 강조된 대상만 클릭 가능(나머지는 전부 무시).

const DIM := Color(0.164, 0.129, 0.106, 0.62)
const PAD := 8.0

var target: Control            ## 강조·허용 대상(없으면 전체 차단)
var _blk: Array[ColorRect] = []   # 구멍 주변 4분할 블로커(입력 차단)
var _msg_pill: PanelContainer
var _msg_label: Label
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 루트는 통과, 블로커만 차단
	z_index = 500

	for i in 4:
		var b := ColorRect.new()
		b.color = DIM
		b.mouse_filter = Control.MOUSE_FILTER_STOP   # 이 영역 클릭 = 삼킴(무시)
		add_child(b)
		_blk.append(b)

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
	add_child(_msg_pill)   # 블로커 뒤(위)에 추가 → 항상 보임


func set_message(msg: String) -> void:
	_msg_label.text = msg
	_msg_pill.visible = msg != ""


func _process(delta: float) -> void:
	_t += delta
	_layout_blockers()
	queue_redraw()
	_place_message()


func _hole() -> Rect2:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return Rect2()
	return target.get_global_rect().grow(PAD)


## 구멍(대상) 주변만 블로커로 덮는다. 구멍이 없으면 전체 차단.
func _layout_blockers() -> void:
	var r := _hole()
	if r.size == Vector2.ZERO:
		_set_blk(0, Rect2(Vector2.ZERO, size))
		for i in range(1, 4):
			_set_blk(i, Rect2())
		return
	_set_blk(0, Rect2(0, 0, size.x, maxf(0.0, r.position.y)))                       # 위
	_set_blk(1, Rect2(0, r.end.y, size.x, maxf(0.0, size.y - r.end.y)))             # 아래
	_set_blk(2, Rect2(0, r.position.y, maxf(0.0, r.position.x), r.size.y))          # 왼
	_set_blk(3, Rect2(r.end.x, r.position.y, maxf(0.0, size.x - r.end.x), r.size.y))# 오


func _set_blk(i: int, rect: Rect2) -> void:
	var b := _blk[i]
	b.position = rect.position
	b.size = rect.size
	b.visible = rect.size.x > 0.0 and rect.size.y > 0.0


func _draw() -> void:
	var r := _hole()
	if r.size == Vector2.ZERO:
		return
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
		if below + pill.y > size.y - 12.0:
			pos = Vector2(cx, r.position.y - pill.y - 12.0)
		else:
			pos = Vector2(cx, below)
	pos.x = clampf(pos.x, 12.0, maxf(12.0, size.x - pill.x - 12.0))
	pos.y = clampf(pos.y, 12.0, maxf(12.0, size.y - pill.y - 12.0))
	_msg_pill.position = pos
