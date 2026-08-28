class_name Shop
extends Control
## 인터세션 상점 — 보유 돈 + 슬롯 확장 + 버프 팩(카드깡) + 보유 버프 + [영업 시작].
## 딤 배경 + 입력 차단. 대강 구현(디자인 후 정리).

signal start_business
signal go_home   # 상단바 홈 버튼 → main이 확인창(진행 판 포기) 처리

var session: Session  # main이 add_child 전에 주입
var _cash_label: Label
var _buff_btn: Button            # 보유 버프 서랍 여는 버튼(계속하기 왼쪽). 보유 0개면 비활성.
var _buff_sheet: BuffSheet       # 보유 버프 리스트 서랍(바텀시트)
var _buff_backdrop: ColorRect    # 서랍 열림 시 딤 + 바깥 탭 닫기
# 상점 물품 3칸 — 슬롯쿠폰(1회용) + 버프팩. 각 칸이 독립 상태(done)를 가짐(방문당 팩 여러 개 개봉 가능).
var _products: Array = []   # 항목: {kind:"coupon"|"pack", card, btn, price_label, done}
var _reroll := 0     # 이번 개봉에서 리롤한 횟수(비용 ×2 계산용). 팩 개봉마다 0으로 리셋.
var _last_price_label: Label   # _product가 방금 만든 가격 라벨(호출 직후 회수용)
var _last_card: PanelContainer # _product가 방금 만든 카드(호출 직후 회수용)
var _shake_tws := {}   # 후보 카드별 진행 중 흔들림 트윈(반복 클릭 시 드리프트 방지)

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

  # 상단바 — 게임 화면과 완전히 동일한 공용 컴포넌트(UI.top_bar)를 그대로 사용.
  var nx := Levels.get_week(session.day + 1)   # 다음(곧 진입할) 주
  var bar := UI.top_bar()
  v.add_child(bar)
  (bar.get_meta("day_num") as Label).text = str(session.day + 1)
  _cash_label = bar.get_meta("money_label") as Label
  var slabel := bar.get_meta("score_label") as Label
  var target := int(nx["monthly_rent"])
  slabel.text = "%s/%s" % [UI.money(session.month_score), UI.money(target)]
  slabel.add_theme_color_override("font_color", Palette.DANGER if nx["is_month_end"] else Palette.COCOA_800)
  var home := bar.get_meta("home_btn") as Button
  home.pressed.connect(func(): go_home.emit())
  Audio.attach_click(home)

  # 본문(스크롤) — 상품·보유버프. 콘텐츠 늘어나도 스크롤로 흡수(상점은 날짜마다 성장).
  var scroll := ScrollContainer.new()
  scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  v.add_child(scroll)

  var body := VBoxContainer.new()
  body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  body.add_theme_constant_override("separation", 12)
  scroll.add_child(body)

  # 상품 3칸 — 슬롯확장권(1회용 쿠폰) + 버프팩(카드깡). 확장 여지만큼 쿠폰 배치(최대 2),
  # 나머지는 버프팩. 슬롯 만렙이면 쿠폰 0 → 버프팩 3개.
  var coupon_n := clampi(Config.MAX_SLOTS - session.slots, 0, 2)
  for _i in coupon_n:
    _add_slot_coupon(body)
  for _i in (3 - coupon_n):
    _add_buff_pack(body)

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
  _last_card = card
  parent.add_child(card)
  return btn


## 슬롯확장권 카드 1칸 — 탭하면 슬롯 +1(escalating 가격), 그 칸은 SOLD OUT(1회용).
func _add_slot_coupon(parent: Node) -> void:
  var st := {"kind": "coupon", "done": false}
  var price := Config.slot_price(session.day, session.slots - Config.START_SLOTS)
  st["btn"] = _product(parent, UI.ui_icon("slot_expand", 72), price, Loc.t("shop_buy"), Palette.SUB, func(): _on_buy_coupon(st))
  st["card"] = _last_card
  st["price_label"] = _last_price_label
  _products.append(st)


## 버프팩 카드 1칸 — 탭하면 3장 개봉(택1), 그 칸은 SOLD OUT.
func _add_buff_pack(parent: Node) -> void:
  var st := {"kind": "pack", "done": false}
  st["btn"] = _product(parent, UI.ui_icon("card_pack", 72), Config.BUFF_PACK_PRICE, Loc.t("shop_draw"), Palette.MAIN, func(): _on_draw_pack(st))
  st["card"] = _last_card
  st["price_label"] = _last_price_label
  _products.append(st)


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


func _on_buy_coupon(st: Dictionary) -> void:
  if st["done"]:
    return
  if session.buy_slot():
    st["done"] = true   # 쿠폰 1회용 — 소진
    Audio.play("coins")   # 슬롯 구매(동전)
    _refresh()


func _on_draw_pack(st: Dictionary) -> void:
  if st["done"]:
    return   # 그 칸은 이미 개봉함
  var pack := session.buy_buff_pack()
  if pack.is_empty():
    return
  st["done"] = true
  _reroll = 0   # 새 개봉 — 리롤 비용 초기화
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
    # z 복원은 픽 완료(_pick_chosen)에서 — 리롤은 오버레이를 재생성하므로 여기서 복원하면 안 됨.

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

  # 가득 찬 채로 카드깡 → 개봉 즉시 상단 안내(선택하려면 서랍에서 버프를 팔아 자리 확보).
  # 딤 배경과 겹쳐 안 보이던 문제 → 꽉 찬 DANGER 알약 배경 + 흰 글씨로 대비 확보.
  if Buffs.is_full():
    var warnbox := PanelContainer.new()
    warnbox.add_theme_stylebox_override("panel", UI.chip(Palette.DANGER))
    var wp := MarginContainer.new()
    for side in ["left", "right"]:
      wp.add_theme_constant_override("margin_" + side, 16)
    for side in ["top", "bottom"]:
      wp.add_theme_constant_override("margin_" + side, 9)
    warnbox.add_child(wp)
    var warn := UI.label(Loc.t("shop_full_notice"), 15, Palette.WHITE, true)
    warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    warn.custom_minimum_size = Vector2(320, 0)
    wp.add_child(warn)
    box.add_child(warnbox)

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

  # 가득 찬 채로 개봉 — 리롤 위에 [되팔기 +환급] 하나. 아무것도 안 받고 환급받고 종료.
  if Buffs.is_full():
    var refund := int(round(Config.BUFF_PACK_PRICE * Config.BUFF_SELL_RATIO))
    var sell := Button.new()
    sell.add_theme_font_size_override("font_size", 16)
    sell.add_theme_color_override("font_color", Palette.WHITE)
    sell.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_400))
    sell.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_400.lightened(0.08)))
    sell.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_400.darkened(0.1)))
    sell.custom_minimum_size = Vector2(160, 40)
    sell.text = Loc.t("shop_sell") + "  +" + UI.money(refund)
    sell.pressed.connect(func(): _sell_drawn(overlay))
    Audio.attach_click(sell)
    box.add_child(sell)

  # 리롤 — 돈 내고 3장 다시 뽑기(리롤마다 ×2). 못 사면 흐리게 비활성.
  var cost := Config.BUFF_REROLL_BASE * int(pow(2, _reroll))
  var can := session.cash >= cost
  var reroll := Button.new()
  reroll.add_theme_font_size_override("font_size", 16)
  reroll.add_theme_color_override("font_color", Palette.WHITE)
  reroll.add_theme_stylebox_override("normal", UI.chip(Palette.SUB))
  reroll.add_theme_stylebox_override("hover", UI.chip(Palette.SUB.lightened(0.08)))
  reroll.add_theme_stylebox_override("pressed", UI.chip(Palette.SUB.darkened(0.1)))
  reroll.add_theme_stylebox_override("disabled", UI.chip(Palette.SUB))
  reroll.custom_minimum_size = Vector2(160, 40)
  reroll.text = "🔄  " + UI.money(cost)
  reroll.disabled = not can
  reroll.modulate = Color.WHITE if can else Color(1, 1, 1, 0.5)
  reroll.pressed.connect(func(): _do_reroll(cost, overlay))
  Audio.attach_click(reroll)
  box.add_child(reroll)


## 리롤 — 비용 차감 후 현재 개봉을 닫고 새 3장으로 다시 개봉(리롤 횟수·비용↑).
func _do_reroll(cost: int, overlay: Control) -> void:
  if session.cash < cost:
    return
  var newpack := BuffDefs.random_pack(3)
  if newpack.is_empty():
    return   # 뽑을 후보 없음(전부 보유 등) — 리롤 취소
  session.add_cash(-cost)
  Audio.play("coins")
  _reroll += 1
  if is_instance_valid(overlay):
    overlay.queue_free()
  _refresh()
  _show_pack(newpack)


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
  pick.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
  pick.custom_minimum_size = Vector2(84, 40)   # 눈에 띄되 과하지 않은 선택 버튼 높이
  pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  pick.pressed.connect(func(): _try_pick(card, id, choices, overlay))
  Audio.attach_click(pick)   # 뽑기 버튼 클릭음
  h.add_child(pick)
  return card


## 선택 시도 — 자리 없으면 후보 3장 좌우 흔들림(거절) + 순한 거절음. 있으면 확정.
func _try_pick(chosen: Control, id: String, choices: Array, overlay: Control) -> void:
  if overlay.get_meta("picked", false):
    return
  if Buffs.is_full():
    _shake_choices(choices)
    Audio.play("disabled")
    return
  _pick_chosen(chosen, id, choices, overlay)


## [팔기] — 뽑은 카드를 보유하지 않고 바로 환급(팩값 30%)받고 개봉 종료.
func _sell_drawn(overlay: Control) -> void:
  if overlay.get_meta("picked", false):
    return
  overlay.set_meta("picked", true)
  _buff_btn.z_index = 0
  _buff_backdrop.z_index = 0
  _buff_sheet.z_index = 0
  session.add_cash(int(round(Config.BUFF_PACK_PRICE * Config.BUFF_SELL_RATIO)))
  Audio.play("coins")
  if is_instance_valid(overlay):
    var ot := create_tween()
    ot.tween_property(overlay, "modulate:a", 0.0, 0.28)
    ot.tween_callback(overlay.queue_free)
  await get_tree().create_timer(0.4).timeout
  _refresh()


## 거절 흔들림 — board.shake_slots와 동일(좌우 5px 2회 왕복). 반복 클릭 시 이전 트윈 정리로 드리프트 방지.
func _shake_choices(choices: Array) -> void:
  for c in choices:
    if is_instance_valid(c):
      _shake_card(c)

func _shake_card(n: Control) -> void:
  if _shake_tws.has(n) and _shake_tws[n] != null and (_shake_tws[n] as Tween).is_valid():
    (_shake_tws[n] as Tween).kill()
    n.position.x = n.get_meta("shake_base_x", n.position.x)
  else:
    n.set_meta("shake_base_x", n.position.x)
  var base: float = n.get_meta("shake_base_x")
  n.position.x = base
  var a := 5.0
  var t := n.create_tween()
  _shake_tws[n] = t
  t.tween_property(n, "position:x", base - a, 0.05).set_trans(Tween.TRANS_SINE)
  t.tween_property(n, "position:x", base + a, 0.07).set_trans(Tween.TRANS_SINE)
  t.tween_property(n, "position:x", base - a, 0.07).set_trans(Tween.TRANS_SINE)
  t.tween_property(n, "position:x", base + a, 0.07).set_trans(Tween.TRANS_SINE)
  t.tween_property(n, "position:x", base, 0.05).set_trans(Tween.TRANS_SINE)


## 버프 선택 — 나머지 쪼그라들며 사라짐 + 고른 카드는 [버프] 버튼으로 날아가 흡수(수집 피드백).
func _pick_chosen(chosen: Control, id: String, choices: Array, overlay: Control) -> void:
  if overlay.get_meta("picked", false):
    return   # 중복 선택 방지
  overlay.set_meta("picked", true)
  _buff_btn.z_index = 0       # 개봉 중 올렸던 z 복원(픽으로 개봉 종료)
  _buff_backdrop.z_index = 0
  _buff_sheet.z_index = 0
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

  # 상품 3칸 — 슬롯쿠폰/버프팩 각 칸 상태 갱신.
  var slot_price := Config.slot_price(session.day, session.slots - Config.START_SLOTS)
  for st in _products:
    var btn: Button = st["btn"]
    var sold := false
    if st["kind"] == "coupon":
      # 쿠폰 가격은 구매 수에 따라 급증 — 옆 칸을 사면 다음 칸 값도 갱신.
      (st["price_label"] as Label).text = UI.money(slot_price)
      if st["done"] or session.slots >= Config.MAX_SLOTS:
        sold = true
        btn.text = Loc.t("sold_out")
        btn.disabled = true
        btn.modulate = Color.WHITE
      else:
        btn.text = Loc.t("shop_buy")
        var can_slot := session.cash >= slot_price
        btn.disabled = not can_slot
        btn.modulate = Color.WHITE if can_slot else Color(1, 1, 1, 0.5)
    else:
      # 버프팩 — 그 칸을 이미 개봉했으면 SOLD OUT(가득 차도 개봉은 허용 — 선택 시 판매 요구).
      if st["done"]:
        sold = true
        btn.text = Loc.t("sold_out")
        btn.disabled = true
        btn.modulate = Color.WHITE
      else:
        btn.text = Loc.t("shop_draw")
        var can_draw := session.cash >= Config.BUFF_PACK_PRICE
        btn.disabled = not can_draw
        btn.modulate = Color.WHITE if can_draw else Color(1, 1, 1, 0.5)
    _set_card_sold(st["card"] as PanelContainer, sold)

  # [버프] 버튼 — 보유 0개면 비활성(서랍 안 열림).
  if _buff_btn != null:
    _buff_btn.disabled = Buffs.owned().is_empty()
    _buff_btn.modulate.a = 0.45 if _buff_btn.disabled else 1.0   # 아이콘도 비활성 시 흐리게


## 품절(구매·개봉 완료) 칸 — 불투명한 회색(disabled) 배경으로 "소진" 표시. 되돌리면 원래 크림 카드.
## (투명도 X — 알파 낮추면 뒤 배경이 비쳐 보임. 배경색만 disabled 톤으로 교체)
func _set_card_sold(card: PanelContainer, sold: bool) -> void:
  if sold:
    card.add_theme_stylebox_override("panel", UI.card(Palette.COCOA_200, Palette.COCOA_200))
  else:
    card.add_theme_stylebox_override("panel", UI.card(Palette.COCOA_100, Palette.COCOA_200))
  card.modulate = Color.WHITE


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
