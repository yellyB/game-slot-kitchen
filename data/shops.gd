class_name Shops
extends RefCounted
## 가게(런) 정의 — 선택 화면·콘텐츠 스왑용. 지금은 donut만 콘텐츠 있음.
## burger·ramen은 준비중(unlocked=false) — 화면엔 잠금 카드로만 표시.
## 이름/설명은 로케일 키 shop.<id> / shop.<id>.desc.

const ALL := {
	"donut":  {"icon": "🍩", "art": "glazed", "unlocked": true},   # art=완성품 손그림(assets/art/recipes)
	"burger": {"icon": "🍔", "unlocked": false},
	"ramen":  {"icon": "🍜", "unlocked": false},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func is_unlocked(id: String) -> bool:
	return bool(get_def(id).get("unlocked", false))

static func icon_of(id: String) -> String:
	return str(get_def(id).get("icon", "🍽"))

static func name_of(id: String) -> String:
	return Loc.t("shop.%s" % id)

static func desc_of(id: String) -> String:
	return Loc.t("shop.%s.desc" % id)
