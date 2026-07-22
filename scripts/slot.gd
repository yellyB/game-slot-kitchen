class_name Slot
extends PanelContainer
## 카드가 놓이는 칸. 타깃 역할(클릭·드래그 공용):
##   "new"(창고 신규) / "move"(슬롯↔슬롯) / "dish"(완성품).
## (도구석은 Slot이 아니라 ToolStation)

var _holder: MarginContainer

func _ready() -> void:
	custom_minimum_size = Vector2(104, 104)
	add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200, 1))

	_holder = MarginContainer.new()
	# 빈 슬롯의 클릭/드롭이 Slot 자신에게 오도록 holder는 마우스 통과 무시
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		_holder.add_theme_constant_override("margin_" + side, 6)
	add_child(_holder)


func is_empty() -> bool:
	return _get_card() == null


func _get_card() -> Card:
	for ch in _holder.get_children():
		if ch is Card:
			return ch
	return null


## 현재 놓인 카드(없으면 null).
func get_card() -> Card:
	return _get_card()


## 카드 제거 + 슬롯 비우기 (조리 재료 소비 등).
func clear() -> void:
	var c := _get_card()
	if c:
		_holder.remove_child(c)
		c.queue_free()


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


## 다른 슬롯/도구석에서 카드를 옮겨오기.
func take_card(card: Card) -> void:
	if not is_empty() or card == null or not is_instance_valid(card):
		return
	var prev := card.get_parent()
	if prev:
		prev.remove_child(card)
	_holder.add_child(card)
	# 완성품을 도구석에서 가져온 경우 → 그 도구석 회복
	var dc := card as DishCard
	if dc != null and dc.tool != null:
		var t := dc.tool
		dc.tool = null
		t.reset()


# ── 공용 타깃 인터페이스 (클릭·드래그 공용) ────────────────
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
