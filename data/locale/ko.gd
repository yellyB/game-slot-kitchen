class_name LocaleKo
extends RefCounted
## 한국어 문자열. 키는 en.gd·ja.gd와 동일하게 유지. 조회는 Loc.t(key).

const S := {
	# 타이틀 / 설정
	"start": "시작",
	"settings": "설정",
	"sound": "소리",
	"bgm": "배경음",
	"sfx": "효과음",
	"vibrate": "진동",
	"language": "언어",

	# 게임 — 상단바 / 토스트
	"day_n": "%d일차",
	"no_empty_slot": "빈 칸 없음",

	# 게임 — 결과 모달
	"win_title": "승리! 🎉",
	"win_days": "%d일 완주",
	"day_closed": "%d일차 마감",
	"revenue": "매출  %d",
	"rent": "가게세  %d",
	"remaining": "남음  %d",
	"passed": "통과! ✅",
	"gameover_title": "폐업 😢",
	"gameover_day": "%d일차에서 끝",
	"gameover_reason": "매출 %d < 가게세 %d",
	"to_title": "처음으로",
	"to_shop": "상점으로",

	# 상점
	"shop_slot": "슬롯 +1",
	"shop_buffpack": "버프 팩",
	"shop_draw": "뽑기",
	"shop_pick": "선택",
	"shop_buy": "구매",
	"shop_start": "영업 시작",
	"shop_owned": "보유 버프",
	"shop_pick3": "3개 중 1개 선택",
	"shop_price": "가격 %d",

	# 손님
	"customer_wants": "뭔가 원함",
}
