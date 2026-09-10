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
var _buff_sheet: BuffSheet   # 보유 버프 리스트 서랍(플레이 중 보기 전용)
var _buff_btn: Button        # 휴지통 옆 [버프] 버튼. 보유 0개면 비활성.
var _tutorial: Tutorial      # 게임 내 가이드 오버레이(실제 컴포넌트 위)
var _tutorial_active := false  # 튜토리얼 진행 중 — 시계·트립비용·인내심 타이머 억제

var _queue_row: HBoxContainer
var _margin: MarginContainer   # 플레이 HUD 루트 여백 — 세이프에어리어(노치·시스템 바) 인셋 반영

# 하루 정산(day_end_bonus) 집계 — day_started에서 리셋. sim_core의 하루 스코프 카운터와 동치.
var _visited_today := 0     # 등장 손님 수
var _accepted_today := 0    # 주문 접수 수(슬롯 주문 카드 생성)
var _served_today := 0      # 서빙 완료 수
var _order_lost_today := 0  # 주문 낸 손님이 못 받고 떠난 수(음식대기 만료)
var _missed_today := 0      # 놓친 손님(대기열 이탈 + 주문 이탈) — 완벽/우수정산 처리율 분모
var _run_id := ""           # 이번 판 고유 id(로그에서 같은 판 묶기용). _start_game마다 새로 발급.
var _max_sale_today := 0    # OP 검사: 그날 최고 단일 판매금
var _max_mult_today := 1.0  # OP 검사: 그날 최고 배수(곱연산)
var _served_by_menu := {}   # 메뉴별 서빙 수 → 같은메뉴 최대(63·samemenu)
var _sales_by_menu := {}    # 메뉴별 판매 집계(정산 팝업): rid → {count, base, bonus}
var _settle_bonus := 0      # 마감 추가금(day_end_bonus) — day_closing에서 earn, 정산 팝업에서 연출
var _week_reward := 0        # 주 클리어 보상 — 실적검사 통과 후(_settle_pass) 지급

var _day_num: Label   # 일력 뱃지 위 날짜 숫자
var _money_label: Label
var _debug_bar: Control        # 디버그 바(숨김) — 보유금 5연속 클릭으로 토글
var _cash_clicks := 0          # 보유금 연속 클릭 수(간격 크면 리셋)
var _last_cash_click := 0      # 마지막 보유금 클릭 시각(ms)
var _score_label: Label   # 이달 실적(점수) — "현재/목표"(÷100)
var _last_cash := 0   # 돈 증감 방향 판별(증가 시 라벨 팝)용
var _expect_fly := false   # true면 이번 증가는 _fly_gain 도착 때 팝(즉시 팝 생략)
var _hours_bar: ProgressBar
var _hours_glow: Tween      # 마감 임박 펄스
var _celebrating := false   # 승리 축포 중 — 새 게임/타이틀 이동 시 false(예약된 2차 축포 취소)
var _hours_warning := false  # 임박 상태 진입 여부(전환 시 1회만 처리)
var _blackout: ColorRect    # 폐업 암전 오버레이
var _countdown_edge: Panel  # 카운트다운 화면 가장자리 빨강 비네트(마감 임박 원인 구분·A안)
var _last_countdown := 0    # 막판 카운트다운 마지막 표시 초(중복 방지)
const COUNTDOWN_FROM := 5   # 마감 몇 초 전부터 카운트다운
const TUTORIAL_FLAG := "user://tutorial.done"   # 최초 실행 시 튜토리얼 1회 재생 판별용 영구 플래그


func _ready() -> void:
  Loc.init()   # 저장된 언어 선택 로드, 없으면 기기 언어로 자동 선택(첫 실행)
  # 배경(빵 패턴) — 빈 곳 클릭 시 선택 해제 캐처. 화면 흔들림 때 가장자리 빈틈 안 보이게 여유 확장.
  var bg := TextureRect.new()
  bg.texture = load("res://assets/art/bg/play_bg.jpg")
  bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  bg.offset_left = -40
  bg.offset_top = -40
  bg.offset_right = 40
  bg.offset_bottom = 40
  bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  bg.mouse_filter = Control.MOUSE_FILTER_STOP   # 빈 곳 클릭 캐처 유지
  bg.gui_input.connect(_on_background_input)
  add_child(bg)

  _margin = MarginContainer.new()
  _margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  _margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
  var margin := _margin
  add_child(margin)
  _apply_safe_area()
  get_viewport().size_changed.connect(_apply_safe_area)

  var col := VBoxContainer.new()
  col.mouse_filter = Control.MOUSE_FILTER_IGNORE
  col.add_theme_constant_override("separation", 10)
  margin.add_child(col)

  col.add_child(_build_top_bar())
  if OS.is_debug_build():   # 운영(릴리스) 빌드에선 디버그 바 자체가 없음
    _debug_bar = _build_debug()
    # 로컬 개발(에디터 실행)=항상 표시, 익스포트 빌드=숨김 → 보유금 5연속 클릭으로 토글
    _debug_bar.visible = OS.has_feature("editor")
    col.add_child(_debug_bar)
  col.add_child(_build_customer_queue())

  _board = Board.new()
  _board.tool_tapped.connect(_on_tool_tapped)
  # 보드가 큐~하단버튼 사이 남는 세로 공간을 차지 → 슬롯이 늘어도 그 공간에 맞춰
  # 열 수·슬롯 크기를 자동 조절(하단 버튼이 잘리지 않음). [[Board._relayout]]
  _board.size_flags_vertical = Control.SIZE_EXPAND_FILL
  col.add_child(_board)

  col.add_child(_build_bottom_buttons())
  add_child(_build_warehouse_handle())   # 창고 열림 핸들(화면 우하단 앵커, 서랍보다 아래 z)

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
  _buff_sheet = BuffSheet.new()   # 플레이 중 보유 버프 보기(판매 없음 — on_sell 미주입)
  _buff_sheet.close_requested.connect(_close_sheets)
  add_child(_buff_sheet)

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

  # 시작(타이틀) 화면 — 앱 실행 시 게임 위에 덮음. [시작] → 최초 1회는 튜토리얼 후 게임.
  _title = TitleScreen.new()
  _title.start_pressed.connect(_on_start_pressed)
  _title.tutorial_pressed.connect(_start_tutorial)
  add_child(_title)

  if "--replay" in OS.get_cmdline_user_args():
    # 실로그 A판(run 2026-08-30#1813, 11주) — 주차별 보유버프/슬롯을 주입해 서빙·점수 재현 대조.
    # 주8은 실제로 보스 time_short(서빙 13)였음: 리플레이는 보스 미주입이라 그 주만 크게 벗어남(정상).
    var bw := [
      [], [], ["ramp_t3"], ["ramp_t3", "tool_slot"],
      ["ramp_t3", "tool_slot", "ramp_t1"],
      ["ramp_t3", "tool_slot", "ramp_t1", "mult_all"],
      ["ramp_t3", "tool_slot", "ramp_t1", "mult_all", "mp_t34"],
      ["ramp_t3", "tool_slot", "ramp_t1", "mult_all", "mp_t34"],
      ["ramp_t3", "tool_slot", "ramp_t1", "mult_all", "mp_t34"],
      ["ramp_t3", "tool_slot", "ramp_t1", "mult_all", "mp_t34"],
      ["ramp_t3", "tool_slot", "ramp_t1", "mult_all", "mp_t34"],
    ]
    var slots := [9, 10, 10, 11, 11, 11, 12, 12, 13, 13, 13]
    var log_served := [21, 20, 22, 21, 23, 21, 23, 13, 22, 24, 21]
    var log_rev := [124, 96, 111, 115, 224, 538, 1590, 1772, 3727, 2222, 4941]   # day_score(=day_revenue)
    var script := []
    for wi in bw.size():
      script.append({"buffs": bw[wi], "slots": slots[wi]})
    var h := float(OS.get_environment("SIM_HANDLE")) if OS.has_environment("SIM_HANDLE") else 0.65
    var reps := int(OS.get_environment("SIM_N")) if OS.has_environment("SIM_N") else 30   # 레시피 RNG 평활용 시드 평균
    var sum_served := []
    var sum_rev := []
    for _i in bw.size():
      sum_served.append(0.0)
      sum_rev.append(0.0)
    for s in reps:
      var res: Array = SimCore.new().run_replay(script, s, h)
      for i in res.size():
        sum_served[i] += float(res[i]["served"])
        sum_rev[i] += float(res[i]["revenue"])
    print("[REPLAY] handle=%.1f  n=%d  주 | 서빙(sim/log) | 점수(sim/log)  Δ%%" % [h, reps])
    var tot_d := 0.0
    for i in bw.size():
      var sv := float(sum_served[i]) / float(reps)
      var rv := float(sum_rev[i]) / float(reps)
      var lr: int = log_rev[i]
      var d := (rv - lr) / maxf(1.0, lr) * 100.0
      tot_d += absf(d)
      print("[REPLAY] %2d | %4.1f / %2d | %8.0f / %8d  %+5.0f%%%s" % [
        i + 1, sv, log_served[i], rv, lr, d, "  ← 주8=보스(제외)" if i == 7 else ""])
    print("[REPLAY] 평균 |Δ점수| = %.0f%% (주8 보스 포함)" % (tot_d / float(bw.size())))
    get_tree().quit()

  # 개발용 테스트 하니스 (릴리스엔 영향 없음): godot4 ... -- --test
  if OS.is_debug_build() and "--test" in OS.get_cmdline_user_args():
    await TestHarness.new().run(self)

  if "--shotdone" in OS.get_cmdline_user_args():
    _start_game()
    for _i in 6:
      await get_tree().process_frame
    _board.tools[0].produce_instant(Stats.random_recipe())
    for _i in 6:
      await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png("/tmp/done.png")
    get_tree().quit()

  # 헤드리스 시뮬레이션: godot4 ... -- --sim
  if "--sim" in OS.get_cmdline_user_args():
    # 기본을 현실 플레이어 모델로 — 초인(handle=0)이 아니라 사람 손속도/놓침이 걸려야 실측 중앙값에 붙는다.
    if not OS.has_environment("SIM_HANDLE"): OS.set_environment("SIM_HANDLE", "0.65")   # 실로그 보정: day-1 평균 110·즉사 44%가 실측(108/45%)에 일치
    if not OS.has_environment("SIM_MISS"): OS.set_environment("SIM_MISS", "0.03")   # 실측 응대율 높음(accepted≈visited) → 놓침 낮게
    var batch := SimBatch.new()
    var n := int(OS.get_environment("SIM_N")) if OS.has_environment("SIM_N") else 200
    print("\n[SIM] ===== 생존 시뮬 (실패 중지·12주(3개월) 캡, %d회, 상점 ON, handle=%s miss=%s) — 일수=생존 주 =====" % [
      n, OS.get_environment("SIM_HANDLE"), OS.get_environment("SIM_MISS")])
    var s := batch.run(n, [], true)   # 빈 로드아웃 = 상점으로 스스로 성장
    print("[SIM] 승률 %.1f%%  최종현금 %.0f  서빙 %.1f  놓침 %.1f  슬롯 %.1f  버프 %.1f  일수 %.1f" % [
      s["win_rate"] * 100.0, s["avg_cash"], s["avg_served"], s["avg_lost"],
      s["avg_slots"], s["avg_buffs"], s["avg_days"]])
    print("[SIM] 손실원인/판  큐만료(접수병목) %.1f  주문만료(조리/서빙병목) %.1f  주의력 %.1f  큐꽉참 %.1f" % [
      s["avg_lost_queue"], s["avg_lost_order"], s["avg_lost_miss"], s["avg_lost_qfull"]])
    _print_survival_dist(s["days_list"], n)
    get_tree().quit()

  # 병렬 샤딩 워커/카운트(tools/sim_parallel.sh 전용) — 버프 순위를 코어 수만큼 쪼개 실행.
  if "--simcount" in OS.get_cmdline_user_args():
    print("[SIMCOUNT] %d" % BuffDefs.ids().size())
    get_tree().quit()
  if "--simshard" in OS.get_cmdline_user_args():
    var sa := OS.get_cmdline_user_args()
    var si := sa.find("--simshard")   # 뒤 인자: <n> <start> <count> [surv]
    if sa.size() > si + 4 and sa[si + 4] == "surv":
      SimShard.surv_shard(int(sa[si + 1]), int(sa[si + 2]), int(sa[si + 3]))
    else:
      SimShard.buff_shard(int(sa[si + 1]), int(sa[si + 2]), int(sa[si + 3]))
    get_tree().quit()

  # 버프 페어 시너지: SIM_N=<판수> SIM_SYN_K=<후보수> [SIM_SYN_IDS=a,b,c] godot4 ... -- --simsyn
  if "--simsyn" in OS.get_cmdline_user_args():
    var yn := int(OS.get_environment("SIM_N")) if OS.has_environment("SIM_N") else 40
    SimSynergy.run_report(yn)
    get_tree().quit()

  # 버프 효과 측정: SIM_RENT=<배수> SIM_N=<판수> godot4 ... -- --simbuffs
  if "--simbuffs" in OS.get_cmdline_user_args():
    var bn := int(OS.get_environment("SIM_N")) if OS.has_environment("SIM_N") else 40
    SimBatch.new().buff_report(bn)
    get_tree().quit()

  # 등급판매(53~55) 배수 곡선 탐색: 세 카드를 동일 배수로 두고 각각 단독 레버리지 측정.
  # SIM_RENT=<가혹도> SIM_N=<판수> SIM_MULTS=2,3,5,9 godot4 ... -- --simtier
  if "--simtier" in OS.get_cmdline_user_args():
    var tn := int(OS.get_environment("SIM_N")) if OS.has_environment("SIM_N") else 200
    var mults := PackedFloat32Array()
    if OS.has_environment("SIM_MULTS"):
      for s in OS.get_environment("SIM_MULTS").split(","):
        mults.append(float(s))
    else:
      mults = PackedFloat32Array([2.0, 3.0, 5.0, 9.0])
    var cards := ["sale_t12", "sale_t34", "sale_t56"]
    var b := SimBatch.new()
    var base := b.run(tn, [], false)
    var bscore := float(base.get("avg_score", 0.0))
    print("[SIMTIER] base(버프0)  점수 %.1f  일수 %.2f  (n=%d, SIM_RENT=%s, SIM_MAXDAY=%s)" % [
      bscore, base["avg_days"], tn,
      OS.get_environment("SIM_RENT") if OS.has_environment("SIM_RENT") else "1",
      OS.get_environment("SIM_MAXDAY") if OS.has_environment("SIM_MAXDAY") else "-"])
    if OS.has_environment("SIM_CURVE"):   # 개별 곡선 검증: SIM_CURVE=고수,장인,명장 배수
      var cv := OS.get_environment("SIM_CURVE").split(",")
      for i in cards.size():
        var cid: String = cards[i]
        var m := float(cv[i])
        BuffDefs.ALL[cid]["sale"]["pct"] = m
        var r := b.run(tn, [cid], false)
        var sc := float(r.get("avg_score", 0.0))
        print("[SIMTIER] %-10s ×%-4.1f  점수 %9.1f  Δ%+9.1f  (×base %.2f)" % [
          cid, m, sc, sc - bscore, sc / maxf(bscore, 1.0)])
      get_tree().quit()
      return
    for m in mults:
      for cid in cards:
        BuffDefs.ALL[cid]["sale"]["pct"] = float(m)
        var r := b.run(tn, [cid], false)
        var sc := float(r.get("avg_score", 0.0))
        print("[SIMTIER] %-10s ×%-4.1f  점수 %9.1f  Δ%+9.1f  (×base %.2f)" % [
          cid, m, sc, sc - bscore, sc / maxf(bscore, 1.0)])
    get_tree().quit()

  # 메뉴별 효율: 손님이 한 메뉴만 주문하도록 강제해 처리량(점수/일)을 측정.
  # 재료 수(트립·배치 시간)·조리시간(도구 점유)·서빙점수가 처리량에 녹아든다. 상점·버프 OFF로 격리.
  # SIM_N=<판수> SIM_MAXDAY=<일> SIM_HANDLE=<손속도> godot4 ... -- --simmenu
  if "--simmenu" in OS.get_cmdline_user_args():
    var mmn := int(OS.get_environment("SIM_N")) if OS.has_environment("SIM_N") else 300
    if not OS.has_environment("SIM_MAXDAY"): OS.set_environment("SIM_MAXDAY", "3")
    if not OS.has_environment("SIM_HANDLE"): OS.set_environment("SIM_HANDLE", "0.65")
    OS.set_environment("SIM_NOFAIL", "1")
    var mdays := int(OS.get_environment("SIM_MAXDAY"))
    print("\n[SIMMENU] ===== 메뉴별 효율 (단일메뉴 강제·상점OFF, n=%d, %d일, HANDLE=%s) =====" % [
      mmn, mdays, OS.get_environment("SIM_HANDLE")])
    var mrows := []
    for rid in Recipes.all_ids():
      var tot_score := 0
      var tot_served := 0
      for i in mmn:
        var sim := SimCore.new()
        sim.force_menu = rid
        var r := sim.run([], i, false)
        tot_score += int(r.get("score", 0))
        tot_served += int(r.get("served", 0))
      var d := Recipes.get_def(rid)
      var ing_arr: Array = d.get("ingredients", [])
      var denom := float(mmn * mdays)
      mrows.append({
        "name": d.get("name", rid), "ing": ing_arr.size(),
        "cook": float(d.get("cook_time", 0.0)), "price": int(d.get("price", 0)),
        "served": float(tot_served) / denom, "score": float(tot_score) / denom,
      })
    mrows.sort_custom(func(a, b): return a["score"] > b["score"])
    print("[SIMMENU]  메뉴        재료  조리(s)  서빙점수   서빙/일   점수/일   점수/재료  점수/조리초")
    for row in mrows:
      print("[SIMMENU]  %-9s  %2d    %4.1f    %5d    %7.2f   %7.2f   %7.2f    %7.2f" % [
        row["name"], row["ing"], row["cook"], row["price"], row["served"], row["score"],
        row["score"] / maxf(1.0, float(row["ing"])), row["score"] / maxf(0.1, row["cook"])])
    get_tree().quit()


## 생존주 분포 — 실플레이 바이모달(사망 4~6주 vs 승리 11+)이 시뮬에 나타나는지 본다.
## 월 경계(1개월=4주): 월2 도달=≥5주, 월3 도달=≥9주, 완주=12주.
func _print_survival_dist(days_list: Array, n: int) -> void:
  var counts := {}
  var reach2 := 0
  var reach3 := 0
  var full := 0
  for d in days_list:
    var w := int(d)
    counts[w] = int(counts.get(w, 0)) + 1
    if w >= 5: reach2 += 1
    if w >= 9: reach3 += 1
    if w >= 12: full += 1
  var nf := float(maxi(n, 1))
  print("[SIM] 도달률  월2(≥5주) %.0f%%  월3(≥9주) %.0f%%  완주(12주) %.0f%%" % [
    reach2 / nf * 100.0, reach3 / nf * 100.0, full / nf * 100.0])
  var line := ""
  for w in range(1, 13):
    var c := int(counts.get(w, 0))
    line += "%2d주:%-3d " % [w, c]
    if w == 4 or w == 8:
      line += "| "
  print("[SIM] 분포  %s" % line)


## 홈 버튼 — 확인창(진행 중인 판이 사라짐).
func _on_home_pressed() -> void:
  _set_world_paused(true)   # 확인창 동안 게임 일시정지(창고 열림과 동일)
  var m := Modal.open(self) \
    .title(Loc.t("home_title")) \
    .row(Loc.t("home_warn"), Palette.COCOA_600) \
    .button(Loc.t("go_home"), _go_home) \
    .button(Loc.t("cancel"), func(): pass)
  # 모달 닫히면 재개 — 단 '홈으로'로 나가면(타이틀 표시) 유지.
  m.tree_exited.connect(func():
    if is_instance_valid(self) and not _title.visible:
      _set_world_paused(false))


## 진행 중인 판을 접고 타이틀로. 다음 [시작] 때 start_run이 전부 리셋.
func _go_home() -> void:
  _session.set_process(false)   # 세션 정지(시계·스폰)
  _warehouse.visible = false
  _cooking.visible = false
  _buff_sheet.visible = false
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


## [시작] 버튼 — 최초 실행(튜토리얼 미완료)이면 튜토리얼부터, 이후엔 바로 게임.
func _on_start_pressed() -> void:
  if _tutorial_seen():
    _start_game()
  else:
    _start_tutorial("game")   # 튜토리얼 끝나면 _start_game() 자동 호출


## 튜토리얼을 한 번이라도 끝냈는지(영구 플래그 파일 존재 여부).
func _tutorial_seen() -> bool:
  return FileAccess.file_exists(TUTORIAL_FLAG)


func _mark_tutorial_seen() -> void:
  var f := FileAccess.open(TUTORIAL_FLAG, FileAccess.WRITE)
  if f != null:
    f.store_8(1)
    f.close()


func _start_game() -> void:
  _celebrating = false           # 이전 승리 축포 예약 취소
  _clear_confetti()              # 남은 색종이 제거(축포 후 홈→시작 시 잔재 방지)
  _last_cash = 0                 # 새 판 — 이전 판 보유금 잔상 제거(시작 시 -표시 방지)
  _money_label.text = UI.money(0)
  Boss.reset()                   # 예약된 보스가 새 판으로 새지 않게
  _run_id = Time.get_datetime_string_from_system() + "#" + str(Time.get_ticks_msec())   # 판 고유 id
  _title.hide()
  _session.start_run()


func _show_title() -> void:
  _celebrating = false           # 타이틀 이동 → 예약된 2차 축포 취소
  _clear_confetti()
  _clear_blackout()   # 게임오버 암전 잔재 제거(안 치우면 시작해도 검은 화면+입력 차단)
  _title.show()


## 세이프에어리어(노치·시스템 바) 인셋을 HUD 루트 여백에 반영 — edge-to-edge에서 HUD가 바 밑에 깔리지 않게.
## 안드로이드에서만 인셋 적용(데스크톱/에디터는 기본 여백만). stretch=canvas_items라 실화면 px를 캔버스 스케일로 환산.
func _apply_safe_area() -> void:
  var base := 12
  for side in ["left", "right", "top", "bottom"]:
    _margin.add_theme_constant_override("margin_" + side, base)
  if OS.get_name() != "Android":
    return
  var win := DisplayServer.window_get_size()
  if win.x <= 0 or win.y <= 0:
    return
  var safe := DisplayServer.get_display_safe_area()
  var vp := get_viewport_rect().size
  var sx := vp.x / float(win.x)
  var sy := vp.y / float(win.y)
  _margin.add_theme_constant_override("margin_left", base + int(round(maxf(0.0, safe.position.x) * sx)))
  _margin.add_theme_constant_override("margin_top", base + int(round(maxf(0.0, safe.position.y) * sy)))
  _margin.add_theme_constant_override("margin_right", base + int(round(maxf(0.0, win.x - (safe.position.x + safe.size.x)) * sx)))
  _margin.add_theme_constant_override("margin_bottom", base + int(round(maxf(0.0, win.y - (safe.position.y + safe.size.y)) * sy)))


## 화면에 남은 축포(색종이) 일괄 제거.
func _clear_confetti() -> void:
  for p in get_tree().get_nodes_in_group("confetti"):
    p.queue_free()


## 튜토리얼 진입 — 실제 play 화면 위에 가이드 오버레이를 얹는다(별도 화면 아님).
## after: 끝난 뒤 행선지 — "title"(기본, 메뉴 복귀) 또는 "game"(바로 게임 시작).
## → 나중에 "최초 플레이 시 게임 시작 직전 자동 재생"은 _start_tutorial("game") 한 줄이면 됨.
func _start_tutorial(after := "title") -> void:
  _title.hide()
  _enter_tutorial_state()
  _tutorial = Tutorial.new()
  _tutorial.board = _board
  _tutorial.queue_row = _queue_row
  _tutorial.warehouse = _warehouse
  _tutorial.cooking = _cooking
  _tutorial.warehouse_btn = _warehouse_btn
  _tutorial.spawn_customer = _spawn_customer.bind(Tutorial.RECIPE)
  _tutorial.finished.connect(func():
    if is_instance_valid(_tutorial):
      _tutorial.queue_free()
    _tutorial = null
    _exit_tutorial_state()
    _mark_tutorial_seen()   # 완료했으면 다음 실행부터 [시작] 시 튜토리얼 자동재생 안 함
    if after == "game":
      _start_game()
    else:
      _show_title())
  add_child(_tutorial)


## 실제 화면을 "가이드용 하루"로 세팅 — 시계·스케줄 스폰·경제를 멈추고 깨끗한 보드 구성.
func _enter_tutorial_state() -> void:
  _tutorial_active = true
  Buffs.clear()                 # 버프 없는 깨끗한 상태
  _session.set_process(false)   # 시계·스케줄 스폰·마감 정지(가이드 동안 시간 흐르지 않음)
  _clear_blackout()
  _day_num.text = "1"
  _money_label.text = UI.money(0)
  for s in _board.slots:
    s.clear()
  for t in _board.tools:
    t.reset()
  for c in _queue_row.get_children():
    c.queue_free()
  _board.rebuild(4)             # 가이드용 고정 슬롯 수(주문1+재료2+여유)
  _warehouse.visible = false
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = false
  _refresh_warehouse()


## 가이드 종료 — 필드 정리 + 게이트 잔재 제거(세션 재개는 _start_game/start_run이 담당).
func _exit_tutorial_state() -> void:
  _tutorial_active = false
  Move.clear()
  for s in _board.slots:
    s.clear()
  for t in _board.tools:
    t.reset()
  for c in _queue_row.get_children():
    c.queue_free()
  _warehouse.visible = false
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = false


# ── 상단바: 일차·돈·가게세 + 영업시간 바 (UI.top_bar 공용 컴포넌트) ──────────────────────
func _build_top_bar() -> Control:
  var panel := UI.top_bar()
  _day_num = panel.get_meta("day_num") as Label
  _money_label = panel.get_meta("money_label") as Label
  _score_label = panel.get_meta("score_label") as Label
  _hours_bar = panel.get_meta("hours_bar") as ProgressBar

  var home := panel.get_meta("home_btn") as Button
  home.pressed.connect(_on_home_pressed)
  Audio.attach_click(home)

  # 보유금 5연속 클릭 = 디버그 바 토글(개발용). 릴리스(운영) 빌드엔 핸들러 자체를 안 붙인다.
  if OS.is_debug_build():
    var coin := panel.get_meta("coin_box") as HBoxContainer
    coin.mouse_filter = Control.MOUSE_FILTER_STOP
    coin.gui_input.connect(_on_cash_clicked)

  return panel


# ── 디버그 바 (개발용) ────────────────────────────────────
## 보유금 5연속 클릭 → 디버그 바 토글. 간격 1.5초 넘으면 카운트 리셋(진짜 '연속'만 인정).
func _on_cash_clicked(event: InputEvent) -> void:
  if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
    return
  if _debug_bar == null:   # 릴리스 빌드 = 디버그 바 없음
    return
  var now := Time.get_ticks_msec()
  if now - _last_cash_click > 1500:
    _cash_clicks = 0
  _last_cash_click = now
  _cash_clicks += 1
  if _cash_clicks >= 5:
    _cash_clicks = 0
    _debug_bar.visible = not _debug_bar.visible


func _build_debug() -> Control:
  var row := HBoxContainer.new()
  row.add_theme_constant_override("separation", 6)
  row.add_child(UI.label("🐞", 14, Palette.COCOA_400))
  row.add_child(_debug_btn("+10만", func(): _session.add_cash(100000)))
  row.add_child(_debug_btn("별+10만", func(): _session.earn(100000, true)))
  row.add_child(_debug_btn("종료", func(): _session.debug_end_soon(1.0)))
  row.add_child(_debug_btn("손님-", _debug_kick_customer))
  row.add_child(_debug_btn("버프", _debug_add_buff))
  row.add_child(_debug_btn("도감-", func(): Codex.reset()))
  row.add_child(_debug_btn("보스", _debug_boss))
  row.add_child(_debug_btn("로그", func(): DisplayServer.clipboard_set(PlayLog.read_text())))   # 폰: 클립보드로 빼기
  row.add_child(_debug_btn("로그-", func(): PlayLog.clear()))
  return row


## 디버그: 다음날을 보스전(계약 갱신 심사·랜덤 제약)으로 예약 + 오늘 즉시 마감(빠른 진입).
func _debug_boss() -> void:
  Boss.queue_random()
  if _session != null and not _title.visible:
    _session.debug_end_soon(1.0)


## 디버그: 랜덤 버프 1개 획득(차단 카드 제외) + 보드 빈 슬롯에 즉시 배치.
func _debug_add_buff() -> void:
  var pack := BuffDefs.random_pack(1)
  if pack.is_empty():
    return
  var id: String = pack[0]
  var before := Buffs.owned().size()
  Buffs.add(id)
  if Buffs.owned().size() == before:
    return   # 보유 가득
  var slot := _board.first_empty_slot()
  if slot:
    var bc := BuffCard.new()
    bc.setup(id)
    slot.place_card(bc)
  _refresh_buff_btn()


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
  # 손님 유무·종류와 무관하게 높이 고정 — 꽉 찬 기준(카드 67 + 여백 20 + 테두리 2).
  # 최소높이가 이보다 작으면 손님 등장 시 패널이 늘어나 화면이 흔들림.
  panel.custom_minimum_size = Vector2(0, 89)

  var pad := MarginContainer.new()
  for side in ["left", "right", "top", "bottom"]:
    pad.add_theme_constant_override("margin_" + side, 10)
  panel.add_child(pad)

  _queue_row = HBoxContainer.new()
  _queue_row.add_theme_constant_override("separation", 8)
  pad.add_child(_queue_row)

  return panel


# ── 하단 버튼: 휴지통(좌 30%) · 창고(우 70%) ───────────────
# 자주 쓰는 창고를 오른손 엄지존(우측)에 크게, 가끔 쓰는 휴지통은 좌측에 좁게.
func _build_bottom_buttons() -> Control:
  var row := HBoxContainer.new()
  row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_theme_constant_override("separation", 10)

  # 휴지통 — 작은 정사각(좌하단). 자주 안 쓰니 작게.
  _trash_btn = TrashButton.new()
  _style_bottom_button(_trash_btn, Palette.SUB)
  _trash_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 확장 X
  _trash_btn.custom_minimum_size = Vector2(56, 56)
  _trash_btn.add_child(UI.ui_btn_icon("trash", 30))
  row.add_child(_trash_btn)

  # [버프] — 휴지통 옆. 탭하면 보유 버프 서랍(보기 전용). 보유 0개면 비활성(안 열림).
  _buff_btn = Button.new()
  _style_bottom_button(_buff_btn, Palette.MAIN)
  _buff_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 확장 X
  _buff_btn.custom_minimum_size = Vector2(64, 56)
  _buff_btn.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_200))
  _buff_btn.add_child(UI.ui_btn_icon("buffs", 40))   # 텍스트 대신 버프 덱 손그림
  _buff_btn.pressed.connect(_toggle_buffs)
  Audio.attach_click(_buff_btn)
  row.add_child(_buff_btn)
  _refresh_buff_btn()

  # 창고 열림 핸들은 하단바가 아니라 화면에 직접 앵커(우하단 50~90%) — _build_warehouse_handle.
  var gap := Control.new()
  gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(gap)

  return row


## 창고 열림 핸들 — 화면 우하단 50~90% 영역에 붙은 탭(창고 이미지만). 탭 = 열기.
## (열리면 서랍이 위로 덮어 가려짐. 닫기는 서랍 우상단 ✕ 또는 dim 탭)
func _build_warehouse_handle() -> Control:
  var b := Button.new()
  _warehouse_btn = b
  # 우하단 고정(오른쪽 가장자리 앵커 + 픽셀 오프셋) — 상점 다음날 버튼과 동일 좌표.
  b.anchor_left = 1.0
  b.anchor_right = 1.0
  b.anchor_top = 1.0
  b.anchor_bottom = 1.0
  b.offset_left = -150   # 버튼 폭 ≈ 134 (상점 다음날 버튼과 동일)
  b.offset_right = -16   # 우측 여백 16
  b.offset_top = -76
  b.offset_bottom = -8
  b.add_theme_stylebox_override("normal", _handle_style(Palette.MAIN))
  b.add_theme_stylebox_override("hover", _handle_style(Palette.MAIN.lightened(0.08)))
  b.add_theme_stylebox_override("pressed", _handle_style(Palette.MAIN.darkened(0.1)))
  b.pressed.connect(_toggle_warehouse)
  Audio.attach_click(b)
  var cc := CenterContainer.new()
  cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
  cc.add_child(UI.ui_icon("warehouse", 38))   # 꺽쇠 없이 창고 이미지만
  b.add_child(cc)
  return b


## 위쪽만 둥근 핸들 스타일.
func _handle_style(c: Color) -> StyleBoxFlat:
  var s := StyleBoxFlat.new()
  s.bg_color = c
  s.corner_radius_top_left = 18
  s.corner_radius_top_right = 18
  return s


# ── 상호작용 ──────────────────────────────────────────────
func _toggle_warehouse() -> void:
  if _warehouse.visible:
    _close_sheets()
  else:
    _open_warehouse()


func _open_warehouse() -> void:
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = true
  _set_world_paused(true)   # 재료 고르는 동안 시계 정지
  _warehouse.slide_open()   # 아래서 슬라이드 업
  Audio.play("door_open")   # 창고 들어감(문 열림)
  _refresh_warehouse()


func _on_tool_tapped(tool: ToolStation) -> void:
  _warehouse.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = true
  _set_world_paused(true)   # 레시피 고르는 동안 시계 정지
  _cooking.open_for(tool)


## [버프] 토글 — 보유 0개면 무시(버튼도 disabled). 창고와 달리 트립 비용 없음(닫아도 시간 소모 X).
func _toggle_buffs() -> void:
  if Buffs.owned().is_empty():
    return
  if _buff_sheet.visible:
    _close_sheets()
  else:
    _open_buff_sheet()


func _open_buff_sheet() -> void:
  _warehouse.visible = false
  _cooking.visible = false
  _backdrop.visible = true
  _set_world_paused(true)   # 보는 동안 시계 정지
  _buff_sheet.open()   # 현재 보유로 재구성 + 슬라이드 업


## [버프] 버튼 활성화 — 보유 버프 있을 때만.
func _refresh_buff_btn() -> void:
  if _buff_btn != null:
    _buff_btn.disabled = Buffs.owned().is_empty()
    _buff_btn.modulate.a = 0.45 if _buff_btn.disabled else 1.0   # 아이콘도 비활성 시 흐리게


## 월드 정지/재개 — 시계·손님 인내심·조리 타이머 전부. 시트 열림 동안 시간 멈춤.
func _set_world_paused(p: bool) -> void:
  if _tutorial_active:
    return   # 튜토리얼은 세션 자체를 정지(set_process)하고 손님/주문을 개별 정지 관리 — 시트 여닫이로 재개 금지
  _session.set_paused(p)
  for c in _queue_row.get_children():
    if c is Customer:
      (c as Customer).set_paused(p)
  for s in _board.slots:
    var card := s.get_card()
    if card is OrderCard:
      (card as OrderCard).set_paused(p)
  for t in _board.tools:
    t.set_paused(p)


func _close_sheets() -> void:
  _set_world_paused(false)   # 시계 재개(트립 비용은 아래 spend_time으로 별도 소모)
  # 튜토리얼: 트립 비용·시간 소모 없이 시트만 닫음(시계 정지 상태 유지).
  if _tutorial_active:
    if _warehouse.visible:
      Audio.play("door_close")
      _warehouse.slide_close()
    if _cooking.visible:
      _cooking.slide_close()
    if _buff_sheet.visible:
      _buff_sheet.slide_close()
    _backdrop.visible = false
    return
  # 창고 퇴장 = 트립 비용(영업시간 소모).
  if _warehouse.visible:
    var cost := Stats.warehouse_cost()
    var before_v := _hours_bar.value
    _session.spend_time(cost)   # → _on_progress가 바 값을 새 위치로
    # 트립 비용으로 영업시간이 끝났으면(하루 마감) _on_day_ended가 이미 창고를 닫음.
    # door_close 사운드·트립비용 팝업은 마감 연출(CLOSE 배너)과 겹치므로 생략하고 반환.
    if not _session.is_running():
      return
    var after_v := _hours_bar.value
    Audio.play("door_close")   # 창고 나옴(문 닫힘)
    _warehouse.slide_close()   # 아래로 슬라이드 다운
    _show_trip_cost(cost, before_v, after_v)   # 시간 소모 시각 피드백
  if _cooking.visible:
    _cooking.slide_close()
  if _buff_sheet.visible:
    _buff_sheet.slide_close()   # 보기 전용 — 트립 비용 없음
  _backdrop.visible = false


func _on_cooked() -> void:
  _close_sheets()
  _refresh_warehouse()


func _on_backdrop_input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
    _close_sheets()


func _refresh_warehouse() -> void:
  _warehouse.refresh(_board.is_full())


## 창고 타일(4열 그리드) 자리 대응 키 — QWER(윗줄)·ASDF(둘째줄)·ZXCV(셋째줄). 좌상단→우하단.
const _WAREHOUSE_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_A, KEY_S, KEY_D, KEY_F, KEY_Z, KEY_X, KEY_C, KEY_V]

## 키보드 단축키(데스크톱/테스트용): 스페이스=창고 토글, QWER/ASDF=창고 타일(자리 대응) 첫 빈 슬롯 배치.
## 타일 키는 창고가 열려 있을 때만(트립 비용 경제 유지). 모바일엔 키보드 없어 무영향.
func _unhandled_input(event: InputEvent) -> void:
  if not (event is InputEventKey) or not event.pressed or event.echo:
    return
  if _title.visible or _tutorial_active or not _session.is_running():
    return
  var key := (event as InputEventKey).keycode
  if key == KEY_SPACE:
    _toggle_warehouse()
    get_viewport().set_input_as_handled()
    return
  var idx: int = _WAREHOUSE_KEYS.find(key)
  if idx >= 0 and _warehouse.visible:
    _warehouse.place_by_index(idx)
    get_viewport().set_input_as_handled()


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
func _spawn_customer(force_recipe := "") -> void:
  if _queue_row.get_child_count() >= Config.MAX_QUEUE:
    return
  var c := Customer.new()
  c.setup(force_recipe if force_recipe != "" else Stats.random_recipe())
  c.confirm_pressed.connect(_on_confirm_order)
  c.expired.connect(_on_customer_expired)
  c.urged.connect(_on_urged)
  _queue_row.add_child(c)
  if _tutorial_active:
    c.set_process(false)   # 튜토리얼: 인내심 타이머 정지(압박 없음)
  c.slide_in()   # 오른쪽에서 슬라이드 인 등장
  Audio.play("customer_in")   # 손님 방문음
  _visited_today += 1   # 정산(served_ratio)용 등장 손님 집계 — sim_core._on_spawn과 동치


## 주문 확인 → 손님이 큐에서 사라지고 다음 빈 슬롯의 주문 카드로 "이동".
## 큐 재정렬 애니 — 접수/이탈 후 남은 손님이 새 자리로 부드럽게 슬라이드(즉시 점프 방지).
func _reflow_queue(customers: Array, old_pos: Dictionary) -> void:
  if customers.is_empty():
    return
  await _queue_row.sort_children   # HBox 재정렬 완료까지 확실히 대기(1프레임 레이스 제거)
  for c in customers:
    if not is_instance_valid(c):
      continue
    if c.has_method("stop_slide"):
      c.stop_slide()   # 등장 슬라이드 중이면 중단(위치 충돌 방지)
    var np: Vector2 = c.position
    var op: Vector2 = old_pos.get(c, np)
    if np == op:
      continue
    c.position = op
    var tw := create_tween()
    tw.tween_property(c, "position", np, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_confirm_order(customer: Customer) -> void:
  # 주문 상한 — 나머지 슬롯은 재료/완성품(조리 공간)용으로 남김.
  if _board.slot_counts()["orders"] >= Config.MAX_ORDERS:
    _board.shake_slots()     # 주문 꽉 참 — 슬롯 좌우 흔들림(토스트 대체)
    Audio.play("disabled")   # 더 못 받음(불가)
    Audio.vibrate(30)        # 접수 불가 — 짧은 에러 진동
    return
  var slot := _board.first_empty_slot()
  if slot == null:
    _board.shake_slots()     # 빈 칸 없음 — 슬롯 좌우 흔들림(토스트 대체)
    Audio.play("disabled")   # 더 못 받음(불가)
    Audio.vibrate(30)        # 접수 불가 — 짧은 에러 진동
    return
  var rid := customer.recipe_id
  var order := OrderCard.new()
  order.setup(rid)
  order.animal = customer.animal   # 같은 손님(동물)이 주문서로 이어짐
  order.born = _session.now()   # 주문 접수 시각 스탬프 — 판매 ctx의 order_age(빠른/느린 서빙 카드)
  order.expired.connect(_on_order_expired)
  order.served.connect(_on_served)
  order.rejected.connect(_on_order_rejected)
  order.urged.connect(_on_urged)
  if _tutorial_active:
    order.set_process(false)   # 튜토리얼: 음식 대기 인내심 정지
  # 주문서가 클릭한 손님 자리에서 슬롯으로 날아가 안착.
  # 자리는 착지까지 유지(dismiss=투명 홀드) → 뒤 손님이 즉시 안 밀려 "그 손님 주문서"로 읽힘.
  var from_pos := customer.global_position + customer.size * 0.5
  # 접수 손님 즉시 제거(빈칸 없이 큐 좁혀짐 → 새 손님이 앞자리) + 남은 손님 부드럽게 슬라이드.
  var others: Array = []
  var oldp := {}
  for c in _queue_row.get_children():
    if c is Customer and c != customer:
      others.append(c)
      oldp[c] = c.position
  _queue_row.remove_child(customer)
  customer.queue_free()
  _fly_order_to_slot(order, slot, from_pos)
  _reflow_queue(others, oldp)   # 남은 손님이 새 자리로 슬라이드(즉시 점프 방지)
  _accepted_today += 1
  # 카드60: N번째 주문마다 즉시 완성품 생성(재료·조리 생략). 놓을 자리 있을 때만 발동 소비(없으면 다음 주문 재시도).
  if Buffs.has_instant_order() and _produce_dish(rid):
    Buffs.consume_instant_order()
  _refresh_warehouse()


## 완성품을 즉시 생성해 보드에 올림(카드60 즉시완료 등). 유휴 도구석 우선, 없으면 빈 슬롯.
## 놓을 자리(도구석·슬롯)가 없으면 false 반환 — 호출측이 발동을 소비하지 않고 유지한다.
func _produce_dish(rid: String) -> bool:
  for t in _board.tools:
    if t.is_idle():
      t.produce_instant(rid)
      return true
  var s := _board.first_empty_slot()
  if s == null:
    return false
  var dish := DishCard.new()
  dish.setup(rid)
  dish.born = _session.now()
  s.place_card(dish)
  return true


## 인내심 임박 재촉 — 카드 위에 💢 팝(카드 흔들림은 카드가 자체 처리).
func _on_urged(card: Control) -> void:
  if not is_instance_valid(card):
    return
  _spawn_pop("💢", card.global_position + Vector2(card.size.x * 0.5, -8))


func _on_customer_expired(customer: Customer) -> void:
  _missed_today += 1   # 대기열 이탈 = 놓친 손님(정산 처리율 분모)
  _spawn_pop("😠", customer.global_position + customer.size * 0.5)   # 성난 손님 이탈
  Audio.play("customer_leave")   # 손님 떠남(왈왈)
  Audio.vibrate(40)   # 손님 놓침 — 에러 진동
  _detach_and_fade(customer)


## 음식 대기 인내심 0 → 주문 카드(=손님) 통째로 사라짐, 슬롯 회복.
func _on_order_expired(order: OrderCard) -> void:
  # 카드71·72: 주문 낸 손님이 못 받고 떠나면 보상(72는 다음 획득 2배 예약).
  var gain := Buffs.on_lost(order.recipe_id)
  if gain != 0:
    _expect_fly = true   # 이번 증가 팝은 _fly_gain 도착 때
    _session.earn(gain, false)   # 취소수수료 = 돈만(점수 X)
    _expect_fly = false
    _show_gain_breakdown([{"src": "buff", "amount": gain, "buff": "onlost_pay"}])   # 버프 획득 → 중앙 버프색 +n
  _order_lost_today += 1
  _missed_today += 1   # 주문 이탈 = 놓친 손님(정산 처리율 분모)
  _spawn_pop("😠", order.global_position + order.size * 0.5)   # 성난 손님 이탈
  Audio.play("customer_leave")   # 손님 떠남(왈왈)
  Audio.vibrate(40)   # 손님 놓침 — 에러 진동
  _detach_and_fade(order)   # 슬롯에서 떼어내며 페이드아웃(슬롯 즉시 회복)
  _refresh_warehouse()


## 완성품이 매칭 주문 카드에 서빙됨 → 돈 + 손님 퇴장 + 슬롯/도구 회복.
## 안 맞는 완성품 서빙 시도 → 😠 팝(카드 흔들림은 OrderCard가 처리).
func _on_order_rejected(order: OrderCard) -> void:
  _spawn_pop("😠", order.global_position + order.size * 0.5)
  Audio.vibrate(30)   # 반려 — 짧은 에러 진동


const GAIN_BASE_COLOR := Palette.SUCCESS   # 기본 판매금 색
const GAIN_BUFF_COLOR := Palette.MAIN      # 버프 추가분 색(판매/비판매 공통)

## 획득 내역을 화면 중앙에 순차 표시 — 기본가(메뉴 아이콘·기본색) → 버프별 추가분(버프 이모지·버프색).
## breakdown: [{src, amount, icon, recipe?/buff?}, ...] — 첫 항목=기본가(메뉴), 이후=버프 보너스.
## 연출: 메뉴 이미지+가격이 제자리에 뜨고(띠링) → 버프 합산 시작 시 메뉴 이미지는 사라지고,
## 그 자리의 합계 금액이 +N 팝(띠링)과 함께 카운트업으로 오른다. 동전음은 최종 합류 때 딱 한 번.
func _show_gain_breakdown(breakdown: Array) -> void:
  var items: Array = []
  for entry in breakdown:
    if int(entry.get("amount", 0)) != 0:
      items.append(entry)
  if items.is_empty():
    return
  var base_entry: Dictionary = items[0]
  var base_amt := int(base_entry.get("amount", 0))
  var base_col: Color = GAIN_BASE_COLOR if base_entry.get("src", "") == "base" else GAIN_BUFF_COLOR

  var has_buffs := items.size() > 1

  # 중앙 합계 금액(제자리 카운트업). base 뜰 때 띠링은 서빙음(_on_served)이 겸함.
  var total_l := UI.label(UI.money(base_amt), 34, base_col, true)
  total_l.add_theme_constant_override("outline_size", 4)
  total_l.add_theme_color_override("font_outline_color", Palette.WHITE)
  total_l.z_index = 110
  add_child(total_l)
  # 메뉴 이미지(합계 왼쪽, 별도 노드) — 버프 합산이 시작되면 사라진다.
  var menu_icon := _gain_icon(base_entry, 40)
  menu_icon.z_index = 110
  add_child(menu_icon)
  await get_tree().process_frame
  if not is_instance_valid(total_l):
    return
  var center := size * 0.5
  total_l.pivot_offset = total_l.size * 0.5
  total_l.position = center - total_l.size * 0.5
  if is_instance_valid(menu_icon):
    var isz := menu_icon.size
    if isz == Vector2.ZERO:
      isz = Vector2(40, 40)
    menu_icon.pivot_offset = isz * 0.5
    menu_icon.position = Vector2(total_l.position.x - 8.0 - isz.x, center.y - isz.y * 0.5)
  # 등장 팝(금액 + 메뉴 이미지 함께 살짝 튐)
  total_l.scale = Vector2(0.4, 0.4)
  var tin := create_tween()
  tin.tween_property(total_l, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tin.tween_property(total_l, "scale", Vector2.ONE, 0.08)
  if is_instance_valid(menu_icon):
    menu_icon.scale = Vector2(0.4, 0.4)
    var ti2 := create_tween()
    ti2.tween_property(menu_icon, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    ti2.tween_property(menu_icon, "scale", Vector2.ONE, 0.08)
  # 버프가 있으면 첫 합산 직전 메뉴 이미지 페이드아웃 → 합쳐지는 동안엔 사진 없음
  if has_buffs:
    get_tree().create_timer(0.28).timeout.connect(func():
      if is_instance_valid(menu_icon):
        var fo := create_tween()
        fo.tween_property(menu_icon, "modulate:a", 0.0, 0.14)
        fo.tween_callback(menu_icon.queue_free))

  # 버프 추가금 — 순차로 +N 팝 + 음정 상승(크레셴도) + 점점 커지는 펀치 + 카운트업
  var running := base_amt
  var t := 0.34
  for k in range(1, items.size()):
    var entry: Dictionary = items[k]
    var amt := int(entry.get("amount", 0))
    var from_total := running
    running += amt
    var to_total := running
    get_tree().create_timer(t).timeout.connect(func():
      if not is_instance_valid(total_l):
        return
      Audio.play("serve", clampf(1.0 + float(k) * 0.06, 1.0, 1.9))   # 체인마다 음정↑ = 크레셴도
      _spawn_bonus_pop(amt, entry, total_l.position + Vector2(total_l.size.x * 0.5, 0.0))
      var cu := create_tween()
      cu.tween_method(_set_money_text.bind(total_l), float(from_total), float(to_total), 0.26)
      var punch := clampf(1.18 + float(k) * 0.04, 1.18, 1.5)   # 뒤로 갈수록 더 크게 튐
      var bump := create_tween()
      bump.tween_property(total_l, "scale", Vector2(punch, punch), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
      bump.tween_property(total_l, "scale", Vector2.ONE, 0.11))
    t += 0.34

  # 최종 방출 — 금액 규모에 비례해 슬램(큰 스케일→1.0) + 화면 흔들림 + 코인 파티클 + 동전음
  var total_gain := running
  get_tree().create_timer(t + 0.2).timeout.connect(func():
    if not is_inside_tree():
      return
    var feel := _gain_feel(total_gain)
    _pop_label(_score_label)
    Audio.play("score_up", feel["pitch"])   # 점수(별) 슬램 — 글로켄슈필 상승음
    # (서빙 보상 화면 흔들림 제거 — 플레이 중 산만함. 흔들림은 막판 카운트다운에서만.)
    if is_instance_valid(menu_icon):   # 버프 없던 서빙(페이드 안 탄 경우) 메뉴 이미지 정리
      var mo := create_tween()
      mo.tween_property(menu_icon, "modulate:a", 0.0, 0.3)
      mo.tween_callback(menu_icon.queue_free)
    if is_instance_valid(total_l):
      _coin_burst(total_l.position + total_l.size * 0.5, total_gain, 116, _score_label, "star")
      total_l.scale = Vector2(feel["slam"], feel["slam"])   # 크게 나타났다 임팩트 있게 축소
      var slam := create_tween()
      slam.tween_property(total_l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
      slam.tween_interval(0.22)   # 잠깐 유지(잔상)
      slam.tween_property(total_l, "modulate:a", 0.0, 0.28).set_ease(Tween.EASE_IN)
      slam.parallel().tween_property(total_l, "position:y", total_l.position.y - 28.0, 0.28)
      slam.tween_callback(total_l.queue_free))


## 카운트업 tween_method 콜백 — 합계 라벨 텍스트를 금액 표기로 갱신.
func _set_money_text(v: float, lbl: Label) -> void:
  if is_instance_valid(lbl):
    lbl.text = UI.money(int(round(v)))


## 획득 금액 규모 → 최종 슬램 스케일·화면흔들림 강도·동전음 피치. (클수록 크게 터짐)
func _gain_feel(total: int) -> Dictionary:
  if total >= 15000:
    return {"slam": 1.65, "shake": 24.0, "pitch": 1.3}
  if total >= 6000:
    return {"slam": 1.45, "shake": 15.0, "pitch": 1.2}
  if total >= 2000:
    return {"slam": 1.28, "shake": 8.0, "pitch": 1.1}
  return {"slam": 1.15, "shake": 0.0, "pitch": 1.0}


## 코인 파티클 — from 지점에서 여러 코인이 보유금 라벨로 날아가며 사라짐(금액 클수록 많이).
func _coin_burst(from: Vector2, amount: int, z := 116, target_node: Control = null, icon := "coin") -> void:
  if not is_inside_tree():
    return
  var tgt: Control = target_node if target_node != null else _money_label
  var n := clampi(3 + int(float(amount) / 1500.0), 3, 14)
  var target := tgt.global_position + tgt.size * 0.5
  for i in n:
    var coin := UI.ui_icon(icon, 20)
    coin.z_index = z
    coin.pivot_offset = Vector2(10, 10)
    coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(coin)
    coin.global_position = from + Vector2(randf_range(-26, 26), randf_range(-20, 20))
    var delay := float(i) * 0.025
    var tw := create_tween().set_parallel(true)
    tw.tween_property(coin, "global_position", target, 0.42).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tw.tween_property(coin, "scale", Vector2(0.4, 0.4), 0.42).set_delay(delay)
    tw.tween_property(coin, "modulate:a", 0.0, 0.42).set_delay(delay).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(coin.queue_free)


## breakdown 항목 → 실제 아이콘 노드. recipe/buff id 있으면 텍스처, 없으면 이모지 폴백.
func _gain_icon(entry: Dictionary, px: int) -> Control:
  if entry.has("recipe"):
    return Recipes.icon_node(str(entry["recipe"]), px)
  if entry.has("buff"):
    return BuffDefs.icon_node(str(entry["buff"]), px)
  var lbl := UI.label(str(entry.get("icon", "")), px)
  lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  return lbl


## 버프 추가금 "+N" 팝 — 합계 위에서 살짝 튀어올랐다 떠오르며 사라짐(동전음 없음).
func _spawn_bonus_pop(amount: int, entry: Dictionary, anchor: Vector2) -> void:
  if not is_inside_tree():
    return
  var box := HBoxContainer.new()
  box.add_theme_constant_override("separation", 4)
  box.alignment = BoxContainer.ALIGNMENT_CENTER
  box.z_index = 111
  box.add_child(_gain_icon(entry, 28))
  var amt_l := UI.label("+" + UI.money(amount), 28, GAIN_BUFF_COLOR, true)
  amt_l.add_theme_constant_override("outline_size", 4)
  amt_l.add_theme_color_override("font_outline_color", Palette.WHITE)
  box.add_child(amt_l)
  add_child(box)
  await get_tree().process_frame
  if not is_instance_valid(box):
    return
  box.pivot_offset = box.size * 0.5
  box.position = anchor - Vector2(box.size.x * 0.5, box.size.y + 6.0)
  box.scale = Vector2(0.4, 0.4)
  var tw := create_tween()
  tw.tween_property(box, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.tween_property(box, "scale", Vector2.ONE, 0.08)
  tw.tween_interval(0.1)
  tw.tween_property(box, "position:y", box.position.y - 46.0, 0.34).set_ease(Tween.EASE_IN)
  tw.parallel().tween_property(box, "modulate:a", 0.0, 0.34)
  tw.tween_callback(box.queue_free)


func _on_served(order: OrderCard, dish: DishCard) -> void:
  Audio.play("serve")   # 서빙 완료음(리워드)
  Audio.vibrate(20)   # 서빙 성공 — 짧은 확정 진동
  var rid := order.recipe_id
  # 판매금 계산(판매금/추가금/콤보/적립 전 카드) — sim_core._serve와 동일한 훅.
  var ctx := _sale_ctx(order, dish)
  var res := Buffs.sale_amount(rid, ctx)
  var amount := int(res["amount"])
  _max_sale_today = maxi(_max_sale_today, amount)                       # OP 검사: 최고 단일 판매금
  _max_mult_today = maxf(_max_mult_today, float(res.get("mult", 1.0)))  # OP 검사: 최고 배수
  _expect_fly = true   # 이번 증가 팝은 _fly_gain 도착 때
  _session.earn(amount)
  _expect_fly = false
  var tip := Buffs.serve_tip()
  if tip > 0:
    _session.earn(tip, false)
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
  # 메뉴별 판매 집계(정산 팝업): 기본가(breakdown[0]=base) vs 보너스(나머지)
  var base_this := amount
  var bd: Array = res.get("breakdown", [])
  if bd.size() > 0 and str(bd[0].get("src", "")) == "base":
    base_this = int(bd[0].get("amount", amount))
  var e: Dictionary = _sales_by_menu.get(rid, {"count": 0, "base": 0, "bonus": 0})
  e["count"] = int(e["count"]) + 1
  e["base"] = int(e["base"]) + base_this
  e["bonus"] = int(e["bonus"]) + (amount - base_this)
  _sales_by_menu[rid] = e

  var serve_pos := order.global_position + order.size * 0.5
  _show_gain_breakdown(res.get("breakdown", [{"src": "base", "amount": amount}]))   # 중앙에 기본가+버프별 순차
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


## 자기폐기(48·49 등) 버프 카드를 보드에서 제거(보유 목록은 Buffs.discard가 처리).
## 슬롯에서 빼내 최상위로 올린 뒤 파괴 연출을 재생 → 플레이어가 사라지는 순간을 인지.
func _remove_buff_card(buff_id: String) -> void:
  for s in _board.slots:
    var c := s.get_card()
    if c is BuffCard and c.buff_id == buff_id:
      var gpos := c.global_position
      var parent := c.get_parent()
      if parent != null:
        parent.remove_child(c)   # 슬롯 비움(홀더에서 분리) — clear() 대신 직접 빼서 연출용으로 보존
      add_child(c)
      c.top_level = true
      c.global_position = gpos
      _destroy_buff_card_fx(c)
      return


## 버프 카드 파괴 연출 — 제자리에서 붉게 부풀었다 회전하며 쪼그라들어 사라짐 + 파편 버스트 + 파괴음.
func _destroy_buff_card_fx(c: Control) -> void:
  var center := c.global_position + c.size * 0.5
  c.pivot_offset = c.size * 0.5
  c.z_index = 120
  c.mouse_filter = Control.MOUSE_FILTER_IGNORE
  c.modulate = Palette.DANGER
  Audio.play("trash")
  _shard_burst(center)
  var tw := create_tween()
  tw.tween_property(c, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tw.tween_property(c, "scale", Vector2(0.15, 0.15), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
  tw.parallel().tween_property(c, "rotation", randf_range(-0.7, 0.7), 0.32)
  tw.parallel().tween_property(c, "modulate:a", 0.0, 0.32).set_ease(Tween.EASE_IN)
  tw.chain().tween_callback(c.queue_free)


## 파괴 파편 — 중심에서 사방으로 튀어나가 페이드되는 붉은 조각들.
func _shard_burst(center: Vector2) -> void:
  for i in 8:
    var p := ColorRect.new()
    p.color = Palette.DANGER
    p.size = Vector2(6, 6)
    p.pivot_offset = Vector2(3, 3)
    p.z_index = 121
    p.top_level = true
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(p)
    p.global_position = center
    var ang := TAU * float(i) / 8.0 + randf_range(-0.3, 0.3)
    var dest := center + Vector2(cos(ang), sin(ang)) * randf_range(40.0, 85.0)
    var tw := create_tween().set_parallel(true)
    tw.tween_property(p, "global_position", dest, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.tween_property(p, "scale", Vector2(0.2, 0.2), 0.35)
    tw.tween_property(p, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(p.queue_free)


## 마감 정산 훅(가게세 차감 전) — 정산 보너스/차감(63~65,73,50)을 세션에 반영.
func _on_day_closing(s: Session) -> void:
  var same_max := 0
  for k in _served_by_menu:
    same_max = maxi(same_max, int(_served_by_menu[k]))
  var ctx := {
    "served": _served_today,
    "visited": _visited_today,
    "missed": _missed_today,
    "accepted": _accepted_today,
    "order_lost": _order_lost_today,
    "same_max": same_max,
    "day_revenue": s.day_revenue,
    "cash": s.cash,
    "rent": s.rent,
  }
  var db := Buffs.day_end_bonus(ctx)
  var score_g := int(db["score"])   # 정산3형제·콩고물 = 점수
  var money_g := int(db["money"])   # 손절 = 돈
  _week_reward = Config.week_reward(_session.day, _served_today)   # 주 클리어 보상 — 지급은 실적검사 통과 후(_settle_pass)
  if score_g != 0 or money_g != 0:
    _settle_bonus = money_g   # 코인 연출은 돈만(점수는 라벨만 갱신)

    _expect_fly = true
    if score_g != 0:
      s.earn(score_g, true)
    if money_g != 0:
      s.earn(money_g, false)
    _expect_fly = false
    _money_label.text = UI.money(_last_cash - money_g)
  for id in db.get("destroy", []):   # 만기 도달한 적금(78) 카드 파괴 연출
    _remove_buff_card(id)


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
  ghost.animal = card.animal            # 실물과 같은 손님(동물)로 — 날아갈 때 안 바뀌게
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
  # 감정 이모지는 손그림 아이콘으로(😊 만족 / 💢 조급 / 😠 화남). 그 외는 이모지 라벨.
  var mood := {"😊": "mood_happy", "💢": "mood_impatient", "😠": "mood_angry"}
  var l: Control
  if mood.has(text):
    l = UI.ui_icon(mood[text], 30)
    l.size = Vector2(30, 30)
  else:
    l = UI.label(text, 30)
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
## 실적 라벨 갱신 — 현재 누적/이번 주 관문.
func _update_score_bar() -> void:
  if _score_label == null or _session == null:
    return
  var target := int(Levels.get_week(_session.day)["target"])
  _score_label.text = "%s/%s" % [UI.money(_session.month_score), UI.money(target)]
  _score_label.add_theme_color_override("font_color",
    Palette.SUCCESS if _session.month_score >= target else Palette.DANGER)


func _on_cash_changed(cash: int) -> void:
  var delta := cash - _last_cash
  _last_cash = cash
  _money_label.text = UI.money(cash)
  _update_score_bar()
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
    p.add_to_group("confetti")   # 새 게임/홈 이동 시 일괄 제거용
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


## 큰 중앙 배너 화면 — 딤(어두운 배경) + 이미지(달/해) 크게 + 텍스트(CLOSE/OPEN) + 하단 "click ▸" 힌트.
## 자동 페이드 안 함(탭 대기 동안 유지). 딤·내용·힌트를 담은 루트 Control 반환(탭 시 통째로 페이드).
## OPEN 배너용 월 진행 트랙 — 주차 노드(●◉○) ─ … ─ [🧾 월세]. 끝의 청구서=이번 달 납부 목표.
## 월말 주(4주차)면 빨강+점멸 + "본사 감사" 문구. 그 외엔 "이번 주 실적 심사".
func _month_track(week: int) -> Control:
  var wk := Levels.get_week(week)
  var wim := int(wk["week_in_month"])       # 1..4 (이번 달 몇 주차)
  var is_end: bool = wk["is_month_end"]
  var wpm := Levels.WEEKS_PER_MONTH

  var v := VBoxContainer.new()
  v.alignment = BoxContainer.ALIGNMENT_CENTER
  v.add_theme_constant_override("separation", 6)
  v.mouse_filter = Control.MOUSE_FILTER_IGNORE

  var row := HBoxContainer.new()
  row.alignment = BoxContainer.ALIGNMENT_CENTER
  row.add_theme_constant_override("separation", 3)
  row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  for i in range(1, wpm):   # 주차 점 1..(wpm-1). 지난주 ●, 이번주 ◉, 미래 ○
    var glyph := "●" if i < wim else ("◉" if i == wim else "○")
    var dot := UI.label(glyph, 24 if i == wim else 18, Palette.WHITE if i <= wim else Color(1, 1, 1, 0.45), true)
    dot.add_theme_constant_override("outline_size", 3)
    dot.add_theme_color_override("font_outline_color", Palette.COCOA_900)
    dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(dot)
    var conn := UI.label("─", 16, Color(1, 1, 1, 0.45), true)
    conn.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(conn)
  # 끝 = 심사 노드(별 아이콘 — 실적 심사)
  var goal := UI.ui_icon("star", 28)
  goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_child(goal)
  v.add_child(row)

  # 월말(보스날)=본사 감사, 그 외=N주 뒤 보스 카운트다운
  var msg := Loc.t("month_audit") if is_end else Loc.t("boss_incoming") % int(wk["weeks_left"])
  var lbl := UI.label(msg, 18, Palette.DANGER if is_end else Palette.WHITE, true)
  lbl.add_theme_constant_override("outline_size", 4)
  lbl.add_theme_color_override("font_outline_color", Palette.COCOA_900)
  lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
  v.add_child(lbl)

  if is_end:   # 납부 주 — 문구 점멸(긴장)
    var pt := create_tween().set_loops()
    pt.tween_property(lbl, "modulate:a", 0.4, 0.5).set_trans(Tween.TRANS_SINE)
    pt.tween_property(lbl, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
    lbl.tree_exiting.connect(pt.kill)   # 배너 제거 시 루핑 트윈 종료(free된 대상 step → 릴리스 무한루프 방지)
  else:   # 노란 줄 = 그 4주차에 걸릴 제약 미리보기
    var pen := Boss.preview_for_month(int(wk["month"]))
    var pen_lbl := UI.label("%s %s" % [pen["icon"], Loc.t("boss." + str(pen["type"]))], 13, Palette.ACCENT, true)
    pen_lbl.add_theme_constant_override("outline_size", 3)
    pen_lbl.add_theme_color_override("font_outline_color", Palette.COCOA_900)
    pen_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pen_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(pen_lbl)
  return v


func _make_bigbanner(icon_name: String, text: String, dim_fade := 0.3, extra: Control = null) -> Control:
  var root := Control.new()
  root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  root.z_index = 200
  root.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(root)

  var dim := ColorRect.new()   # 어두운 배경(흐림 효과)
  dim.color = Color(0.164, 0.129, 0.106, 0.55)
  dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  dim.mouse_filter = Control.MOUSE_FILTER_STOP   # 딤 뜬 동안 뒤 버튼(창고 등) 클릭 차단
  root.add_child(dim)

  var center := CenterContainer.new()   # 이미지+텍스트 정중앙
  center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  center.mouse_filter = Control.MOUSE_FILTER_IGNORE
  root.add_child(center)
  var box := VBoxContainer.new()
  box.alignment = BoxContainer.ALIGNMENT_CENTER
  box.add_theme_constant_override("separation", 8)
  box.mouse_filter = Control.MOUSE_FILTER_IGNORE
  center.add_child(box)
  var img := UI.ui_icon(icon_name, 100)   # 달/해 크게
  img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  box.add_child(img)
  var l := UI.label(text, 54, Palette.WHITE, true)   # 딤 위라 흰 글씨
  l.add_theme_constant_override("outline_size", 8)
  l.add_theme_color_override("font_outline_color", Palette.COCOA_900)
  l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  l.mouse_filter = Control.MOUSE_FILTER_IGNORE
  box.add_child(l)
  if extra != null:
    box.add_child(extra)
    extra.modulate.a = 0.0

  var hint := UI.label("click ▸", 20, Palette.WHITE, true)   # 하단 탭 유도 힌트
  hint.add_theme_constant_override("outline_size", 4)
  hint.add_theme_color_override("font_outline_color", Palette.COCOA_900)
  hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
  root.add_child(hint)

  # 등장 순서: 딤 → 해/달이 서서히(약 0.9초) 떠오름 → 다 보이면 글자 팝 → 힌트.
  # 해/달이 완전히 뜬 뒤에야 반환 → 그 후에만 탭(다음)이 가능(호출측이 반환 대기).
  dim.modulate.a = 0.0 if dim_fade > 0.0 else 1.0   # 즉시 딤이면 처음부터 꽉(첫 프레임부터 어두움)
  img.modulate.a = 0.0
  img.scale = Vector2(0.5, 0.5)
  l.modulate.a = 0.0
  l.scale = Vector2(0.7, 0.7)
  hint.modulate.a = 0.0
  await get_tree().process_frame   # 크기 확보 → 피벗·힌트 배치
  if not is_instance_valid(root):
    return null
  var vp := get_viewport_rect().size
  if extra != null:
    center.offset_bottom = -vp.y * 0.14   # 트랙(예고 줄)이 있으면 중앙 블록을 위로 올려 힌트와 겹침 방지
  img.pivot_offset = img.size * 0.5
  l.pivot_offset = l.size * 0.5
  hint.position = Vector2((vp.x - hint.size.x) * 0.5, vp.y * 0.72 - 60.0)   # 하단 중앙(위로)

  if dim_fade > 0.0:
    create_tween().tween_property(dim, "modulate:a", 1.0, dim_fade)   # 배경 서서히 어두워짐

  var it := create_tween().set_parallel(true)   # 해/달 서서히 떠오름(페이드+확대)
  it.tween_property(img, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
  it.tween_property(img, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
  await it.finished
  if not is_instance_valid(root):
    return null

  var lt := create_tween()   # 해/달 다 뜨면 글자 딱 팝
  lt.tween_property(l, "modulate:a", 1.0, 0.14)
  lt.parallel().tween_property(l, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  lt.tween_property(l, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
  await lt.finished

  if extra != null:
    var et := create_tween()
    et.tween_property(extra, "modulate:a", 1.0, 0.25)
    await et.finished

  var hp := create_tween()   # 힌트 페이드인 후 깜빡 펄스(탭 유도)
  hp.tween_property(hint, "modulate:a", 1.0, 0.3)
  hp.set_loops()
  hp.tween_property(hint, "modulate:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)
  hp.tween_property(hint, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
  # 루핑 트윈은 Main에 바인딩돼 있어 대상(hint)이 free돼도 계속 step → 릴리스에서 무한루프.
  # 대상이 트리에서 빠질 때 트윈을 확실히 종료(디버그만 안전처리되던 엔진 버그 회피).
  hint.tree_exiting.connect(hp.kill)
  return root


## 탭 대기 — 전체화면 캐처(투명). 탭하면 반환. (배너는 별도로 유지·페이드)
func _tap_to_continue() -> void:
  var catcher := Button.new()
  catcher.flat = true
  catcher.focus_mode = Control.FOCUS_NONE
  catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  catcher.z_index = 350
  add_child(catcher)
  await catcher.pressed
  catcher.queue_free()


## 인트로 배너 정리 — 탭 후 호출. 페이드아웃 후 제거.
func _dismiss_banner(banner: Control) -> void:
  if not is_instance_valid(banner):
    return
  var bt := create_tween()
  bt.tween_property(banner, "modulate:a", 0.0, 0.22)
  bt.tween_callback(banner.queue_free)


## 하루 시작 인트로 — 해 + OPEN 배너 + 딤 → 유저 탭해야 게임(시계·스폰) 시작.
## (배너 등장 시엔 무음 — 소리는 아래 탭 시점의 개점음만)
func _start_day_intro() -> void:
  var banner: Control = await _make_bigbanner("sun_big", "OPEN", 0.0, _month_track(_session.day))   # 해 + OPEN + 월세 예고 트랙
  await _tap_to_continue()
  if not is_inside_tree() or _title.visible:
    if is_instance_valid(banner): banner.queue_free()
    return
  Audio.play("door_open")   # OPEN 화면 탭 = 가게 문 여는 개점 효과음
  Audio.play("day_start")   # + 어서오세요(개점) — door_open이 약해 함께 재생해 확실히 들리게
  if is_instance_valid(_session):
    _session.set_process(true)   # 탭 후 게임플레이(시계·손님 스폰) 시작
  _dismiss_banner(banner)


## 보스 하루 인트로 — 계약 갱신 심사 배너(제약 예고 + 재계약비 목표) → 탭 시 시작.
func _start_boss_intro() -> void:
  var banner := _make_boss_banner()
  await _tap_to_continue()
  if not is_inside_tree() or _title.visible:
    if is_instance_valid(banner): banner.queue_free()
    return
  Audio.play("door_open")
  Audio.play("day_start")
  if is_instance_valid(_session):
    _session.set_process(true)
  _dismiss_banner(banner)


## 계약 갱신 심사 배너 — 딤 + 📜 + 제목 + 제약(아이콘+이름) + 재계약비 목표 + click. 루트 반환.
func _make_boss_banner() -> Control:
  var root := Control.new()
  root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  root.z_index = 200
  root.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(root)
  var dim := ColorRect.new()
  dim.color = Color(0.164, 0.129, 0.106, 0.62)
  dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  dim.mouse_filter = Control.MOUSE_FILTER_STOP
  root.add_child(dim)
  var center := CenterContainer.new()
  center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  center.mouse_filter = Control.MOUSE_FILTER_IGNORE
  root.add_child(center)
  var box := VBoxContainer.new()
  box.alignment = BoxContainer.ALIGNMENT_CENTER
  box.add_theme_constant_override("separation", 10)
  box.mouse_filter = Control.MOUSE_FILTER_IGNORE
  center.add_child(box)
  # 📜 + 심사 제목
  var seal := UI.label("📜", 84)
  seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  box.add_child(seal)
  var title := UI.label(Loc.t("boss.title"), 40, Palette.WHITE, true)
  title.add_theme_constant_override("outline_size", 8)
  title.add_theme_color_override("font_outline_color", Palette.COCOA_900)
  title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  box.add_child(title)
  # 제약 칩(아이콘 + 이름)
  var chip := HBoxContainer.new()
  chip.alignment = BoxContainer.ALIGNMENT_CENTER
  chip.add_theme_constant_override("separation", 6)
  if Boss.kind() == "time_short":
    chip.add_child(UI.ui_icon("timer", 34))
  else:
    chip.add_child(UI.label(Boss.icon(), 34))
  chip.add_child(UI.label(Boss.label(), 26, Palette.WHITE, true))
  box.add_child(chip)
  # 재계약비 목표(마감까지 확보)
  var hint := UI.label(Loc.t("boss.hint") % UI.money(_session.rent), 20, Palette.WHITE, true)
  hint.add_theme_constant_override("outline_size", 4)
  hint.add_theme_color_override("font_outline_color", Palette.COCOA_900)
  hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  box.add_child(hint)
  var tap := UI.label("click ▸", 20, Palette.WHITE, true)
  tap.add_theme_constant_override("outline_size", 4)
  tap.add_theme_color_override("font_outline_color", Palette.COCOA_900)
  tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  box.add_child(tap)
  return root


## 화면 전체 흔들림 — 루트(self) 위치를 감쇠 랜덤으로 흔들고 0으로 복귀. 마감 임팩트용.
func _screen_shake(strength := 13.0, dur := 0.45) -> void:
  var steps := 7
  var tw := create_tween()
  for i in steps:
    var damp := strength * (1.0 - float(i) / float(steps))
    var off := Vector2(randf_range(-damp, damp), randf_range(-damp, damp))
    tw.tween_property(self, "position", off, dur / float(steps + 1)).set_trans(Tween.TRANS_SINE)
  tw.tween_property(self, "position", Vector2.ZERO, dur / float(steps + 1)).set_trans(Tween.TRANS_SINE)


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


## 창고 트립 시간 소모 피드백 — 영업시간 바의 먹힌 구간 빨강 플래시 + "⏱ -N초" 플로터.
func _show_trip_cost(cost: float, before_v: float, after_v: float) -> void:
  if cost <= 0.0 or after_v <= before_v:
    return
  var bx := _hours_bar.global_position
  var bw := _hours_bar.size.x
  var bh := _hours_bar.size.y
  # 먹힌 구간 빨강 플래시(얇으면 최소폭 보정)
  var seg := ColorRect.new()
  seg.color = Palette.DANGER
  seg.z_index = 120
  seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(seg)
  seg.global_position = Vector2(bx.x + bw * before_v / 100.0, bx.y)
  seg.size = Vector2(maxf(6.0, bw * (after_v - before_v) / 100.0), bh)
  var st := create_tween()
  st.tween_property(seg, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
  st.chain().tween_callback(seg.queue_free)
  # 시계 아이콘 + "-N초" — 화면 중앙에 크게 팝(시선 유도)
  var l := HBoxContainer.new()
  l.alignment = BoxContainer.ALIGNMENT_CENTER
  l.add_theme_constant_override("separation", 6)
  l.add_child(UI.ui_icon("timer", 40))
  var amt := UI.label("-%.1f초" % cost, 40, Palette.DANGER, true)
  amt.add_theme_constant_override("outline_size", 6)
  amt.add_theme_color_override("font_outline_color", Palette.WHITE)
  l.add_child(amt)
  l.z_index = 200
  l.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(l)
  await get_tree().process_frame   # 크기 확보 → 중앙 정렬·피벗
  if not is_instance_valid(l):
    return
  var vp := get_viewport_rect().size
  l.pivot_offset = l.size * 0.5
  l.position = (vp - l.size) * 0.5 - Vector2(0, vp.y * 0.05)
  l.scale = Vector2(1.5, 1.5)
  l.modulate.a = 0.0
  var lt := create_tween()
  lt.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  lt.parallel().tween_property(l, "modulate:a", 1.0, 0.12)
  lt.tween_interval(0.35)
  lt.tween_property(l, "modulate:a", 0.0, 0.4)
  lt.tween_callback(l.queue_free)


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
  # 카운트다운마다 화면 흔들림 + 나무 똑딱 틱(0초에 가까울수록 피치↑=긴박감). dur<1s라 겹침 없음.
  _screen_shake(4.0 + float(COUNTDOWN_FROM - sec) * 2.5, 0.4)
  Audio.play("countdown", 1.0 + float(COUNTDOWN_FROM - sec) * 0.08)   # 5:1.0 → 1:1.32
  Audio.vibrate(15)   # 마지막 5초 — 매 초 톡(긴장)
  _pulse_countdown_edge()   # 화면 가장자리 빨강 비네트 — 마감 임박 원인 구분(A안)
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


## 카운트다운 빨강 비네트 1회 펄스(페이드인→아웃). 지연 생성, 평소엔 alpha 0이라 안 보임.
## 접수 불가(슬롯 빨강 플래시)와 원인을 구분하는 시간압박 신호 — 화면 "가장자리"에만 뜸.
func _pulse_countdown_edge() -> void:
  if _countdown_edge == null:
    _countdown_edge = Panel.new()
    _countdown_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _countdown_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _countdown_edge.z_index = 190   # 카운트다운 숫자(200)보다 아래, 게임판 위
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0, 0, 0, 0)   # 중앙 투명 — 테두리만
    sb.set_border_width_all(20)       # 가장자리 두께
    sb.border_color = Palette.DANGER
    sb.border_blend = true            # 안쪽으로 부드럽게 번지게(비네트 느낌)
    _countdown_edge.add_theme_stylebox_override("panel", sb)
    add_child(_countdown_edge)
  _countdown_edge.modulate.a = 0.0
  var t := create_tween()
  t.tween_property(_countdown_edge, "modulate:a", 0.7, 0.12).set_trans(Tween.TRANS_SINE)
  t.tween_property(_countdown_edge, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


## 영업시간 바를 평상 상태로 되돌림(색·펄스 리셋).
func _reset_hours_bar() -> void:
  if _hours_glow != null:
    _hours_glow.kill()
    _hours_glow = null
  _hours_bar.modulate.a = 1.0
  _hours_warning = false
  _hours_bar.add_theme_stylebox_override("fill", UI.chip(Palette.ACCENT))


func _on_day_started(day: int, rent: int) -> void:
  _day_num.text = str(day)
  # 하루 시작 홀드 — 게임플레이(시계·스폰) 정지. 인트로(딤+OPEN 배너)는 함수 끝에서 즉시 표시.
  # (예전엔 DAY_INTRO_DELAY 뒤에 떠서 그 사이 딤 없는 빈 화면이 보였음 → 진입 즉시 딤으로 변경)
  _session.set_process(false)
  _update_score_bar()
  _hours_bar.value = 0
  _reset_hours_bar()   # 새 하루 — 바 색·펄스 초기화
  _last_countdown = 0  # 카운트다운 상태 리셋
  _clear_blackout()    # 폐업 암전 잔재 제거(재도전 시)
  # 새 세션 시작 — 시트 강제 닫기(트립 비용 없음)
  _warehouse.visible = false
  _cooking.visible = false
  _buff_sheet.visible = false
  _backdrop.visible = false
  # 하루 정산 카운터 리셋(sim_core._reset_day_consumables와 동치)
  _visited_today = 0
  _accepted_today = 0
  _served_today = 0
  _order_lost_today = 0
  _missed_today = 0
  _max_sale_today = 0
  _max_mult_today = 1.0
  _served_by_menu = {}
  _sales_by_menu = {}
  _settle_bonus = 0
  _week_reward = 0
  Buffs.reset_day()   # #45 적립 하루 리셋
  # 보드 재구성: 작업 슬롯 = 실효 슬롯(상점확장 + 구조버프12 slot_bonus).
  #   추가로 버프칸 보너스(11 buff_slot)만큼 슬롯을 더 둬서 그만큼 버프가 "공짜"로 얹히게 함
  #   → 순 작업공간 = effective_slots - max(0, 보유버프수 - buff_slot_bonus) (sim_core._serve_cap과 동치).
  Move.clear()
  _board.rebuild(_session.effective_slots() + Buffs.buff_slot_bonus())
  # 보유 버프는 슬롯을 점유(배치형) — 작업공간과 트레이드오프.
  # 지난 주 안착 위치(Buffs.slot_pos)를 우선 복원, 무효(신규·범위밖·이미 참)면 first_empty 폴백.
  for id in Buffs.owned():
    var idx := Buffs.slot_pos(id)
    var slot: Slot = null
    if idx >= 0 and idx < _board.slots.size() and _board.slots[idx].is_empty():
      slot = _board.slots[idx]
    else:
      slot = _board.first_empty_slot()
    if slot:
      var bc := BuffCard.new()
      bc.setup(id)
      slot.place_card(bc, false)   # 버프 재배치는 무음(매일 리빌드 버스트 방지)
  if Boss.locked_slots() > 0:   # 보스(좁은 주방): 버프 배치 후 뒤쪽 빈칸 잠금
    _board.lock_last_slots(Boss.locked_slots())
  for c in _queue_row.get_children():
    c.queue_free()
  _refresh_warehouse()
  _refresh_buff_btn()   # 이 판의 보유 버프 유무로 [버프] 버튼 활성화
  # 게임 화면 진입 즉시 딤+OPEN 배너(지연·페이드 없이 바로 어두워짐).
  if is_inside_tree() and not _title.visible:
    if Boss.is_active():
      _start_boss_intro()
    else:
      _start_day_intro()


## 실플레이 로그 — 하루 마감 지표를 user://playlog.jsonl 에 1줄 추가(카운터 리셋 전 호출).
func _log_day(summary: Dictionary) -> void:
  var wk := Levels.get_week(int(summary.get("day", 0)))
  PlayLog.append({
    "run": _run_id,
    "t": Time.get_datetime_string_from_system(),
    "day": int(summary.get("day", 0)),
    "month": int(wk["month"]),
    "week_in_month": int(wk["week_in_month"]),
    "is_month_end": bool(wk["is_month_end"]),
    "monthly_target": int(wk["monthly_rent"]),
    "due_target": int(summary.get("rent", 0)),
    "day_score": int(summary.get("revenue", 0)),
    "month_score": int(summary.get("month_score", 0)),
    "cash": int(summary.get("cash_after", 0)),
    "passed": bool(summary.get("passed", false)),
    "won": bool(summary.get("won", false)),
    "visited": _visited_today,
    "accepted": _accepted_today,
    "served": _served_today,
    "lost": _order_lost_today,
    "max_sale": _max_sale_today,
    "max_mult": snappedf(_max_mult_today, 0.01),
    "slots": _session.slots,
    "buffs": Buffs.owned(),
    "boss": Boss.kind(),
  })
  if OS.has_feature("editor"):
    print("[PLAYLOG] ", PlayLog.abs_path())


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
  _log_day(summary)   # 실플레이 지표 기록(카운터 리셋 전)
  # 창고/조리 시트가 열린 채 마감되면 즉시 치워 상점·다음날에 안 남게 (트립 비용 없이).
  # force_close: 슬라이드 트윈이 끊겨 열린 채 남는 버그 방지.
  _warehouse.force_close()
  _cooking.force_close()
  _buff_sheet.force_close()
  _backdrop.visible = false
  if summary["won"]:
    _session.pay_rent()   # 승리 확정 전 가게세 정산(세션은 더 이상 자동 차감 안 함)
    _clear_play_field()   # 마감 즉시 필드 비움
    Modal.open(self) \
      .title(Loc.t("win_title")) \
      .stamp_row(Loc.t("win_days") % Levels.count(), Palette.SUCCESS, 0.15) \
      .button(Loc.t("to_title"), _show_title)
    _celebrating = true
    _spawn_confetti()   # 축포 한 번
    # 6초 뒤 2차 축포 — 그 사이 타이틀/새 게임으로 나갔으면(_celebrating=false) 취소
    get_tree().create_timer(6.0).timeout.connect(func():
      if _celebrating:
        _spawn_confetti(46))
  else:
    # 마감 임팩트: 마감 종 + 큰 중앙 날짜 배너. (화면 흔들림 없음 — 흔들림은 막판 카운트다운에서만)
    Audio.play("day_close")   # 영업 종료 딩동(마감 임팩트)
    Audio.vibrate(40)   # 하루 마감 임팩트 — 묵직한 진동
    var banner: Control = await _make_bigbanner("moon_big", "CLOSE")   # 달(고해상도) + CLOSE + 딤 (유지)
    # 남은 슬롯 카드 팝 소멸은 백그라운드로(await 안 함) — "click ▸" 뜨자마자 탭이 먹히게.
    # (예전엔 이 시퀀스를 await한 뒤에야 탭 캐처가 생겨서, 힌트만 뜨고 몇 초간 클릭이 안 먹었음)
    _dayend_sequence()
    # 자동으로 정산 안 감 — 배너 유지한 채 유저 탭 대기, 탭하면 정산 팝업.
    await _tap_to_continue()
    if not is_inside_tree() or _title.visible:
      if is_instance_valid(banner): banner.queue_free()
      return   # 탭 전에 홈으로 나갔으면 정산 팝업 생략(타이틀 위에 안 뜨게)
    if is_instance_valid(banner):
      var bt := create_tween()
      bt.tween_property(banner, "modulate:a", 0.0, 0.22)
      bt.tween_callback(banner.queue_free)
    _show_settlement(summary)      # 매주 — 실적확인(점수 판정) 팝업


## 하루 정산 팝업 — 영수증(빌지) 이미지 + 가게세 액수 → [가게세 지불] 버튼.
## 지불 시 실제 차감(pay_rent) + 빌지 이미지를 같은 크기의 결과 표시(✅/❌)로 교체.
## 오늘 판매 내역 UI — 메뉴별 [아이콘 ×개수 … 판매금 +보너스] + 합계. 판매 없으면 null.
func _sales_rows() -> Control:
  if _sales_by_menu.is_empty():
    return null
  var box := VBoxContainer.new()
  box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  box.add_theme_constant_override("separation", 5)
  var sum_total := 0
  var sum_bonus := 0
  for rid in Recipes.all_ids():   # 등급(정의) 순
    if not _sales_by_menu.has(rid):
      continue
    var e: Dictionary = _sales_by_menu[rid]
    var bonus: int = int(e["bonus"])
    var line_total: int = int(e["base"]) + bonus
    sum_total += line_total
    sum_bonus += bonus
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 6)
    row.add_child(Recipes.icon_node(rid, 30))
    row.add_child(UI.label("×%d" % int(e["count"]), 15, Palette.COCOA_600, true))
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(gap)
    row.add_child(UI.ui_icon("star", 16))
    row.add_child(UI.label(UI.money(line_total), 15, Palette.COCOA_800, true))
    if bonus > 0:
      row.add_child(UI.label("  +" + UI.money(bonus), 13, Palette.MAIN))
    box.add_child(row)
  var line := ColorRect.new()
  line.color = Palette.COCOA_200
  line.custom_minimum_size = Vector2(0, 1.5)
  box.add_child(line)
  var trow := HBoxContainer.new()
  trow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  trow.add_theme_constant_override("separation", 6)
  trow.add_child(UI.label("합계", 15, Palette.COCOA_600, true))
  var tgap := Control.new()
  tgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  trow.add_child(tgap)
  trow.add_child(UI.ui_icon("star", 16))
  trow.add_child(UI.label(UI.money(sum_total), 16, Palette.COCOA_800, true))
  if sum_bonus > 0:
    trow.add_child(UI.label("  +" + UI.money(sum_bonus), 13, Palette.MAIN))
  box.add_child(trow)
  return box


## 오늘 손님 이탈 — 방문 대비 떠난(놓친) 손님 수. 완벽/우수정산 처리율의 근거를 마감에 노출.
##   이탈 = 대기열 이탈 + 주문 이탈(_missed_today), 분모 = 등장 손님(_visited_today).
func _churn_row() -> Control:
  if _visited_today <= 0:
    return null
  var row := HBoxContainer.new()
  row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_theme_constant_override("separation", 6)
  row.add_child(UI.label(Loc.t("settle_churn"), 15, Palette.COCOA_600, true))
  var gap := Control.new()
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(gap)
  var col := Palette.DANGER if _missed_today > 0 else Palette.SUCCESS
  var pct := int(round(float(_missed_today) / float(_visited_today) * 100.0))
  row.add_child(UI.label("%d%%" % pct, 16, col, true))
  return row


## 마감 추가금(day_end_bonus: 64·65·66·74 등) 정산 팝업 행 — 있으면 "마감 보너스 +N" 행을 넣고,
## 코인이 지갑으로 날아가며 상단 보유금이 촤르륵 오르는 연출(서빙 획득과 동일 결). earn은 이미 됨.
func _add_settle_bonus_row(m: Modal) -> void:
  if _settle_bonus <= 0:
    return
  var bonus := _settle_bonus
  _settle_bonus = 0
  var row := HBoxContainer.new()
  row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_theme_constant_override("separation", 6)
  row.add_child(UI.label(Loc.t("settle_bonus"), 15, Palette.MAIN, true))
  var gap := Control.new()
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(gap)
  row.add_child(UI.ui_icon("coin", 16))
  var amt_l := UI.label(UI.money(0), 16, Palette.MAIN, true)
  row.add_child(amt_l)
  m.add_row(row)
  _animate_settle_bonus(amt_l, bonus)


## 주 클리어 보상 지급 — 실적검사 통과 시에만 호출. 지금 earn + "주간 보상 +N" 행 + 코인 연출.
func _pay_week_reward(m: Modal) -> void:
  if _week_reward <= 0:
    return
  var reward := _week_reward
  _week_reward = 0
  _expect_fly = true
  _session.earn(reward, false)   # 통과 확정 후 실제 지급(연출은 아래 카운트업)
  _expect_fly = false
  _money_label.text = UI.money(_last_cash - reward)   # 롤백 후 카운트업으로 채움
  var row := HBoxContainer.new()
  row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_theme_constant_override("separation", 6)
  row.add_child(UI.label(Loc.t("week_reward"), 15, Palette.MAIN, true))
  var gap := Control.new()
  gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  row.add_child(gap)
  row.add_child(UI.ui_icon("coin", 16))
  var amt_l := UI.label(UI.money(0), 16, Palette.MAIN, true)
  row.add_child(amt_l)
  m.add_row(row)
  _animate_settle_bonus(amt_l, reward)


## 위 행의 등장 연출(비동기) — 팝업 +금액 카운트업 + 코인 버스트 + 상단 보유금 카운트업/팝.
func _animate_settle_bonus(amt_l: Label, bonus: int) -> void:
  await get_tree().process_frame   # 레이아웃 확정 후 위치 사용
  if not is_instance_valid(amt_l) or not is_inside_tree():
    return
  var cu := create_tween()
  cu.tween_method(func(v: float): amt_l.text = UI.money(int(round(v))), 0.0, float(bonus), 0.6) \
    .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  var from := amt_l.global_position + amt_l.size * 0.5
  _coin_burst(from, bonus, 350)   # z 350 — 모달 딤(300) 위로 보이게
  var mc := create_tween()
  mc.tween_method(_set_money_text.bind(_money_label), float(_last_cash - bonus), float(_last_cash), 0.6)
  mc.tween_callback(func(): _pop_label(_money_label))
  Audio.play("coins", 1.1)


func _show_settlement(summary: Dictionary) -> void:
  var m := Modal.open(self).title(Loc.t("day_closed") % summary["day"]).gap(5)

  var sr := _sales_rows()
  if sr != null:
    m.add_row(sr)   # 오늘 판매 내역(메뉴별 + 합계)
  var cr := _churn_row()   # 오늘 손님 이탈(방문 대비 떠난 손님)
  if cr != null:
    m.add_row(cr)
  var had_bonus := _settle_bonus > 0
  _add_settle_bonus_row(m)   # 마감 추가금(있으면) 행 + 돈 오르는 연출
  if had_bonus:
    var sp := Control.new()
    sp.custom_minimum_size = Vector2(0, 30)   # 마감 보너스↔목표 ~40px(모달 간격 5×2 포함)
    m.add_row(sp)

  # 통과 목표 — 별 + 목표점수(점수 게이트라 코인이 아닌 별로 표시)
  var goal_lbl := UI.label(UI.money(int(summary["rent"])), 26, Palette.COCOA_800, true)
  var goal_row := _settle_icon_row("star", goal_lbl, 26)
  goal_row.modulate.a = 1.0   # _settle_icon_row 기본 숨김(0) — 정적 표시라 바로 보이게
  m.add_row(goal_row)

  # '실적확인' 버튼(핵심 액션) — 처음 숨김 → 잠깐 뒤 등장. 클릭 시 점수로 통과 판정.
  var check_btn := Button.new()
  check_btn.text = Loc.t("check_score")
  check_btn.custom_minimum_size = Vector2(0, 48)
  check_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  check_btn.add_theme_font_size_override("font_size", 18)
  check_btn.add_theme_color_override("font_color", Palette.WHITE)
  check_btn.add_theme_color_override("font_hover_color", Palette.WHITE)
  check_btn.add_theme_color_override("font_pressed_color", Palette.WHITE)
  check_btn.add_theme_color_override("font_disabled_color", Palette.COCOA_600)
  check_btn.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
  check_btn.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
  check_btn.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
  check_btn.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_200))
  check_btn.modulate.a = 0.0
  check_btn.disabled = true
  check_btn.pressed.connect(func(): _on_check_score(summary, m, check_btn))
  Audio.attach_click(check_btn)
  m.add_row(check_btn)

  # 등장 연출: 잠깐 뒤 [실적확인] 버튼 페이드인
  var tw := create_tween()
  tw.tween_interval(0.25)
  tw.tween_callback(func():
    check_btn.disabled = false
    create_tween().tween_property(check_btn, "modulate:a", 1.0, 0.2))


## 실적확인 클릭 — 이제까지 모은 점수(month_score)로 통과/미통과 판정.
## 통과: ✅ + [상점으로]. 미통과: [지불하기(목표점수 1/100 소모)]·[파산 신청] 두 버튼 노출(1회).
func _on_check_score(summary: Dictionary, m: Modal, check_btn: Button) -> void:
  var goal: int = int(summary["rent"])
  if int(summary["month_score"]) >= goal:   # 점수로 통과 — 무료
    _settle_pass(summary, m, check_btn)
    return
  # 미통과 — [지불하기]·[파산 신청] 선택지 노출(1회만)
  if check_btn.get_meta("opts_shown", false):
    return
  check_btn.set_meta("opts_shown", true)   # 재클릭해도 선택지 중복 추가 방지(버튼은 활성 유지)
  Audio.play("disabled")   # 미통과 피드백음
  Audio.vibrate(30)
  m.pin_top()   # 팝업 위치 고정 → 실적확인 버튼은 두고 아래로만 버튼 추가

  var fee: int = maxi(maxi(1, int(goal / Config.SCORE_GATE_FEE_DIV)), _session.cash - Config.SCORE_GATE_FEE_KEEP)   # max(목표점수 1/N, 보유금-KEEP) — 부유하면 KEEP만 남기고 소진
  var wrap := VBoxContainer.new()
  wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  wrap.add_theme_constant_override("separation", 8)
  wrap.modulate.a = 0.0

  # 지불하기 — 코인 아이콘 + "{fee} 소모". 잔액 부족이면 비활성.
  var pay_btn := Button.new()
  var pay_row := HBoxContainer.new()
  pay_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  pay_row.alignment = BoxContainer.ALIGNMENT_CENTER
  pay_row.add_theme_constant_override("separation", 5)
  pay_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  var pay_coin := UI.ui_icon("coin", 20)
  pay_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  pay_row.add_child(pay_coin)
  var pay_lbl := UI.label(Loc.t("pay_fee") % UI.money(fee), 18, Palette.WHITE, true)
  pay_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  pay_row.add_child(pay_lbl)
  pay_btn.add_child(pay_row)
  pay_btn.custom_minimum_size = Vector2(0, 48)
  pay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  pay_btn.add_theme_font_size_override("font_size", 18)
  pay_btn.add_theme_color_override("font_color", Palette.WHITE)
  pay_btn.add_theme_color_override("font_hover_color", Palette.WHITE)
  pay_btn.add_theme_color_override("font_pressed_color", Palette.WHITE)
  pay_btn.add_theme_stylebox_override("normal", UI.chip(Palette.DANGER))
  pay_btn.add_theme_stylebox_override("hover", UI.chip(Palette.DANGER.lightened(0.08)))
  pay_btn.add_theme_stylebox_override("pressed", UI.chip(Palette.DANGER.darkened(0.1)))
  pay_btn.add_theme_stylebox_override("disabled", UI.chip(Palette.COCOA_400))
  pay_btn.disabled = _session.cash < fee
  pay_btn.pressed.connect(func():
    if _session.cash < fee:
      return
    _session.add_cash(-fee)   # 지불 — 소지금만 차감(점수 채널과 무관)
    if is_instance_valid(check_btn):
      check_btn.queue_free()   # 통과 확정 → 유지했던 실적확인 버튼도 정리
    _settle_pass(summary, m, wrap))
  Audio.attach_click(pay_btn)
  wrap.add_child(pay_btn)

  # 파산 신청 — 게임오버로
  var bk := _bankrupt_button()
  bk.pressed.connect(func(): _settle_bankrupt(summary, m))
  Audio.attach_click(bk)
  wrap.add_child(bk)

  m.add_row(wrap)
  create_tween().tween_property(wrap, "modulate:a", 1.0, 0.28)


## 정산 통과 확정 — 액션 버튼 치우고 ✅ 표시 후 [상점으로]. (점수통과·지불통과 공용)
func _settle_pass(summary: Dictionary, m: Modal, action_node: Control) -> void:
  if is_instance_valid(action_node):
    action_node.queue_free()   # [실적확인] 또는 [지불/파산] 묶음 제거

  _pay_week_reward(m)   # 주 클리어 보상 — 통과가 확정된 지금 지급(점수통과·지불통과 공용)

  var px := 38.0
  var mark := UI.ui_icon("pass_check", int(px))
  mark.pivot_offset = Vector2(px, px) * 0.5
  mark.modulate.a = 0.0
  mark.scale = Vector2(0.5, 0.5)
  var mark_box := CenterContainer.new()
  mark_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  mark_box.add_child(mark)
  m.add_row(mark_box)
  var pt := create_tween()
  pt.tween_property(mark, "modulate:a", 1.0, 0.12)
  pt.parallel().tween_property(mark, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  pt.tween_property(mark, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)

  Audio.play("day_pass")   # 정산 통과음
  Audio.vibrate(30)

  # [상점으로] 버튼
  var go := Button.new()
  go.text = Loc.t("to_shop")
  go.custom_minimum_size = Vector2(0, 48)
  go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  go.add_theme_font_size_override("font_size", 18)
  go.add_theme_color_override("font_color", Palette.WHITE)
  go.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
  go.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
  go.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
  go.pressed.connect(func(): m.queue_free(); _open_shop())
  Audio.attach_click(go)
  m.add_row(go)


## 파산 신청 확정 — 정산 닫고 'Run Failed' 게임오버 화면.
func _settle_bankrupt(summary: Dictionary, m: Modal) -> void:
  Audio.play("fail")   # 폐업 스팅
  Audio.vibrate(60)    # 강한(긴) 에러 진동
  m.queue_free()
  _show_run_failed(summary)


## 파산(런 실패) 게임오버 — 'Run Failed' + 일력(주차, 상단바식) + ❌ + 이달 점수 근접도 + 홈 버튼.
func _show_run_failed(summary: Dictionary) -> void:
  var day := int(summary["day"])
  var m := Modal.open(self).title(Loc.t("run_failed"))
  # 도달 주차 — 상단바처럼 일력 이미지 + 숫자
  var badge := UI.day_badge(64)
  (badge.get_meta("num") as Label).text = str(day)
  var badge_wrap := CenterContainer.new()
  badge_wrap.add_child(badge)
  m.add_row(badge_wrap)
  # ❌ 크게(지금과 동일한 실패 마크)
  var x_box := CenterContainer.new()
  x_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  x_box.add_child(UI.ui_icon("fail_x", 32))
  m.add_row(x_box)
  # 이달 점수 근접도 — ⭐ 모은점수(부족하면 빨강) / 목표점수.
  var got := int(summary["month_score"])
  var goal := int(summary["rent"])
  var score_row := HBoxContainer.new()
  score_row.alignment = BoxContainer.ALIGNMENT_CENTER
  score_row.add_theme_constant_override("separation", 6)
  score_row.add_child(UI.ui_icon("star", 22))
  score_row.add_child(UI.label(UI.money(got), 22, Palette.DANGER if goal > got else Palette.COCOA_800, true))
  score_row.add_child(UI.label(" / " + UI.money(goal), 22, Palette.COCOA_800, true))
  m.add_row(score_row)
  # 홈 이미지 버튼 → 타이틀(홈)로
  var home := Button.new()
  home.custom_minimum_size = Vector2(0, 56)
  home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  home.add_theme_stylebox_override("normal", UI.chip(Palette.MAIN))
  home.add_theme_stylebox_override("hover", UI.chip(Palette.MAIN.lightened(0.08)))
  home.add_theme_stylebox_override("pressed", UI.chip(Palette.MAIN.darkened(0.1)))
  home.add_child(UI.ui_btn_icon("house", 30))   # 텍스트 대신 홈 손그림
  home.pressed.connect(func(): m.queue_free(); _fade_to_black(_show_title))
  Audio.attach_click(home)
  m.add_row(home)


## 파산 신청 버튼 — 가게세 못 낼 때 지불 버튼 아래 등장. 누르면 게임오버(❌)로 진행.
func _bankrupt_button() -> Button:
  var b := Button.new()
  b.text = Loc.t("declare_bankrupt")
  b.custom_minimum_size = Vector2(0, 44)
  b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  b.add_theme_font_size_override("font_size", 16)
  b.add_theme_color_override("font_color", Palette.COCOA_600)
  b.add_theme_color_override("font_hover_color", Palette.COCOA_800)
  b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100, Palette.COCOA_200))
  b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
  b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
  return b


## 정산 팝업 행 — 아이콘 + 숫자(글자 없이). 행 전체를 투명으로 두고 순차 페이드인.
func _settle_icon_row(icon: String, value: Label, px := 22) -> HBoxContainer:
  var row := HBoxContainer.new()
  row.alignment = BoxContainer.ALIGNMENT_CENTER
  row.add_theme_constant_override("separation", 6)
  row.modulate.a = 0.0
  row.add_child(UI.ui_icon(icon, px))
  row.add_child(value)
  return row


## 결과 → 인터세션 상점 (슬롯 확장 등) → [영업 시작] → 다음 세션.
func _open_shop() -> void:
  var shop := Shop.new()
  shop.session = _session
  shop.start_business.connect(_session.advance_day)
  shop.go_home.connect(_on_home_pressed)
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
