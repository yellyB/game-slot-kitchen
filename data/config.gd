class_name Config
extends RefCounted
## 튜닝 숫자 모음 — 하드코딩 금지, 여기 한 곳에서 조정.
## 기능 개발하면서 그때그때 관련 숫자를 여기에 추가한다(나중에 몰아서 X).
## (레시피별 조리시간 등 "데이터"는 recipes.gd 등 각 data 파일에 유지.)

# ── 보드 (슬롯 그리드) ────────────────────────────────────
const BOARD_COLS := 3
const BOARD_SLOTS := 9
const TOOL_SLOTS := [2, 8]   # 도구석(🔥) 위치 — 재료/카드 못 들어옴

# ── 손님 큐 / 스포너 ──────────────────────────────────────
const MAX_QUEUE := 4          # 큐 최대 인원
const SPAWN_INTERVAL := 4.0   # 손님 등장 간격(초)

# ── 인내심 (2단계 별도 타이머) ────────────────────────────
const PATIENCE_ORDER := 45.0  # 주문 대기(큐)
const PATIENCE_DISH := 60.0   # 음식 대기(슬롯 주문 카드)
const PATIENCE_LOW_FRAC := 0.3  # 이 비율 이하로 남으면 게이지 빨강
