class_name Shop
extends Control
## 인터세션 상점 — 보유 돈 + 슬롯 확장 + 버프 팩(카드깡) + 보유 버프 + [영업 시작].
## 딤 배경 + 입력 차단. 대강 구현(디자인 후 정리).

signal start_business

var session: Session  # main이 add_child 전에 주입
var _cash_label: Label
var _buy_slot_btn: Button
var _draw_btn: Button
var _buff_btn: Button            # 보유 버프 서랍 여는 버튼(계속하기 왼쪽). 보유 0개면 비활성.
var _buff_sheet: BuffSheet       # 보유 버프 리스트 서랍(바텀시트)
var _buff_backdrop: ColorRect    # 서랍 열림 시 딤 + 바깥 탭 닫기
var _drew := false   # 이번 상점 방문에서 이미 뽑았는지(방문당 1회). 다음날 재진입 시 새 인스턴스로 리셋.
var _slot_price_label: Label   # 슬롯 가격 표시(구매마다 갱신)
var _last_price_label: Label   # _product가 방금 만든 가격 라벨(호출 직후 회수용)

func _ready() -> void:
  set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  z_index = 300
  mouse_filter = Control.MOUSE_FILTER_STOP

  # 페이지 배경 — 크림 바탕. 상점 손그림(assets/art/bg/shop.png) 있으면 그 위에 덮음.
  # (팝업이 아니라 화면을 꽉 채우는 별도 페이즈 화면) [[화구 아트 로딩과 동일 폴백 패턴]]
  var bg := ColorRect.new()
  bg.color = Palette.COCOA_50
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  add_child(bg)
  var bg_path := "res://assets/art/bg/shop.png"
  if ResourceLoader.exists(bg_path):
    var bgi := TextureRect.new()
    bgi.texture = load(bg_path)
    bgi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bgi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # 가로(좌우) 맞춤, 위아래는 비율대로(크롭 없음)
    bgi.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bgi)

  # 전체 여백 프레임(화면 가장자리 패딩)
  var pad := MarginContainer.new()
  pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  for side in ["left", "right"]:
    pad.add_theme_constant_override("margin_" + side, 20)
  pad.add_theme_constant_override("margin_top", 24)
  pad.add_theme_constant_override("margin_bottom", 20)
  add_child(pad)

  var v := VBoxContainer.new()
  v.add_theme_constant_override("separation", 16)
  pad.add_child(v)

  # 헤더(상단 바): 보유 돈 (가게 아이콘은 배경에 이미 있어 제거)
  var header := HBoxContainer.new()
  header.add_theme_constant_override("separation", 8)
  v.add_child(header)
  var gap := Control.new()
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  header.add_child(gap)
  # 보유금 — 배경과 안 겹치게 흰 상자(칩) 안에 표시(대비 확보).
  var cash_box := PanelContainer.new()
  cash_box.add_theme_stylebox_override("panel", UI.chip(Palette.WHITE, Palette.COCOA_200))
  var cbpad := MarginContainer.new()
  cbpad.add_theme_constant_override("margin_left", 12)
  cbpad.add_theme_constant_override("margin_right", 12)
  cbpad.add_theme_constant_override("margin_top", 4)
  cbpad.add_theme_constant_override("margin_bottom", 4)
  cash_box.add_child(cbpad)
  var cbrow := HBoxContainer.new()
  cbrow.add_theme_constant_override("separation", 5)
  cbpad.add_child(cbrow)
  cbrow.add_child(UI.ui_icon("coin", 22))   # 동전 손그림
  _cash_label = UI.label("0", 22, Palette.COCOA_800, true)
  cbrow.add_child(_cash_label)
  header.add_child(cash_box)

  # 본문(스크롤) — 상품·보유버프. 콘텐츠 늘어나도 스크롤로 흡수(상점은 날짜마다 성장).
  var scroll := ScrollContainer.new()
  scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  v.add_child(scroll)

  var body := VBoxContainer.new()
  body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  body.add_theme_constant_override("separation", 12)
  scroll.add_child(body)

  # 상품: 슬롯 확장 / 버프 팩
  var slot_price := Config.slot_price(session.day, session.slots - Config.START_SLOTS)
  # 슬롯 확장 = 슬롯+ 손그림, 버프 팩(카드깡) = 카드팩 손그림
  _buy_slot_btn = _product(body, UI.ui_icon("slot_expand", 72), slot_price, Loc.t("shop_buy"), Palette.SUB, _on_buy_slot)
  _slot_price_label = _last_price_label   # 슬롯 가격 라벨 회수(구매마다 갱신)
  _draw_btn = _product(body, UI.ui_icon("card_pack", 72), Config.BUFF_PACK_PRICE, Loc.t("shop_draw"), Palette.MAIN, _on_draw)

  # 보유 버프는 인라인 목록 대신 [버프] 버튼 → 서랍(BuffSheet)에서 확인/판매.

  # [다음날 시작] — 글자 대신 >> 겹화살표. 위치는 플레이 화면 창고 버튼과 동일(우하단),
  # 단 아래 모서리도 위처럼 radius(전 모서리 둥근). v(마진 프레임)가 아니라 self에 직접 앵커.
  var start := Button.new()
  # 우하단 고정(오른쪽 가장자리 앵커 + 픽셀 오프셋) — 앵커% 대신 명시 오프셋으로 정확 배치.
  start.anchor_left = 1.0
  start.anchor_right = 1.0
  start.anchor_top = 1.0
  start.anchor_bottom = 1.0
  start.offset_left = -150   # 버튼 폭 ≈ 134 (원래대로)
  start.offset_right = -16   # 우측 여백 16
  start.offset_top = -76
  start.offset_bottom = -8
  start.add_theme_stylebox_override("normal", _round_style(Palette.MAIN))
  start.add_theme_stylebox_override("hover", _round_style(Palette.MAIN.lightened(0.08)))
  start.add_theme_stylebox_override("pressed", _round_style(Palette.MAIN.darkened(0.1)))
  start.draw.connect(_draw_chevrons.bind(start))   # >> 겹화살표 직접 그림
  start.pressed.connect(func():
    queue_free()
    start_business.emit())
  Audio.attach_click(start)   # 영업 시작 버튼 클릭음
  add_child(start)

  # [버프] — 계속하기(>>) 버튼 왼쪽. 탭하면 보유 버프 서랍. 보유 0개면 비활성(안 열림).
  _buff_btn = Button.new()
  _buff_btn.add_child(UI.ui_btn_icon("buffs", 40))   # 텍스트 대신 버프 덱 손그림
  _buff_btn.anchor_left = 1.0
  _buff_btn.anchor_right = 1.0
  _buff_btn.anchor_top = 1.0
  _buff_btn.anchor_bottom = 1.0
  _buff_btn.offset_left = -252   # 계속하기(좌 -150) 왼쪽에 폭≈90 배치
  _buff_btn.offset_right = -162  # 계속하기와 12 간격
  _buff_btn.offset_top = -76
  _buff_btn.offset_bottom = -8
  _buff_btn.add_theme_stylebox_override("normal", _round_style(Palette.SUB))
  _buff_btn.add_theme_stylebox_override("hover", _round_style(Palette.SUB.lightened(0.08)))
  _buff_btn.add_theme_stylebox_override("pressed", _round_style(Palette.SUB.darkened(0.1)))
  _buff_btn.add_theme_stylebox_override("disabled", _round_style(Palette.COCOA_200))
  _buff_btn.pressed.connect(_toggle_buffs)
  Audio.attach_click(_buff_btn)
  add_child(_buff_btn)

  # 서랍 딤 배경(탭하면 닫기) → 그 위에 서랍. 딤은 버튼들 위에 덮여 서랍 중엔 상점 조작 차단.
  _buff_backdrop = ColorRect.new()
  _buff_backdrop.color = Palette.DIM
  _buff_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _buff_backdrop.visible = false
  _buff_backdrop.gui_input.connect(func(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
      _close_buffs())
  add_child(_buff_backdrop)

  _buff_sheet = BuffSheet.new()
  _buff_sheet.on_sell = _confirm_sell   # 상점: 항목 탭 = 판매
  _buff_sheet.close_requested.connect(_close_buffs)
  add_child(_buff_sheet)

  _refresh()


## 상품 카드 (이름/가격/버튼). 버튼 반환.
func _product(parent: Node, icon: Control, price: int, btn_text: String, btn_color: Color, cb: Callable) -> Button:
  var card := PanelContainer.new()
  card.custom_minimum_size = Vector2(0, 128)   # 카드 높이 2배(내용물은 세로 중앙 정렬)
  card.add_theme_stylebox_override("panel", UI.card(Palette.COCOA_100, Palette.COCOA_200))
  var pad := MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]:
    pad.add_theme_constant_override("margin_" + side, 12)
  card.add_child(pad)
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation", 10)
  row.alignment = BoxContainer.ALIGNMENT_CENTER
  pad.add_child(row)
  icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # 키 큰 카드에서 세로 중앙
  row.add_child(icon)   # 상품 아이콘(글자 제목 대체)
  var gap := Control.new()
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(gap)
  # 가격 — '가격' 글자 없이 코인 아이콘 + 숫자
  var price_row := HBoxContainer.new()
  price_row.add_theme_constant_override("separation", 5)
  price_row.add_child(UI.ui_icon("coin", 18))
  _last_price_label = UI.label(UI.money(price), 15, Palette.COCOA_800, true)
  price_row.add_child(_last_price_label)
  price_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  row.add_child(price_row)
  var btn := Button.new()
  btn.text = btn_text
  btn.custom_minimum_size = Vector2(72, 40)
  btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  btn.add_theme_font_size_override("font_size", 15)
  btn.add_theme_color_override("font_color", Palette.WHITE)
  btn.add_theme_color_override("font_hover_color", Palette.WHITE)
  btn.add_theme_color_override("font_disabled_color", Palette.COCOA_600)   # 비활성(SOLD OUT 등) 글자 대비
  btn.add_theme_stylebox_override("normal", UI.chip(btn_color))
  btn.add_theme_stylebox_override("hover", UI.chip(btn_color.lightened(0.08)))
  btn.add_theme_stylebox_override("pressed", UI.chip(btn_color.darkened(0.1)))
  btn.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_200))
  btn.pressed.connect(cb)
  Audio.attach_click(btn)   # 구매 버튼 클릭음
  row.add_child(btn)
  parent.add_child(card)
  return btn


## 임의 경로 손그림 아이콘 → TextureRect(px×px, 비율유지 중앙). ui/ 밖 자산용(예: buffs_128).
func _art_icon(path: String, px: int) -> TextureRect:
  var tr := TextureRect.new()
  tr.texture = load(path)
  tr.custom_minimum_size = Vector2(px, px)
  tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
  tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
  return tr


## 전(全) 모서리 둥근 틀(창고 핸들은 위만 둥글지만 다음날 버튼은 아래도 둥글게).
func _round_style(c: Color) -> StyleBoxFlat:
  var s := StyleBoxFlat.new()
  s.bg_color = c
  s.set_corner_radius_all(18)
  return s


## 다음날 버튼 위 >> 겹화살표(글자 아님 — 직접 그림). 흰색 두 꺽쇠, 굵은 선 + 둥근 끝.
func _draw_chevrons(btn: Button) -> void:
  var sz := btn.size
  var cx := sz.x - 30.0   # 버튼 중앙이 아니라 오른쪽에 붙여 그림
  var cy := sz.y * 0.5
  var w := 12.0     # 꺽쇠 깊이(가로)
  var h := 15.0     # 꺽쇠 반높이(세로)
  var th := 6.0     # 선 두께
  var spacing := 16.0
  var cap := th * 0.5
  for tip_x in [cx - spacing * 0.5, cx + spacing * 0.5]:
    var top := Vector2(tip_x - w, cy - h)
    var tip := Vector2(tip_x, cy)
    var bot := Vector2(tip_x - w, cy + h)
    btn.draw_polyline(PackedVector2Array([top, tip, bot]), Palette.WHITE, th, true)
    # 세 꼭짓점에 원을 찍어 끝·꺾임을 둥글게(깔끔한 마감)
    for p in [top, tip, bot]:
      btn.draw_circle(p, cap, Palette.WHITE)


## [버프] 토글 — 보유 0개면 무시(버튼도 disabled). 서랍 열림/닫힘.
func _toggle_buffs() -> void:
  if Buffs.owned().is_empty():
    return
  if _buff_sheet.visible:
    _close_buffs()
  else:
    _buff_backdrop.visible = true
    _buff_sheet.open()   # 현재 보유로 재구성 + 슬라이드 업


func _close_buffs() -> void:
  _buff_backdrop.visible = false
  _buff_sheet.slide_close()


func _on_buy_slot() -> void:
  if session.buy_slot():
    Audio.play("coins")   # 슬롯 구매(동전)
    _refresh()


func _on_draw() -> void:
  if _drew:
    return   # 방문당 1회만
  var pack := session.buy_buff_pack()
  if pack.is_empty():
    return
  _drew = true
  _refresh()
  _show_pack(pack)


## 버프 팩 개봉 — 3개 중 1개 택(드래프트), 나머지 버림.
func _show_pack(pack: Array) -> void:
  Audio.play("pack_open")   # 카드팩 개봉 순간
  Audio.vibrate(30)   # 카드팩 개봉 — 만족감 진동
  var overlay := Control.new()
  overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  overlay.mouse_filter = Control.MOUSE_FILTER_STOP
  overlay.z_index = 10
  add_child(overlay)

  # 개봉 중에도 [버프] 버튼/서랍으로 보유 버프를 확인 가능하게 오버레이(z10) 위로 올림.
  # (버프 아이콘이 겹쳐 이름·설명 확인이 필요 → 기존 서랍 재사용)
  # z_index는 '그리기'만 위로 올려주고, '입력'은 트리 순서(나중 형제 우선)라 오버레이 뒤로 재배치해야 클릭이 닿음.
  if not Buffs.owned().is_empty():
    _buff_btn.z_index = 11
    _buff_backdrop.z_index = 12
    _buff_sheet.z_index = 13
    _buff_btn.move_to_front()       # 오버레이보다 뒤 형제 → 입력 우선
    _buff_backdrop.move_to_front()
    _buff_sheet.move_to_front()
    overlay.tree_exited.connect(func():
      _buff_btn.z_index = 0
      _buff_backdrop.z_index = 0
      _buff_sheet.z_index = 0)

  var od := ColorRect.new()
  od.color = Palette.DIM
  od.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  overlay.add_child(od)

  var oc := CenterContainer.new()
  oc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  overlay.add_child(oc)

  var box := VBoxContainer.new()
  box.add_theme_constant_override("separation", 12)
  box.alignment = BoxContainer.ALIGNMENT_CENTER
  oc.add_child(box)
  var t := UI.label(Loc.t("shop_pick3"), 18, Palette.WHITE, true)
  t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  box.add_child(t)

  var col := VBoxContainer.new()   # 세로 배치 — 각 카드가 넓은 폭을 써서 설명 줄바꿈 최소화
  col.add_theme_constant_override("separation", 10)
  col.alignment = BoxContainer.ALIGNMENT_CENTER
  box.add_child(col)
  var choices: Array = []
  var i := 0
  for id in pack:
    var choice := _pack_choice(id, choices, overlay)
    col.add_child(choice)
    choices.append(choice)
    _reveal_choice(choice, i)   # 하나씩 팝하며 개봉
    i += 1


## 개봉 연출 — 카드가 작게/투명하게 시작해 순서대로 튀며 나타남.
func _reveal_choice(card: Control, idx: int) -> void:
  card.scale = Vector2(0.2, 0.2)
  card.modulate.a = 0.0
  await get_tree().process_frame
  if not is_instance_valid(card):
    return
  card.pivot_offset = card.size * 0.5
  var tw := create_tween()
  tw.tween_interval(idx * 0.5)   # 스태거(하나씩 이어서 개봉)
  tw.tween_callback(func(): Audio.play("card_slide"))   # 꺼내지는 순간(등장 시작)
  # 0.2 → 1.3(잠시 크게) → 1.0(원래 크기). 한 카드 ~1초로 천천히.
  tw.tween_property(card, "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tw.parallel().tween_property(card, "modulate:a", 1.0, 0.35)
  tw.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pack_choice(id: String, choices: Array, overlay: Control) -> Control:
  var def := BuffDefs.get_def(id)
  var card := PanelContainer.new()
  card.custom_minimum_size = Vector2(330, 150)   # 세로 배치 — 세 후보 동일 고정폭·높이(카드 목록이 화면 ~60% 차지)
  card.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.MAIN, 2))
  var pad := MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]:
    pad.add_theme_constant_override("margin_" + side, 14)
  card.add_child(pad)
  var h := HBoxContainer.new()   # 아이콘(좌) · 텍스트(중) · 선택버튼(우)
  h.alignment = BoxContainer.ALIGNMENT_CENTER
  h.add_theme_constant_override("separation", 14)
  pad.add_child(h)
  var icon := BuffDefs.icon_node(id, 56)   # 카테고리 아이콘(손그림)
  icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  h.add_child(icon)
  var texts := VBoxContainer.new()
  texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  texts.add_theme_constant_override("separation", 4)
  h.add_child(texts)
  var nm := UI.label(BuffDefs.display_name(id), 16, Palette.COCOA_800, true)
  nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  nm.custom_minimum_size = Vector2.ZERO
  texts.add_child(nm)
  var lb := UI.label(BuffDefs.display_label(id), 13, Palette.MAIN)
  lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  lb.custom_minimum_size = Vector2.ZERO
  texts.add_child(lb)
  var pick := Button.new()
  pick.text = Loc.t("shop_pick")
  pick.add_theme_font_size_override("font_size", 17)
  pick.add_theme_color_override("font_color", Palette.WHITE)
  pick.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
  pick.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
  pick.custom_minimum_size = Vector2(84, 40)   # 눈에 띄되 과하지 않은 선택 버튼 높이
  pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  pick.pressed.connect(func(): _pick_chosen(card, id, choices, overlay))
  Audio.attach_click(pick)   # 뽑기 버튼 클릭음
  h.add_child(pick)
  return card


## 버프 선택 — 나머지 쪼그라들며 사라짐 + 고른 카드는 [버프] 버튼으로 날아가 흡수(수집 피드백).
func _pick_chosen(chosen: Control, id: String, choices: Array, overlay: Control) -> void:
  if overlay.get_meta("picked", false):
    return   # 중복 선택 방지
  overlay.set_meta("picked", true)
  Buffs.add(id)
  Audio.play("card_place")   # 버프 선택 확정(탁)
  # 나머지 후보 — 쪼그라들며 사라짐
  for c in choices:
    if not is_instance_valid(c) or c == chosen:
      continue
    c.pivot_offset = c.size * 0.5
    var tw2 := create_tween()
    tw2.set_parallel(true)
    tw2.tween_property(c, "scale", Vector2(0.5, 0.5), 0.25).set_ease(Tween.EASE_IN)
    tw2.tween_property(c, "modulate:a", 0.0, 0.25)
  # 고른 카드 — [버프] 버튼으로 날아가 흡수
  _fly_card_to_buff_btn(chosen)
  # 딤/힌트 오버레이는 카드 날아가는 동안 페이드아웃 → 버튼이 드러나며 흡수 보임
  if is_instance_valid(overlay):
    var ot := create_tween()
    ot.tween_property(overlay, "modulate:a", 0.0, 0.28).set_delay(0.2)
    ot.tween_callback(overlay.queue_free)
  await get_tree().create_timer(0.6).timeout
  _refresh()


## 고른 버프 카드가 [버프] 버튼으로 날아가 축소·페이드(수집 연출) + 착지 시 버튼 톡 팝.
func _fly_card_to_buff_btn(card: Control) -> void:
  var gpos := card.global_position
  var sz := card.size
  card.pivot_offset = sz * 0.5
  add_child(card)             # 레이아웃 밖으로 옮겨 자유 이동
  card.top_level = true
  card.z_index = 60           # 딤 오버레이(z10) 위에서 보이게
  card.global_position = gpos
  var target := _buff_btn.global_position + _buff_btn.size * 0.5
  var end_pos := target - sz * 0.5   # 피벗(중앙) 기준 카드 중심이 버튼 중심에 오도록
  var tw := create_tween()
  tw.tween_property(card, "scale", Vector2(1.2, 1.2), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.tween_callback(func(): Audio.play("card_slide"))   # 날아가기 시작
  tw.tween_property(card, "global_position", end_pos, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tw.parallel().tween_property(card, "scale", Vector2(0.22, 0.22), 0.42).set_ease(Tween.EASE_IN)
  tw.parallel().tween_property(card, "modulate:a", 0.0, 0.42).set_delay(0.18)
  tw.tween_callback(func():
    _pop_buff_btn()
    if is_instance_valid(card):
      card.queue_free())


## [버프] 버튼 톡 팝(카드 흡수 순간 피드백).
func _pop_buff_btn() -> void:
  if not is_instance_valid(_buff_btn):
    return
  _buff_btn.pivot_offset = _buff_btn.size * 0.5
  var t := create_tween()
  t.tween_property(_buff_btn, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  t.tween_property(_buff_btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)


func _refresh() -> void:
  _cash_label.text = UI.money(session.cash)

  # 슬롯 확장 — 구매마다 가격 급증. 갱신 후 표시. MAX 도달 시 SOLD OUT.
  var slot_price := Config.slot_price(session.day, session.slots - Config.START_SLOTS)
  if _slot_price_label != null:
    _slot_price_label.text = UI.money(slot_price)
  if session.slots >= Config.MAX_SLOTS:
    _buy_slot_btn.text = Loc.t("sold_out")
    _buy_slot_btn.disabled = true
    _buy_slot_btn.modulate = Color.WHITE   # SOLD OUT은 또렷하게(글자 대비 위해 안 흐림)
  else:
    _buy_slot_btn.text = Loc.t("shop_buy")
    var can_slot := session.cash >= slot_price
    _buy_slot_btn.disabled = not can_slot
    _buy_slot_btn.modulate = Color.WHITE if can_slot else Color(1, 1, 1, 0.5)

  # 버프 팩 — 방문당 1회. 뽑았거나 보유 가득이면 SOLD OUT.
  if _drew or Buffs.is_full():
    _draw_btn.text = Loc.t("sold_out")
    _draw_btn.disabled = true
    _draw_btn.modulate = Color.WHITE   # SOLD OUT은 또렷하게
  else:
    _draw_btn.text = Loc.t("shop_draw")
    var can_draw := session.cash >= Config.BUFF_PACK_PRICE
    _draw_btn.disabled = not can_draw
    _draw_btn.modulate = Color.WHITE if can_draw else Color(1, 1, 1, 0.5)

  # [버프] 버튼 — 보유 0개면 비활성(서랍 안 열림).
  if _buff_btn != null:
    _buff_btn.disabled = Buffs.owned().is_empty()
    _buff_btn.modulate.a = 0.45 if _buff_btn.disabled else 1.0   # 아이콘도 비활성 시 흐리게


## 보유 버프 판매 확인 — 버프명 + 환급액(팩값의 30%). [+환급][취소].
func _confirm_sell(id: String) -> void:
  var refund := int(round(Config.BUFF_PACK_PRICE * Config.BUFF_SELL_RATIO))
  Modal.open(self) \
    .title(BuffDefs.display_name(id)) \
    .button("+" + UI.money(refund), func(): _sell(id, refund)) \
    .button(Loc.t("cancel"), func(): pass)


## 판매 확정 — 버프 제거(슬롯 회복) + 환급, 표시 갱신.
func _sell(id: String, refund: int) -> void:
  if not Buffs.remove(id):
    return
  session.add_cash(refund)
  Audio.play("coins")   # 환급(동전)
  _refresh()
  # 서랍 갱신 — 다 팔았으면 닫고, 남았으면 목록 재구성.
  if _buff_sheet.visible:
    if Buffs.owned().is_empty():
      _close_buffs()
    else:
      _buff_sheet.rebuild()
