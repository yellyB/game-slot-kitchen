class_name Customers
extends RefCounted
## 손님(동물) 캐릭터 — 상반신 아트. assets/art/customers/customer_<id>.png.
## 큐 손님·주문서 얼굴에 랜덤 배정.

const IDS := ["bear", "rabbit", "fox", "cat", "dog"]

static var _tex_cache := {}

static func random_id() -> String:
	return IDS[randi() % IDS.size()]

static var _tex_cache_sm := {}   # 초소형(≤30px) 48px 캐시

static func tex(id: String, small := false) -> Texture2D:
	var cache: Dictionary = _tex_cache_sm if small else _tex_cache
	if not cache.has(id):
		var dir := "customers_48" if small else "customers_128"   # 작은 표시=48px, 그 외=128px
		var path := "res://assets/art/%s/customer_%s.png" % [dir, id]
		cache[id] = load(path) if ResourceLoader.exists(path) else null
	return cache[id]

## 손님 아이콘 노드 — 텍스처 있으면 TextureRect(px, 밉맵 필터), 없으면 이모지 폴백.
static func icon_node(id: String, px: int) -> Control:
	var t := tex(id, px <= 30)   # ≤30px(주문서 손님 등)는 48px 초소형 소스
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 밉맵 OFF — 선명(리사이즈 소스)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label("🙋", px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
