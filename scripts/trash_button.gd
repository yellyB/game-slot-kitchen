class_name TrashButton
extends Button
## 휴지통. 타깃 역할 — "move" payload(슬롯의 재료 카드)를 받아 제거.
## 클릭·드래그 공용 (can_accept/accept). 창고 신규("new")는 받지 않음.

func _ready() -> void:
	pressed.connect(func(): Move.on_click(self))


# ── 공용 타깃 인터페이스 ──────────────────────────────────
func can_accept(payload: Dictionary) -> bool:
	return payload.get("kind") == "move"


func accept(payload: Dictionary) -> void:
	var card = payload.get("card")
	if card == null or not is_instance_valid(card):
		return
	var holder := (card as Node).get_parent()
	if holder:
		holder.remove_child(card)
	card.queue_free()


# ── 드래그앤드롭 타깃 ─────────────────────────────────────
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)
