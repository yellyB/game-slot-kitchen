class_name TrashButton
extends Button

func _ready() -> void:
	pressed.connect(func(): Move.on_click(self))


func can_accept(payload: Dictionary) -> bool:
	var kind = payload.get("kind")
	if kind != "move" and kind != "dish":
		return false
	var card = payload.get("card")
	if card == null or not is_instance_valid(card):
		return false
	return card is Card and card.is_trashable()


func accept(payload: Dictionary) -> void:
	var card = payload.get("card")
	if card == null or not is_instance_valid(card):
		return
	Audio.play("trash")
	_suck(card)


func _suck(card: Card) -> void:
	var gpos := card.global_position
	var sz := card.size
	var holder := card.get_parent()
	if holder:
		holder.remove_child(card)
	var dc := card as DishCard
	if dc != null and dc.tool != null:
		var t := dc.tool
		dc.tool = null
		t.reset()
	get_tree().root.add_child(card)
	card.top_level = true
	card.z_index = 400
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.global_position = gpos
	card.pivot_offset = sz * 0.5
	var target := global_position + size * 0.5 - sz * 0.5
	var tw := card.create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "global_position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(0.12, 0.12), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "modulate:a", 0.0, 0.1).set_delay(0.22)
	tw.chain().tween_callback(card.queue_free)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)
