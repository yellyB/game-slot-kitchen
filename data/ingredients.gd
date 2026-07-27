class_name Ingredients
extends RefCounted
## 재료 정의 — id · 이름 · 아이콘(이모지 placeholder) · 해금 여부.
## 아이콘은 나중에 손그림(assets/)으로 교체. 순서 = 창고 타일 표시 순서.

const ALL := {
	"flour":     {"name": "밀가루", "icon": "🌾", "unlocked": true},
	"egg":       {"name": "계란",   "icon": "🥚", "unlocked": true},
	"sugar":     {"name": "설탕",   "icon": "🧂", "unlocked": true},
	"chocolate": {"name": "초콜릿", "icon": "🍫", "unlocked": true},
	"bean":      {"name": "원두",   "icon": "🌰", "unlocked": true},
	"milk":      {"name": "우유",   "icon": "🥛", "unlocked": true},
	"water":     {"name": "물",     "icon": "💧", "unlocked": true},
	"cream":     {"name": "크림",   "icon": "🍦", "unlocked": true},
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
