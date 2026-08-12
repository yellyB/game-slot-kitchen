extends Control
## 메인 게임 화면 — 코디네이터.
## 레이아웃 조립 + 손님 큐/스포너 + 경제(돈·서빙) 담당.
## 슬롯 그리드=Board, 창고=Warehouse, 조리=Cooking, 이동=Move(autoload)로 위임.

var _board: Board
var _warehouse: Warehouse
var _cooking: Cooking
var _backdrop: ColorRect
var _session: Session
var _title: TitleScreen

var _warehouse_btn: Button
var _trash_btn: TrashButton

var _queue_row: HBoxContainer

# 하루 정산(day_end_bonus) 집계 — day_started에서 리셋. sim_core의 하루 스코프 카운터와 동치.
var _visited_today := 0     # 등장 손님 수
var _accepted_today := 0    # 주문 접수 수(슬롯 주문 카드 생성)
var _served_today := 0      # 서빙 완료 수
var _order_lost_today := 0  # 주문 낸 손님이 못 받고 떠난 수(음식대기 만료)
var _served_by_menu := {}   # 메뉴별 서빙 수 → 같은메뉴 최대(63·samemenu)

var _day_label: Label
var _money_label: Label
var _rent_label: Label
var _last_cash := 0   # 돈 증감 방향 판별(증가 시 라벨 팝)용
var _expect_fly := false   # true면 이번 증가는 _fly_gain 도착 때 팝(즉시 팝 생략)
var _hours_bar: ProgressBar
var _hours_glow: Tween      # 마감 임박 펄스
var _hours_warning := false  # 임박 상태 진입 여부(전환 시 1회만 처리)
var _blackout: ColorRect    # 폐업 암전 오버레이
var _last_countdown := 0    # 막판 카운트다운 마지막 표시 초(중복 방지)
const COUNTDOWN_FROM := 5   # 마감 몇 초 전부터 카운트다운


func _ready() -> void:
	# 배경 크림 — 빈 곳 클릭 시 선택 해제 캐처
	var bg := ColorRect.new()
	bg.color = Palette.COCOA_50
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_background_input)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(_build_top_bar())
	if OS.is_debug_build():   # 운영(릴리스) 빌드에선 디버그 바 숨김
		col.add_child(_build_debug())
	col.add_child(_build_customer_queue())

	_board = Board.new()
	_board.tool_tapped.connect(_on_tool_tapped)
	# 보드가 큐~하단버튼 사이 남는 세로 공간을 차지 → 슬롯이 늘어도 그 공간에 맞춰
	# 열 수·슬롯 크기를 자동 조절(하단 버튼이 잘리지 않음). [[Board._relayout]]
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_board)

	col.add_child(_build_bottom_buttons())

	# 시트 백드롭 — 시트 열리면 뒤쪽(보드·큐·버튼) 입력 차단, 바깥 탭 = 닫기
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.164, 0.129, 0.106, 0.28)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	# 시트는 백드롭 위에
	_warehouse = Warehouse.new()
	_warehouse.close_requested.connect(_close_sheets)
	add_child(_warehouse)
	_cooking = Cooking.new()
	_cooking.board = _board
	_cooking.close_requested.connect(_close_sheets)
	_cooking.cooked.connect(_on_cooked)
	add_child(_cooking)

	Move.performed.connect(_refresh_warehouse)
	# quick 동작(창고 클릭)의 기본 타깃 = 첫 빈 슬롯
	Move.default_target = func(_payload): return _board.first_empty_slot()

	# 세션(하루 루프)
	_session = Session.new()
	_session.cash_changed.connect(_on_cash_changed)
	_session.progress.connect(_on_progress)
	_session.spawn_requested.connect(_spawn_customer)
	_session.day_started.connect(_on_day_started)
	_session.day_closing.connect(_on_day_closing)   # 마감 정산(63~65,73,50)
	_session.day_ended.connect(_on_day_ended)
	add_child(_session)

	# 완성품 나이(dish_age) 스탬프용 게임 클록을 세션 경과시간에 연결.
	_board.now_provider = _session.now

	# 시작(타이틀) 화면 — 앱 실행 시 게임 위에 덮음. [시작] → 게임 시작.
	_title = TitleScreen.new()
	_title.start_pressed.connect(_start_game)
	_title.tutorial_pressed.connect(_start_tutorial)
	add_child(_title)

	# 개발용 테스트 하니스 (릴리스엔 영향 없음): godot4 ... -- --test
	if OS.is_debug_build() and "--test" in OS.get_cmdline_user_args():
		await TestHarness.new().run(self)

	# 헤드리스 시뮬레이션: godot4 ... -- --sim
	if "--sim" in OS.get_cmdline_user_args():
		var batch := SimBatch.new()
		var n := 200
		print("\n[SIM] ===== 생존 시뮬 (판당 5일, %d회, 상점 ON) =====" % n)
		var s := batch.run(n, [], true)   # 빈 로드아웃 = 상점으로 스스로 성장
		print("[SIM] 승률 %.1f%%  최종현금 %.0f  서빙 %.1f  놓침 %.1f  슬롯 %.1f  버프 %.1f  일수 %.1f" % [
			s["win_rate"] * 100.0, s["avg_cash"], s["avg_served"], s["avg_lost"],
			s["avg_slots"], s["avg_buffs"], s["avg_days"]])
		get_tree().quit()


## 홈 버튼 — 확인창(진행 중인 판이 사라짐).
func _on_home_pressed() -> void:
	Modal.open(self) \
		.title(Loc.t("home_title")) \
		.row(Loc.t("home_warn"), Palette.COCOA_600) \
		.button(Loc.t("go_home"), _go_home) \
		.button(Loc.t("cancel"), func(): pass)


## 진행 중인 판을 접고 타이틀로. 다음 [시작] 때 start_run이 전부 리셋.
func _go_home() -> void:
	_session.set_process(false)   # 세션 정지(시계·스폰)
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false
	_clear_blackout()
	for s in _board.slots:        # 슬롯 전부 비움(버프 포함 — 새 런)
		s.clear()
	for t in _board.tools:
		t.reset()
	for c in _queue_row.get_children():
		c.queue_free()
	for ch in get_children():     # 열린 상점/모달 잔재 제거
		if ch is Shop or ch is Modal:
			ch.queue_free()
	_show_title()


func _start_game() -> void:
	_title.hide()
	_session.start_run()


func _show_title() -> void:
	_title.show()


## 독립 튜토리얼 진입 — 본격 게임(세션)과 분리. 끝나면 타이틀 복귀.
func _start_tutorial() -> void:
	_title.hide()
	var tut := Tutorial.new()
	tut.finished.connect(func():
		tut.queue_free()
		_show_title())
	add_child(tut)


# ── 상단바: 일차·돈·가게세 + 영업시간 바 ──────────────────────
func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.card(Palette.WHITE))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pad.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	# 홈(타이틀)으로 — 진행 중인 판 포기(확인창). 좌상단, 돈·가게세와 안 겹치게 작게.
	var home := Button.new()
	home.text = "🏠"
	home.add_theme_font_size_override("font_size", 16)
	home.custom_minimum_size = Vector2(34, 34)
	home.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	home.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	home.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	home.pressed.connect(_on_home_pressed)
	Audio.attach_click(home)
	row.add_child(home)

	_day_label = UI.label(Loc.t("day_n") % 1, 20, Palette.COCOA_800, true)
	row.add_child(_day_label)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	# 돈 (소지금)
	var coin := HBoxContainer.new()
	coin.add_theme_constant_override("separation", 4)
	coin.add_child(_dot(Palette.ACCENT))
	_money_label = UI.label("0", 18, Palette.COCOA_800, true)
	coin.add_child(_money_label)
	row.add_child(coin)

	# 가게세
	var rentbox := HBoxContainer.new()
	rentbox.add_theme_constant_override("separation", 4)
	rentbox.add_child(_dot(Palette.DANGER))
	_rent_label = UI.label("0", 18, Palette.COCOA_800, true)
	rentbox.add_child(_rent_label)
	row.add_child(rentbox)

	var hours := HBoxContainer.new()
	hours.add_theme_constant_override("separation", 8)
	box.add_child(hours)

	hours.add_child(UI.label("☀️", 14, Palette.COCOA_400))

	_hours_bar = ProgressBar.new()
	_hours_bar.min_value = 0
	_hours_bar.max_value = 100
	_hours_bar.value = 0
	_hours_bar.show_percentage = false
	_hours_bar.custom_minimum_size = Vector2(0, 14)
	_hours_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hours_bar.add_theme_stylebox_override("background", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	_hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.ACCENT))
	hours.add_child(_hours_bar)

	hours.add_child(UI.label("🌙", 14, Palette.COCOA_400))

	return panel


# ── 디버그 바 (개발용) ────────────────────────────────────
func _build_debug() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UI.label("🐞", 14, Palette.COCOA_400))
	row.add_child(_debug_btn("돈+10만", func(): _session.add_cash(100000)))
	row.add_child(_debug_btn("돈-5만", func(): _session.add_cash(-50000)))
	row.add_child(_debug_btn("즉시종료", func(): _session.debug_end_soon(1.0)))
	row.add_child(_debug_btn("손님내보냄", _debug_kick_customer))
	return row


## 디버그: 손님 하나 강제 이탈. 슬롯 주문서(순회 순서 첫 번째) 먼저, 없으면 대기열 첫 손님.
func _debug_kick_customer() -> void:
	for s in _board.slots:
		var c := s.get_card()
		if c is OrderCard:
			(c as OrderCard).force_expire()
			return
	for ch in _queue_row.get_children():
		if ch is Customer:
			(ch as Customer).force_expire()
			return


func _debug_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Palette.COCOA_800)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	b.pressed.connect(cb)
	return b


# ── 손님 큐 ───────────────────────────────────────────────
func _build_customer_queue() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.card(Palette.COCOA_100, Palette.COCOA_200))
	panel.custom_minimum_size = Vector2(0, 96)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(pad)

	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 8)
	pad.add_child(_queue_row)

	return panel


# ── 하단 버튼: 창고 · 휴지통 ───────────────────────────────
func _build_bottom_buttons() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)

	_warehouse_btn = _make_bottom_button(Palette.MAIN)
	_warehouse_btn.text = "🏬"
	_warehouse_btn.pressed.connect(_toggle_warehouse)
	row.add_child(_warehouse_btn)

	_trash_btn = TrashButton.new()
	_trash_btn.text = "🗑️"
	_style_bottom_button(_trash_btn, Palette.SUB)
	row.add_child(_trash_btn)

	return row


# ── 상호작용 ──────────────────────────────────────────────
func _toggle_warehouse() -> void:
	if _warehouse.visible:
		_close_sheets()
	else:
		_open_warehouse()


func _open_warehouse() -> void:
	_cooking.visible = false
	_backdrop.visible = true
	_warehouse.slide_open()   # 아래서 슬라이드 업
	Audio.play("door_open")   # 창고 들어감(문 열림)
	_refresh_warehouse()


func _on_tool_tapped(tool: ToolStation) -> void:
	_warehouse.visible = false
	_backdrop.visible = true
	_cooking.open_for(tool)


func _close_sheets() -> void:
	# 창고 퇴장 = 트립 비용(영업시간 3초 소모). 세션 진행 중일 때만(spend_time가 가드).
	if _warehouse.visible:
		_session.spend_time(Stats.warehouse_cost())
		Audio.play("door_close")   # 창고 나옴(문 닫힘)
		_warehouse.slide_close()   # 아래로 슬라이드 다운
	if _cooking.visible:
		_cooking.slide_close()
	_backdrop.visible = false


func _on_cooked() -> void:
	_close_sheets()
	_refresh_warehouse()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_close_sheets()


func _refresh_warehouse() -> void:
	_warehouse.refresh(_board.is_full())


func _process(_delta: float) -> void:
	_refresh_servable()


## 주문 카드에 "지금 서빙 가능"(매칭 완성품이 보드에 있음) 발광 표시 갱신.
## 완성품은 도구 타이머로 생겨 신호가 없어 매 프레임 폴링(주문 몇 개라 저렴, set_servable가 가드).
func _refresh_servable() -> void:
	if _board == null:
		return
	var ready := _board.available_dish_ids()
	for s in _board.slots:
		var c := s.get_card()
		if c is OrderCard:
			c.set_servable(ready.has(c.recipe_id))


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		Move.background_click()


# ── 손님 / 주문 ───────────────────────────────────────────
func _spawn_customer() -> void:
	if _queue_row.get_child_count() >= Config.MAX_QUEUE:
		return
	var c := Customer.new()
	c.setup(Stats.random_recipe())
	c.confirm_pressed.connect(_on_confirm_order)
	c.expired.connect(_on_customer_expired)
	c.urged.connect(_on_urged)
	_queue_row.add_child(c)
	c.slide_in()   # 오른쪽에서 슬라이드 인 등장
	Audio.play("customer_in")   # 손님 방문음
	_visited_today += 1   # 정산(served_ratio)용 등장 손님 집계 — sim_core._on_spawn과 동치


## 주문 확인 → 손님이 큐에서 사라지고 다음 빈 슬롯의 주문 카드로 "이동".
func _on_confirm_order(customer: Customer) -> void:
	# 주문 상한 — 나머지 슬롯은 재료/완성품(조리 공간)용으로 남김.
	if _board.slot_counts()["orders"] >= Config.MAX_ORDERS:
		Toast.show_msg(self, Loc.t("orders_full"))
		return
	var slot := _board.first_empty_slot()
	if slot == null:
		Toast.show_msg(self, Loc.t("no_empty_slot"))
		return
	var rid := customer.recipe_id
	var order := OrderCard.new()
	order.setup(rid)
	order.born = _session.now()   # 주문 접수 시각 스탬프 — 판매 ctx의 order_age(빠른/느린 서빙 카드)
	order.expired.connect(_on_order_expired)
	order.served.connect(_on_served)
	order.rejected.connect(_on_order_rejected)
	order.urged.connect(_on_urged)
	# 주문서가 클릭한 손님 자리에서 슬롯으로 날아가 안착.
	# 자리는 착지까지 유지(dismiss=투명 홀드) → 뒤 손님이 즉시 안 밀려 "그 손님 주문서"로 읽힘.
	var from_pos := customer.global_position + customer.size * 0.5
	customer.dismiss()
	_fly_order_to_slot(order, slot, from_pos)
	get_tree().create_timer(0.36).timeout.connect(func():
		if is_instance_valid(customer):
			customer.queue_free())   # 착지 후 제거 → 그때 큐가 좁혀짐
	_accepted_today += 1
	# 카드60: N번째 주문마다 즉시 완성품 생성(재료·조리 생략).
	if Buffs.consume_instant_order():
		_produce_dish(rid)
	_refresh_warehouse()


## 완성품을 즉시 생성해 보드에 올림(카드60 즉시완료 등). 유휴 도구석 우선, 없으면 빈 슬롯.
func _produce_dish(rid: String) -> void:
	for t in _board.tools:
		if t.is_idle():
			t.produce_instant(rid)
			return
	var s := _board.first_empty_slot()
	if s == null:
		return
	var dish := DishCard.new()
	dish.setup(rid)
	dish.born = _session.now()
	s.place_card(dish)


## 인내심 임박 재촉 — 카드 위에 💢 팝(카드 흔들림은 카드가 자체 처리).
func _on_urged(card: Control) -> void:
	if not is_instance_valid(card):
		return
	_spawn_pop("💢", card.global_position + Vector2(card.size.x * 0.5, -8))


func _on_customer_expired(customer: Customer) -> void:
	_spawn_pop("😠", customer.global_position + customer.size * 0.5)   # 성난 손님 이탈
	_detach_and_fade(customer)


## 음식 대기 인내심 0 → 주문 카드(=손님) 통째로 사라짐, 슬롯 회복.
func _on_order_expired(order: OrderCard) -> void:
	# 카드71·72: 주문 낸 손님이 못 받고 떠나면 보상(72는 다음 획득 2배 예약).
	var gain := Buffs.on_lost(order.recipe_id)
	if gain != 0:
		_expect_fly = true   # 이번 증가 팝은 _fly_gain 도착 때
		_session.earn(gain)
		_expect_fly = false
		_fly_gain(gain, order.global_position + order.size * 0.5, Palette.SUB)
	_order_lost_today += 1
	_spawn_pop("😠", order.global_position + order.size * 0.5)   # 성난 손님 이탈
	_detach_and_fade(order)   # 슬롯에서 떼어내며 페이드아웃(슬롯 즉시 회복)
	_refresh_warehouse()


## 완성품이 매칭 주문 카드에 서빙됨 → 돈 + 손님 퇴장 + 슬롯/도구 회복.
## 안 맞는 완성품 서빙 시도 → 😠 팝(카드 흔들림은 OrderCard가 처리).
func _on_order_rejected(order: OrderCard) -> void:
	_spawn_pop("😠", order.global_position + order.size * 0.5)


func _on_served(order: OrderCard, dish: DishCard) -> void:
	Audio.play("serve")   # 서빙 완료음(리워드)
	var rid := order.recipe_id
	# 판매금 계산(판매금/추가금/콤보/적립 전 카드) — sim_core._serve와 동일한 훅.
	var ctx := _sale_ctx(order, dish)
	var res := Buffs.sale_amount(rid, ctx)
	var amount := int(res["amount"])
	_expect_fly = true   # 이번 증가 팝은 _fly_gain 도착 때
	_session.earn(amount)
	_expect_fly = false
	# 리스크(56 등) 패널티: 소지금 차감(매출 집계 X)
	var penalty := int(res.get("penalty", 0))
	if penalty != 0:
		_session.add_cash(-penalty)
	# 자기폐기(48 등): 발동한 버프를 보드/보유에서 제거
	var discard_id := str(res.get("discard", ""))
	if discard_id != "":
		Buffs.discard(discard_id)
		_remove_buff_card(discard_id)
	# 판매 후 누적(램프24~29·트리거42~44·즉시주문60 카운터)
	Buffs.on_serve(rid, ctx)
	# 하루 정산 집계
	_served_today += 1
	_served_by_menu[rid] = int(_served_by_menu.get(rid, 0)) + 1

	var serve_pos := order.global_position + order.size * 0.5
	_fly_gain(amount, serve_pos)   # +금액이 돈 라벨로 날아가 합류
	_spawn_pop("😊", serve_pos + Vector2(0, -18))   # 만족한 손님 팝

	var holder := order.get_parent()
	if holder:
		holder.remove_child(order)
	order.queue_free()

	# 완성품 제거: 도구석 위면 도구 회복(제거 포함), 슬롯이면 슬롯에서 제거
	if dish != null and is_instance_valid(dish):
		if dish.tool != null:
			dish.tool.reset()
		else:
			var dp := dish.get_parent()
			if dp:
				dp.remove_child(dish)
			dish.queue_free()

	_refresh_warehouse()


## 판매 ctx — sim_core._sale_ctx와 같은 필드. 보드 실제 상태에서 구성.
func _sale_ctx(order: OrderCard, dish: DishCard) -> Dictionary:
	var counts := _board.slot_counts()
	var orders: int = counts["orders"]
	var dishes: int = counts["dishes"]
	var ingr: int = counts["ingr"]
	var empty: int = counts["empty"]
	var now := _session.now()
	var dish_born := dish.born if (dish != null and is_instance_valid(dish)) else now
	return {
		"filled": orders + dishes + ingr,
		"empty": empty,
		"orders": orders,
		"dishes": dishes,
		"ingr": ingr,
		"buffs": Buffs.owned().size(),
		"now": now,
		"dish_age": now - dish_born,
		"order_age": now - order.born,
		"pat_frac": order.pat_frac(),
		"cash": _session.cash,
		"day_revenue": _session.day_revenue,
	}


## 자기폐기(48) 버프 카드를 보드에서 제거(보유 목록은 Buffs.discard가 처리).
func _remove_buff_card(buff_id: String) -> void:
	for s in _board.slots:
		var c := s.get_card()
		if c is BuffCard and c.buff_id == buff_id:
			s.clear()
			return


## 마감 정산 훅(가게세 차감 전) — 정산 보너스/차감(63~65,73,50)을 세션에 반영.
func _on_day_closing(s: Session) -> void:
	var same_max := 0
	for k in _served_by_menu:
		same_max = maxi(same_max, int(_served_by_menu[k]))
	var ctx := {
		"served": _served_today,
		"visited": _visited_today,
		"accepted": _accepted_today,
		"order_lost": _order_lost_today,
		"same_max": same_max,
		"day_revenue": s.day_revenue,
		"cash": s.cash,
		"rent": s.rent,
	}
	var bonus := Buffs.day_end_bonus(ctx)
	if bonus != 0:
		s.earn(bonus)


## 이탈 연출 — 카드를 부모(슬롯/큐)에서 떼어내 제자리에서 쪼그라들며 페이드아웃 후 제거.
## 슬롯은 즉시 회복(remove_child)되고, 카드는 최상위로 옮겨 잔상만 남긴다.
func _detach_and_fade(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var gpos := card.global_position
	var sz := card.size
	var holder := card.get_parent()
	if holder:
		holder.remove_child(card)
	add_child(card)
	card.top_level = true          # 컨테이너 정렬 영향 배제 — 좌표 고정
	card.global_position = gpos
	card.size = sz
	card.z_index = 90
	card.pivot_offset = sz * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(card.queue_free)


## 주문 확인 연출 — 주문서가 손님 자리(from_pos)에서 목표 슬롯으로 스윽 날아가 안착.
## 실물 카드는 슬롯에 즉시 안착(점유)하되 도착 전까지 숨기고, 겉보기 고스트만 날린다.
## (실물을 top_level로 날렸다 되돌리면 컨테이너 재정렬이 안 돼 좌표가 틀어지므로 고스트로 분리.)
func _fly_order_to_slot(card: OrderCard, slot: Slot, from_pos: Vector2) -> void:
	slot.place_card(card, false, false)   # 점유만 — 팝·소리는 도착 때
	if not is_instance_valid(card) or card.get_parent() == null:
		return
	# 착지 목표는 슬롯 기하로 확정 — 갓 놓인 카드의 폭 확장 전 측정을 피함(좁게 날던 버그).
	var rect := slot.card_rect()
	var dest := rect.position             # 슬롯에서의 최종 좌표(좌상단)
	var sz := rect.size
	card.modulate.a = 0.0                 # 도착 시 공개

	# 손님 자리→슬롯으로 날아가는 고스트(실물과 동일 외형).
	var ghost := OrderCard.new()
	ghost.setup(card.recipe_id)
	add_child(ghost)
	ghost.set_process(false)              # 인내심 타이머 등 로직 정지
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.top_level = true                # 컨테이너 정렬 배제 — 좌표 직접 제어
	ghost.z_index = 95
	ghost.size = sz
	ghost.pivot_offset = sz * 0.5
	ghost.global_position = from_pos - sz * 0.5
	ghost.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "global_position", dest, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(ghost):
			ghost.queue_free()
		if is_instance_valid(card):
			card.modulate.a = 1.0
			card.pop_in()                 # 실물 공개 + 배치 팝
		Audio.play("card_place"))         # 안착음(탁)


## 팝 버스트 — 작게 나타나 크게 튀며(스케일) 살짝 떠오르다 사라짐. 서빙 성공 😊 등.
func _spawn_pop(text: String, at_pos: Vector2) -> void:
	var l := UI.label(text, 30)
	l.z_index = 101
	l.pivot_offset = Vector2(15, 15)
	add_child(l)
	l.position = at_pos - Vector2(15, 15)
	l.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2(1.3, 1.3), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 22, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


# ── 공용 헬퍼 ─────────────────────────────────────────────
func _dot(color: Color) -> Control:
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(14, 14)
	var wrap := CenterContainer.new()
	wrap.add_child(dot)
	return wrap


# ── 세션 반응 ─────────────────────────────────────────────
func _on_cash_changed(cash: int) -> void:
	var delta := cash - _last_cash
	_last_cash = cash
	_money_label.text = UI.money(cash)
	if delta > 0 and not _expect_fly:   # fly 없는 증가(디버그 등)는 즉시 팝
		_pop_label(_money_label)
		Audio.play("coins")             # 소지금 증가음(동전)
	elif delta < 0:                     # 감소(가게세·페널티) → 빨간 -n 아래로
		_spawn_loss(-delta)
		Audio.play("coins")             # 소지금 감소음(동전)


## 폐업 암전 — 화면을 서서히 어둡게(COCOA_900) 덮은 뒤 콜백(게임오버 모달) 실행.
func _fade_to_black(cb: Callable) -> void:
	_clear_blackout()
	_blackout = ColorRect.new()
	_blackout.color = Palette.COCOA_900
	_blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blackout.modulate.a = 0.0
	_blackout.z_index = 290   # 필드 위, 모달(z300) 아래
	_blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blackout)
	var tw := create_tween()
	tw.tween_property(_blackout, "modulate:a", 0.82, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(cb)


func _clear_blackout() -> void:
	if _blackout != null and is_instance_valid(_blackout):
		_blackout.queue_free()
	_blackout = null


## 승리 축포 — 팔레트 색 색종이가 화면 위에서 흩날리며 떨어져 페이드아웃. 모달 위(z 350).
func _spawn_confetti(count := 46) -> void:
	var vp := get_viewport_rect().size
	var colors := [Palette.MAIN, Palette.SUB, Palette.ACCENT, Palette.SUCCESS, Palette.DANGER]
	for i in count:
		var p := ColorRect.new()
		p.color = colors[i % colors.size()]
		p.size = Vector2(8, 12)
		p.z_index = 350   # 모달(z 300) 위로
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.pivot_offset = p.size * 0.5
		add_child(p)
		p.position = Vector2(randf_range(vp.x * 0.15, vp.x * 0.85), -20.0)
		var tw := create_tween()
		tw.set_parallel(true)
		var fall := randf_range(vp.y * 0.55, vp.y * 0.95)
		var drift := randf_range(-90.0, 90.0)
		var dur := randf_range(1.0, 1.8)
		tw.tween_property(p, "position", p.position + Vector2(drift, fall), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "rotation", randf_range(-6.0, 6.0), dur)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(p.queue_free)


## 하루 시작 배너 — 화면 중앙 위쪽에 큰 "N일차"가 팝인 → 잠깐 유지 → 페이드아웃.
func _show_day_banner(day: int) -> void:
	var l := UI.label(Loc.t("day_n") % day, 48, Palette.COCOA_800, true)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	l.z_index = 200
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	await get_tree().process_frame   # 크기 확보 → 중앙 정렬·피벗
	if not is_instance_valid(l):
		return
	var vp := get_viewport_rect().size
	l.pivot_offset = l.size * 0.5
	l.position = (vp - l.size) * 0.5 - Vector2(0, vp.y * 0.12)   # 정중앙보다 살짝 위
	l.scale = Vector2(0.6, 0.6)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## 손실 연출 — 보유금액 바로 아래에서 빨간 "-금액"이 아래로 이동하며 페이드아웃.
func _spawn_loss(amount: int) -> void:
	if amount <= 0:
		return
	var l := UI.label("-" + UI.money(amount), 18, Palette.DANGER, true)
	l.z_index = 100
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	add_child(l)
	var start := _money_label.global_position + Vector2(0, _money_label.size.y + 2)
	l.position = start
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", start.y + 26, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


## 라벨 강조 팝 — 살짝 커졌다 원래대로(BACK). 돈 라벨 합류 시 등.
func _pop_label(lbl: Control) -> void:
	lbl.pivot_offset = lbl.size * 0.5   # 중앙 기준 스케일
	lbl.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## 획득 연출 — "+금액"이 획득 위치에서 상단 돈 라벨로 날아가 합쳐지고, 도착 시 라벨 팝.
func _fly_gain(amount: int, from_pos: Vector2, color := Palette.SUCCESS) -> void:
	if amount == 0:
		return
	var l := UI.label("+" + UI.money(amount), 20, color, true)
	l.z_index = 100
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	add_child(l)
	l.position = from_pos
	await get_tree().process_frame   # 라벨 크기 확보 → 피벗 중앙
	if not is_instance_valid(l):
		return
	l.pivot_offset = l.size * 0.5
	var target := _money_label.global_position + _money_label.size * 0.5 - l.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "scale", Vector2(0.55, 0.55), 0.45).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if is_instance_valid(l):
			l.queue_free()
		_pop_label(_money_label)   # 합류 → 보유금액 통통
		Audio.play("coins"))       # 도착 시 동전음(서빙 수입 등)


func _on_progress(t01: float) -> void:
	_hours_bar.value = t01 * 100.0
	if t01 >= Config.HOURS_WARN_FRAC and not _hours_warning:   # 마감 임박 진입
		_hours_warning = true
		_hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.DANGER))
		_hours_glow = create_tween().set_loops()
		_hours_glow.tween_property(_hours_bar, "modulate:a", 0.45, 0.35).set_trans(Tween.TRANS_SINE)
		_hours_glow.tween_property(_hours_bar, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	# 막판 카운트다운 — 마지막 COUNTDOWN_FROM초, 정수 초가 바뀔 때마다 숫자 팝
	var left := _session.time_left()
	if left > 0.0 and left <= COUNTDOWN_FROM:
		var sec := int(ceil(left))
		if sec != _last_countdown:
			_last_countdown = sec
			_countdown_pop(sec)
	else:
		_last_countdown = 0


## 막판 카운트다운 숫자 — 화면 중앙 위쪽에 큰 빨간 숫자 팝 후 페이드.
func _countdown_pop(sec: int) -> void:
	var l := UI.label(str(sec), 46, Palette.DANGER, true)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	l.z_index = 200
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	await get_tree().process_frame
	if not is_instance_valid(l):
		return
	var vp := get_viewport_rect().size
	l.pivot_offset = l.size * 0.5
	l.position = (vp - l.size) * 0.5 - Vector2(0, vp.y * 0.15)
	l.scale = Vector2(1.6, 1.6)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.1)
	tw.tween_interval(0.25)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## 영업시간 바를 평상 상태로 되돌림(색·펄스 리셋).
func _reset_hours_bar() -> void:
	if _hours_glow != null:
		_hours_glow.kill()
		_hours_glow = null
	_hours_bar.modulate.a = 1.0
	_hours_warning = false
	_hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.ACCENT))


func _on_day_started(day: int, rent: int) -> void:
	_day_label.text = Loc.t("day_n") % day
	# 하루 시작 홀드 — 플레이 화면만 먼저 보이고, 게임플레이(시계·스폰)는 잠깐 멈춤.
	# DAY_INTRO_DELAY 뒤에 재개 + "N일차" 배너 + 시작음(그때 재생).
	_session.set_process(false)
	get_tree().create_timer(Config.DAY_INTRO_DELAY).timeout.connect(func():
		if not is_inside_tree() or _title.visible:
			return
		_session.set_process(true)   # 시계·손님 스폰 시작
		_show_day_banner(day)        # 화면 중앙 "N일차" 배너
		Audio.play("day_start"))     # 하루 시작 효과음
	_rent_label.text = UI.money(rent)
	_hours_bar.value = 0
	_reset_hours_bar()   # 새 하루 — 바 색·펄스 초기화
	_last_countdown = 0  # 카운트다운 상태 리셋
	_clear_blackout()    # 폐업 암전 잔재 제거(재도전 시)
	# 새 세션 시작 — 시트 강제 닫기(트립 비용 없음)
	_warehouse.visible = false
	_cooking.visible = false
	_backdrop.visible = false
	# 하루 정산 카운터 리셋(sim_core._reset_day_consumables와 동치)
	_visited_today = 0
	_accepted_today = 0
	_served_today = 0
	_order_lost_today = 0
	_served_by_menu = {}
	Buffs.reset_day()   # #45 적립 하루 리셋
	# 보드 재구성: 작업 슬롯 = 실효 슬롯(상점확장 + 구조버프12 slot_bonus).
	#   추가로 버프칸 보너스(11 buff_slot)만큼 슬롯을 더 둬서 그만큼 버프가 "공짜"로 얹히게 함
	#   → 순 작업공간 = effective_slots - max(0, 보유버프수 - buff_slot_bonus) (sim_core._serve_cap과 동치).
	Move.clear()
	_board.rebuild(_session.effective_slots() + Buffs.buff_slot_bonus())
	# 보유 버프는 슬롯을 점유(배치형) — 작업공간과 트레이드오프
	for id in Buffs.owned():
		var slot := _board.first_empty_slot()
		if slot:
			var bc := BuffCard.new()
			bc.setup(id)
			slot.place_card(bc, false)   # 버프 재배치는 무음(매일 리빌드 버스트 방지)
	for c in _queue_row.get_children():
		c.queue_free()
	_refresh_warehouse()


## 하루 종료 시 필드 정리 — 재료·주문·완성품·큐 제거(타이머 즉시 정지). 버프 카드는 유지.
func _clear_play_field() -> void:
	for s in _board.slots:
		if s.get_card() is BuffCard:
			continue   # 버프 카드는 남김(플레이어 빌드)
		s.clear()
	for t in _board.tools:
		t.reset()
	for c in _queue_row.get_children():
		c.queue_free()


## 마감 연출 — 잠깐 정지 → 남은 슬롯 카드 팝 소멸. (호출측이 이후 정산 모달)
func _dayend_sequence() -> void:
	_freeze_field()
	await get_tree().create_timer(Config.DAY_END_PAUSE).timeout   # 잠깐 정지(마감 여운)
	await _pop_clear_slots()
	for t in _board.tools:
		t.reset()
	for c in _queue_row.get_children():
		c.queue_free()


## 남은 카드·손님 타이머 정지(제거는 아직 — 팝 연출 후).
func _freeze_field() -> void:
	for s in _board.slots:
		var c := s.get_card()
		if c != null:
			c.set_process(false)
	for t in _board.tools:
		t.set_process(false)
	for c in _queue_row.get_children():
		c.set_process(false)


## 남은 슬롯 카드(버프 제외)를 하나씩 팝 소멸 — 스태거. 마지막 트윈까지 await.
func _pop_clear_slots() -> void:
	var cards: Array = []
	for s in _board.slots:
		var c := s.get_card()
		if c != null and not (c is BuffCard):
			cards.append(c)
	if cards.is_empty():
		return
	var last: Tween = null
	var i := 0
	for c in cards:
		c.set_process(false)
		if c.has_method("set_servable"):
			c.set_servable(false)   # 서빙 발광 트윈 정지(스케일 충돌 방지)
		c.pivot_offset = c.size * 0.5
		var tw := create_tween()
		tw.tween_interval(i * 0.07)   # 하나씩 이어서
		tw.tween_property(c, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2(0.05, 0.05), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.16)
		last = tw
		i += 1
	if last != null:
		await last.finished
	for s in _board.slots:
		if not (s.get_card() is BuffCard):
			s.clear()


func _on_day_ended(summary: Dictionary) -> void:
	if summary["won"]:
		_clear_play_field()   # 마감 즉시 필드 비움
		Modal.open(self) \
			.title(Loc.t("win_title")) \
			.stamp_row(Loc.t("win_days") % Levels.count(), Palette.SUCCESS, 0.15) \
			.button(Loc.t("to_title"), _show_title)
		_spawn_confetti()   # 축포 한 번
		get_tree().create_timer(0.5).timeout.connect(_spawn_confetti.bind(46))   # 0.5s 뒤 한 번 더
	elif summary["passed"]:
		# 카운트다운 종료 → 1초 정지 → 남은 슬롯 카드 팝 소멸 → 그 뒤 정산 모달.
		await _dayend_sequence()
		Modal.open(self) \
			.title(Loc.t("day_closed") % summary["day"]) \
			.count_row(Loc.t("revenue"), summary["revenue"]) \
			.count_row(Loc.t("rent"), summary["rent"], Palette.DANGER) \
			.sep() \
			.count_row(Loc.t("remaining"), summary["cash_after"], Palette.COCOA_800) \
			.stamp_row(Loc.t("passed"), Palette.SUCCESS) \
			.button(Loc.t("to_shop"), _open_shop)
	else:
		_clear_play_field()   # 마감 즉시 필드 비움
		_fade_to_black(func():   # 폐업 암전 후 게임오버 모달
			Modal.open(self) \
				.title(Loc.t("gameover_title")) \
				.row(Loc.t("gameover_day") % summary["day"]) \
				.row(Loc.t("gameover_reason") % [UI.money(summary["revenue"]), UI.money(summary["rent"])], Palette.DANGER) \
				.button(Loc.t("to_title"), _show_title))


## 결과 → 인터세션 상점 (슬롯 확장 등) → [영업 시작] → 다음 세션.
func _open_shop() -> void:
	var shop := Shop.new()
	shop.session = _session
	shop.start_business.connect(_session.advance_day)
	add_child(shop)


func _make_bottom_button(color: Color) -> Button:
	var b := Button.new()
	_style_bottom_button(b, color)
	return b


func _style_bottom_button(b: Button, color: Color) -> void:
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Palette.WHITE)
	b.add_theme_color_override("font_hover_color", Palette.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE)
	b.add_theme_stylebox_override("normal", UI.chip(color))
	b.add_theme_stylebox_override("hover", UI.chip(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", UI.chip(color.darkened(0.1)))
