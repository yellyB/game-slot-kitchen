class_name Recipes
extends RefCounted
## 레시피 정의 — 요리명 · 아이콘 · 필요재료[] · 조리시간(초).
## 재료 id는 Ingredients와 일치. 아이콘은 이모지 placeholder.

## 메뉴 6개 — 등급 1~6, 가격 100~2000원(비쌀수록 수요↓, Stats.random_recipe에서 등급 가중).
## 종류/테마는 placeholder(미정) — 나중에 이름·아이콘·재료 교체. 경제·수요 곡선용.
## (카테고리 tag는 아직 안 넣음 — 카테고리 버프 설계 시 추가)
const ALL := {
	"coffee":  {"name": "커피",     "icon": "☕", "ingredients": ["bean", "water"], "cook_time": 3.0, "price": 100,  "tier": 1},
	"latte":   {"name": "라떼",     "icon": "🥛", "ingredients": ["bean", "milk"], "cook_time": 4.0, "price": 200,  "tier": 2},
	"glazed":  {"name": "글레이즈드", "icon": "🍩", "ingredients": ["flour", "egg", "sugar"], "cook_time": 5.0, "price": 600,  "tier": 3},
	"choco":   {"name": "초코도넛",  "icon": "🍪", "ingredients": ["flour", "egg", "chocolate"], "cook_time": 5.0, "price": 800,  "tier": 4},
	"tiramisu": {"name": "티라미수",  "icon": "🍮", "ingredients": ["bean", "cream", "sugar"], "cook_time": 6.0, "price": 1200, "tier": 5},
	"special": {"name": "초코케이크",  "icon": "🍰", "ingredients": ["flour", "cream", "sugar", "chocolate"], "cook_time": 7.0, "price": 2000, "tier": 6},
}

static func all_ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func random_id() -> String:
	var ids := ALL.keys()
	return ids[randi() % ids.size()]


static var _tex_cache := {}

## 완성품 손그림 텍스처(assets/art/recipes/<id>.png). 없으면 null → 이모지 폴백.
static func tex(id: String) -> Texture2D:
	if not _tex_cache.has(id):
		var path := "res://assets/art/recipes/%s.png" % id
		_tex_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[id]

## 메뉴/완성품 아이콘 노드 — 텍스처 있으면 TextureRect(px×px), 없으면 이모지 라벨(font=px).
static func icon_node(id: String, px: int) -> Control:
	var t := tex(id)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # 작게 축소 시 깨짐 방지
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label(str(get_def(id).get("icon", "?")), px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
