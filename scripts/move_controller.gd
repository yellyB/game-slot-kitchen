extends Node
## 공용 이동 컨트롤러 (autoload "Move").
## 모든 이동(창고→슬롯, 슬롯→슬롯, 슬롯→휴지통 …)을 하나의 규칙으로 통합.
##
## 소스(옮길 수 있는 것): get_move_payload() -> Dictionary  (없으면 {} )
## 타깃(받는 곳):        can_accept(payload) -> bool / accept(payload) -> void
##
## 클릭-투-클릭과 드래그앤드롭이 같은 payload·can_accept·accept를 사용한다.
##  - 클릭: on_click(node) — 타깃 우선 → 소스 선택 → 해제
##  - 드래그: 타깃의 _can_drop_data → can_accept, _drop_data → on_drop

signal performed  ## 이동 성공 시 (보드 상태 갱신용)

var _payload: Dictionary = {}
var _source: Object = null


func has_selection() -> bool:
	return not _payload.is_empty()


## 인터랙티브 요소를 클릭했을 때 호출.
func on_click(node: Object) -> void:
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


## 드래그앤드롭에서 타깃이 _drop_data 안에서 호출.
func on_drop(target: Object, payload: Dictionary) -> void:
	if target.has_method("can_accept") and target.can_accept(payload):
		target.accept(payload)
		performed.emit()


## 드래그 시작 시 소스가 호출 — 진행 중이던 클릭 선택을 정리.
func begin_drag() -> void:
	clear()


func background_click() -> void:
	clear()


func _select(node: Object, payload: Dictionary) -> void:
	clear()
	_payload = payload
	_source = node
	if node.has_method("set_selected"):
		node.set_selected(true)


func clear() -> void:
	if _source != null and is_instance_valid(_source) and _source.has_method("set_selected"):
		_source.set_selected(false)
	_payload = {}
	_source = null
