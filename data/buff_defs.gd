class_name BuffDefs
extends RefCounted
## 버프 정의 — 버프.md 카드 대응(slug=id). 각 def는 "효과 필드"(선택적)를 가진다.
## 훅마다 자기 필드만 읽으므로 거대한 분기 없이 확장됨. 값은 버프.md 기준(튜닝 전제).
##
## [효과 필드]
##  mult{stat,value}            : 패시브 곱연산(Buffs.mod). stat=cook_mult·patience_mult·day_mult·rent_mult
##  cook_clean{max,per}         : 조리시간 -(max - filled*per), filled=보드 작업카드수 (38)
##  patience_flat               : 인내심 초 가산 (67)
##  menu_price{tiers,pct}       : 메뉴가격(base) 배율 인상 (22~24)
##  ramp{tier,value}            : 그 등급 판매 시 등급 기본가×value 메뉴가격 누적 (25~30)
##  trigger{kind,value,window?} : 조건 발동 시 그 메뉴 기본가×value 누적 (43 streak3·44 every7·45 fast3)
##  sale{type,...}              : 판매금(추가금) 보너스. Buffs.sale_amount 파이프라인이 처리.
##  demand{tiers|ingredient,mult}: 손님 등장 가중 (16~21)
##  economy{kind,pct}           : interest(개장) · rent_penalty(마감) (63,51)
##  settle{kind,threshold,pct}  : 마감 정산 (64~66,74)
##  onlost{money_pct?,double_next?}: 손님 이탈 시 (72,73)
##  structure{buff_slot?,tool?,slot?}: 슬롯/도구/버프칸 (11,12)
##  rent_skip                   : 가게세 1회 통과 (9)
##  blocked:true                : v1 시뮬 미지원(등록만, 무효과) — 사유는 버프.md '시뮬 미지원' 표

static var ALL := {
	# ── 전역 도움(유틸) ──
	# name/label은 로케일 파일(b.<slug>.name/label)로 이동 — display_name/display_label로 조회.
	"cook":       {"card": 1, "icon": "⚡", "mult": {"stat": "cook_mult", "value": 0.71}},
	"patience":   {"card": 2, "icon": "⏳", "mult": {"stat": "patience_mult", "value": 1.35}},
	"day_len":    {"card": 3, "icon": "🕒", "mult": {"stat": "day_mult", "value": 1.29}},
	"wh_chance":  {"card": 4, "icon": "🍀", "trip_free": 0.86},
	"wh_fast":    {"card": 5, "icon": "🏃", "mult": {"stat": "warehouse_mult", "value": 0.08}},
	"rent_down":  {"card": 6, "icon": "🏠", "mult": {"stat": "rent_mult", "value": 0.77}},
	"shop_disc":  {"card": 7, "icon": "🏷️", "blocked": true},
	"pack_more":  {"card": 8, "icon": "🃏", "blocked": true},
	"rent_skip":  {"card": 9, "icon": "🎟️", "rent_skip": true},
	"reveal":     {"card": 10, "icon": "🔮", "blocked": true},

	# ── 슬롯/구조 ──
	"buff_slot":  {"card": 11, "icon": "🧩", "structure": {"buff_slot": 1}},
	"tool_slot":  {"card": 12, "icon": "🔥", "structure": {"tool": 1, "slot": 1}},

	# ── 재료(v1 미지원) ──
	"opt_egg":    {"card": 13, "icon": "🥚", "opt_ingredient": "egg"},
	"opt_flour":  {"card": 14, "icon": "🌾", "opt_ingredient": "flour"},
	"opt_bean":   {"card": 15, "icon": "🌰", "opt_ingredient": "bean"},

	# ── 등급/수요 ──
	"dmd_t12":    {"card": 16, "icon": "📈", "demand": {"tiers": [1, 2], "mult": 1.6}},
	"dmd_t34":    {"card": 17, "icon": "📈", "demand": {"tiers": [3, 4], "mult": 1.6}},
	"dmd_t56":    {"card": 18, "icon": "📈", "demand": {"tiers": [5, 6], "mult": 1.6}},
	"dmd_bean":   {"card": 19, "icon": "🌰", "demand": {"ingredient": "bean", "mult": 1.5}},
	"dmd_choco":  {"card": 20, "icon": "🍫", "demand": {"ingredient": "chocolate", "mult": 1.5}},
	"dmd_cream":  {"card": 21, "icon": "🍦", "demand": {"ingredient": "cream", "mult": 1.5}},

	# ── 메뉴가격 등급별 인상 ──
	"mp_t12":     {"card": 22, "icon": "💲", "menu_price": {"tiers": [1, 2], "pct": 10.4}},
	"mp_t34":     {"card": 23, "icon": "💲", "menu_price": {"tiers": [3, 4], "pct": 4.0}},
	"mp_t56":     {"card": 24, "icon": "💲", "menu_price": {"tiers": [5, 6], "pct": 9.0}},

	# ── 메뉴가격 성장(램프) 25~30 ──
	"ramp_t1":    {"card": 25, "icon": "📈", "ramp": {"tier": 1, "value": 1.0}},
	"ramp_t2":    {"card": 26, "icon": "📈", "ramp": {"tier": 2, "value": 1.0}},
	"ramp_t3":    {"card": 27, "icon": "📈", "ramp": {"tier": 3, "value": 1.0}},
	"ramp_t4":    {"card": 28, "icon": "📈", "ramp": {"tier": 4, "value": 1.0}},
	"ramp_t5":    {"card": 29, "icon": "📈", "ramp": {"tier": 5, "value": 2.0}},
	"ramp_t6":    {"card": 30, "icon": "📈", "ramp": {"tier": 6, "value": 2.5}},

	# ── 판매금: 슬롯/버프 공간 빌드(31~41) ──
	"sc_buff_a":  {"card": 31, "icon": "🧮", "sale": {"type": "mult_count", "per": "buff", "step": 0.40}},
	"sc_buff_b":  {"card": 32, "icon": "🧮", "sale": {"type": "exp_count", "per": "buff", "rate": 0.30}},
	"sc_fill_a":  {"card": 33, "icon": "🧱", "sale": {"type": "mult_count", "per": "filled", "step": 0.18}},
	"sc_fill_b":  {"card": 34, "icon": "🧱", "sale": {"type": "exp_count", "per": "filled", "rate": 0.13}},
	"sc_empt_a":  {"card": 35, "icon": "⬜", "sale": {"type": "mult_count", "per": "empty", "step": 0.18}},
	"sc_empt_b":  {"card": 36, "icon": "⬜", "sale": {"type": "exp_count", "per": "empty", "rate": 0.13}},
	"sale_full":  {"card": 37, "icon": "🈵", "sale": {"type": "mult", "value": 1.4, "when": "board_full"}},
	"cook_empty": {"card": 38, "icon": "💨", "cook_clean": {"max": 0.40, "per": 0.05}},
	"sc_order":   {"card": 39, "icon": "📝", "sale": {"type": "count", "per": "orders", "base": 0.0, "step": 0.8}},
	"sc_dish":    {"card": 40, "icon": "🍽️", "sale": {"type": "mult_count", "per": "dishes", "step": 0.3}},
	"sc_ingr":    {"card": 41, "icon": "🧺", "sale": {"type": "count", "per": "ingr", "base": 0.0, "step": 1.2}},

	# ── 판매금: 콤보/연속/확률(42~52) ──
	"prob_x2":    {"card": 42, "icon": "🎲", "sale": {"type": "prob_double", "chance": 0.40}},
	"rt_streak3": {"card": 43, "icon": "📈", "trigger": {"kind": "streak3", "value": 3.0}},
	"rt_every7":  {"card": 44, "icon": "📈", "trigger": {"kind": "every7", "value": 2.0}},
	"rt_fast3":   {"card": 45, "icon": "📈", "trigger": {"kind": "fast3", "value": 2.0, "window": 3.0}},
	"accum_sale": {"card": 46, "icon": "🪙", "sale": {"type": "accum", "pct": 0.02}},
	"sale_flat3": {"card": 47, "icon": "💰", "sale": {"type": "flat", "pct": 3.4}},
	"prob_bonus": {"card": 48, "icon": "🍀", "sale": {"type": "prob_pct", "chance": 0.10, "pct": 5.0}},
	"sale_risk":  {"card": 49, "icon": "💥", "sale": {"type": "risk", "pct": 4.2, "chance": 0.05}},
	"no_buy":     {"card": 50, "icon": "🚫", "blocked": true},
	"sale_cash":  {"card": 51, "icon": "🏦", "settle": {"kind": "served", "threshold": 0.0, "pct": 0.10}},
	"sale_pat":   {"card": 52, "icon": "⚖️", "sale": {"type": "flat", "pct": 2.9}, "mult": {"stat": "patience_mult", "value": 0.80}},

	# ── 판매금: 조건부/앰프(53~58) ──
	"sale_t12":   {"card": 53, "icon": "💰", "sale": {"type": "tier", "tiers": [1, 2], "pct": 5.0}},
	"sale_t34":   {"card": 54, "icon": "💰", "sale": {"type": "tier", "tiers": [3, 4], "pct": 2.5}},
	"sale_t56":   {"card": 55, "icon": "💰", "sale": {"type": "tier", "tiers": [5, 6], "pct": 3.0}},
	"sale_fresh": {"card": 56, "icon": "✨", "sale": {"type": "fresh", "within": 2.0, "pct": 3.4}},
	"sale_fast":  {"card": 57, "icon": "⚡", "sale": {"type": "fast_order", "within": 6.0, "pct": 5.2}},
	"sale_addon": {"card": 58, "icon": "🔊", "sale": {"type": "addon", "pct": 0.69}},

	"mult_all":   {"card": 75, "icon": "✖️", "sale": {"type": "mult", "value": 1.3}},
	"serve_tip":  {"card": 76, "icon": "🔔", "tip": {"chance": 0.08, "money": 1}},
	"settle_perfect": {"card": 77, "icon": "💯", "settle": {"kind": "served", "threshold": 1.00, "money": 5}},
	"nest_egg":   {"card": 78, "icon": "🐷", "matures": {"weeks": 4, "money": 15}},

	# ── 자동화(59~62) ──
	"auto_serve": {"card": 59, "icon": "🤖", "blocked": true},
	"auto_cook":  {"card": 60, "icon": "🤖", "blocked": true},
	"inst_order": {"card": 61, "icon": "⏭️", "instant": {"kind": "order", "n": 8}},
	"inst_cook":  {"card": 62, "icon": "⏩", "instant": {"kind": "cook", "n": 4}},

	# ── 경제/정산(63~66) ──
	"interest":   {"card": 63, "icon": "🏦", "economy": {"kind": "interest", "pct": 0.10}},
	"settle_100": {"card": 64, "icon": "🏆", "settle": {"kind": "served", "threshold": 1.00, "pct": 0.25}},
	"settle_90":  {"card": 65, "icon": "🥇", "settle": {"kind": "served", "threshold": 0.90, "pct": 0.15}},
	"settle_same":{"card": 66, "icon": "🎯", "settle": {"kind": "samemenu", "threshold": 0.70, "pct": 0.20}},

	# ── 벼랑끝(67~70) ──
	"pat_extend": {"card": 67, "icon": "🧘", "patience_flat": 7.0},
	"sale_late":  {"card": 68, "icon": "⌛", "sale": {"type": "late", "after": 25.0, "pct": 6.9}},
	"sale_burn":  {"card": 69, "icon": "🔥", "sale": {"type": "consumed", "pct": 8.1}},
	"sale_crit":  {"card": 70, "icon": "🚨", "sale": {"type": "critical", "pct": 5.2}},

	# ── 방치(71~74) ──
	"pat_down":   {"card": 71, "icon": "💢", "mult": {"stat": "patience_mult", "value": 0.70}},
	"onlost_pay": {"card": 72, "icon": "💸", "onlost": {"chance": 0.50, "money": 1}},
	"onlost_x2":  {"card": 73, "icon": "😈", "onlost": {"double_next": true}},
	"settle_leave":{"card": 74, "icon": "🏳️", "settle": {"kind": "leave", "threshold": 0.30, "money": 10}},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

## 현지화된 카드 이름/라벨 — 로케일 파일(b.<slug>.name/label)에서 조회.
static func display_name(id: String) -> String:
	return Loc.t("b." + id + ".name")

static func display_label(id: String) -> String:
	return Loc.t("b." + id + ".label")


## 버프 → 아이콘 카테고리(9종). assets/art/buffs/buff_<cat>.png 공용.
const _CAT_OVERRIDE := {
	"cook": "cook", "cook_empty": "cook",
	"patience": "time", "day_len": "time", "pat_extend": "time", "pat_down": "time",
	"wh_chance": "time", "wh_fast": "time",
	"rent_down": "money", "rent_skip": "money", "shop_disc": "money", "interest": "money",
	"no_buy": "money", "onlost_pay": "money", "settle_leave": "money", "serve_tip": "money",
	"settle_perfect": "money", "nest_egg": "money",
	"buff_slot": "struct", "tool_slot": "struct", "pack_more": "struct", "reveal": "struct",
	"opt_egg": "struct", "opt_flour": "struct", "opt_bean": "struct",
	"accum_sale": "growth", "sale_cash": "growth",
	"settle_100": "growth", "settle_90": "growth", "settle_same": "growth",
	"prob_x2": "luck", "prob_bonus": "luck", "sale_risk": "luck", "onlost_x2": "luck",
}

static func category(id: String) -> String:
	if _CAT_OVERRIDE.has(id):
		return _CAT_OVERRIDE[id]
	if id.begins_with("dmd_"): return "demand"
	if id.begins_with("ramp_") or id.begins_with("rt_"): return "growth"
	if id.begins_with("auto_") or id.begins_with("inst_"): return "auto"
	if id.begins_with("mp_") or id.begins_with("sc_") or id.begins_with("sale_"): return "sale"
	return "sale"

static var _tex_cache := {}

static var _tex_cache_sm := {}   # 초소형(≤30px) 48px 캐시

static func tex(id: String, small := false) -> Texture2D:
	var cat := category(id)
	var cache: Dictionary = _tex_cache_sm if small else _tex_cache
	if not cache.has(cat):
		var dir := "buffs_48" if small else "buffs_128"   # 작은 표시=48px, 그 외=128px
		var path := "res://assets/art/%s/buff_%s.png" % [dir, cat]
		var base: Texture2D = load(path) if ResourceLoader.exists(path) else null
		cache[cat] = _opaque_crop(base)   # 원본마다 다른 투명 여백을 제거 → 슬롯에서 아이콘 크기 균일화
	return cache[cat]

## 텍스처를 불투명 영역(+약간의 여백)으로 크롭한 AtlasTexture 반환. 원본별 여백 차이로
## 아이콘이 제각각 작아 보이던 문제 보정(모든 카테고리가 칸을 같은 비율로 채우게). 실패 시 원본 그대로.
static func _opaque_crop(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var img := t.get_image()
	if img == null:
		return t
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.06:
				if x < minx: minx = x
				if x > maxx: maxx = x
				if y < miny: miny = y
				if y > maxy: maxy = y
	if maxx < minx:
		return t   # 전부 투명 — 그대로
	var m := int(round(float(maxi(maxx - minx + 1, maxy - miny + 1)) * 0.06))
	minx = maxi(0, minx - m)
	miny = maxi(0, miny - m)
	maxx = mini(w - 1, maxx + m)
	maxy = mini(h - 1, maxy + m)
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = Rect2(minx, miny, maxx - minx + 1, maxy - miny + 1)
	return at

## 버프 아이콘 노드 — 카테고리 텍스처 있으면 TextureRect(px, 밉맵), 없으면 이모지(⚡).
static func icon_node(id: String, px: int) -> Control:
	var t := tex(id, px <= 30)   # ≤30px(보유 버프 줄 등)는 48px 초소형 소스
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 밉맵 OFF — 선명(리사이즈 소스)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label(str(get_def(id).get("icon", "?")), px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

## 팩: 서로 다른 버프 n개 랜덤(차단 카드·이미 보유한 버프 제외 — 중복 방지).
static func random_pack(n := 3) -> Array:
	var owned := Buffs.owned()
	var pool := []
	for id in ALL.keys():
		if ALL[id].get("blocked", false):
			continue
		if id in owned:
			continue   # 이미 보유한 버프는 후보에서 제외
		pool.append(id)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))
