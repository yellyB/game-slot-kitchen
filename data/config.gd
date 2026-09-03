class_name Config
extends RefCounted
## 튜닝 숫자 모음 — 하드코딩 금지, 여기 한 곳에서 조정.
## 기능 개발하면서 그때그때 관련 숫자를 여기에 추가한다(나중에 몰아서 X).
## (레시피별 조리시간 등 "데이터"는 recipes.gd 등 각 data 파일에 유지.)

# ── 보드 (슬롯 그리드) ────────────────────────────────────
const BOARD_COLS := 3
const START_SLOTS := 9   # 시작 슬롯 수(도구석 제외). 버프도 슬롯 점유(온보드).
const TOOL_COUNT := 2    # 도구석(🔥) 개수 — 그리드 마지막 칸들에 배치
const MAX_SLOTS := 21    # 슬롯 확장 상한 (구매마다 가격 급증 → 실질 1~2회. 도달 시 SOLD OUT)

# ── 손님 큐 / 스포너 ──────────────────────────────────────
const MAX_QUEUE := 4          # 큐 최대 인원
const MAX_ORDERS := 6         # 동시 접수 주문 상한 — 나머지 슬롯은 재료/완성품용(조리 공간 확보)
const SPAWN_INTERVAL := 4.0   # 손님 등장 간격(초) — (미사용, 스케줄은 균등분포)
const SPAWN_FIRST := 1.0      # 첫 손님 등장 시각(초) — 시작하자마자 한 명
const SPAWN_LAST_MARGIN := 8.0  # 마지막 손님은 마감 이 시간(초) 전까지

# ── 손님 수요 (등급별 등장 가중 = 확률 %, 합 100) ──────────
# 싼(낮은 등급) 메뉴 손님이 많이, 비싼(높은 등급) 손님은 드물게. 인덱스 = 등급-1.
const SPAWN_WEIGHTS := [30, 22, 18, 15, 10, 5]  # 1등급 30% … 6등급 5%

# ── 인내심 (2단계 별도 타이머) ────────────────────────────
const PATIENCE_ORDER := 25.0  # 주문 대기(큐)
const PATIENCE_DISH := 35.0   # 음식 대기(슬롯 주문 카드)
const PATIENCE_LOW_FRAC := 0.3  # 이 비율 이하로 남으면 게이지 빨강

# ── 경제 (금액 최소단위 1원, 가장 싼 메뉴 = 1) ────────────
const START_MONEY := 0     # 시작 소지금
# 현금비례 보너스(이자·부자세)의 기준잔액 — 보너스 = pct × √(현금 × 이 값).
# 잔액이 이 값일 때 정확히 pct%로 동작하고, 그 이상은 이율이 체감(√)해 지수폭주를 차단.
const CASH_BONUS_REF := 25000
const SLOT_PRICE := 4         # 슬롯 +1 확장 기본가(소액 통화). 구간별 상승(초반 급→후반 완만): 4→7→12→20→24…
const BUFF_PACK_PRICE := 2    # 버프 팩(카드깡) 고정가 — 최소 단위
const BUFF_REROLL_BASE := 1   # 팩 개봉 중 리롤 기본가 — 리롤마다 ×2(1·2·4…), 방문마다 리셋
const SLOT_PRICE_STEP_EARLY := 1.7   # 슬롯 확장 배수 — 무릎(KNEE) 전 초반 급경사
const SLOT_PRICE_STEP_LATE := 1.2    # 슬롯 확장 배수 — 무릎 후 후반 완만
const SLOT_PRICE_KNEE := 3           # 이 구매 횟수까지 EARLY 배수, 이후 LATE 배수
const MAX_BUFFS := 5        # 버프 보유 상한 (온보드 점유 — 판 절반 이상 못 줌)
# 주 클리어 보상(돈 faucet) — 서빙=점수라 돈은 매주 클리어로만 들어옴. 소액.
const WEEK_REWARD_BASE := 4       # 첫 주 완료 보상(돈)
const WEEK_REWARD_STEP := 1       # 주마다 증가분(1~2 권장) — 작다가 점점 증가
const WEEK_REWARD_PER_SERVE := 0

## 주 완료 보상 = 기본 + 주당 증가 × (경과 주-1) + 서빙당 보너스. day=1-base 주차.
static func week_reward(day: int, served: int) -> int:
	return WEEK_REWARD_BASE + WEEK_REWARD_STEP * maxi(0, day - 1) + served * WEEK_REWARD_PER_SERVE
const BUFF_SELL_RATIO := 0.2  # 보유 버프 판매 환급률 (버프팩 가격의 20% = 500→100원)
const MONEY_ABBR_AT := 100000  # 이 값 이상은 k/m 축약 표시(미만은 콤마) — UI.money
const SCORE_GATE_FEE_DIV := 100  # 실적(점수) 미달 시 목표점수의 1/이 값 만큼 코인 지불로 통과
const SCORE_GATE_FEE_KEEP := 5   # 지불통과 시 max(목표1/DIV, 보유-이 값) — 부유하면 이 액수만 남기고 소진
# (가게세는 하루별 → data/levels.gd)

# ── 세션 / 하루 ───────────────────────────────────────────
const DAY_LENGTH := 90.0       # 영업시간(초)
const DAY_INTRO_DELAY := 0.5   # 하루 시작 시 게임플레이(시계·스폰) 홀드 후 배너·시작음 (초)
const DAY_END_PAUSE := 1.0     # 하루 마감 후 정지 시간 — 남은 슬롯 카드 팝 소멸 전 (초)
const HOURS_WARN_FRAC := 0.8   # 이 진행도 이상이면 영업시간 바 빨강 + 임박 펄스(마감 임박)
const WAVES := 3                # 웨이브 수(고정). 웨이브당 손님 수는 data/levels.gd
const WAVE_SPACING := 0.7       # 웨이브 내 손님 간격(초)
const WAREHOUSE_EXIT_COST := 1.5  # 창고 닫을 때(퇴장) 소모 영업시간(초) — 트립 비용
# (fetch 독점 완화: 3.0→1.5. 시뮬상 창고=최대병목이라 조리/도구 카드가 죽던 문제 조정.
#  트립이 게임의 전부가 안 되게 하되, 여전히 유의미한 시간비용으로 유지.)
# (일차별 가게세·손님 수·승리 일차 = data/levels.gd)

# ── 시뮬 현실성(핸들링 타임) ───────────────────────────────
# 사람 손동작 1회당 소모 시간(초). SIM_HANDLE 환경변수>0일 때만 적용(=현실 플레이어 모델).
# 미설정 시 시뮬은 기존대로 즉시 처리(이상적 상한 — 버프 상대비교용).
const SIM_HANDLE_ACCEPT := 0.5   # 손님 탭해 주문 접수
const SIM_HANDLE_COOK := 0.4     # 도구 탭해 조리 시작
const SIM_HANDLE_SERVE := 0.6    # 완성품 드래그해 서빙
const SIM_HANDLE_PLACE := 0.35   # 창고 재료 1개를 슬롯에 놓기


## 슬롯 확장가 = 기본가 × 구간별 배수(bought=이미 확장한 수). 무릎(KNEE) 전은 EARLY 배수(급),
## 후는 LATE 배수(완만) — 초반 가파르고 후반 완만한 concave 곡선. 날짜 인플레 없음(_day 미사용).
static func slot_price(_day: int, bought: int) -> int:
	var b := maxi(0, bought)
	var early := mini(b, SLOT_PRICE_KNEE)
	var late := maxi(0, b - SLOT_PRICE_KNEE)
	return int(ceil(SLOT_PRICE * pow(SLOT_PRICE_STEP_EARLY, early) * pow(SLOT_PRICE_STEP_LATE, late)))
