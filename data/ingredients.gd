class_name Ingredients
extends RefCounted
## 재료 정의 — id · 이름 · 아이콘(이모지 placeholder) · 해금 여부.
## 아이콘은 나중에 손그림(assets/)으로 교체. 순서 = 창고 타일 표시 순서.

## 순서 = 창고 타일 표시 순서(4열). 윗줄=베이킹(밀·계란·설탕·초콜릿),
## 아랫줄=디저트토핑+음료(크림·원두·우유·물) — 한 메뉴 재료가 뭉쳐 손 이동 최소화.
const ALL := {
	"flour":     {"name": "밀가루", "icon": "🌾", "unlocked": true},
	"egg":       {"name": "계란",   "icon": "🥚", "unlocked": true},
	"sugar":     {"name": "설탕",   "icon": "🧂", "unlocked": true},
	"chocolate": {"name": "초콜릿", "icon": "🍫", "unlocked": true},
	"cream":     {"name": "크림",   "icon": "🍦", "unlocked": true},
	"bean":      {"name": "원두",   "icon": "🌰", "unlocked": true},
	"milk":      {"name": "우유",   "icon": "🥛", "unlocked": true},
	"water":     {"name": "물",     "icon": "💧", "unlocked": true},
}

## 해금된 재료 id 목록 (표시 순서 유지).
static func unlocked_ids() -> Array:
	var out := []
	for id in ALL:
		if ALL[id]["unlocked"]:
			out.append(id)
	return out

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})


static var _tex_cache := {}
static var _tex_cache_sm := {}   # 초소형(주문서·조리목록) 48px 캐시

## 재료 손그림 텍스처(assets/art/ingredients/<id>.png). 없으면 null → 이모지 폴백.
static func tex(id: String, small := false) -> Texture2D:
	var cache: Dictionary = _tex_cache_sm if small else _tex_cache
	if not cache.has(id):
		var dir := "ingredients_48" if small else "ingredients_128"   # 작은 표시=48px, 카드=128px
		var path := "res://assets/art/%s/%s.png" % [dir, id]
		cache[id] = load(path) if ResourceLoader.exists(path) else null
	return cache[id]

## 재료 아이콘 노드 — 텍스처 있으면 TextureRect(px×px, 비율유지 중앙), 없으면 이모지 라벨(font=px).
static func icon_node(id: String, px: int) -> Control:
	var t := tex(id, px <= 30)   # 30px 이하(주문서·조리목록)는 48px 초소형 소스
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 원본 크기 무시(안 그럼 256px 강제)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 밉맵 OFF — 선명 우선(128 소스라 지글거림 적음)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label(str(get_def(id).get("icon", "?")), px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
