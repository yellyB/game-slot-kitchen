class_name Slot
extends PanelContainer

const PAD := 4

var _holder: MarginContainer
var locked := false

func _get_minimum_size() -> Vector2:
  return custom_minimum_size


func _ready() -> void:
  custom_minimum_size = Vector2(104, 104)
  clip_contents = true
  add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200, 1))

  _holder = MarginContainer.new()
  _holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
  for side in ["left", "right", "top", "bottom"]:
    _holder.add_theme_constant_override("margin_" + side, PAD)
  add_child(_holder)


func card_rect() -> Rect2:
  return Rect2(_holder.global_position + Vector2(PAD, PAD), _holder.size - Vector2(PAD, PAD) * 2.0)


func is_empty() -> bool:
  return not locked and _get_card() == null


func lock() -> void:
  if locked:
    return
  locked = true
  add_theme_stylebox_override("panel", UI.card(Palette.COCOA_200, Palette.COCOA_400, 1))
  var lbl := UI.label("🔒", 40, Palette.COCOA_800, true)
  lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
  lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _holder.add_child(lbl)


func _get_card() -> Card:
  for ch in _holder.get_children():
    if ch is Card:
      return ch
  return null


func get_card() -> Card:
  return _get_card()


func clear() -> void:
  var c := _get_card()
  if c:
    _holder.remove_child(c)
    c.queue_free()


func place_new(id: String) -> void:
  var card := IngredientCard.new()
  card.setup(id)
  place_card(card)


func place_card(card: Card, play_sfx := true, pop := true) -> void:
  if not is_empty() or card == null:
    return
  card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  card.size_flags_vertical = Control.SIZE_EXPAND_FILL
  _holder.add_child(card)
  if pop:
    card.pop_in()
  if play_sfx:
    Audio.play("card_place")
    Audio.vibrate(10)


func take_card(card: Card) -> void:
  if not is_empty() or card == null or not is_instance_valid(card):
    return
  var prev := card.get_parent()
  if prev:
    prev.remove_child(card)
  _holder.add_child(card)
  card.pop_in()
  Audio.play("card_place")
  Audio.vibrate(10)
  var dc := card as DishCard
  if dc != null and dc.tool != null:
    var t := dc.tool
    dc.tool = null
    t.reset()


func can_accept(payload: Dictionary) -> bool:
  if not is_empty():
    return false
  var k = payload.get("kind")
  return k == "new" or k == "move" or k == "dish"


func accept(payload: Dictionary) -> void:
  match payload.get("kind"):
    "new":
      place_new(str(payload.get("id")))
    "move", "dish":
      take_card(payload.get("card"))


func _gui_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
    Move.on_click(self)
    accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
  return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
  Move.on_drop(self, data)
