class_name Slot
extends PanelContainer
## 카드가 놓이는 칸. 도구석은 재료/카드를 받지 않는다.
## 타깃 역할: 창고 신규 배치("new") / 다른 슬롯에서 이동("move").
## 클릭·드래그 모두 can_accept/accept로 처리 (Move 컨트롤러 참고).

var is_tool := false
var _holder: MarginContainer

func setup(tool: bool) -> void:
	is_tool = tool

func _ready() -> void:
	custom_minimum_size = Vector2(104, 104)
	add_theme_stylebox_override("panel", _box())

	_holder = MarginContainer.new()
	# 빈 슬롯의 클릭/드롭이 Slot 자신에게 오도록 holder는 마우스 통과 무시
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		_holder.add_theme_constant_override("margin_" + side, 6)
	add_child(_holder)

	if is_tool:
		var lbl := Label.new()
		lbl.text = "🔥"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Palette.SUB)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_holder.add_child(lbl)


func is_empty() -> bool:
	return not is_tool and _get_card() == null


func _get_card() -> Card:
	for ch in _holder.get_children():
		if ch is Card:
			return ch
	return null


## 창고에서 꺼낸 재료를 신규 배치.
func place_new(id: String) -> void:
	var card := IngredientCard.new()
	card.setup(id)
	place_card(card)


## 이미 만들어진 카드(재료·주문서 등)를 배치.
func place_card(card: Card) -> void:
	if not is_empty() or card == null:
		return
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.add_child(card)


## 다른 슬롯에서 카드를 옮겨오기.
func take_card(card: Card) -> void:
	if not is_empty() or card == null or not is_instance_valid(card):
		return
	var prev := card.get_parent()
	if prev:
		prev.remove_child(card)
	_holder.add_child(card)


# ── 공용 타깃 인터페이스 (클릭·드래그 공용) ────────────────
func can_accept(payload: Dictionary) -> bool:
	if is_tool or not is_empty():
		return false
	return payload.get("kind") == "new" or payload.get("kind") == "move"


func accept(payload: Dictionary) -> void:
	match payload.get("kind"):
		"new":
			place_new(str(payload.get("id")))
		"move":
			take_card(payload.get("card"))


# ── 클릭(빈 슬롯) ─────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.on_click(self)
		accept_event()


# ── 드래그앤드롭 타깃 ─────────────────────────────────────
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)


func _box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(14)
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	if is_tool:
		s.bg_color = Color("FBE9DA")
		s.set_border_width_all(2)
		s.border_color = Palette.SUB
	else:
		s.bg_color = Palette.WHITE
		s.set_border_width_all(1)
		s.border_color = Palette.COCOA_200
	return s
