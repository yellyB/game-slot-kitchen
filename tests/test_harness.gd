class_name TestHarness
extends RefCounted
## 개발용 경량 테스트 하니스. 실제 Main 씬을 구동해 엣지케이스를 검증.
## 실행: godot4 --headless res://scenes/Main.tscn -- --test
## 새 테스트는 _cases()에 메서드 하나 추가하면 됨. _check(이름, 조건)으로 단언.

var _m               # Main 노드
var _tree: SceneTree
var _last := {}      # 마지막 day_ended summary (member라 캡처 안전)
var _pass := 0
var _fail := 0


func run(main) -> void:
	_m = main
	_tree = main.get_tree()
	_m._title.hide()
	_m._session.day_ended.connect(func(s): _last = s)  # member 대입이라 밖에서 보임

	for case in _cases():
		await case.call()

	print("\n[TEST] ===== %d PASS / %d FAIL =====" % [_pass, _fail])
	_tree.quit(1 if _fail > 0 else 0)


func _cases() -> Array:
	return [
		_t_win_boundary,
		_t_lose_boundary,
		_t_buffs_over_slots,
		_t_serve_matching,
		_t_session_cleanup,
		_t_trash_rules,
		_t_board_full_quick,
		_t_buff_cap,
		_t_price_rarity,
	]


# ── 케이스들 ──────────────────────────────────────────────
func _t_win_boundary() -> void:
	var s = _m._session
	s.start_run(); s.day = Levels.count(); s.start_day()
	s.cash = s.rent           # 딱 가게세만큼
	s._end_day()
	_check("승패경계: cash==rent → 통과", _last.get("passed") == true)
	_check("승패경계: 마지막날 통과 → 승리", _last.get("won") == true)
	_reset()


func _t_lose_boundary() -> void:
	var s = _m._session
	s.start_run(); s.day = 3; s.start_day()
	s.cash = s.rent - 1       # 1 부족
	s._end_day()
	_check("승패경계: cash<rent → 게임오버", _last.get("passed") == false)
	_reset()


func _t_buffs_over_slots() -> void:
	_m._session.start_run()          # start_run이 버프 초기화
	for i in 9: Buffs.add("cook")    # 많이 사도 캡(3)까지만
	_m._session.start_day()          # 배치 반영
	await _tree.process_frame
	var placed := 0
	for sl in _m._board.slots:
		if sl.get_card() is BuffCard: placed += 1
	_check("버프 배치 = 보유 캡(%d)" % Config.MAX_BUFFS, placed == Config.MAX_BUFFS)
	_check("버프 캡으로 여유 슬롯 남음(softlock 방지)", _m._board.first_empty_slot() != null)
	_reset()


func _t_serve_matching() -> void:
	_m._session.start_run()
	await _tree.process_frame
	var order := OrderCard.new(); order.setup("coffee")
	_m._board.slots[0].place_card(order)
	var wrong := DishCard.new(); wrong.setup("glazed")
	var right := DishCard.new(); right.setup("coffee")
	_check("서빙매칭: 안 맞는 요리 거부", order.can_accept(wrong.get_move_payload()) == false)
	_check("서빙매칭: 맞는 요리 수락", order.can_accept(right.get_move_payload()) == true)
	wrong.free(); right.free()
	_reset()


func _t_session_cleanup() -> void:
	var s = _m._session
	s.start_run()
	await _tree.process_frame
	_m._board.slots[1].place_new("flour")
	_m._spawn_customer()
	s.advance_day()           # 다음날 → 정리
	await _tree.process_frame
	var occ := 0
	for sl in _m._board.slots:
		if not sl.is_empty(): occ += 1
	_check("세션전환: 다음날 슬롯 전부 비움", occ == 0)
	_check("세션전환: 큐 비움", _m._queue_row.get_child_count() == 0)
	_reset()


func _t_trash_rules() -> void:
	var ing := IngredientCard.new(); ing.setup("flour")
	var order := OrderCard.new(); order.setup("coffee")
	_check("휴지통: 재료는 버릴 수 있음", _m._trash_btn.can_accept(ing.get_move_payload()) == true)
	_check("휴지통: 주문서는 못 버림", _m._trash_btn.can_accept(order.get_move_payload()) == false)
	ing.free(); order.free()


func _t_board_full_quick() -> void:
	var s = _m._session
	s.start_run()
	await _tree.process_frame
	for sl in _m._board.slots:      # 모든 슬롯 채우기
		sl.place_new("flour")
	# quick 배치 시도 → 빈 슬롯 없어도 크래시 없어야
	var ok := Move.quick({"kind": "new", "id": "egg"})
	_check("판꽉참: quick 배치 거부(크래시X)", ok == false)
	_reset()


func _t_buff_cap() -> void:
	Buffs.clear()
	for i in 5: Buffs.add("cook")   # 상한 초과 시도
	_check("버프 보유 상한 %d장" % Config.MAX_BUFFS, Buffs.owned().size() == Config.MAX_BUFFS)
	_reset()


func _t_price_rarity() -> void:
	# 비싼(고등급) 메뉴가 싼 것보다 덜 등장하는지
	Buffs.clear()
	var cheap := 0   # tier1 커피
	var pricey := 0  # tier6 스페셜
	for i in 400:
		var r := Stats.random_recipe()
		if r == "coffee": cheap += 1
		elif r == "special": pricey += 1
	_check("가격-희귀도: 비싼 메뉴가 싼 메뉴보다 드묾", cheap > pricey)
	_reset()


# ── 유틸 ──────────────────────────────────────────────────
func _reset() -> void:
	for ch in _m.get_children():
		if ch is Modal: ch.free()
	Buffs.clear()


func _check(name: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[TEST] PASS  ", name)
	else:
		_fail += 1
		print("[TEST] FAIL  ", name)
