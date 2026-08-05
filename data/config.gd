class_name Config
extends RefCounted
## 튜닝 숫자 모음 — 하드코딩 금지, 여기 한 곳에서 조정.
## 기능 개발하면서 그때그때 관련 숫자를 여기에 추가한다(나중에 몰아서 X).
## (레시피별 조리시간 등 "데이터"는 recipes.gd 등 각 data 파일에 유지.)

# ── 보드 (슬롯 그리드) ────────────────────────────────────
const BOARD_COLS := 3
const START_SLOTS := 9   # 시작 슬롯 수(도구석 제외). 버프도 슬롯 점유(온보드).
const TOOL_COUNT := 2    # 도구석(🔥) 개수 — 그리드 마지막 칸들에 배치
const MAX_SLOTS := 10    # 슬롯 확장 상한 (세로 화면상 4줄 = 실질 상한)

# ── 손님 큐 / 스포너 ──────────────────────────────────────
const MAX_QUEUE := 4          # 큐 최대 인원
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
const SLOT_PRICE := 500       # 슬롯 +1 확장 1일차 기본가(상점) — 일수 따라 SHOP_PRICE_GROWTH로 상승
const BUFF_PACK_PRICE := 200  # 버프 팩(카드깡) 1일차 기본가 — 일수 따라 상승
const SHOP_PRICE_GROWTH := 1.65  # 상점가 일당 증가 배율(복리): 가격 = ceil(기본 × GROWTH^(day-1))
const MAX_BUFFS := 5        # 버프 보유 상한 (온보드 점유 — 판 절반 이상 못 줌)
# (가게세는 하루별 → data/levels.gd)

# ── 세션 / 하루 ───────────────────────────────────────────
const DAY_LENGTH := 120.0       # 영업시간(초)
const WAVES := 3                # 웨이브 수(고정). 웨이브당 손님 수는 data/levels.gd
const WAVE_SPACING := 0.7       # 웨이브 내 손님 간격(초)
const WAREHOUSE_EXIT_COST := 1.5  # 창고 닫을 때(퇴장) 소모 영업시간(초) — 트립 비용
# (fetch 독점 완화: 3.0→1.5. 시뮬상 창고=최대병목이라 조리/도구 카드가 죽던 문제 조정.
#  트립이 게임의 전부가 안 되게 하되, 여전히 유의미한 시간비용으로 유지.)
# (일차별 가게세·손님 수·승리 일차 = data/levels.gd)


## 상점가 = 기본가 × 증가율^(day-1), 올림(비용). day는 1부터.
static func shop_price(base: int, day: int) -> int:
	return int(ceil(base * pow(SHOP_PRICE_GROWTH, day - 1)))
