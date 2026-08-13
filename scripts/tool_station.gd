class_name ToolStation
extends PanelContainer

signal tapped(tool: ToolStation)

enum State { IDLE, COOKING, DONE }

var state := State.IDLE
var recipe_id := ""
var now_provider: Callable = func() -> float: return 0.0

var _cook_left := 0.0
var _cook_total := 0.0
var _cook_timer: RadialTimer
var _holder: MarginContainer
var _style: StyleBoxFlat
var _glow: Tween

func _ready() -> void:
  custom_minimum_size = Vector2(104, 104)
  _style = UI.card(Palette.TOOL, Palette.SUB, 2)
  add_theme_stylebox_override("panel", _style)

  _holder = MarginContainer.new()
  _holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _set_holder_pad(6)
  add_child(_holder)

  set_process(false)
  _show_idle()


func _set_holder_pad(px: int) -> void:
  for side in ["left", "right", "top", "bottom"]:
    _holder.add_theme_constant_override("margin_" + side, px)


func is_idle() -> bool:
  return state == State.IDLE


func set_paused(p: bool) -> void:
  if state == State.COOKING:
    set_process(not p)
    if _glow != null and _glow.is_valid():
      if p:
        _glow.pause()
      else:
        _glow.play()


func get_dish() -> DishCard:
  for ch in _holder.get_children():
    if ch is DishCard:
      return ch
  return null


func reset() -> void:
  _stop_glow()
  _show_idle()


func _show_idle() -> void:
  state = State.IDLE
  recipe_id = ""
  _clear_holder()
  _set_holder_pad(6)
  _style.border_color = Palette.SUB
  var path := "res://assets/art/tools/burner.png"
  var icon: Control
  if ResourceLoader.exists(path):
    var tr := TextureRect.new()
    tr.texture = load(path)
    tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    icon = tr
  else:
    var lbl := Label.new()
    lbl.text = "🔥"
    lbl.add_theme_font_size_override("font_size", 28)
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    icon = lbl
  icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
  icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _holder.add_child(icon)


func start_cooking(id: String, empty := 0) -> void:
  if state != State.IDLE:
    return
  recipe_id = id
  if Buffs.on_cook_start():
    _finish_cooking()
    return
  _cook_total = Stats.cook_time(id, empty)
  _cook_left = _cook_total
  state = State.COOKING
  _clear_holder()
  _style.border_color = Palette.ACCENT

  var v := VBoxContainer.new()
  v.mouse_filter = Control.MOUSE_FILTER_IGNORE
  v.alignment = BoxContainer.ALIGNMENT_CENTER
  v.add_theme_constant_override("separation", 4)
  _holder.add_child(v)

  var dish := Recipes.icon_node(id, 34)
  dish.modulate = Color(1, 1, 1, 0.6)
  v.add_child(dish)

  _cook_timer = RadialTimer.new()
  _cook_timer.frac = 1.0
  _cook_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
  _cook_timer.custom_minimum_size = Vector2(40, 40)
  v.add_child(_cook_timer)

  set_process(true)
  _start_glow()


func produce_instant(id: String) -> void:
  if state != State.IDLE:
    return
  recipe_id = id
  _finish_cooking()


func _finish_cooking() -> void:
  state = State.DONE
  set_process(false)
  _stop_glow()
  _style.border_color = Palette.SUCCESS
  _set_holder_pad(4)
  _clear_holder()
  var dish := DishCard.new()
  dish.setup(recipe_id)
  dish.tool = self
  dish.born = now_provider.call()
  dish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  dish.size_flags_vertical = Control.SIZE_EXPAND_FILL
  _holder.add_child(dish)
  dish.pop_in()
  Audio.play("cook_done")


func _process(delta: float) -> void:
  if state != State.COOKING:
    return
  _cook_left -= delta
  _cook_timer.frac = _cook_left / maxf(0.001, _cook_total)
  if _cook_left <= 0.0:
    _finish_cooking()


func _gui_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
    if state == State.IDLE:
      tapped.emit(self)
      accept_event()


func _start_glow() -> void:
  _glow = create_tween().set_loops()
  _glow.tween_property(self, "modulate:a", 0.72, 0.5)
  _glow.tween_property(self, "modulate:a", 1.0, 0.5)

func _stop_glow() -> void:
  if _glow:
    _glow.kill()
    _glow = null
  modulate.a = 1.0


func _clear_holder() -> void:
  for ch in _holder.get_children():
    ch.queue_free()
