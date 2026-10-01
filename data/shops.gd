class_name Shops
extends RefCounted
## 가게(런) 정의 — 선택 화면·콘텐츠 스왑용. 지금은 donut만 콘텐츠 있음.
## burger·ramen은 준비중(unlocked=false) — 화면엔 잠금 카드로만 표시.
## 이름/설명은 로케일 키 shop.<id> / shop.<id>.desc.

## econ = 가게 성격 값. 인내심·도착간격 모두 가게별로 직접 박음(가게끼리 독립 튜닝).
##   patience_order/dish = 손님 대기 초. spawn_gap_min/max = 손님 도착(방문) 간격 초.
##   spawn_weights = 티어별 손님 등장 가중(합 100, 인덱스=티어-1). (미지정 시 Config 기본값.)
## unlock_after_clear = 도넛 첫 클리어(cleared.flag) 후 해금.
const ALL := {
	"donut":  {"icon": "🍩", "art": "glazed", "unlocked": true,   # art=완성품 손그림(assets/art/recipes)
		"econ": {"patience_order": 25, "patience_dish": 35, "spawn_gap_min": 1.0, "spawn_gap_max": 2.5}},
	"burger": {"icon": "🍔", "unlock_after_clear": true,   # 러시: 인내심 짧고 도착 잦음
		"econ": {"patience_order": 20, "patience_dish": 28, "spawn_gap_min": 0.85, "spawn_gap_max": 2.1,
			"spawn_weights": [20, 20, 35, 25]}},   # 4메뉴: 버거(t3) 최다·치즈버거(t4) 2등·나머지 비슷
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

## 현재 가게의 경제 성격 값. 없으면 default.
static func econ(key: String, default := 1.0) -> float:
	return float(get_def(BuffDefs.current_shop).get("econ", {}).get(key, default))

## 현재 가게의 손님 대기 초(가게별 절대값). 미지정 시 Config 기본.
static func patience_order() -> float:
	return econ("patience_order", Config.PATIENCE_ORDER)

static func patience_dish() -> float:
	return econ("patience_dish", Config.PATIENCE_DISH)

## 현재 가게의 손님 도착(방문) 간격 초. 미지정 시 Config 기본.
static func spawn_gap_min() -> float:
	return econ("spawn_gap_min", Config.SPAWN_GAP_MIN)

static func spawn_gap_max() -> float:
	return econ("spawn_gap_max", Config.SPAWN_GAP_MAX)

## 현재 가게의 티어별 손님 등장 가중(인덱스=티어-1). 미지정 시 Config 기본.
static func spawn_weights() -> Array:
	return get_def(BuffDefs.current_shop).get("econ", {}).get("spawn_weights", Config.SPAWN_WEIGHTS)

static func icon_of(id: String) -> String:
	return str(get_def(id).get("icon", "🍽"))

static func name_of(id: String) -> String:
	return Loc.t("shop.%s" % id)

static func desc_of(id: String) -> String:
	return Loc.t("shop.%s.desc" % id)
