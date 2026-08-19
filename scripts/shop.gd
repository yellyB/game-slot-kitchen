class_name Shop
extends Control

signal start_business

var session: Session
var _cash_label: Label
var _buy_slot_btn: Button
var _draw_btn: Button
var _buff_btn: Button
var _buff_sheet: BuffSheet
var _buff_backdrop: ColorRect
var _drew := false
var _slot_price_label: Label
var _last_price_label: Label

func _ready() -> void:
  set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  z_index = 300
  mouse_filter = Control.MOUSE_FILTER_STOP

  var bg := ColorRect.new()
  bg.color = Palette.COCOA_50
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  add_child(bg)
  var bg_path := "res://assets/art/bg/shop.png"
  if ResourceLoader.exists(bg_path):
    var bgi := TextureRect.new()
    bgi.texture = load(bg_path)
    bgi.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bgi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    bgi.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bgi)

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

  var header := HBoxContainer.new()
  header.add_theme_constant_override("separation", 8)
  v.add_child(header)
  var gap := Control.new()
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  header.add_child(gap)
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
  cbrow.add_child(UI.ui_icon("coin", 22))
  _cash_label = UI.label("0", 22, Palette.COCOA_800, true)
  cbrow.add_child(_cash_label)
  header.add_child(cash_box)

  var scroll := ScrollContainer.new()
  scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  v.add_child(scroll)

  var body := VBoxContainer.new()
  body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  body.add_theme_constant_override("separation", 12)
  scroll.add_child(body)

  var slot_price := Config.slot_price(session.day, session.slots - Config.START_SLOTS)
  _buy_slot_btn = _product(body, UI.ui_icon("slot_expand", 72), slot_price, Loc.t("shop_buy"), Palette.SUB, _on_buy_slot)
  _slot_price_label = _last_price_label
  _draw_btn = _product(body, UI.ui_icon("card_pack", 72), Config.shop_price(Config.BUFF_PACK_PRICE, session.day), Loc.t("shop_draw"), Palette.MAIN, _on_draw)


  var start := Button.new()
  start.anchor_left = 1.0
  start.anchor_right = 1.0
  start.anchor_top = 1.0
  start.anchor_bottom = 1.0
  start.offset_left = -150
  start.offset_right = -16
  start.offset_top = -76
  start.offset_bottom = -8
  start.add_theme_stylebox_override("normal", _round_style(Palette.MAIN))
  start.add_theme_stylebox_override("hover", _round_style(Palette.MAIN.lightened(0.08)))
  start.add_theme_stylebox_override("pressed", _round_style(Palette.MAIN.darkened(0.1)))
  start.draw.connect(_draw_chevrons.bind(start))
  start.pressed.connect(func():
    queue_free()
    start_business.emit())
  Audio.attach_click(start)
  add_child(start)

  _buff_btn = Button.new()
  _buff_btn.add_child(UI.ui_btn_icon("buffs", 40))
  _buff_btn.anchor_left = 1.0
  _buff_btn.anchor_right = 1.0
  _buff_btn.anchor_top = 1.0
  _buff_btn.anchor_bottom = 1.0
  _buff_btn.offset_left = -252
  _buff_btn.offset_right = -162
  _buff_btn.offset_top = -76
  _buff_btn.offset_bottom = -8
  _buff_btn.add_theme_stylebox_override("normal", _round_style(Palette.SUB))
  _buff_btn.add_theme_stylebox_override("hover", _round_style(Palette.SUB.lightened(0.08)))
  _buff_btn.add_theme_stylebox_override("pressed", _round_style(Palette.SUB.darkened(0.1)))
  _buff_btn.add_theme_stylebox_override("disabled", _round_style(Palette.COCOA_200))
  _buff_btn.pressed.connect(_toggle_buffs)
  Audio.attach_click(_buff_btn)
  add_child(_buff_btn)

  _buff_backdrop = ColorRect.new()
  _buff_backdrop.color = Palette.DIM
  _buff_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _buff_backdrop.visible = false
  _buff_backdrop.gui_input.connect(func(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
      _close_buffs())
  add_child(_buff_backdrop)

  _buff_sheet = BuffSheet.new()
  _buff_sheet.on_sell = _confirm_sell
  _buff_sheet.close_requested.connect(_close_buffs)
  add_child(_buff_sheet)

  _refresh()


func _product(parent: Node, icon: Control, price: int, btn_text: String, btn_color: Color, cb: Callable) -> Button:
  var card := PanelContainer.new()
  card.custom_minimum_size = Vector2(0, 128)
  card.add_theme_stylebox_override("panel", UI.card(Palette.COCOA_100, Palette.COCOA_200))
  var pad := MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]:
    pad.add_theme_constant_override("margin_" + side, 12)
  card.add_child(pad)
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation", 10)
  row.alignment = BoxContainer.ALIGNMENT_CENTER
  pad.add_child(row)
  icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  row.add_child(icon)
  var gap := Control.new()
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(gap)
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
  btn.add_theme_color_override("font_disabled_color", Palette.COCOA_600)
  btn.add_theme_stylebox_override("normal", UI.chip(btn_color))
  btn.add_theme_stylebox_override("hover", UI.chip(btn_color.lightened(0.08)))
  btn.add_theme_stylebox_override("pressed", UI.chip(btn_color.darkened(0.1)))
  btn.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_200))
  btn.pressed.connect(cb)
  Audio.attach_click(btn)
  row.add_child(btn)
  parent.add_child(card)
  return btn


func _art_icon(path: String, px: int) -> TextureRect:
  var tr := TextureRect.new()
  tr.texture = load(path)
  tr.custom_minimum_size = Vector2(px, px)
  tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
  tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
  return tr


func _round_style(c: Color) -> StyleBoxFlat:
  var s := StyleBoxFlat.new()
  s.bg_color = c
  s.set_corner_radius_all(18)
  return s


func _draw_chevrons(btn: Button) -> void:
  var sz := btn.size
  var cx := sz.x - 30.0
  var cy := sz.y * 0.5
  var w := 12.0
  var h := 15.0
  var th := 6.0
  var spacing := 16.0
  var cap := th * 0.5
  for tip_x in [cx - spacing * 0.5, cx + spacing * 0.5]:
    var top := Vector2(tip_x - w, cy - h)
    var tip := Vector2(tip_x, cy)
    var bot := Vector2(tip_x - w, cy + h)
    btn.draw_polyline(PackedVector2Array([top, tip, bot]), Palette.WHITE, th, true)
    for p in [top, tip, bot]:
      btn.draw_circle(p, cap, Palette.WHITE)


func _toggle_buffs() -> void:
  if Buffs.owned().is_empty():
    return
  if _buff_sheet.visible:
    _close_buffs()
  else:
    _buff_backdrop.visible = true
    _buff_sheet.open()


func _close_buffs() -> void:
  _buff_backdrop.visible = false
  _buff_sheet.slide_close()


func _on_buy_slot() -> void:
  if session.buy_slot():
    Audio.play("coins")
    _refresh()


func _on_draw() -> void:
  if _drew:
    return
  var pack := session.buy_buff_pack()
  if pack.is_empty():
    return
  _drew = true
  _refresh()
  _show_pack(pack)


func _show_pack(pack: Array) -> void:
  Audio.play("pack_open")
  Audio.vibrate(30)
  var overlay := Control.new()
  overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  overlay.mouse_filter = Control.MOUSE_FILTER_STOP
  overlay.z_index = 10
  add_child(overlay)

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

  var col := VBoxContainer.new()
  col.add_theme_constant_override("separation", 10)
  col.alignment = BoxContainer.ALIGNMENT_CENTER
  box.add_child(col)
  var choices: Array = []
  var i := 0
  for id in pack:
    var choice := _pack_choice(id, choices, overlay)
    col.add_child(choice)
    choices.append(choice)
    _reveal_choice(choice, i)
    i += 1


func _reveal_choice(card: Control, idx: int) -> void:
  card.scale = Vector2(0.2, 0.2)
  card.modulate.a = 0.0
  await get_tree().process_frame
  if not is_instance_valid(card):
    return
  card.pivot_offset = card.size * 0.5
  var tw := create_tween()
  tw.tween_interval(idx * 0.5)
  tw.tween_callback(func(): Audio.play("card_slide"))
  tw.tween_property(card, "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  tw.parallel().tween_property(card, "modulate:a", 1.0, 0.35)
  tw.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pack_choice(id: String, choices: Array, overlay: Control) -> Control:
  var def := BuffDefs.get_def(id)
  var card := PanelContainer.new()
  card.custom_minimum_size = Vector2(330, 150)
  card.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.MAIN, 2))
  var pad := MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]:
    pad.add_theme_constant_override("margin_" + side, 14)
  card.add_child(pad)
  var h := HBoxContainer.new()
  h.alignment = BoxContainer.ALIGNMENT_CENTER
  h.add_theme_constant_override("separation", 14)
  pad.add_child(h)
  var icon := BuffDefs.icon_node(id, 56)
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
  pick.custom_minimum_size = Vector2(84, 40)
  pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  pick.pressed.connect(func(): _pick_chosen(card, id, choices, overlay))
  Audio.attach_click(pick)
  h.add_child(pick)
  return card


func _pick_chosen(chosen: Control, id: String, choices: Array, overlay: Control) -> void:
  if overlay.get_meta("picked", false):
    return
  overlay.set_meta("picked", true)
  Buffs.add(id)
  Audio.play("card_place")
  for c in choices:
    if not is_instance_valid(c) or c == chosen:
      continue
    c.pivot_offset = c.size * 0.5
    var tw2 := create_tween()
    tw2.set_parallel(true)
    tw2.tween_property(c, "scale", Vector2(0.5, 0.5), 0.25).set_ease(Tween.EASE_IN)
    tw2.tween_property(c, "modulate:a", 0.0, 0.25)
  _fly_card_to_buff_btn(chosen)
  if is_instance_valid(overlay):
    var ot := create_tween()
    ot.tween_property(overlay, "modulate:a", 0.0, 0.28).set_delay(0.2)
    ot.tween_callback(overlay.queue_free)
  await get_tree().create_timer(0.6).timeout
  _refresh()


func _fly_card_to_buff_btn(card: Control) -> void:
  var gpos := card.global_position
  var sz := card.size
  card.pivot_offset = sz * 0.5
  add_child(card)
  card.top_level = true
  card.z_index = 60
  card.global_position = gpos
  var target := _buff_btn.global_position + _buff_btn.size * 0.5
  var end_pos := target - sz * 0.5
  var tw := create_tween()
  tw.tween_property(card, "scale", Vector2(1.2, 1.2), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.tween_callback(func(): Audio.play("card_slide"))
  tw.tween_property(card, "global_position", end_pos, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
  tw.parallel().tween_property(card, "scale", Vector2(0.22, 0.22), 0.42).set_ease(Tween.EASE_IN)
  tw.parallel().tween_property(card, "modulate:a", 0.0, 0.42).set_delay(0.18)
  tw.tween_callback(func():
    _pop_buff_btn()
    if is_instance_valid(card):
      card.queue_free())


func _pop_buff_btn() -> void:
  if not is_instance_valid(_buff_btn):
    return
  _buff_btn.pivot_offset = _buff_btn.size * 0.5
  var t := create_tween()
  t.tween_property(_buff_btn, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  t.tween_property(_buff_btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)


func _refresh() -> void:
  _cash_label.text = UI.money(session.cash)

  var slot_price := Config.slot_price(session.day, session.slots - Config.START_SLOTS)
  if _slot_price_label != null:
    _slot_price_label.text = UI.money(slot_price)
  if session.slots >= Config.MAX_SLOTS:
    _buy_slot_btn.text = Loc.t("sold_out")
    _buy_slot_btn.disabled = true
    _buy_slot_btn.modulate = Color.WHITE
  else:
    _buy_slot_btn.text = Loc.t("shop_buy")
    var can_slot := session.cash >= slot_price
    _buy_slot_btn.disabled = not can_slot
    _buy_slot_btn.modulate = Color.WHITE if can_slot else Color(1, 1, 1, 0.5)

  if _drew or Buffs.is_full():
    _draw_btn.text = Loc.t("sold_out")
    _draw_btn.disabled = true
    _draw_btn.modulate = Color.WHITE
  else:
    _draw_btn.text = Loc.t("shop_draw")
    var can_draw := session.cash >= Config.shop_price(Config.BUFF_PACK_PRICE, session.day)
    _draw_btn.disabled = not can_draw
    _draw_btn.modulate = Color.WHITE if can_draw else Color(1, 1, 1, 0.5)

  if _buff_btn != null:
    _buff_btn.disabled = Buffs.owned().is_empty()
    _buff_btn.modulate.a = 0.45 if _buff_btn.disabled else 1.0


func _confirm_sell(id: String) -> void:
  var refund := int(round(Config.shop_price(Config.BUFF_PACK_PRICE, session.day) * Config.BUFF_SELL_RATIO))
  Modal.open(self) \
    .title(BuffDefs.display_name(id)) \
    .button("+" + UI.money(refund), func(): _sell(id, refund)) \
    .button(Loc.t("cancel"), func(): pass)


func _sell(id: String, refund: int) -> void:
  if not Buffs.remove(id):
    return
  session.add_cash(refund)
  Audio.play("coins")
  _refresh()
  if _buff_sheet.visible:
    if Buffs.owned().is_empty():
      _close_buffs()
    else:
      _buff_sheet.rebuild()
