class_name Card
extends PanelContainer
## 슬롯에 놓이는 카드 공통 베이스. 소스 역할(클릭/드래그로 이동) 공용 구현.
## 서브클래스: IngredientCard(재료), OrderCard(주문서), DishCard(완성품).
## 서브클래스는 _build_content()로 내용을, is_trashable()/_preview_text()를 오버라이드.

var _style: StyleBoxFlat
var _wrap: Control     # 카드 내용영역을 꽉 채우는 래퍼(full-rect)
var _holder: Control   # 내용을 담는 안쪽 홀더 — 자연 크기로 중앙 배치 후 통째 축소(균등 여백)
var _content_min := Vector2.ZERO   # 내용 자연 크기(앵커 전 측정) — fit 기준

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
	# _wrap: 카드 내용영역을 꽉 채움. _holder: 그 안에서 내용을 담아 중앙배치+축소.
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(holder)
	for ch in built:
		remove_child(ch)
		holder.add_child(ch)
	add_child(wrap)
	_wrap = wrap
	_holder = holder
	# 슬롯 크기 바뀌면 재계산 — resized 시점엔 size가 아직 정착 전일 수 있어 deferred로.
	resized.connect(func(): _fit_wrap.call_deferred())
	_setup_fit()   # 자연 크기 측정 → 앵커 → 초기 fit (레이아웃 후)


## 내용 자연 크기를 측정한 뒤 FULL_RECT 앵커를 건다.
## (앵커를 먼저 걸면 컨테이너 min-size가 0으로 보고돼 축소 기준을 못 잡음. 또 _ready 시점엔
##  레이아웃 전이라 min-size가 0 → 여러 프레임 누적 최댓값으로 측정.)
func _setup_fit() -> void:
	for _i in 8:
		await get_tree().process_frame
		if _holder == null or not is_instance_valid(_holder):
			return
		for ch in _holder.get_children():
			if ch is Control:
				_content_min = _content_min.max((ch as Control).get_combined_minimum_size())
	if _content_min.x <= 0.0 and _content_min.y <= 0.0:
		return   # 끝내 측정 실패(내용 없음 등) — 원본 그대로
	for ch in _holder.get_children():
		if ch is Control:
			(ch as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_wrap()


## 내용을 자연 크기(_content_min)로 홀더에 담아 카드 중앙에 놓고, 카드보다 크면 통째로 축소.
## 홀더를 '자연 크기 이상'으로 잡아 좌우 대칭이 되게 → 축소해도 중앙 정렬(오른쪽 쏠림 방지).
## 내용이 다 들어가면 scale=1(완성품 아이콘 등은 홀더가 내용영역을 꽉 채워 그대로 큼).
const _FIT_MARGIN := 0.9   # 내용이 카드 가장자리에 닿지 않게 여백(균등한 안쪽 패딩)

func _fit_wrap() -> void:
	if _wrap == null or not is_instance_valid(_wrap) or _holder == null:
		return
	if _content_min.x <= 0.0 and _content_min.y <= 0.0:
		return
	var avail := _wrap.size   # 카드 내용영역(full-rect). deferred라 갱신 완료 상태.
	if avail.x <= 0.0 or avail.y <= 0.0:
		return
	# 홀더 크기 = max(자연 크기, 내용영역) — 넘칠 땐 자연 크기(대칭), 넉넉할 땐 내용영역(꽉 참).
	var target := Vector2(maxf(_content_min.x, avail.x), maxf(_content_min.y, avail.y))
	_holder.size = target
	_holder.position = (avail - target) * 0.5   # 내용영역 중앙(넘치면 좌우로 대칭 오버플로)
	_holder.pivot_offset = target * 0.5
	var raw := minf(avail.x / _content_min.x, avail.y / _content_min.y)
	var s := minf(1.0, raw * _FIT_MARGIN)   # 넉넉하면 1(그대로), 빠듯/넘치면 여백 두고 축소
	_holder.scale = Vector2(s, s)


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
	# 레이아웃 전엔 size=0 → pivot(중앙)이 (0,0)이 돼 좌상단으로 축소돼 보임.
	# 그래서 첫 프레임은 투명하게 숨겨(레이아웃 크기 계산은 유지) 좌상단 깜빡임을 없애고,
	# 크기 확정 후 '중앙 기준'으로 작게 시작해 커지게 한다.
	modulate.a = 0.0
	await get_tree().process_frame   # 레이아웃 후 크기 확정
	if not is_instance_valid(self):
		return
	pivot_offset = size * 0.5        # 중앙 기준 스케일
	scale = Vector2(0.6, 0.6)
	modulate.a = 1.0
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
