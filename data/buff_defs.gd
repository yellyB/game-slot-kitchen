class_name BuffDefs
extends RefCounted
## 버프 정의 — 단순 패시브(자동 적용). 곱연산 스택.
## stat: cook_mult(조리시간) · price_mult(판매가) · patience_mult(인내심) · warehouse_mult(창고비용)
##
## [버프 추가 규칙] 효과는 Stats(수치 단일 관리소)로 표현 가능해야 한다.
##  - 기존 stat 재사용: 여기 항목 한 줄만 추가(코드 변경 0).
##  - 새 대상 값: 여기 + Stats에 getter 하나 추가, 소비처는 그 getter만 조회.
##  - Stats 배율로 표현 불가한 특수 효과(분기·이벤트성): 추가 재고(무분별한 분기 금지).

const ALL := {
	"cook":      {"name": "조리 속도", "icon": "⚡", "stat": "cook_mult", "value": 0.75, "label": "조리 -25%"},
	"price":     {"name": "판매가",   "icon": "💰", "stat": "price_mult", "value": 1.25, "label": "판매가 +25%"},
	"patience":  {"name": "인내심",   "icon": "⏳", "stat": "patience_mult", "value": 1.10, "label": "인내심 +10%"},
	"warehouse": {"name": "창고 속도", "icon": "🏃", "stat": "warehouse_mult", "value": 0.7, "label": "창고 -30%"},
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
