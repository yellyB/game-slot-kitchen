class_name TrashButton
extends Button
## 휴지통. 타깃 역할 — 재료(move)·완성품(dish) 카드를 받아 제거(is_trashable로 게이트).
## 클릭·드래그 공용 (can_accept/accept). 주문서·창고 신규("new")는 안 받음.

func _ready() -> void:
	pressed.connect(func(): Move.on_click(self))


# ── 공용 타깃 인터페이스 ──────────────────────────────────
func can_accept(payload: Dictionary) -> bool:
	var kind = payload.get("kind")
	if kind != "move" and kind != "dish":   # 재료(move)·완성품(dish) 둘 다
		return false
	var card = payload.get("card")
	if card == null or not is_instance_valid(card):
		return false
	return card is Card and card.is_trashable()


func accept(payload: Dictionary) -> void:
	var card = payload.get("card")
	if card == null or not is_instance_valid(card):
		return
	card.dispose()   # 카드별 정리(완성품이면 도구 리셋)


# ── 드래그앤드롭 타깃 ─────────────────────────────────────
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)
