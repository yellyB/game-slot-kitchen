class_name BuffDefs
extends RefCounted
## 버프 정의 — 버프.md 카드 대응(slug=id). 각 def는 "효과 필드"(선택적)를 가진다.
## 훅마다 자기 필드만 읽으므로 거대한 분기 없이 확장됨. 값은 버프.md 기준(튜닝 전제).
##
## [효과 필드]
##  mult{stat,value}            : 패시브 곱연산(Buffs.mod). stat=cook_mult·patience_mult·day_mult·rent_mult
##  cook_empty{step}            : 빈 슬롯 1개당 조리시간 -step (37)
##  patience_flat               : 인내심 초 가산 (66)
##  menu_price{tiers,pct}       : 메뉴가격(base) 배율 인상 (21~23)
##  ramp{tier,value}            : 그 등급 판매 시 등급 기본가×value 메뉴가격 누적 (24~29)
##  trigger{kind,value,window?} : 조건 발동 시 그 메뉴 기본가×value 누적 (42 streak3·43 every7·44 fast3)
##  sale{type,...}              : 판매금(추가금) 보너스. Buffs.sale_amount 파이프라인이 처리.
##  demand{tiers|ingredient,mult}: 손님 등장 가중 (15~20)
##  economy{kind,pct}           : interest(개장) · rent_penalty(마감) (62,50)
##  settle{kind,threshold,pct}  : 마감 정산 (63~65,73)
##  onlost{money_pct?,double_next?}: 손님 이탈 시 (71,72)
##  structure{buff_slot?,tool?,slot?}: 슬롯/도구/버프칸 (11,12)
##  rent_skip                   : 가게세 1회 통과 (9)
##  blocked:true                : v1 시뮬 미지원(등록만, 무효과) — 사유는 버프.md '시뮬 미지원' 표

const ALL := {
	# ── 전역 도움(유틸) ──
	"cook":       {"card": 1, "name": "조리 속도", "icon": "⚡", "label": "조리 -25%", "mult": {"stat": "cook_mult", "value": 0.75}},
	"patience":   {"card": 2, "name": "인내심", "icon": "⏳", "label": "인내심 +10%", "mult": {"stat": "patience_mult", "value": 1.10}},
	"day_len":    {"card": 3, "name": "영업시간", "icon": "🕒", "label": "영업시간 +7%", "mult": {"stat": "day_mult", "value": 1.07}},
	"wh_chance":  {"card": 4, "name": "창고 무비용", "icon": "🍀", "label": "창고 30% 무시간", "blocked": true},
	"wh_fast":    {"card": 5, "name": "창고 1초", "icon": "🏃", "label": "창고 1초", "blocked": true},
	"rent_down":  {"card": 6, "name": "가게세", "icon": "🏠", "label": "가게세 -10%", "mult": {"stat": "rent_mult", "value": 0.90}},
	"shop_disc":  {"card": 7, "name": "상점 할인", "icon": "🏷️", "label": "상점 -10%", "blocked": true},
	"pack_more":  {"card": 8, "name": "카드깡+1", "icon": "🃏", "label": "후보 +1", "blocked": true},
	"rent_skip":  {"card": 9, "name": "가게세 통과", "icon": "🎟️", "label": "가게세 1회 통과", "rent_skip": true},
	"reveal":     {"card": 10, "name": "메뉴 공개", "icon": "🔮", "label": "대기열 공개", "blocked": true},

	# ── 슬롯/구조 ──
	"buff_slot":  {"card": 11, "name": "버프칸+1", "icon": "🧩", "label": "버프칸 +1", "structure": {"buff_slot": 1}},
	"tool_slot":  {"card": 12, "name": "도구+1", "icon": "🔥", "label": "도구석 +1(슬롯+1)", "structure": {"tool": 1, "slot": 1}},

	# ── 재료(v1 미지원) ──
	"opt_egg":    {"card": 13, "name": "계란 생략", "icon": "🥚", "label": "계란 없어도 조리", "blocked": true},
	"opt_flour":  {"card": 14, "name": "밀가루 생략", "icon": "🌾", "label": "밀가루 없어도 조리", "blocked": true},

	# ── 등급/수요 ──
	"dmd_t12":    {"card": 15, "name": "1·2등급 수요", "icon": "📈", "label": "1·2등급 손님 +100%", "demand": {"tiers": [1, 2], "mult": 2.0}},
	"dmd_t34":    {"card": 16, "name": "3·4등급 수요", "icon": "📈", "label": "3·4등급 손님 +100%", "demand": {"tiers": [3, 4], "mult": 2.0}},
	"dmd_t56":    {"card": 17, "name": "5·6등급 수요", "icon": "📈", "label": "5·6등급 손님 +100%", "demand": {"tiers": [5, 6], "mult": 2.0}},
	"dmd_bean":   {"card": 18, "name": "원두 선호", "icon": "🌰", "label": "원두 메뉴 손님 +50%", "demand": {"ingredient": "bean", "mult": 1.5}},
	"dmd_choco":  {"card": 19, "name": "초콜릿 선호", "icon": "🍫", "label": "초콜릿 메뉴 손님 +60%", "demand": {"ingredient": "chocolate", "mult": 1.6}},
	"dmd_cream":  {"card": 20, "name": "크림 선호", "icon": "🍦", "label": "크림 메뉴 손님 +70%", "demand": {"ingredient": "cream", "mult": 1.7}},

	# ── 메뉴가격 등급별 인상 ──
	"mp_t12":     {"card": 21, "name": "1·2등급 가격", "icon": "💲", "label": "1·2등급 가격 +15%", "menu_price": {"tiers": [1, 2], "pct": 0.15}},
	"mp_t34":     {"card": 22, "name": "3·4등급 가격", "icon": "💲", "label": "3·4등급 가격 +15%", "menu_price": {"tiers": [3, 4], "pct": 0.15}},
	"mp_t56":     {"card": 23, "name": "5·6등급 가격", "icon": "💲", "label": "5·6등급 가격 +15%", "menu_price": {"tiers": [5, 6], "pct": 0.15}},

	# ── 메뉴가격 성장(램프) 24~29 ──
	"ramp_t1":    {"card": 24, "name": "커피 성장", "icon": "📈", "label": "커피 판매마다 기본가 +7%", "ramp": {"tier": 1, "value": 0.07}},
	"ramp_t2":    {"card": 25, "name": "라떼 성장", "icon": "📈", "label": "라떼 판매마다 기본가 +7%", "ramp": {"tier": 2, "value": 0.07}},
	"ramp_t3":    {"card": 26, "name": "글레 성장", "icon": "📈", "label": "글레 판매마다 기본가 +7%", "ramp": {"tier": 3, "value": 0.07}},
	"ramp_t4":    {"card": 27, "name": "초코도넛 성장", "icon": "📈", "label": "초코도넛 판매마다 기본가 +7%", "ramp": {"tier": 4, "value": 0.07}},
	"ramp_t5":    {"card": 28, "name": "티라미수 성장", "icon": "📈", "label": "티라미수 판매마다 기본가 +7%", "ramp": {"tier": 5, "value": 0.07}},
	"ramp_t6":    {"card": 29, "name": "초코케이크 성장", "icon": "📈", "label": "초코케이크 판매마다 기본가 +7%", "ramp": {"tier": 6, "value": 0.07}},

	# ── 판매금: 슬롯/버프 공간 빌드(30~40) ──
	"sc_buff_a":  {"card": 30, "name": "버프당 판매", "icon": "🧮", "label": "판매가 +7%×버프", "sale": {"type": "count", "per": "buff", "base": 0.0, "step": 0.07}},
	"sc_buff_b":  {"card": 31, "name": "버프당 판매+", "icon": "🧮", "label": "판매가 +10%+3%×버프", "sale": {"type": "count", "per": "buff", "base": 0.10, "step": 0.03}},
	"sc_fill_a":  {"card": 32, "name": "찬슬롯 판매", "icon": "🧱", "label": "판매가 +4%×찬슬롯", "sale": {"type": "count", "per": "filled", "base": 0.0, "step": 0.04}},
	"sc_fill_b":  {"card": 33, "name": "찬슬롯 판매+", "icon": "🧱", "label": "판매가 +10%+1%×찬슬롯", "sale": {"type": "count", "per": "filled", "base": 0.10, "step": 0.01}},
	"sc_empt_a":  {"card": 34, "name": "빈슬롯 판매", "icon": "⬜", "label": "판매가 +6%×빈슬롯", "sale": {"type": "count", "per": "empty", "base": 0.0, "step": 0.06}},
	"sc_empt_b":  {"card": 35, "name": "빈슬롯 판매+", "icon": "⬜", "label": "판매가 +10%+2%×빈슬롯", "sale": {"type": "count", "per": "empty", "base": 0.10, "step": 0.02}},
	"sale_full":  {"card": 36, "name": "만석 서빙", "icon": "🈵", "label": "만석 서빙 판매가 +15%", "sale": {"type": "full", "pct": 0.15}},
	"cook_empty": {"card": 37, "name": "빈슬롯 조리", "icon": "💨", "label": "빈슬롯당 조리 +8%", "cook_empty": {"step": 0.08}},
	"sc_order":   {"card": 38, "name": "주문카드 판매", "icon": "📝", "label": "주문카드당 판매금 +10%", "sale": {"type": "count", "per": "orders", "base": 0.0, "step": 0.10}},
	"sc_dish":    {"card": 39, "name": "완성품 판매", "icon": "🍽️", "label": "완성품당 판매금 +20%", "sale": {"type": "count", "per": "dishes", "base": 0.0, "step": 0.20}},
	"sc_ingr":    {"card": 40, "name": "재료카드 판매", "icon": "🧺", "label": "재료카드당 판매금 +4%", "blocked": true},

	# ── 판매금: 콤보/연속/확률(41~51) ──
	"prob_x2":    {"card": 41, "name": "대박", "icon": "🎲", "label": "8% 확률 판매금 2배", "sale": {"type": "prob_double", "chance": 0.08}},
	"rt_streak3": {"card": 42, "name": "몰빵 성장", "icon": "📈", "label": "같은메뉴 3연속→그 메뉴 기본가 +20%", "trigger": {"kind": "streak3", "value": 0.20}},
	"rt_every7":  {"card": 43, "name": "7배수 성장", "icon": "📈", "label": "7번째 제공마다 그 메뉴 기본가 +30%", "trigger": {"kind": "every7", "value": 0.30}},
	"rt_fast3":   {"card": 44, "name": "속공 성장", "icon": "📈", "label": "5초내 3개→마지막 메뉴 기본가 +18%", "trigger": {"kind": "fast3", "value": 0.18, "window": 5.0}},
	"accum_sale": {"card": 45, "name": "적립", "icon": "🪙", "label": "제공마다 판매금 5% 누적획득", "sale": {"type": "accum", "pct": 0.05}},
	"sale_flat3": {"card": 46, "name": "판매금+3%", "icon": "💰", "label": "판매금 +3%", "sale": {"type": "flat", "pct": 0.03}},
	"prob_bonus": {"card": 47, "name": "행운", "icon": "🍀", "label": "10% 확률 판매금 +30%", "sale": {"type": "prob_pct", "chance": 0.10, "pct": 0.30}},
	"sale_risk":  {"card": 48, "name": "도박", "icon": "💥", "label": "판매금+20% / 10% 폐기·수익-30%", "sale": {"type": "risk", "pct": 0.20, "chance": 0.10, "penalty_pct": 0.30}},
	"no_buy":     {"card": 49, "name": "절약", "icon": "🚫", "label": "미구매시 다음날 +5%", "blocked": true},
	"sale_cash":  {"card": 50, "name": "부자세", "icon": "🏦", "label": "판매금+보유금2% / 마감 가게세20%↓", "sale": {"type": "cash", "pct": 0.02}, "economy": {"kind": "rent_penalty", "pct": 0.20}},
	"sale_pat":   {"card": 51, "name": "박리다매", "icon": "⚖️", "label": "판매가+25% / 인내심-20%", "sale": {"type": "flat", "pct": 0.25}, "mult": {"stat": "patience_mult", "value": 0.80}},

	# ── 판매금: 조건부/앰프(52~57) ──
	"sale_t12":   {"card": 52, "name": "1·2등급 판매", "icon": "💰", "label": "1·2등급 판매금 +10%", "sale": {"type": "tier", "tiers": [1, 2], "pct": 0.10}},
	"sale_t34":   {"card": 53, "name": "3·4등급 판매", "icon": "💰", "label": "3·4등급 판매금 +10%", "sale": {"type": "tier", "tiers": [3, 4], "pct": 0.10}},
	"sale_t56":   {"card": 54, "name": "5·6등급 판매", "icon": "💰", "label": "5·6등급 판매금 +10%", "sale": {"type": "tier", "tiers": [5, 6], "pct": 0.10}},
	"sale_fresh": {"card": 55, "name": "신선", "icon": "✨", "label": "2초내 서빙 +20%", "sale": {"type": "fresh", "within": 2.0, "pct": 0.20}},
	"sale_fast":  {"card": 56, "name": "쾌속", "icon": "⚡", "label": "주문 4초내 완료 +20%", "sale": {"type": "fast_order", "within": 4.0, "pct": 0.20}},
	"sale_addon": {"card": 57, "name": "앰프", "icon": "🔊", "label": "추가금의 +30%", "sale": {"type": "addon", "pct": 0.30}},

	# ── 자동화(58~61) ──
	"auto_serve": {"card": 58, "name": "자동 서빙", "icon": "🤖", "label": "50% 자동서빙", "blocked": true},
	"auto_cook":  {"card": 59, "name": "자동 조리", "icon": "🤖", "label": "접수시 자동조리", "blocked": true},
	"inst_order": {"card": 60, "name": "즉시 주문", "icon": "⏭️", "label": "8번째 서빙후 다음 주문 즉완", "instant": {"kind": "order", "n": 8}},
	"inst_cook":  {"card": 61, "name": "즉시 조리", "icon": "⏩", "label": "6번째 조리마다 즉완", "instant": {"kind": "cook", "n": 6}},

	# ── 경제/정산(62~65) ──
	"interest":   {"card": 62, "name": "이자", "icon": "🏦", "label": "개장시 보유금 +4%", "economy": {"kind": "interest", "pct": 0.04}},
	"settle_100": {"card": 63, "name": "완벽정산", "icon": "🏆", "label": "100% 처리시 수익 +28%", "settle": {"kind": "served", "threshold": 1.00, "pct": 0.28}},
	"settle_90":  {"card": 64, "name": "우수정산", "icon": "🥇", "label": "90%+ 처리시 수익 +12%", "settle": {"kind": "served", "threshold": 0.90, "pct": 0.12}},
	"settle_same":{"card": 65, "name": "전문점", "icon": "🎯", "label": "같은메뉴 70%+ 수익 +17%", "settle": {"kind": "samemenu", "threshold": 0.70, "pct": 0.17}},

	# ── 벼랑끝(66~69) ──
	"pat_extend": {"card": 66, "name": "여유", "icon": "🧘", "label": "떠나기 전 3초 더", "patience_flat": 3.0},
	"sale_late":  {"card": 67, "name": "인내 보상", "icon": "⌛", "label": "25초 후 서빙 +35%", "sale": {"type": "late", "after": 25.0, "pct": 0.35}},
	"sale_burn":  {"card": 68, "name": "소진 보상", "icon": "🔥", "label": "소모 인내심%×40% 추가", "sale": {"type": "consumed", "pct": 0.40}},
	"sale_crit":  {"card": 69, "name": "임박 보상", "icon": "🚨", "label": "인내 임박 서빙 +20%", "sale": {"type": "critical", "pct": 0.20}},

	# ── 방치(70~73) ──
	"pat_down":   {"card": 70, "name": "박대", "icon": "💢", "label": "인내심 -30%", "mult": {"stat": "patience_mult", "value": 0.70}},
	"onlost_pay": {"card": 71, "name": "위약금", "icon": "💸", "label": "이탈시 메뉴가 +34%", "onlost": {"money_pct": 0.34}},
	"onlost_x2":  {"card": 72, "name": "보복", "icon": "😈", "label": "이탈시 다음 획득 2배", "onlost": {"double_next": true}},
	"settle_leave":{"card": 73, "name": "손절", "icon": "🏳️", "label": "30%+ 이탈시 보유금 +15%", "settle": {"kind": "leave", "threshold": 0.30, "pct": 0.15}},
}

static func ids() -> Array:
	return ALL.keys()

static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})

## 팩: 서로 다른 버프 n개 랜덤(차단 카드 제외).
static func random_pack(n := 3) -> Array:
	var pool := []
	for id in ALL.keys():
		if not ALL[id].get("blocked", false):
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))
