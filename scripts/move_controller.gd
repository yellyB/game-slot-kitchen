extends Node
## 공용 이동 컨트롤러 (autoload "Move").
## 모든 이동(창고→슬롯, 슬롯→슬롯, 슬롯→휴지통 …)을 하나의 규칙으로 통합.
##
## 소스(옮길 수 있는 것): get_move_payload() -> Dictionary  (없으면 {} )
## 타깃(받는 곳):        can_accept(payload) -> bool / accept(payload) -> void
##
## 두 가지 공용 동작:
##  - move : 소스 선택(클릭) → 타깃 클릭, 또는 드래그. (슬롯↔슬롯·서빙 등)
##  - quick: 소스 클릭 즉시 기본 타깃(첫 빈 슬롯)에 배치. 드래그는 특정 타깃. (창고 꺼내기 등)
##    quick 소스는 is_quick()==true. 기본 타깃은 default_target(payload)로 결정.
##
## 클릭-투-클릭과 드래그앤드롭이 같은 payload·can_accept·accept를 사용한다.

signal performed  ## 동작 성공 시 (보드 상태 갱신용)

## quick 동작의 기본 타깃 제공자: func(payload) -> Node (예: 첫 빈 슬롯). main이 주입.
var default_target := Callable()

var _payload: Dictionary = {}
var _source: Object = null


func has_selection() -> bool:
	return not _payload.is_empty()


## 인터랙티브 요소를 클릭했을 때 호출.
func on_click(node: Object) -> void:
	# 선택된 소스가 그새 free됐으면(주문 만료·재료 소비 등) 선택 정리
	if _source != null and not is_instance_valid(_source):
		_payload = {}
		_source = null

	# quick 소스: 클릭 즉시 기본 타깃(첫 빈 슬롯)에 배치 (선택 모드 X)
	if node.has_method("is_quick") and node.is_quick() and node.has_method("get_move_payload"):
		clear()
		quick(node.get_move_payload())
		return

	# 이미 선택된 소스를 다시 클릭 → 선택 해제 (토글)
	if node == _source:
		clear()
		return

	# 선택 중이고 node가 payload를 받을 수 있으면 → 이동 실행
	if has_selection() and node.has_method("can_accept") and node.can_accept(_payload):
		node.accept(_payload)
		clear()
		performed.emit()
		return

	# node가 소스면 → 선택(또는 다른 소스로 전환)
	if node.has_method("get_move_payload"):
		var p: Dictionary = node.get_move_payload()
		if not p.is_empty():
			_select(node, p)
			return

	# 그 외 → 선택 해제
	clear()


## quick 배치 — payload를 기본 타깃(첫 빈 슬롯)에 즉시 넣는다. 성공 시 true.
func quick(payload: Dictionary) -> bool:
	if default_target.is_null() or payload.is_empty():
		return false
	var target = default_target.call(payload)
	if target != null and is_instance_valid(target) \
			and target.has_method("can_accept") and target.can_accept(payload):
		target.accept(payload)
		performed.emit()
		return true
	return false


## 드래그앤드롭에서 타깃이 _drop_data 안에서 호출.
func on_drop(target: Object, payload: Dictionary) -> void:
	if target.has_method("can_accept") and target.can_accept(payload):
		target.accept(payload)
		performed.emit()


## 드래그 시작 시 소스가 호출 — 진행 중이던 클릭 선택을 정리.
func begin_drag() -> void:
	clear()
	Audio.play("card_pick")   # 카드 집기음(드래그 시작)


func background_click() -> void:
	clear()


func _select(node: Object, payload: Dictionary) -> void:
	clear()
	_payload = payload
	_source = node
	if node.has_method("set_selected"):
		node.set_selected(true)
	Audio.play("card_pick")   # 카드 집기음(클릭 선택)


func clear() -> void:
	if _source != null and is_instance_valid(_source) and _source.has_method("set_selected"):
		_source.set_selected(false)
	_payload = {}
	_source = null
