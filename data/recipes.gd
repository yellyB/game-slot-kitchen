class_name Recipes
extends RefCounted
## 레시피 정의 — 요리명 · 아이콘 · 필요재료[] · 조리시간(초).
## 재료 id는 Ingredients와 일치. 아이콘은 이모지 placeholder.

const ALL := {
	"glazed": {"name": "글레이즈드", "icon": "🍩", "ingredients": ["flour", "egg", "sugar"], "cook_time": 5.0},
	"choco":  {"name": "초코도넛",   "icon": "🍩", "ingredients": ["flour", "egg", "chocolate"], "cook_time": 5.0},
	"coffee": {"name": "커피",       "icon": "☕", "ingredients": ["bean", "water"], "cook_time": 3.0},
}

static func all_ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func random_id() -> String:
	var ids := ALL.keys()
	return ids[randi() % ids.size()]
