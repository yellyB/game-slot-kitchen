class_name BuffCard
extends Card
## 슬롯에 놓이는 버프 카드(배치형). 슬롯 한 칸을 점유 → 작업공간과 트레이드오프.
## 넣고빼기(이동)는 나중 구현 — 지금은 뽑으면 세션 시작 시 슬롯 자동 점유.

var buff_id: String

func setup(id: String) -> void:
	buff_id = id

func is_trashable() -> bool:
	return false

# 이동은 나중 — 지금은 선택/드래그 비활성(슬롯 점유만)
func get_move_payload() -> Dictionary:
	return {}

func _get_drag_data(_at_position: Vector2) -> Variant:
	return null

func _gui_input(_event: InputEvent) -> void:
	pass

func _build_content() -> void:
	var def := BuffDefs.get_def(buff_id)
	_style.bg_color = Palette.MAIN.lightened(0.82)  # 연분홍 = 버프 구분
	_style.border_color = Palette.MAIN
	_style.set_border_width_all(2)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	add_child(v)

	var icon := UI.label(str(def.get("icon", "?")), 30)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(icon)

	var lbl := UI.label(str(def.get("label", "")), 12, Palette.MAIN)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)
