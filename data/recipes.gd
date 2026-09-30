class_name Recipes
extends RefCounted
## 레시피 정의 — 요리명 · 아이콘 · 필요재료[] · 조리시간(초).
## 재료 id는 Ingredients와 일치. 아이콘은 이모지 placeholder.

## 가게별 메뉴 테이블 — 등급 1~6(비쌀수록 수요↓, Stats.random_recipe에서 등급 가중).
## 현재 가게(BuffDefs.current_shop)로 all()이 골라줌 — 호출부는 그대로 all_ids/get_def 사용.
const BANK := {
	# 도넛 카페(균형형).
	"donut": {
		"coffee":  {"name": "커피",     "icon": "☕", "ingredients": ["bean", "water"], "cook_time": 3.0, "price": 1,  "tier": 1},
		"latte":   {"name": "라떼",     "icon": "🥛", "ingredients": ["bean", "milk"], "cook_time": 4.0, "price": 2,  "tier": 2},
		"glazed":  {"name": "글레이즈드", "icon": "🍩", "ingredients": ["flour", "egg", "sugar"], "cook_time": 5.0, "price": 6,  "tier": 3},
		"choco":   {"name": "초코도넛",  "icon": "🍪", "ingredients": ["flour", "egg", "chocolate"], "cook_time": 5.0, "price": 8,  "tier": 4},
		"tiramisu": {"name": "티라미수",  "icon": "🍮", "ingredients": ["bean", "cream", "sugar"], "cook_time": 6.0, "price": 12, "tier": 5},
		"special": {"name": "초코케이크",  "icon": "🍰", "ingredients": ["flour", "cream", "sugar", "chocolate"], "cook_time": 7.0, "price": 20, "tier": 6},
	},
	# 버거 가게(러시·세트/프리메이크). 조리 카페보다 −1s(2~6s). 세트=다재료 단일 레시피(콤보 로직 아님).
	"burger": {
		"icecream":     {"name": "아이스크림",   "icon": "🍦", "ingredients": ["cream", "sugar"], "cook_time": 2.0, "price": 1,  "tier": 1},
		"shake":        {"name": "셰이크",       "icon": "🥤", "ingredients": ["milk", "cream"], "cook_time": 2.0, "price": 2,  "tier": 2},
		"burger":       {"name": "버거",         "icon": "🍔", "ingredients": ["bun", "patty"], "cook_time": 3.0, "price": 4,  "tier": 3},
		"cheeseburger": {"name": "치즈버거",     "icon": "🍔", "ingredients": ["bun", "patty", "cheese"], "cook_time": 4.0, "price": 6,  "tier": 4},
		"burgerset":    {"name": "버거세트",     "icon": "🍟", "ingredients": ["bun", "patty", "potato", "cola"], "cook_time": 5.0, "price": 12, "tier": 5},
		"cheeseset":    {"name": "치즈버거세트", "icon": "🍟", "ingredients": ["bun", "patty", "cheese", "potato", "cola"], "cook_time": 6.0, "price": 20, "tier": 6},
	},
}

## 현재 가게의 메뉴 테이블. current_shop이 BANK에 없으면 도넛으로 폴백.
static func all() -> Dictionary:
	return BANK.get(BuffDefs.current_shop, BANK["donut"])

static func all_ids() -> Array:
	return all().keys()

static func get_def(id: String) -> Dictionary:
	return all().get(id, {})

static func random_id() -> String:
	var ids := all().keys()
	return ids[randi() % ids.size()]


static var _tex_cache := {}
static var _tex_cache_sm := {}   # 초소형(주문서·조리목록) 48px 캐시

## 완성품 손그림 텍스처(assets/art/recipes/<id>.png). 없으면 null → 이모지 폴백.
static func tex(id: String, small := false) -> Texture2D:
	var cache: Dictionary = _tex_cache_sm if small else _tex_cache
	if not cache.has(id):
		var dir := "recipes_48" if small else "recipes_128"   # 작은 표시=48px, 그 외=128px
		var path := "res://assets/art/%s/%s.png" % [dir, id]
		cache[id] = load(path) if ResourceLoader.exists(path) else null
	return cache[id]

## 메뉴/완성품 아이콘 노드 — 텍스처 있으면 TextureRect(px×px), 없으면 이모지 라벨(font=px).
static func icon_node(id: String, px: int) -> Control:
	var t := tex(id, px <= 30)   # 30px 이하(주문서·조리목록)는 48px 초소형 소스
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 밉맵 OFF — 선명 우선(리사이즈 소스)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label(str(get_def(id).get("icon", "?")), px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
