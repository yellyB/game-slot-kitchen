class_name BuffDefs
extends RefCounted
## 버프 정의 — 단순 패시브(자동 적용). 곱연산 스택.
## stat: cook_mult(조리시간) · price_mult(판매가) · patience_mult(인내심) · warehouse_mult(창고비용)

const ALL := {
	"cook":      {"name": "조리 속도", "icon": "⚡", "stat": "cook_mult", "value": 0.85, "label": "-15%"},
	"price":     {"name": "판매가",   "icon": "💰", "stat": "price_mult", "value": 1.25, "label": "+25%"},
	"patience":  {"name": "인내심",   "icon": "⏳", "stat": "patience_mult", "value": 1.25, "label": "+25%"},
	"warehouse": {"name": "창고 속도", "icon": "🏃", "stat": "warehouse_mult", "value": 0.7, "label": "-30%"},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

## 팩: 서로 다른 버프 n개 랜덤.
static func random_pack(n := 3) -> Array:
	var pool := ALL.keys()
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))
