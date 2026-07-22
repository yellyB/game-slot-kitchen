class_name Config
extends RefCounted
## 튜닝 숫자 모음 — 하드코딩 금지, 여기 한 곳에서 조정.
## 기능 개발하면서 그때그때 관련 숫자를 여기에 추가한다(나중에 몰아서 X).
## (레시피별 조리시간 등 "데이터"는 recipes.gd 등 각 data 파일에 유지.)

# ── 보드 (슬롯 그리드) ────────────────────────────────────
const BOARD_COLS := 3
const START_SLOTS := 7   # 시작 슬롯 수(도구석 제외). 상점에서 확장.
const TOOL_COUNT := 2    # 도구석(🔥) 개수 — 그리드 마지막 칸들에 배치
const MAX_SLOTS := 10    # 슬롯 확장 상한

# ── 손님 큐 / 스포너 ──────────────────────────────────────
const MAX_QUEUE := 4          # 큐 최대 인원
const SPAWN_INTERVAL := 4.0   # 손님 등장 간격(초)

# ── 인내심 (2단계 별도 타이머) ────────────────────────────
const PATIENCE_ORDER := 45.0  # 주문 대기(큐)
const PATIENCE_DISH := 60.0   # 음식 대기(슬롯 주문 카드)
const PATIENCE_LOW_FRAC := 0.3  # 이 비율 이하로 남으면 게이지 빨강

# ── 경제 (금액 최소단위 1원, 가장 싼 메뉴 = 1) ────────────
const START_MONEY := 0     # 시작 소지금
const SLOT_PRICE := 6       # 슬롯 +1 확장 가격(상점)
const BUFF_PACK_PRICE := 4  # 버프 팩(카드깡) 가격
const MAX_BUFFS := 3        # 버프 보유 상한 (슬롯 점유 → 소프트락 방지)
# (가게세는 하루별 → data/levels.gd)

# ── 세션 / 하루 ───────────────────────────────────────────
const DAY_LENGTH := 45.0        # 영업시간(초)
const WAVES := 3                # 웨이브 수(고정). 웨이브당 손님 수는 data/levels.gd
const WAVE_SPACING := 0.7       # 웨이브 내 손님 간격(초)
const WAREHOUSE_EXIT_COST := 3.0  # 창고 닫을 때(퇴장) 소모 영업시간(초) — 트립 비용
# (일차별 가게세·손님 수·승리 일차 = data/levels.gd)
