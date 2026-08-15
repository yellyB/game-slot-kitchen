class_name Sheet
extends Panel
## 하단 시트 공용 베이스 — 아래서 슬라이드 업/다운.
## 서브클래스(창고·조리)가 _ready에서 하단 앵커·offset·내용을 구성한다.
## (하단 앵커 offset_top/bottom을 함께 tween → 크기 유지, 밀림 없음)

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
