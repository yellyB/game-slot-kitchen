class_name Palette
extends RefCounted
## 공용 컬러 팔레트 (화면.md 기준). 따뜻한 도넛 카페 톤.
## 3그룹: Brand · Semantic · Cocoa(웜 뉴트럴 스케일).

# Brand
const MAIN := Color("FF6F91")     # Primary — 딸기 핑크 (강조 버튼)
const SUB := Color("C68B59")      # 카라멜 브라운 — 보조 강조
const ACCENT := Color("FFD166")   # 크림 옐로 — 코인·하이라이트

# Semantic
const SUCCESS := Color("5FBF77")  # 통과
const DANGER := Color("E5544B")   # 가게세·부족·화남

# Cocoa (웜 뉴트럴 스케일: 밝음 → 어둠)
const WHITE := Color("FFFFFF")      # 카드·최밝
const COCOA_50 := Color("FFF7EC")   # 배경(크림)
const COCOA_100 := Color("F3ECE3")  # 서브 배경
const COCOA_200 := Color("DCD3C8")  # 테두리·라인·비활성
const COCOA_400 := Color("A89F94")  # 보조 텍스트
const COCOA_600 := Color("6E6258")  # 약한 텍스트
const COCOA_800 := Color("4A3B32")  # 본문 텍스트
const COCOA_900 := Color("2A211B")  # 최다크

const DIM := Color(0.164, 0.129, 0.106, 0.5)  # 모달 딤 (COCOA_900 @50%)
