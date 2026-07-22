extends Node
## 활성 버프 상태 (autoload "Buffs"). 런 동안 보유한 버프의 곱연산 배율 제공.
## 어디서나 Buffs.cook_mult() 등으로 조회. 새 런 시작 시 clear().

var _owned: Array[String] = []

func clear() -> void:
	_owned.clear()

func add(id: String) -> void:
	if _owned.size() >= Config.MAX_BUFFS:
		return
	_owned.append(id)

func is_full() -> bool:
	return _owned.size() >= Config.MAX_BUFFS

func owned() -> Array[String]:
	return _owned

# ── 단일 적용 게이트웨이 ──────────────────────────────────
## base 값에 해당 stat 버프를 전부 곱해 반환. 모든 효과 적용은 여기로.
##   stat: cook_mult · price_mult · patience_mult · warehouse_mult
func mod(stat: String, base: float) -> float:
	var m := 1.0
	for id in _owned:
		var def := BuffDefs.get_def(id)
		if def.get("stat", "") == stat:
			m *= float(def.get("value", 1.0))
	return base * m
