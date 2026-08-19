class_name TutorialSpotlight
extends Control
## 튜토리얼 스포트라이트 — 대상(구멍) 외 영역을 실제로 입력 차단 + 딤 + 펄스 링 + 말풍선.
## 구멍 주변을 4개의 STOP 블로커로 덮어, 강조된 대상만 클릭 가능(나머지는 전부 무시).

const DIM := Color(0.164, 0.129, 0.106, 0.62)
const PAD := 8.0

## 말풍선 텍스트의 {토큰} → 실제 게임 아이콘(이모지 대신 실사용 손그림).
const _ICONS := {
  "order": "res://assets/art/ui/receipt.png",       # 📋 주문(접수)
  "warehouse": "res://assets/art/ui/warehouse.png",  # 🏬 창고
  "bean": "res://assets/art/ingredients/bean.png",   # 🌰 원두
  "water": "res://assets/art/ingredients/water.png", # 💧 물
  "tool": "res://assets/art/tools/burner.png",       # 🔥 도구(화구)
  "coffee": "res://assets/art/recipes/coffee.png",   # ☕ 커피
}
const _ICON_PX := 20

var target: Control            ## 강조·허용 대상(없으면 전체 차단)
var _blk: Array[ColorRect] = []   # 구멍 주변 4분할 블로커(입력 차단)
var _msg_pill: PanelContainer
var _msg_box: HBoxContainer     # 텍스트 조각 + 인라인 아이콘 혼합 렌더
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
  _msg_box = HBoxContainer.new()
  _msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _msg_box.alignment = BoxContainer.ALIGNMENT_CENTER
  _msg_box.add_theme_constant_override("separation", 0)   # 간격은 텍스트에 넣은 공백으로
  pad.add_child(_msg_box)
  add_child(_msg_pill)   # 블로커 뒤(위)에 추가 → 항상 보임


## 말풍선 설정 — {토큰}은 실제 게임 아이콘으로, 나머지는 텍스트로 인라인 렌더.
func set_message(msg: String) -> void:
  for c in _msg_box.get_children():
    c.queue_free()
  _msg_pill.visible = msg != ""
  if msg == "":
    return
  var buf := ""
  var i := 0
  while i < msg.length():
    if msg[i] == "{":
      var close := msg.find("}", i)
      if close > i:
        if buf != "":
          _add_text(buf)
          buf = ""
        _add_icon(msg.substr(i + 1, close - i - 1))
        i = close + 1
        continue
    buf += msg[i]
    i += 1
  if buf != "":
    _add_text(buf)


func _add_text(t: String) -> void:
  var l := UI.label(t, 16, Palette.WHITE, true)
  l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  _msg_box.add_child(l)


## 토큰 → 실사용 게임 이미지. 자산 없으면 토큰 원문 텍스트로 폴백.
func _add_icon(token: String) -> void:
  var path: String = _ICONS.get(token, "")
  if path == "" or not ResourceLoader.exists(path):
    _add_text("{" + token + "}")
    return
  var tr := TextureRect.new()
  tr.texture = load(path)
  tr.custom_minimum_size = Vector2(_ICON_PX, _ICON_PX)
  tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
  tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
  tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  _msg_box.add_child(tr)


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
