class_name Sheet
extends Panel
## 하단 시트 공용 베이스 — 아래서 슬라이드 업/다운.
## 서브클래스(창고·조리)가 _ready에서 하단 앵커·offset·내용을 구성한다.
## (하단 앵커 offset_top/bottom을 함께 tween → 크기 유지, 밀림 없음)

## 바텀시트 닫기 핸들 — 넓은 알약 + 아래로 향한 꺾쇠(∨). 상단 가운데(서랍 꼭대기)에 둠.
## 서브클래스가 pressed→close_requested 연결 + 헤더에 배치. [[상점 겹화살표와 동일한 draw 방식]]
func make_close_handle() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(80, 26)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	b.draw.connect(_draw_down_chevron.bind(b))
	return b


## 버튼 중앙에 아래로 향한 꺾쇠(∨)를 직접 그림 — 폰트 글리프 의존 없이 선명.
func _draw_down_chevron(b: Button) -> void:
	var w := 16.0
	var h := 7.0
	var th := 3.0
	var cx := b.size.x * 0.5
	var cy := b.size.y * 0.5
	var l := Vector2(cx - w * 0.5, cy - h * 0.5)
	var m := Vector2(cx, cy + h * 0.5)
	var r := Vector2(cx + w * 0.5, cy - h * 0.5)
	b.draw_polyline(PackedVector2Array([l, m, r]), Palette.COCOA_600, th, true)


## 하단에서 슬라이드 업 등장.
func slide_open() -> void:
	visible = true
	var rt := offset_top
	var rb := offset_bottom
	var d := -rt + 20.0   # 화면 밖(아래)까지 이동 거리
	offset_top = rt + d
	offset_bottom = rb + d
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset_top", rt, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "offset_bottom", rb, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 아래로 슬라이드 다운 후 숨김.
func slide_close() -> void:
	if not visible:
		return
	var rt := offset_top
	var rb := offset_bottom
	var d := -rt + 20.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset_top", rt + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "offset_bottom", rb + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		visible = false
		offset_top = rt
		offset_bottom = rb)


## 오른쪽 화면 밖 → 왼쪽으로 슬라이드 인(서랍). 우측 앵커 시트용.
func slide_open_side() -> void:
	visible = true
	var rl := offset_left
	var rr := offset_right
	var d := get_viewport_rect().size.x   # 화면 밖(오른쪽)까지 이동 거리
	offset_left = rl + d
	offset_right = rr + d
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset_left", rl, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "offset_right", rr, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 오른쪽으로 슬라이드 아웃 후 숨김(서랍 닫기).
func slide_close_side() -> void:
	if not visible:
		return
	var rl := offset_left
	var rr := offset_right
	var d := get_viewport_rect().size.x
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "offset_left", rl + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "offset_right", rr + d, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		visible = false
		offset_left = rl
		offset_right = rr)
