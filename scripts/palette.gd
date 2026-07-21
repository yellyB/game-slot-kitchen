class_name Palette
extends RefCounted
## 공용 컬러 팔레트 (화면.md 기준). 따뜻한 도넛 카페 톤.
## 값은 placeholder — 나중에 테마에서 조정.

# 메인/서브
const MAIN := Color("FF6F91")     # 딸기 핑크 — 브랜드·Primary 버튼
const SUB := Color("C68B59")      # 카라멜 브라운 — 보조 강조
const ACCENT := Color("FFD166")   # 크림 옐로 — 코인·하이라이트

# 시맨틱
const SUCCESS := Color("5FBF77")  # 성공/통과
const DANGER := Color("E5544B")   # 위험/경고 (가게세·부족·손님 화남)
const DISABLED := Color("C9C2BB")

# 중립 (따뜻한 톤)
const WHITE := Color("FFFFFF")
const GRAY100 := Color("F3ECE3")  # 서브배경
const GRAY300 := Color("DCD3C8")  # 테두리·비활성
const GRAY500 := Color("A89F94")  # 보조텍스트
const GRAY700 := Color("6E6258")  # 약한텍스트
const NEAR_BLACK := Color("2A211B")

const TEXT := Color("4A3B32")     # 메인 텍스트 (코코아)
const BG_CREAM := Color("FFF7EC") # 배경 크림 (개발플랜 D1)
const DIM := Color(0.164, 0.129, 0.106, 0.5)  # 모달 딤 오버레이 (#2A211B @50%)
