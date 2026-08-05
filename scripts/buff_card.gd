class_name BuffCard
extends Card
## 슬롯에 놓이는 버프 카드(배치형). 슬롯 한 칸을 점유 → 작업공간과 트레이드오프.
## 이동(클릭/드래그, 슬롯↔슬롯)은 Card 베이스에서 제공. 휴지통엔 못 버림.
## (효과는 현재 '보유' 기준 — 슬롯에서 빼도 비활성화되진 않음. 빼기=비활성은 나중.)

var buff_id: String

func setup(id: String) -> void:
	buff_id = id

func is_trashable() -> bool:
	return false

# 선택 하이라이트: 버프 정체성(MAIN 테두리) 유지하며 두께만
func set_selected(sel: bool) -> void:
	_style.set_border_width_all(3 if sel else 2)

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

	var lbl := UI.label(BuffDefs.display_label(buff_id), 12, Palette.MAIN)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)
