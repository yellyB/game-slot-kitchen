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
	Audio.play("trash")   # 종이 구기기 효과음
	_suck(card)   # 휴지통으로 빨려 들어가며 축소·페이드


## 버린 카드가 휴지통 쪽으로 빨려 들어가며 작아지고 사라짐.
## 논리적 정리(슬롯/도구 회복)는 먼저 처리하고, 노드는 살려서 애니 후 제거.
func _suck(card: Card) -> void:
	var gpos := card.global_position
	var sz := card.size
	# 부모(슬롯)에서 떼기 + 완성품이면 도구석 회복 (dispose 부수효과 대체)
	var holder := card.get_parent()
	if holder:
		holder.remove_child(card)
	var dc := card as DishCard
	if dc != null and dc.tool != null:
		var t := dc.tool
		dc.tool = null
		t.reset()
	# 애니용 최상위 부착 — 좌표 고정
	get_tree().root.add_child(card)
	card.top_level = true
	card.z_index = 400
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.global_position = gpos
	card.pivot_offset = sz * 0.5
	var target := global_position + size * 0.5 - sz * 0.5   # 휴지통 중심으로 카드 중심 이동
	var tw := card.create_tween()
	tw.set_parallel(true)
	# 휴지통으로 가속하며 진입(뒤로 당김 없음), 이동하며 서서히 축소
	tw.tween_property(card, "global_position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(0.12, 0.12), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# 페이드는 도착 직전에만 → 중간에 사라지지 않게
	tw.tween_property(card, "modulate:a", 0.0, 0.1).set_delay(0.22)
	tw.chain().tween_callback(card.queue_free)


# ── 드래그앤드롭 타깃 ─────────────────────────────────────
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)
