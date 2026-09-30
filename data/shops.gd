class_name Shops
extends RefCounted
## 가게(런) 정의 — 선택 화면·콘텐츠 스왑용. 지금은 donut만 콘텐츠 있음.
## burger·ramen은 준비중(unlocked=false) — 화면엔 잠금 카드로만 표시.
## 이름/설명은 로케일 키 shop.<id> / shop.<id>.desc.

## econ = 가게 성격 계수(인내심·도착간격 배수 등). 없으면 1.0(도넛=기본).
## unlock_after_clear = 도넛 첫 클리어(cleared.flag) 후 해금.
const ALL := {
	"donut":  {"icon": "🍩", "art": "glazed", "unlocked": true},   # art=완성품 손그림(assets/art/recipes)
	"burger": {"icon": "🍔", "unlock_after_clear": true, "econ": {"patience_mult": 0.8, "spawn_gap_mult": 0.85}},   # 러시: 인내심 −20%·도착 −15%
	"ramen":  {"icon": "🍜", "unlocked": false},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func is_unlocked(id: String) -> bool:
	var d := get_def(id)
	if d.get("unlock_after_clear", false):
		return FileAccess.file_exists("user://cleared.flag")   # 도넛 첫 클리어 후 해금
	return bool(d.get("unlocked", false))

## 현재 가게의 경제 성격 계수. 없으면 default(도넛=기본값).
static func econ(key: String, default := 1.0) -> float:
	return float(get_def(BuffDefs.current_shop).get("econ", {}).get(key, default))

static func icon_of(id: String) -> String:
	return str(get_def(id).get("icon", "🍽"))

static func name_of(id: String) -> String:
	return Loc.t("shop.%s" % id)

static func desc_of(id: String) -> String:
	return Loc.t("shop.%s.desc" % id)
