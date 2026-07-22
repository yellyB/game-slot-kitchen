class_name TrashButton
extends Button

func _ready() -> void:
	pressed.connect(func(): Move.on_click(self))


func can_accept(payload: Dictionary) -> bool:
	if payload.get("kind") != "move":
		return false
	var card = payload.get("card")
	if card == null or not is_instance_valid(card):
		return false
	return card is Card and card.is_trashable()


func accept(payload: Dictionary) -> void:
	var card = payload.get("card")
	if card == null or not is_instance_valid(card):
		return
	var holder := (card as Node).get_parent()
	if holder:
		holder.remove_child(card)
	card.queue_free()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and can_accept(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Move.on_drop(self, data)
