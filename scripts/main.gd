extends Control

var _board: Board
var _warehouse: Warehouse
var _cooking: Cooking
var _backdrop: ColorRect
var _session: Session
var _title: TitleScreen

var _warehouse_btn: Button
var _trash_btn: TrashButton
var _buff_sheet: BuffSheet
var _buff_btn: Button
var _tutorial: Tutorial
var _tutorial_active := false

var _queue_row: HBoxContainer

var _visited_today := 0
var _accepted_today := 0
var _served_today := 0
var _order_lost_today := 0
var _served_by_menu := {}

var _day_num: Label
var _money_label: Label
var _debug_bar: Control
var _cash_clicks := 0
var _last_cash_click := 0
var _rent_label: Label
var _last_cash := 0
var _expect_fly := false
var _hours_bar: ProgressBar
var _hours_glow: Tween
var _celebrating := false
var _hours_warning := false
var _blackout: ColorRect
var _countdown_edge: Panel
var _last_countdown := 0
const COUNTDOWN_FROM := 5


func _ready() -> void:
  var bg := TextureRect.new()
  bg.texture = load("res://assets/art/bg/play_bg.jpg")
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  bg.offset_left = -40
  bg.offset_top = -40
  bg.offset_right = 40
  bg.offset_bottom = 40
  bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  bg.mouse_filter = Control.MOUSE_FILTER_STOP
  bg.gui_input.connect(_on_background_input)
  add_child(bg)

  var margin := MarginContainer.new()
  margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
  for side in ["left", "right", "top", "bottom"]:
    margin.add_theme_constant_override("margin_" + side, 12)
  add_child(margin)

  var col := VBoxContainer.new()
  col.mouse_filter = Control.MOUSE_FILTER_IGNORE
  col.add_theme_constant_override("separation", 10)
  margin.add_child(col)

  col.add_child(_build_top_bar())
  if OS.is_debug_build():
    _debug_bar = _build_debug()
    _debug_bar.visible = OS.has_feature("editor")
    col.add_child(_debug_bar)
  col.add_child(_build_customer_queue())

  _board = Board.new()
  _board.tool_tapped.connect(_on_tool_tapped)
  _board.size_flags_vertical = Control.SIZE_EXPAND_FILL
  col.add_child(_board)

  col.add_child(_build_bottom_buttons())
  add_child(_build_warehouse_handle())

  _backdrop = ColorRect.new()
  _backdrop.color = Color(0.164, 0.129, 0.106, 0.28)
  _backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _backdrop.visible = false
  _backdrop.gui_input.connect(_on_backdrop_input)
  add_child(_backdrop)

  _warehouse = Warehouse.new()
  _warehouse.close_requested.connect(_close_sheets)
  add_child(_warehouse)
  _cooking = Cooking.new()
  _cooking.board = _board
  _cooking.close_requested.connect(_close_sheets)
  _cooking.cooked.connect(_on_cooked)
  add_child(_cooking)
  _buff_sheet = BuffSheet.new()
  _buff_sheet.close_requested.connect(_close_sheets)
  add_child(_buff_sheet)

  Move.performed.connect(_refresh_warehouse)
  Move.default_target = func(_payload): return _board.first_empty_slot()

  _session = Session.new()
  _session.cash_changed.connect(_on_cash_changed)
  _session.progress.connect(_on_progress)
  _session.spawn_requested.connect(_spawn_customer)
  _session.day_started.connect(_on_day_started)
  _session.day_closing.connect(_on_day_closing)
  _session.day_ended.connect(_on_day_ended)
  add_child(_session)

  _board.now_provider = _session.now

  _title = TitleScreen.new()
  _title.start_pressed.connect(_start_game)
  _title.tutorial_pressed.connect(_start_tutorial)
  add_child(_title)

  if OS.is_debug_build() and "--test" in OS.get_cmdline_user_args():
    await TestHarness.new().run(self)

  if "--shotdone" in OS.get_cmdline_user_args():
    _start_game()
    for _i in 6:
      await get_tree().process_frame
    _board.tools[0].produce_instant(Stats.random_recipe())
    for _i in 6:
      await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png("/tmp/done.png")
    get_tree().quit()

  if "--sim" in OS.get_cmdline_user_args():
    var batch := SimBatch.new()
    var n := 200
    print("\n[SIM] ===== 생존 시뮬 (판당 5일, %d회, 상점 ON) =====" % n)
    var s := batch.run(n, [], true)
    print("[SIM] 승률 %.1f%%  최종현금 %.0f  서빙 %.1f  놓침 %.1f  슬롯 %.1f  버프 %.1f  일수 %.1f" % [
      s["win_rate"] * 100.0, s["avg_cash"], s["avg_served"], s["avg_lost"],
      s["avg_slots"], s["avg_buffs"], s["avg_days"]])
    get_tree().quit()

  if "--simbuffs" in OS.get_cmdline_user_args():
    var bn := int(OS.get_environment("SIM_N")) if OS.has_environment("SIM_N") else 40
    SimBatch.new().buff_report(bn)
    get_tree().quit()


func _on_home_pressed() -> void:
  _set_world_paused(true)
  var m := Modal.open(self) \
    .title(Loc.t("home_title")) \
    .row(Loc.t("home_warn"), Palette.COCOA_600) \
    .button(Loc.t("go_home"), _go_home) \
    .button(Loc.t("cancel"), func(): pass)
  m.tree_exited.connect(func():
    if is_instance_valid(self) and not _title.visible:
      _set_world_paused(false))


func _go_home() -> void:
  _session.set_process(false)
  _warehouse.visible = false
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = false
  _clear_blackout()
  for s in _board.slots:
    s.clear()
  for t in _board.tools:
    t.reset()
  for c in _queue_row.get_children():
    c.queue_free()
  for ch in get_children():
    if ch is Shop or ch is Modal:
      ch.queue_free()
  _show_title()


func _start_game() -> void:
  _celebrating = false
  _clear_confetti()
  _last_cash = 0
  _money_label.text = UI.money(0)
  _title.hide()
  _session.start_run()


func _show_title() -> void:
  _celebrating = false
  _clear_confetti()
  _clear_blackout()
  _title.show()


func _clear_confetti() -> void:
  for p in get_tree().get_nodes_in_group("confetti"):
    p.queue_free()


func _start_tutorial(after := "title") -> void:
  _title.hide()
  _enter_tutorial_state()
  _tutorial = Tutorial.new()
  _tutorial.board = _board
  _tutorial.queue_row = _queue_row
  _tutorial.warehouse = _warehouse
  _tutorial.cooking = _cooking
  _tutorial.warehouse_btn = _warehouse_btn
  _tutorial.spawn_customer = _spawn_customer.bind(Tutorial.RECIPE)
  _tutorial.finished.connect(func():
    if is_instance_valid(_tutorial):
      _tutorial.queue_free()
    _tutorial = null
    _exit_tutorial_state()
    if after == "game":
      _start_game()
    else:
      _show_title())
  add_child(_tutorial)


func _enter_tutorial_state() -> void:
  _tutorial_active = true
  Buffs.clear()
  _session.set_process(false)
  _clear_blackout()
  _day_num.text = "1"
  _money_label.text = UI.money(0)
  for s in _board.slots:
    s.clear()
  for t in _board.tools:
    t.reset()
  for c in _queue_row.get_children():
    c.queue_free()
  _board.rebuild(4)
  _warehouse.visible = false
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = false
  _refresh_warehouse()


func _exit_tutorial_state() -> void:
  _tutorial_active = false
  Move.clear()
  for s in _board.slots:
    s.clear()
  for t in _board.tools:
    t.reset()
  for c in _queue_row.get_children():
    c.queue_free()
  _warehouse.visible = false
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = false


func _build_top_bar() -> Control:
  var panel := PanelContainer.new()
  panel.add_theme_stylebox_override("panel", UI.card(Palette.WHITE))

  var pad := MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]:
    pad.add_theme_constant_override("margin_" + side, 12)
  panel.add_child(pad)

  var box := VBoxContainer.new()
  box.add_theme_constant_override("separation", 8)
  pad.add_child(box)

  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation", 10)
  box.add_child(row)

  var home := Button.new()
  home.custom_minimum_size = Vector2(34, 34)
  home.add_child(UI.ui_btn_icon("house", 22))
  home.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
  home.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
  home.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
  home.pressed.connect(_on_home_pressed)
  Audio.attach_click(home)

  var day_badge := UI.day_badge(32)
  _day_num = day_badge.get_meta("num") as Label
  row.add_child(day_badge)
  row.add_child(home)

  var gap := Control.new()
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(gap)

  var coin := HBoxContainer.new()
  coin.add_theme_constant_override("separation", 4)
  coin.mouse_filter = Control.MOUSE_FILTER_STOP
  coin.gui_input.connect(_on_cash_clicked)
  coin.add_child(UI.ui_icon("coin", 20))
  _money_label = UI.label("0", 18, Palette.COCOA_800, true)
  coin.add_child(_money_label)
  row.add_child(coin)

  var rentbox := HBoxContainer.new()
  rentbox.add_theme_constant_override("separation", 4)
  rentbox.add_child(UI.ui_icon("bill", 20))
  _rent_label = UI.label("0", 18, Palette.COCOA_800, true)
  rentbox.add_child(_rent_label)
  row.add_child(rentbox)

  var hours := HBoxContainer.new()
  hours.add_theme_constant_override("separation", 8)
  box.add_child(hours)

  hours.add_child(UI.ui_icon("sun", 18))

  _hours_bar = ProgressBar.new()
  _hours_bar.min_value = 0
  _hours_bar.max_value = 100
  _hours_bar.value = 0
  _hours_bar.show_percentage = false
  _hours_bar.custom_minimum_size = Vector2(0, 14)
  _hours_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  _hours_bar.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
  _hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.ACCENT))
  hours.add_child(_hours_bar)

  hours.add_child(UI.ui_icon("moon", 18))

  return panel


func _on_cash_clicked(event: InputEvent) -> void:
  if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
    return
  if _debug_bar == null:
    return
  var now := Time.get_ticks_msec()
  if now - _last_cash_click > 1500:
    _cash_clicks = 0
  _last_cash_click = now
  _cash_clicks += 1
  if _cash_clicks >= 5:
    _cash_clicks = 0
    _debug_bar.visible = not _debug_bar.visible


func _build_debug() -> Control:
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation", 6)
  row.add_child(UI.label("🐞", 14, Palette.COCOA_400))
  row.add_child(_debug_btn("돈+10만", func(): _session.add_cash(100000)))
  row.add_child(_debug_btn("돈-5만", func(): _session.add_cash(-50000)))
  row.add_child(_debug_btn("즉시종료", func(): _session.debug_end_soon(1.0)))
  row.add_child(_debug_btn("손님내보냄", _debug_kick_customer))
  row.add_child(_debug_btn("버프", _debug_add_buff))
  row.add_child(_debug_btn("도감초기화", func(): Codex.reset()))
  return row


func _debug_add_buff() -> void:
  var pack := BuffDefs.random_pack(1)
  if pack.is_empty():
    return
  var id: String = pack[0]
  var before := Buffs.owned().size()
  Buffs.add(id)
  if Buffs.owned().size() == before:
    return
  var slot := _board.first_empty_slot()
  if slot:
    var bc := BuffCard.new()
    bc.setup(id)
    slot.place_card(bc)
  _refresh_buff_btn()


func _debug_kick_customer() -> void:
  for s in _board.slots:
    var c := s.get_card()
    if c is OrderCard:
      (c as OrderCard).force_expire()
      return
  for ch in _queue_row.get_children():
    if ch is Customer:
      (ch as Customer).force_expire()
      return


func _debug_btn(text: String, cb: Callable) -> Button:
  var b := Button.new()
  b.text = text
  b.add_theme_font_size_override("font_size", 12)
  b.add_theme_color_override("font_color", Palette.COCOA_800)
  b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
  b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
  b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
  b.pressed.connect(cb)
  return b


func _build_customer_queue() -> Control:
  var panel := PanelContainer.new()
  panel.add_theme_stylebox_override("panel", UI.card(Palette.COCOA_100, Palette.COCOA_200))
  panel.custom_minimum_size = Vector2(0, 89)

  var pad := MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]:
    pad.add_theme_constant_override("margin_" + side, 10)
  panel.add_child(pad)

  _queue_row = HBoxContainer.new()
  _queue_row.add_theme_constant_override("separation", 8)
  pad.add_child(_queue_row)

  return panel


func _build_bottom_buttons() -> Control:
  var row := HBoxContainer.new()
  row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_theme_constant_override("separation", 10)

  _trash_btn = TrashButton.new()
  _style_bottom_button(_trash_btn, Palette.SUB)
  _trash_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
  _trash_btn.custom_minimum_size = Vector2(56, 56)
  _trash_btn.add_child(UI.ui_btn_icon("trash", 30))
  row.add_child(_trash_btn)

  _buff_btn = Button.new()
  _style_bottom_button(_buff_btn, Palette.MAIN)
  _buff_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
  _buff_btn.custom_minimum_size = Vector2(64, 56)
  _buff_btn.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_200))
  _buff_btn.add_child(UI.ui_btn_icon("buffs", 40))
  _buff_btn.pressed.connect(_toggle_buffs)
  Audio.attach_click(_buff_btn)
  row.add_child(_buff_btn)
  _refresh_buff_btn()

  var gap := Control.new()
  gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(gap)

  return row


func _build_warehouse_handle() -> Control:
  var b := Button.new()
  _warehouse_btn = b
  b.anchor_left = 1.0
  b.anchor_right = 1.0
  b.anchor_top = 1.0
  b.anchor_bottom = 1.0
  b.offset_left = -150
  b.offset_right = -16
  b.offset_top = -76
  b.offset_bottom = -8
  b.add_theme_stylebox_override("normal", _handle_style(Palette.MAIN))
  b.add_theme_stylebox_override("hover", _handle_style(Palette.MAIN.lightened(0.08)))
  b.add_theme_stylebox_override("pressed", _handle_style(Palette.MAIN.darkened(0.1)))
  b.pressed.connect(_toggle_warehouse)
  Audio.attach_click(b)
  var cc := CenterContainer.new()
  cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
  cc.add_child(UI.ui_icon("warehouse", 38))
  b.add_child(cc)
  return b


func _handle_style(c: Color) -> StyleBoxFlat:
  var s := StyleBoxFlat.new()
  s.bg_color = c
  s.corner_radius_top_left = 18
  s.corner_radius_top_right = 18
  return s


func _toggle_warehouse() -> void:
  if _warehouse.visible:
    _close_sheets()
  else:
    _open_warehouse()


func _open_warehouse() -> void:
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = true
  _set_world_paused(true)
  _warehouse.slide_open()
  Audio.play("door_open")
  _refresh_warehouse()


func _on_tool_tapped(tool: ToolStation) -> void:
  _warehouse.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = true
  _set_world_paused(true)
  _cooking.open_for(tool)


func _toggle_buffs() -> void:
  if Buffs.owned().is_empty():
    return
  if _buff_sheet.visible:
    _close_sheets()
  else:
    _open_buff_sheet()


func _open_buff_sheet() -> void:
  _warehouse.visible = false
  _cooking.visible = false
  _backdrop.visible = true
  _set_world_paused(true)
  _buff_sheet.open()


func _refresh_buff_btn() -> void:
  if _buff_btn != null:
    _buff_btn.disabled = Buffs.owned().is_empty()
    _buff_btn.modulate.a = 0.45 if _buff_btn.disabled else 1.0


func _set_world_paused(p: bool) -> void:
  if _tutorial_active:
    return
  _session.set_paused(p)
  for c in _queue_row.get_children():
    if c is Customer:
      (c as Customer).set_paused(p)
  for s in _board.slots:
    var card := s.get_card()
    if card is OrderCard:
      (card as OrderCard).set_paused(p)
  for t in _board.tools:
    t.set_paused(p)


func _close_sheets() -> void:
  _set_world_paused(false)
  if _tutorial_active:
    if _warehouse.visible:
      Audio.play("door_close")
      _warehouse.slide_close()
    if _cooking.visible:
      _cooking.slide_close()
    if _buff_sheet.visible:
      _buff_sheet.slide_close()
    _backdrop.visible = false
    return
  if _warehouse.visible:
    var cost := Stats.warehouse_cost()
    var before_v := _hours_bar.value
    _session.spend_time(cost)
    if not _session.is_running():
      return
    var after_v := _hours_bar.value
    Audio.play("door_close")
    _warehouse.slide_close()
    _show_trip_cost(cost, before_v, after_v)
  if _cooking.visible:
    _cooking.slide_close()
  if _buff_sheet.visible:
    _buff_sheet.slide_close()
  _backdrop.visible = false


func _on_cooked() -> void:
  _close_sheets()
  _refresh_warehouse()


func _on_backdrop_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
    _close_sheets()


func _refresh_warehouse() -> void:
  _warehouse.refresh(_board.is_full())


func _process(_delta: float) -> void:
  _refresh_servable()


func _refresh_servable() -> void:
  if _board == null:
    return
  var ready := _board.available_dish_ids()
  for s in _board.slots:
    var c := s.get_card()
    if c is OrderCard:
      c.set_servable(ready.has(c.recipe_id))


func _on_background_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
    Move.background_click()


func _spawn_customer(force_recipe := "") -> void:
  if _queue_row.get_child_count() >= Config.MAX_QUEUE:
    return
  var c := Customer.new()
  c.setup(force_recipe if force_recipe != "" else Stats.random_recipe())
  c.confirm_pressed.connect(_on_confirm_order)
  c.expired.connect(_on_customer_expired)
  c.urged.connect(_on_urged)
  _queue_row.add_child(c)
  if _tutorial_active:
    c.set_process(false)
  c.slide_in()
  Audio.play("customer_in")
  _visited_today += 1


func _reflow_queue(customers: Array, old_pos: Dictionary) -> void:
  if customers.is_empty():
    return
  await _queue_row.sort_children
  for c in customers:
    if not is_instance_valid(c):
      continue
    if c.has_method("stop_slide"):
      c.stop_slide()
    var np: Vector2 = c.position
    var op: Vector2 = old_pos.get(c, np)
    if np == op:
      continue
    c.position = op
    var tw := create_tween()
    tw.tween_property(c, "position", np, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_confirm_order(customer: Customer) -> void:
  if _board.slot_counts()["orders"] >= Config.MAX_ORDERS:
    _board.shake_slots()
    Audio.play("disabled")
    Audio.vibrate(30)
    return
  var slot := _board.first_empty_slot()
  if slot == null:
    _board.shake_slots()
    Audio.play("disabled")
    Audio.vibrate(30)
    return
  var rid := customer.recipe_id
  var order := OrderCard.new()
  order.setup(rid)
  order.animal = customer.animal
  order.born = _session.now()
  order.expired.connect(_on_order_expired)
  order.served.connect(_on_served)
  order.rejected.connect(_on_order_rejected)
  order.urged.connect(_on_urged)
  if _tutorial_active:
    order.set_process(false)
  var from_pos := customer.global_position + customer.size * 0.5
  var others: Array = []
  var oldp := {}
  for c in _queue_row.get_children():
    if c is Customer and c != customer:
      others.append(c)
      oldp[c] = c.position
  _queue_row.remove_child(customer)
  customer.queue_free()
  _fly_order_to_slot(order, slot, from_pos)
  _reflow_queue(others, oldp)
  _accepted_today += 1
  if Buffs.consume_instant_order():
    _produce_dish(rid)
  _refresh_warehouse()


func _produce_dish(rid: String) -> void:
  for t in _board.tools:
    if t.is_idle():
      t.produce_instant(rid)
      return
  var s := _board.first_empty_slot()
  if s == null:
    return
  var dish := DishCard.new()
  dish.setup(rid)
  dish.born = _session.now()
  s.place_card(dish)


func _on_urged(card: Control) -> void:
  if not is_instance_valid(card):
    return
  _spawn_pop("💢", card.global_position + Vector2(card.size.x * 0.5, -8))


func _on_customer_expired(customer: Customer) -> void:
  _spawn_pop("😠", customer.global_position + customer.size * 0.5)
  Audio.play("customer_leave")
  Audio.vibrate(40)
  _detach_and_fade(customer)


func _on_order_expired(order: OrderCard) -> void:
  var gain := Buffs.on_lost(order.recipe_id)
  if gain != 0:
    _expect_fly = true
    _session.earn(gain)
    _expect_fly = false
    _show_gain_breakdown([{"src": "buff", "amount": gain, "icon": "✨"}])
  _order_lost_today += 1
  _spawn_pop("😠", order.global_position + order.size * 0.5)
  Audio.play("customer_leave")
  Audio.vibrate(40)
  _detach_and_fade(order)
  _refresh_warehouse()


func _on_order_rejected(order: OrderCard) -> void:
  _spawn_pop("😠", order.global_position + order.size * 0.5)
  Audio.vibrate(30)


const GAIN_BASE_COLOR := Palette.SUCCESS
const GAIN_BUFF_COLOR := Palette.MAIN

func _show_gain_breakdown(breakdown: Array) -> void:
  var items: Array = []
  for entry in breakdown:
    if int(entry.get("amount", 0)) != 0:
      items.append(entry)
  if items.is_empty():
    return
  var base_entry: Dictionary = items[0]
  var base_amt := int(base_entry.get("amount", 0))
  var base_col: Color = GAIN_BASE_COLOR if base_entry.get("src", "") == "base" else GAIN_BUFF_COLOR

  var has_buffs := items.size() > 1

  var total_l := UI.label(UI.money(base_amt), 34, base_col, true)
  total_l.add_theme_constant_override("outline_size", 4)
  total_l.add_theme_color_override("font_outline_color", Palette.WHITE)
  total_l.z_index = 110
  add_child(total_l)
  var menu_icon := _gain_icon(base_entry, 40)
  menu_icon.z_index = 110
  add_child(menu_icon)
  await get_tree().process_frame
  if not is_instance_valid(total_l):
    return
  var center := size * 0.5
  total_l.pivot_offset = total_l.size * 0.5
  total_l.position = center - total_l.size * 0.5
  if is_instance_valid(menu_icon):
    var isz := menu_icon.size
    if isz == Vector2.ZERO:
      isz = Vector2(40, 40)
    menu_icon.pivot_offset = isz * 0.5
    menu_icon.position = Vector2(total_l.position.x - 8.0 - isz.x, center.y - isz.y * 0.5)
  total_l.scale = Vector2(0.4, 0.4)
  var tin := create_tween()
  tin.tween_property(total_l, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tin.tween_property(total_l, "scale", Vector2.ONE, 0.08)
  if is_instance_valid(menu_icon):
    menu_icon.scale = Vector2(0.4, 0.4)
    var ti2 := create_tween()
    ti2.tween_property(menu_icon, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    ti2.tween_property(menu_icon, "scale", Vector2.ONE, 0.08)
  if has_buffs:
    get_tree().create_timer(0.28).timeout.connect(func():
      if is_instance_valid(menu_icon):
        var fo := create_tween()
        fo.tween_property(menu_icon, "modulate:a", 0.0, 0.14)
        fo.tween_callback(menu_icon.queue_free))

  var running := base_amt
  var t := 0.42
  for k in range(1, items.size()):
    var entry: Dictionary = items[k]
    var amt := int(entry.get("amount", 0))
    var from_total := running
    running += amt
    var to_total := running
    get_tree().create_timer(t).timeout.connect(func():
      if not is_instance_valid(total_l):
        return
      Audio.play("serve")
      _spawn_bonus_pop(amt, entry, total_l.position + Vector2(total_l.size.x * 0.5, 0.0))
      var cu := create_tween()
      cu.tween_method(_set_money_text.bind(total_l), float(from_total), float(to_total), 0.3)
      var bump := create_tween()
      bump.tween_property(total_l, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
      bump.tween_property(total_l, "scale", Vector2.ONE, 0.1))
    t += 0.42

  get_tree().create_timer(t + 0.2).timeout.connect(func():
    if not is_inside_tree():
      return
    _pop_label(_money_label)
    Audio.play("coins")
    if is_instance_valid(total_l):
      var out := create_tween()
      out.tween_property(total_l, "position:y", total_l.position.y - 42.0, 0.36).set_ease(Tween.EASE_IN)
      out.parallel().tween_property(total_l, "modulate:a", 0.0, 0.36)
      out.tween_callback(total_l.queue_free))


func _set_money_text(v: float, lbl: Label) -> void:
  if is_instance_valid(lbl):
    lbl.text = UI.money(int(round(v)))


func _gain_icon(entry: Dictionary, px: int) -> Control:
  if entry.has("recipe"):
    return Recipes.icon_node(str(entry["recipe"]), px)
  if entry.has("buff"):
    return BuffDefs.icon_node(str(entry["buff"]), px)
  var lbl := UI.label(str(entry.get("icon", "")), px)
  lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  return lbl


func _spawn_bonus_pop(amount: int, entry: Dictionary, anchor: Vector2) -> void:
  if not is_inside_tree():
    return
  var box := HBoxContainer.new()
  box.add_theme_constant_override("separation", 4)
  box.alignment = BoxContainer.ALIGNMENT_CENTER
  box.z_index = 111
  box.add_child(_gain_icon(entry, 28))
  var amt_l := UI.label("+" + UI.money(amount), 28, GAIN_BUFF_COLOR, true)
  amt_l.add_theme_constant_override("outline_size", 4)
  amt_l.add_theme_color_override("font_outline_color", Palette.WHITE)
  box.add_child(amt_l)
  add_child(box)
  await get_tree().process_frame
  if not is_instance_valid(box):
    return
  box.pivot_offset = box.size * 0.5
  box.position = anchor - Vector2(box.size.x * 0.5, box.size.y + 6.0)
  box.scale = Vector2(0.4, 0.4)
  var tw := create_tween()
  tw.tween_property(box, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.tween_property(box, "scale", Vector2.ONE, 0.08)
  tw.tween_interval(0.1)
  tw.tween_property(box, "position:y", box.position.y - 46.0, 0.34).set_ease(Tween.EASE_IN)
  tw.parallel().tween_property(box, "modulate:a", 0.0, 0.34)
  tw.tween_callback(box.queue_free)


func _on_served(order: OrderCard, dish: DishCard) -> void:
  Audio.play("serve")
  Audio.vibrate(20)
  var rid := order.recipe_id
  var ctx := _sale_ctx(order, dish)
  var res := Buffs.sale_amount(rid, ctx)
  var amount := int(res["amount"])
  _expect_fly = true
  _session.earn(amount)
  _expect_fly = false
  var penalty := int(res.get("penalty", 0))
  if penalty != 0:
    _session.add_cash(-penalty)
  var discard_id := str(res.get("discard", ""))
  if discard_id != "":
    Buffs.discard(discard_id)
    _remove_buff_card(discard_id)
  Buffs.on_serve(rid, ctx)
  _served_today += 1
  _served_by_menu[rid] = int(_served_by_menu.get(rid, 0)) + 1

  var serve_pos := order.global_position + order.size * 0.5
  _show_gain_breakdown(res.get("breakdown", [{"src": "base", "amount": amount}]))
  _spawn_pop("😊", serve_pos + Vector2(0, -18))

  var holder := order.get_parent()
  if holder:
    holder.remove_child(order)
  order.queue_free()

  if dish != null and is_instance_valid(dish):
    if dish.tool != null:
      dish.tool.reset()
    else:
      var dp := dish.get_parent()
      if dp:
        dp.remove_child(dish)
      dish.queue_free()

  _refresh_warehouse()


func _sale_ctx(order: OrderCard, dish: DishCard) -> Dictionary:
  var counts := _board.slot_counts()
  var orders: int = counts["orders"]
  var dishes: int = counts["dishes"]
  var ingr: int = counts["ingr"]
  var empty: int = counts["empty"]
  var now := _session.now()
  var dish_born := dish.born if (dish != null and is_instance_valid(dish)) else now
  return {
    "filled": orders + dishes + ingr,
    "empty": empty,
    "orders": orders,
    "dishes": dishes,
    "ingr": ingr,
    "buffs": Buffs.owned().size(),
    "now": now,
    "dish_age": now - dish_born,
    "order_age": now - order.born,
    "pat_frac": order.pat_frac(),
    "cash": _session.cash,
    "day_revenue": _session.day_revenue,
  }


func _remove_buff_card(buff_id: String) -> void:
  for s in _board.slots:
    var c := s.get_card()
    if c is BuffCard and c.buff_id == buff_id:
      s.clear()
      return


func _on_day_closing(s: Session) -> void:
  var same_max := 0
  for k in _served_by_menu:
    same_max = maxi(same_max, int(_served_by_menu[k]))
  var ctx := {
    "served": _served_today,
    "visited": _visited_today,
    "accepted": _accepted_today,
    "order_lost": _order_lost_today,
    "same_max": same_max,
    "day_revenue": s.day_revenue,
    "cash": s.cash,
    "rent": s.rent,
  }
  var bonus := Buffs.day_end_bonus(ctx)
  if bonus != 0:
    s.earn(bonus)


func _detach_and_fade(card: Control) -> void:
  if not is_instance_valid(card):
    return
  var gpos := card.global_position
  var sz := card.size
  var holder := card.get_parent()
  if holder:
    holder.remove_child(card)
  add_child(card)
  card.top_level = true
  card.global_position = gpos
  card.size = sz
  card.z_index = 90
  card.pivot_offset = sz * 0.5
  card.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var tw := create_tween()
  tw.set_parallel(true)
  tw.tween_property(card, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
  tw.tween_property(card, "modulate:a", 0.0, 0.3)
  tw.chain().tween_callback(card.queue_free)


func _fly_order_to_slot(card: OrderCard, slot: Slot, from_pos: Vector2) -> void:
  slot.place_card(card, false, false)
  if not is_instance_valid(card) or card.get_parent() == null:
    return
  var rect := slot.card_rect()
  var dest := rect.position
  var sz := rect.size
  card.modulate.a = 0.0

  var ghost := OrderCard.new()
  ghost.setup(card.recipe_id)
  ghost.animal = card.animal
  add_child(ghost)
  ghost.set_process(false)
  ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
  ghost.top_level = true
  ghost.z_index = 95
  ghost.size = sz
  ghost.pivot_offset = sz * 0.5
  ghost.global_position = from_pos - sz * 0.5
  ghost.scale = Vector2(0.7, 0.7)
  var tw := create_tween()
  tw.set_parallel(true)
  tw.tween_property(ghost, "global_position", dest, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  tw.tween_property(ghost, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.chain().tween_callback(func():
    if is_instance_valid(ghost):
      ghost.queue_free()
    if is_instance_valid(card):
      card.modulate.a = 1.0
      card.pop_in()
    Audio.play("card_place"))


func _spawn_pop(text: String, at_pos: Vector2) -> void:
  var mood := {"😊": "mood_happy", "💢": "mood_impatient", "😠": "mood_angry"}
  var l: Control
  if mood.has(text):
    l = UI.ui_icon(mood[text], 30)
    l.size = Vector2(30, 30)
  else:
    l = UI.label(text, 30)
  l.z_index = 101
  l.pivot_offset = Vector2(15, 15)
  add_child(l)
  l.position = at_pos - Vector2(15, 15)
  l.scale = Vector2(0.4, 0.4)
  var tw := create_tween()
  tw.set_parallel(true)
  tw.tween_property(l, "scale", Vector2(1.3, 1.3), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.tween_property(l, "position:y", l.position.y - 22, 0.5)
  tw.tween_property(l, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
  tw.chain().tween_callback(l.queue_free)


func _dot(color: Color) -> Control:
  var dot := ColorRect.new()
  dot.color = color
  dot.custom_minimum_size = Vector2(14, 14)
  var wrap := CenterContainer.new()
  wrap.add_child(dot)
  return wrap


func _on_cash_changed(cash: int) -> void:
  var delta := cash - _last_cash
  _last_cash = cash
  _money_label.text = UI.money(cash)
  if delta > 0 and not _expect_fly:
    _pop_label(_money_label)
    Audio.play("coins")
  elif delta < 0:
    _spawn_loss(-delta)
    Audio.play("coins")


func _fade_to_black(cb: Callable) -> void:
  _clear_blackout()
  _blackout = ColorRect.new()
  _blackout.color = Palette.COCOA_900
  _blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _blackout.modulate.a = 0.0
  _blackout.z_index = 290
  _blackout.mouse_filter = Control.MOUSE_FILTER_STOP
  add_child(_blackout)
  var tw := create_tween()
  tw.tween_property(_blackout, "modulate:a", 0.82, 0.8).set_ease(Tween.EASE_IN)
  tw.tween_callback(cb)


func _clear_blackout() -> void:
  if _blackout != null and is_instance_valid(_blackout):
    _blackout.queue_free()
  _blackout = null


func _spawn_confetti(count := 46) -> void:
  var vp := get_viewport_rect().size
  var colors := [Palette.MAIN, Palette.SUB, Palette.ACCENT, Palette.SUCCESS, Palette.DANGER]
  for i in count:
    var p := ColorRect.new()
    p.color = colors[i % colors.size()]
    p.size = Vector2(8, 12)
    p.z_index = 350
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.pivot_offset = p.size * 0.5
    p.add_to_group("confetti")
    add_child(p)
    p.position = Vector2(randf_range(vp.x * 0.15, vp.x * 0.85), -20.0)
    var tw := create_tween()
    tw.set_parallel(true)
    var fall := randf_range(vp.y * 0.55, vp.y * 0.95)
    var drift := randf_range(-90.0, 90.0)
    var dur := randf_range(1.0, 1.8)
    tw.tween_property(p, "position", p.position + Vector2(drift, fall), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_property(p, "rotation", randf_range(-6.0, 6.0), dur)
    tw.tween_property(p, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(p.queue_free)


func _show_day_banner(day: int) -> void:
  var l := UI.label(Loc.t("day_n") % day, 48, Palette.COCOA_800, true)
  l.add_theme_constant_override("outline_size", 6)
  l.add_theme_color_override("font_outline_color", Palette.WHITE)
  l.z_index = 200
  l.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(l)
  await get_tree().process_frame
  if not is_instance_valid(l):
    return
  var vp := get_viewport_rect().size
  l.pivot_offset = l.size * 0.5
  l.position = (vp - l.size) * 0.5 - Vector2(0, vp.y * 0.12)
  l.scale = Vector2(0.6, 0.6)
  l.modulate.a = 0.0
  var tw := create_tween()
  tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.parallel().tween_property(l, "modulate:a", 1.0, 0.2)
  tw.tween_interval(0.7)
  tw.tween_property(l, "modulate:a", 0.0, 0.4)
  tw.tween_callback(l.queue_free)


func _make_bigbanner(icon_name: String, text: String, dim_fade := 0.3) -> Control:
  var root := Control.new()
  root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  root.z_index = 200
  root.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(root)

  var dim := ColorRect.new()
  dim.color = Color(0.164, 0.129, 0.106, 0.55)
  dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  dim.mouse_filter = Control.MOUSE_FILTER_STOP
  root.add_child(dim)

  var center := CenterContainer.new()
  center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  center.mouse_filter = Control.MOUSE_FILTER_IGNORE
  root.add_child(center)
  var box := VBoxContainer.new()
  box.alignment = BoxContainer.ALIGNMENT_CENTER
  box.add_theme_constant_override("separation", 8)
  box.mouse_filter = Control.MOUSE_FILTER_IGNORE
  center.add_child(box)
  var img := UI.ui_icon(icon_name, 100)
  img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  box.add_child(img)
  var l := UI.label(text, 54, Palette.WHITE, true)
  l.add_theme_constant_override("outline_size", 8)
  l.add_theme_color_override("font_outline_color", Palette.COCOA_900)
  l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  l.mouse_filter = Control.MOUSE_FILTER_IGNORE
  box.add_child(l)

  var hint := UI.label("click ▸", 20, Palette.WHITE, true)
  hint.add_theme_constant_override("outline_size", 4)
  hint.add_theme_color_override("font_outline_color", Palette.COCOA_900)
  hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
  root.add_child(hint)

  dim.modulate.a = 0.0 if dim_fade > 0.0 else 1.0
  img.modulate.a = 0.0
  img.scale = Vector2(0.5, 0.5)
  l.modulate.a = 0.0
  l.scale = Vector2(0.7, 0.7)
  hint.modulate.a = 0.0
  await get_tree().process_frame
  if not is_instance_valid(root):
    return null
  var vp := get_viewport_rect().size
  img.pivot_offset = img.size * 0.5
  l.pivot_offset = l.size * 0.5
  hint.position = Vector2((vp.x - hint.size.x) * 0.5, vp.y * 0.72 - 60.0)

  if dim_fade > 0.0:
    create_tween().tween_property(dim, "modulate:a", 1.0, dim_fade)

  var it := create_tween().set_parallel(true)
  it.tween_property(img, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
  it.tween_property(img, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
  await it.finished
  if not is_instance_valid(root):
    return null

  var lt := create_tween()
  lt.tween_property(l, "modulate:a", 1.0, 0.14)
  lt.parallel().tween_property(l, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  lt.tween_property(l, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
  await lt.finished

  var hp := create_tween()
  hp.tween_property(hint, "modulate:a", 1.0, 0.3)
  hp.set_loops()
  hp.tween_property(hint, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)
  hp.tween_property(hint, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
  return root


func _tap_to_continue() -> void:
  var catcher := Button.new()
  catcher.flat = true
  catcher.focus_mode = Control.FOCUS_NONE
  catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  catcher.z_index = 350
  add_child(catcher)
  await catcher.pressed
  catcher.queue_free()


func _start_day_intro() -> void:
  var banner: Control = await _make_bigbanner("sun_big", "OPEN", 0.0)
  await _tap_to_continue()
  if not is_inside_tree() or _title.visible:
    if is_instance_valid(banner): banner.queue_free()
    return
  Audio.play("door_open")
  Audio.play("day_start")
  if is_instance_valid(banner):
    var bt := create_tween()
    bt.tween_property(banner, "modulate:a", 0.0, 0.22)
    bt.tween_callback(banner.queue_free)
  if is_instance_valid(_session):
    _session.set_process(true)


func _screen_shake(strength := 13.0, dur := 0.45) -> void:
  var steps := 7
  var tw := create_tween()
  for i in steps:
    var damp := strength * (1.0 - float(i) / float(steps))
    var off := Vector2(randf_range(-damp, damp), randf_range(-damp, damp))
    tw.tween_property(self, "position", off, dur / float(steps + 1)).set_trans(Tween.TRANS_SINE)
  tw.tween_property(self, "position", Vector2.ZERO, dur / float(steps + 1)).set_trans(Tween.TRANS_SINE)


func _spawn_loss(amount: int) -> void:
  if amount <= 0:
    return
  var l := UI.label("-" + UI.money(amount), 18, Palette.DANGER, true)
  l.z_index = 100
  l.add_theme_constant_override("outline_size", 3)
  l.add_theme_color_override("font_outline_color", Palette.WHITE)
  add_child(l)
  var start := _money_label.global_position + Vector2(0, _money_label.size.y + 2)
  l.position = start
  var tw := create_tween()
  tw.set_parallel(true)
  tw.tween_property(l, "position:y", start.y + 26, 0.6).set_ease(Tween.EASE_OUT)
  tw.tween_property(l, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
  tw.chain().tween_callback(l.queue_free)


func _show_trip_cost(cost: float, before_v: float, after_v: float) -> void:
  if cost <= 0.0 or after_v <= before_v:
    return
  var bx := _hours_bar.global_position
  var bw := _hours_bar.size.x
  var bh := _hours_bar.size.y
  var seg := ColorRect.new()
  seg.color = Palette.DANGER
  seg.z_index = 120
  seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(seg)
  seg.global_position = Vector2(bx.x + bw * before_v / 100.0, bx.y)
  seg.size = Vector2(maxf(6.0, bw * (after_v - before_v) / 100.0), bh)
  var st := create_tween()
  st.tween_property(seg, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
  st.chain().tween_callback(seg.queue_free)
  var l := UI.label("⏱ -%.1f초" % cost, 40, Palette.DANGER, true)
  l.add_theme_constant_override("outline_size", 6)
  l.add_theme_color_override("font_outline_color", Palette.WHITE)
  l.z_index = 200
  l.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(l)
  await get_tree().process_frame
  if not is_instance_valid(l):
    return
  var vp := get_viewport_rect().size
  l.pivot_offset = l.size * 0.5
  l.position = (vp - l.size) * 0.5 - Vector2(0, vp.y * 0.05)
  l.scale = Vector2(1.5, 1.5)
  l.modulate.a = 0.0
  var lt := create_tween()
  lt.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  lt.parallel().tween_property(l, "modulate:a", 1.0, 0.12)
  lt.tween_interval(0.35)
  lt.tween_property(l, "modulate:a", 0.0, 0.4)
  lt.tween_callback(l.queue_free)


func _pop_label(lbl: Control) -> void:
  lbl.pivot_offset = lbl.size * 0.5
  lbl.scale = Vector2.ONE
  var tw := create_tween()
  tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.tween_property(lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _fly_gain(amount: int, from_pos: Vector2, color := Palette.SUCCESS) -> void:
  if amount == 0:
    return
  var l := UI.label("+" + UI.money(amount), 20, color, true)
  l.z_index = 100
  l.add_theme_constant_override("outline_size", 3)
  l.add_theme_color_override("font_outline_color", Palette.WHITE)
  add_child(l)
  l.position = from_pos
  await get_tree().process_frame
  if not is_instance_valid(l):
    return
  l.pivot_offset = l.size * 0.5
  var target := _money_label.global_position + _money_label.size * 0.5 - l.size * 0.5
  var tw := create_tween()
  tw.set_parallel(true)
  tw.tween_property(l, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
  tw.tween_property(l, "scale", Vector2(0.55, 0.55), 0.45).set_ease(Tween.EASE_IN)
  tw.chain().tween_callback(func():
    if is_instance_valid(l):
      l.queue_free()
    _pop_label(_money_label)
    Audio.play("coins"))


func _on_progress(t01: float) -> void:
  _hours_bar.value = t01 * 100.0
  if t01 >= Config.HOURS_WARN_FRAC and not _hours_warning:
    _hours_warning = true
    _hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.DANGER))
    _hours_glow = create_tween().set_loops()
    _hours_glow.tween_property(_hours_bar, "modulate:a", 0.45, 0.35).set_trans(Tween.TRANS_SINE)
    _hours_glow.tween_property(_hours_bar, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
  var left := _session.time_left()
  if left > 0.0 and left <= COUNTDOWN_FROM:
    var sec := int(ceil(left))
    if sec != _last_countdown:
      _last_countdown = sec
      _countdown_pop(sec)
  else:
    _last_countdown = 0


func _countdown_pop(sec: int) -> void:
  _screen_shake(4.0 + float(COUNTDOWN_FROM - sec) * 2.5, 0.4)
  Audio.play("countdown", 1.0 + float(COUNTDOWN_FROM - sec) * 0.08)
  Audio.vibrate(15)
  _pulse_countdown_edge()
  var l := UI.label(str(sec), 46, Palette.DANGER, true)
  l.add_theme_constant_override("outline_size", 5)
  l.add_theme_color_override("font_outline_color", Palette.WHITE)
  l.z_index = 200
  l.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(l)
  await get_tree().process_frame
  if not is_instance_valid(l):
    return
  var vp := get_viewport_rect().size
  l.pivot_offset = l.size * 0.5
  l.position = (vp - l.size) * 0.5 - Vector2(0, vp.y * 0.15)
  l.scale = Vector2(1.6, 1.6)
  l.modulate.a = 0.0
  var tw := create_tween()
  tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.parallel().tween_property(l, "modulate:a", 1.0, 0.1)
  tw.tween_interval(0.25)
  tw.tween_property(l, "modulate:a", 0.0, 0.4)
  tw.tween_callback(l.queue_free)


func _pulse_countdown_edge() -> void:
  if _countdown_edge == null:
    _countdown_edge = Panel.new()
    _countdown_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _countdown_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _countdown_edge.z_index = 190
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0, 0, 0, 0)
    sb.set_border_width_all(20)
    sb.border_color = Palette.DANGER
    sb.border_blend = true
    _countdown_edge.add_theme_stylebox_override("panel", sb)
    add_child(_countdown_edge)
  _countdown_edge.modulate.a = 0.0
  var t := create_tween()
  t.tween_property(_countdown_edge, "modulate:a", 0.7, 0.12).set_trans(Tween.TRANS_SINE)
  t.tween_property(_countdown_edge, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func _reset_hours_bar() -> void:
  if _hours_glow != null:
    _hours_glow.kill()
    _hours_glow = null
  _hours_bar.modulate.a = 1.0
  _hours_warning = false
  _hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.ACCENT))


func _on_day_started(day: int, rent: int) -> void:
  _day_num.text = str(day)
  _session.set_process(false)
  _rent_label.text = UI.money(rent)
  _hours_bar.value = 0
  _reset_hours_bar()
  _last_countdown = 0
  _clear_blackout()
  _warehouse.visible = false
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = false
  _visited_today = 0
  _accepted_today = 0
  _served_today = 0
  _order_lost_today = 0
  _served_by_menu = {}
  Buffs.reset_day()
  Move.clear()
  _board.rebuild(_session.effective_slots() + Buffs.buff_slot_bonus())
  for id in Buffs.owned():
    var slot := _board.first_empty_slot()
    if slot:
      var bc := BuffCard.new()
      bc.setup(id)
      slot.place_card(bc, false)
  for c in _queue_row.get_children():
    c.queue_free()
  _refresh_warehouse()
  _refresh_buff_btn()
  if is_inside_tree() and not _title.visible:
    _start_day_intro()


func _clear_play_field() -> void:
  for s in _board.slots:
    if s.get_card() is BuffCard:
      continue
    s.clear()
  for t in _board.tools:
    t.reset()
  for c in _queue_row.get_children():
    c.queue_free()


func _dayend_sequence() -> void:
  _freeze_field()
  await get_tree().create_timer(Config.DAY_END_PAUSE).timeout
  await _pop_clear_slots()
  for t in _board.tools:
    t.reset()
  for c in _queue_row.get_children():
    c.queue_free()


func _freeze_field() -> void:
  for s in _board.slots:
    var c := s.get_card()
    if c != null:
      c.set_process(false)
  for t in _board.tools:
    t.set_process(false)
  for c in _queue_row.get_children():
    c.set_process(false)


func _pop_clear_slots() -> void:
  var cards: Array = []
  for s in _board.slots:
    var c := s.get_card()
    if c != null and not (c is BuffCard):
      cards.append(c)
  if cards.is_empty():
    return
  var last: Tween = null
  var i := 0
  for c in cards:
    c.set_process(false)
    if c.has_method("set_servable"):
      c.set_servable(false)
    c.pivot_offset = c.size * 0.5
    var tw := create_tween()
    tw.tween_interval(i * 0.07)
    tw.tween_property(c, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(c, "scale", Vector2(0.05, 0.05), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(c, "modulate:a", 0.0, 0.16)
    last = tw
    i += 1
  if last != null:
    await last.finished
  for s in _board.slots:
    if not (s.get_card() is BuffCard):
      s.clear()


func _on_day_ended(summary: Dictionary) -> void:
  if _warehouse.visible:
    _warehouse.slide_close()
  if _cooking.visible:
    _cooking.slide_close()
  if _buff_sheet.visible:
    _buff_sheet.slide_close()
  _backdrop.visible = false
  if summary["won"]:
    _session.pay_rent()
    _clear_play_field()
    Modal.open(self) \
      .title(Loc.t("win_title")) \
      .stamp_row(Loc.t("win_days") % Levels.count(), Palette.SUCCESS, 0.15) \
      .button(Loc.t("to_title"), _show_title)
    _celebrating = true
    _spawn_confetti()
    get_tree().create_timer(6.0).timeout.connect(func():
      if _celebrating:
        _spawn_confetti(46))
  else:
    Audio.play("day_close")
    Audio.vibrate(40)
    var banner: Control = await _make_bigbanner("moon_big", "CLOSE")
    _dayend_sequence()
    await _tap_to_continue()
    if not is_inside_tree() or _title.visible:
      if is_instance_valid(banner): banner.queue_free()
      return
    if is_instance_valid(banner):
      var bt := create_tween()
      bt.tween_property(banner, "modulate:a", 0.0, 0.22)
      bt.tween_callback(banner.queue_free)
    _show_settlement(summary)


func _show_settlement(summary: Dictionary) -> void:
  var rent: int = summary["rent"]
  var m := Modal.open(self).title(Loc.t("day_closed") % summary["day"])

  var receipt_name := "receipt" if ResourceLoader.exists("res://assets/art/ui/receipt.png") else "bill"
  var icon_box := CenterContainer.new()
  icon_box.custom_minimum_size = Vector2(112, 112)
  icon_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  icon_box.add_child(UI.ui_icon(receipt_name, 112))
  m.add_row(icon_box)

  var amount := UI.label(UI.money(rent), 26, Palette.DANGER, true)
  var amount_row := _settle_icon_row("coin", amount, 26)
  amount_row.modulate.a = 1.0
  m.add_row(amount_row)

  var pay_btn := Button.new()
  pay_btn.text = Loc.t("pay_rent")
  pay_btn.custom_minimum_size = Vector2(0, 48)
  pay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  pay_btn.add_theme_font_size_override("font_size", 18)
  pay_btn.add_theme_color_override("font_color", Palette.WHITE)
  pay_btn.add_theme_color_override("font_hover_color", Palette.WHITE)
  pay_btn.add_theme_color_override("font_pressed_color", Palette.WHITE)
  pay_btn.add_theme_stylebox_override("normal", UI.chip(Palette.DANGER))
  pay_btn.add_theme_stylebox_override("hover", UI.chip(Palette.DANGER.lightened(0.08)))
  pay_btn.add_theme_stylebox_override("pressed", UI.chip(Palette.DANGER.darkened(0.1)))
  pay_btn.modulate.a = 0.0
  pay_btn.disabled = true
  pay_btn.pressed.connect(func(): _on_settle_pay(summary, m, pay_btn, icon_box, amount_row))
  Audio.attach_click(pay_btn)
  m.add_row(pay_btn)

  var tw := create_tween()
  tw.tween_interval(0.25)
  tw.tween_callback(func():
    pay_btn.disabled = false
    create_tween().tween_property(pay_btn, "modulate:a", 1.0, 0.2))


func _on_settle_pay(summary: Dictionary, m: Modal, pay_btn: Button, icon_box: Control, amount_row: Control) -> void:
  if not summary["passed"]:
    Audio.play("disabled")
    Audio.vibrate(30)
    if not pay_btn.get_meta("bk_shown", false):
      pay_btn.set_meta("bk_shown", true)
      m.pin_top()
      var bk := _bankrupt_button()
      bk.pressed.connect(func(): _settle_finish(false, summary, m, pay_btn, icon_box, amount_row))
      var wrap := Control.new()
      wrap.clip_contents = true
      wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
      wrap.custom_minimum_size = Vector2(0, 0)
      wrap.modulate.a = 0.0
      bk.anchor_right = 1.0
      bk.offset_right = 0
      bk.offset_top = 0
      bk.offset_bottom = 44
      wrap.add_child(bk)
      pay_btn.set_meta("bk_btn", wrap)
      m.add_row(wrap)
      var gt := create_tween().set_parallel(true)
      gt.tween_property(wrap, "custom_minimum_size:y", 44.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
      gt.tween_property(wrap, "modulate:a", 1.0, 0.28)
    return
  _settle_finish(true, summary, m, pay_btn, icon_box, amount_row)


func _settle_finish(is_pass: bool, summary: Dictionary, m: Modal, pay_btn: Button, icon_box: Control, amount_row: Control) -> void:
  if not is_pass:
    Audio.play("fail")
    Audio.vibrate(60)
    m.queue_free()
    _show_run_failed(int(summary["day"]))
    return

  pay_btn.disabled = true
  for c in pay_btn.pressed.get_connections():
    pay_btn.pressed.disconnect(c["callable"])

  var at := create_tween()
  at.tween_property(amount_row, "modulate:a", 0.0, 0.15)
  at.tween_callback(func(): amount_row.visible = false)

  var px: float = icon_box.custom_minimum_size.y
  for ch in icon_box.get_children():
    ch.visible = false
    ch.queue_free()
  var mark := UI.label("✅", int(px * 0.8), Palette.SUCCESS, true)
  mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  mark.custom_minimum_size = Vector2(px, px)
  mark.pivot_offset = Vector2(px, px) * 0.5
  mark.modulate.a = 0.0
  mark.scale = Vector2(0.5, 0.5)
  icon_box.add_child(mark)
  var pt := create_tween()
  pt.tween_property(mark, "modulate:a", 1.0, 0.12)
  pt.parallel().tween_property(mark, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  pt.tween_property(mark, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)

  if not summary["skipped"] and int(summary["cash"]) >= int(summary["rent"]):
    _session.pay_rent()
  Audio.play("day_pass")
  Audio.vibrate(30)
  pay_btn.text = Loc.t("to_shop")
  pay_btn.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
  pay_btn.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
  pay_btn.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
  pay_btn.pressed.connect(func(): m.queue_free(); _open_shop())
  pay_btn.disabled = false


func _show_run_failed(day: int) -> void:
  var m := Modal.open(self).title(Loc.t("run_failed"))
  var badge := UI.day_badge(64)
  (badge.get_meta("num") as Label).text = str(day)
  var badge_wrap := CenterContainer.new()
  badge_wrap.add_child(badge)
  m.add_row(badge_wrap)
  var x := UI.label("❌", 80, Palette.DANGER, true)
  x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  m.add_row(x)
  var home := Button.new()
  home.custom_minimum_size = Vector2(0, 56)
  home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  home.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
  home.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
  home.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
  home.add_child(UI.ui_btn_icon("house", 30))
  home.pressed.connect(func(): m.queue_free(); _fade_to_black(_show_title))
  Audio.attach_click(home)
  m.add_row(home)


func _bankrupt_button() -> Button:
  var b := Button.new()
  b.text = Loc.t("declare_bankrupt")
  b.custom_minimum_size = Vector2(0, 44)
  b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  b.add_theme_font_size_override("font_size", 16)
  b.add_theme_color_override("font_color", Palette.COCOA_600)
  b.add_theme_color_override("font_hover_color", Palette.COCOA_800)
  b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
  b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
  b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
  return b


func _settle_icon_row(icon: String, value: Label, px := 22) -> HBoxContainer:
  var row := HBoxContainer.new()
  row.alignment = BoxContainer.ALIGNMENT_CENTER
  row.add_theme_constant_override("separation", 6)
  row.modulate.a = 0.0
  row.add_child(UI.ui_icon(icon, px))
  row.add_child(value)
  return row


func _open_shop() -> void:
  var shop := Shop.new()
  shop.session = _session
  shop.start_business.connect(_session.advance_day)
  add_child(shop)


func _make_bottom_button(color: Color) -> Button:
  var b := Button.new()
  _style_bottom_button(b, color)
  return b


func _style_bottom_button(b: Button, color: Color) -> void:
  b.custom_minimum_size = Vector2(0, 56)
  b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  b.add_theme_font_size_override("font_size", 24)
  b.add_theme_color_override("font_color", Palette.WHITE)
  b.add_theme_color_override("font_hover_color", Palette.WHITE)
  b.add_theme_color_override("font_pressed_color", Palette.WHITE)
  b.add_theme_stylebox_override("normal", UI.chip(color))
  b.add_theme_stylebox_override("hover", UI.chip(color.lightened(0.08)))
  b.add_theme_stylebox_override("pressed", UI.chip(color.darkened(0.1)))
