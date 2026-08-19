class_name Card
extends PanelContainer
## 슬롯에 놓이는 카드 공통 베이스. 소스 역할(클릭/드래그로 이동) 공용 구현.
## 서브클래스: IngredientCard(재료), OrderCard(주문서), DishCard(완성품).
## 서브클래스는 _build_content()로 내용을, is_trashable()/_preview_text()를 오버라이드.

var _style: StyleBoxFlat
var _wrap: Control   # 내용 래퍼 — 슬롯이 좁아지면(4열 등) 통째로 축소해 잘림 방지
var _content_min := Vector2.ZERO   # 내용 자연 크기(앵커 걸기 전 캡처) — fit 축소 기준

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 내용이 슬롯보다 크면(슬롯 축소 시) 슬롯을 밀지 말고 잘라냄 → 보드/화면 높이 고정.
	clip_contents = true
	_style = UI.card(Palette.WHITE, Palette.COCOA_200, 1, 12)
	# 슬롯이 이미 프레임/그림자를 주므로 카드 자체 그림자는 끔.
	# (그림자가 아래로 밀려 둥근 모서리 밖으로 회색 뾰족이 삐져나오는 현상 제거)
	_style.shadow_size = 0
	add_theme_stylebox_override("panel", _style)
	_build_content()
	_wrap_content()


## _build_content가 붙인 내용을 '컨테이너가 아닌' Control 래퍼로 감싼다.
## Control은 자식 min-size를 자기 min-size로 올리지 않으므로, 내용이 커도 카드→슬롯으로
## 전파되지 않아 보드/화면이 늘어나지 않음. 카드는 슬롯을 EXPAND_FILL로 그대로 꽉 채움.
## (내용은 래퍼를 앵커로 꽉 채우고, 슬롯이 작아지면 clip_contents로 잘림)
func _wrap_content() -> void:
	var built := get_children()   # _build_content가 self에 붙인 내용 노드들
	if built.is_empty():
		return
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in built:
		remove_child(ch)
		wrap.add_child(ch)
	add_child(wrap)
	_wrap = wrap
	resized.connect(_fit_wrap)   # 슬롯 크기 바뀌면 내용 축소 재계산
	_setup_fit()   # 자연 크기 측정 → 앵커 → 초기 fit (레이아웃 후)


## 내용 자연 크기를 측정한 뒤 FULL_RECT 앵커를 건다.
## (앵커를 먼저 걸면 컨테이너 min-size가 0으로 보고돼 축소 기준을 못 잡음. 또 _ready 시점엔
##  레이아웃 전이라 min-size가 0 → 한 프레임 기다렸다 측정.)
func _setup_fit() -> void:
	# 내용 자연 크기가 0이 아닌 값으로 잡힐 때까지 대기(최대 8프레임).
	# 한 프레임에 0이 잡히면 축소가 안 걸려(scale 1) 잘리는 "랜덤 잘림"을 방지.
	for _i in 8:
		await get_tree().process_frame
		if _wrap == null or not is_instance_valid(_wrap):
			return
		var m := Vector2.ZERO
		for ch in _wrap.get_children():
			if ch is Control:
				m = m.max((ch as Control).get_combined_minimum_size())
		if m.x > 0.0 or m.y > 0.0:
			_content_min = m
			break
	if _content_min.x <= 0.0 and _content_min.y <= 0.0:
		return   # 끝내 측정 실패(내용 없음 등) — 원본 그대로
	for ch in _wrap.get_children():
		if ch is Control:
			(ch as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_wrap()


## 내용(고정 px)이 카드보다 크면 래퍼를 통째로 축소해 잘림 방지(4열 등 슬롯 축소 시).
## 내용이 다 들어가면 scale=1(원래대로). 가로/세로 중 더 빡빡한 비율로 균일 축소.
const _FIT_MARGIN := 0.9   # 내용이 카드 가장자리에 닿지 않게 여백(균등한 안쪽 패딩)

func _fit_wrap() -> void:
	if _wrap == null or not is_instance_valid(_wrap):
		return
	if _content_min.x <= 0.0 and _content_min.y <= 0.0:
		return
	# 카드 전체(size)가 아니라 실제 내용 영역(_wrap.size = 콘텐츠 여백 제외)을 기준으로.
	var avail := _wrap.size
	if avail.x <= 0.0 or avail.y <= 0.0:
		return   # 아직 레이아웃 전(크기 0) — scale 0 되는 것 방지
	var raw := INF   # 내용이 딱 들어가는 배율(1=꽉참, <1=넘침)
	if _content_min.x > 0.0:
		raw = minf(raw, avail.x / _content_min.x)
	if _content_min.y > 0.0:
		raw = minf(raw, avail.y / _content_min.y)
	if raw == INF:
		return
	# 여백 곱한 뒤 1로 상한 — 넉넉하면 원래 크기(1), 빠듯/넘치면 여백 두고 축소.
	var s := minf(1.0, raw * _FIT_MARGIN)
	_wrap.pivot_offset = avail * 0.5   # 내용 영역 중앙 기준 → 상하좌우 균등
	_wrap.scale = Vector2(s, s)


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


## 드래그 프리뷰 아이콘 노드 — 서브클래스가 텍스처로 오버라이드 가능. 기본: 이모지 라벨.
func _preview_icon() -> Control:
	var lbl := UI.label(_preview_text(), 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _make_preview() -> Control:
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.MAIN, 2, 12))
	preview.modulate = Color(1, 1, 1, 0.92)
	preview.custom_minimum_size = size * 0.9   # 집은 카드보다 살짝 작게
	var ic := _preview_icon()
	ic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.add_child(ic)
	return preview
