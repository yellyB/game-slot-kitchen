class_name Recipes
extends RefCounted
## 레시피 정의 — 요리명 · 아이콘 · 필요재료[] · 조리시간(초).
## 재료 id는 Ingredients와 일치. 아이콘은 이모지 placeholder.

## 메뉴 6개 — 등급 1~6, 가격 1~30원(비쌀수록 수요↓, Stats.random_recipe에서 등급 가중).
## 종류/테마는 placeholder(미정) — 나중에 이름·아이콘·재료 교체. 경제·수요 곡선용.
## (카테고리 tag는 아직 안 넣음 — 카테고리 버프 설계 시 추가)
const ALL := {
	"coffee":  {"name": "커피",     "icon": "☕", "ingredients": ["bean", "water"], "cook_time": 3.0, "price": 1,  "tier": 1},
	"latte":   {"name": "라떼",     "icon": "🥛", "ingredients": ["bean", "milk", "water"], "cook_time": 4.0, "price": 3,  "tier": 2},
	"glazed":  {"name": "글레이즈드", "icon": "🍩", "ingredients": ["flour", "egg", "sugar"], "cook_time": 5.0, "price": 6,  "tier": 3},
	"choco":   {"name": "초코도넛",  "icon": "🍪", "ingredients": ["flour", "egg", "chocolate"], "cook_time": 5.0, "price": 10, "tier": 4},
	"cream":   {"name": "와플",     "icon": "🧇", "ingredients": ["flour", "egg", "milk"], "cook_time": 6.0, "price": 18, "tier": 5},
	"special": {"name": "케이크",    "icon": "🍰", "ingredients": ["flour", "egg", "chocolate", "milk"], "cook_time": 7.0, "price": 30, "tier": 6},
}

static func all_ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func random_id() -> String:
	var ids := ALL.keys()
	return ids[randi() % ids.size()]
