class_name Card
extends PanelContainer
## 슬롯에 놓이는 카드 공통 베이스. 소스 역할(클릭/드래그로 이동) 공용 구현.
## 서브클래스: IngredientCard(재료), OrderCard(주문서), DishCard(완성품).
## 서브클래스는 _build_content()로 내용을, is_trashable()/_preview_text()를 오버라이드.

var _style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = UI.card(Palette.WHITE, Palette.COCOA_200, 1, 12)
	add_theme_stylebox_override("panel", _style)
	_build_content()


## 서브클래스가 카드 내용을 구성. (_style도 여기서 조정 가능)
func _build_content() -> void:
	pass

## 휴지통에 버릴 수 있는지 — 재료·완성품 true(주문서는 false).
func is_trashable() -> bool:
	return false

## 제거(휴지통 등) — 기본: 부모에서 떼고 해제. 특수 정리(도구 등)는 서브클래스가 오버라이드.
func dispose() -> void:
	var holder := get_parent()
	if holder:
		holder.remove_child(self)
	queue_free()

## 배치 시 "팝인" — 작게 나타나 슬롯보다 크게 불룩 튄 뒤 제자리로. Slot.place_card/take_card가 호출.
## (흰 카드가 흰 슬롯 위라, 1.0 이상 오버슛해 슬롯 밖으로 불룩해야 눈에 확 띔.)
func pop_in() -> void:
	scale = Vector2(0.6, 0.6)
	await get_tree().process_frame   # 레이아웃 후 크기 확정
	if not is_instance_valid(self):
		return
	pivot_offset = size * 0.5        # 중앙 기준 스케일
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## 드래그 프리뷰 대표 아이콘.
func _preview_text() -> String:
	return "?"


# ── 공용 소스 인터페이스 (클릭·드래그 공용) ────────────────
func get_move_payload() -> Dictionary:
	return {"kind": "move", "card": self}


func set_selected(sel: bool) -> void:
	_style.border_color = Palette.MAIN if sel else Palette.COCOA_200
	_style.set_border_width_all(2 if sel else 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.on_click(self)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	Move.begin_drag()
	set_drag_preview(_make_preview())
	return get_move_payload()


func _make_preview() -> Control:
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.MAIN, 2, 12))
	preview.modulate = Color(1, 1, 1, 0.92)
	preview.custom_minimum_size = size * 1.08   # 집은 카드보다 살짝 크게(들어올린 느낌)
	var lbl := UI.label(_preview_text(), 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(lbl)
	return preview
