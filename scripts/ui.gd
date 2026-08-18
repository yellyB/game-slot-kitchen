class_name UI
extends RefCounted
## 공용 UI 헬퍼 — Label / StyleBox 생성 통합.
## (임시 공통 컴포넌트: 디자인 확정 후 Theme 리소스로 정리 예정)

static var _bold: FontVariation

## 라벨 — 아이콘/텍스트 공용. bold면 폰트 굵게(FontVariation).
static func label(text: String, size: int, color: Color = Palette.COCOA_800, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold_font())
	return l

static func _bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.55
	return _bold

## 알약형(둥근) 틀 — 버튼·게이지·칩.
static func chip(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s

## 하단 시트 틀 — 크게 둥근 + 위로 뜬 그림자.
static func sheet() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.WHITE
	s.set_corner_radius_all(18)
	s.set_border_width_all(1)
	s.border_color = Palette.COCOA_200
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.18)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, -2)
	return s

## 금액 표시 통합 — 모든 금액은 이 함수로. 콤마 구분, Config.MONEY_ABBR_AT 이상은 k/m 축약.
static func money(n: int) -> String:
	var a := absi(n)
	var body := _abbr(a) if a >= Config.MONEY_ABBR_AT else _comma(a)
	return "-" + body if n < 0 else body


## art/ui 손그림 아이콘(이모지 대체) → TextureRect(px×px, 비율유지 중앙, LINEAR).
static func ui_icon(name: String, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load("res://assets/art/ui/%s.png" % name)
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 일력(달력) 뱃지 — day_calendar.png 위에 날짜 숫자를 크림 본체 영역에 얹음.
## 반환 Control의 meta "num"에 숫자 Label을 담아 호출측이 텍스트 갱신.
static func day_badge(px: int) -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(px, px)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cal := ui_icon("day_calendar", px)
	cal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cal.custom_minimum_size = Vector2.ZERO   # 부모(badge) 크기에 맞춤
	badge.add_child(cal)
	var num := label("1", int(px * 0.36), Palette.COCOA_800, true)
	num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.offset_top = px * 0.30   # 상단 철사·핑크 헤더 피해 크림 본체 중앙-하단으로 내림
	badge.add_child(num)
	badge.set_meta("num", num)
	return badge


## 버튼 중앙에 얹는 아이콘(FULL_RECT CenterContainer 래핑) — 텍스트 대신.
static func ui_btn_icon(name: String, px: int) -> Control:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(ui_icon(name, px))
	return cc

## 3자리 콤마 구분.
static func _comma(a: int) -> String:
	var s := str(a)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out

## k/m 축약 — 100 이상 단위는 소수 없이, 미만은 소수 1자리(.0 제거).
static func _abbr(a: int) -> String:
	if a >= 1_000_000:
		return _unit(float(a) / 1_000_000.0, "m")
	if roundi(float(a) / 1_000.0) >= 1000:  # 999,999처럼 반올림이 1000k 되는 경계 → 1m 승격
		return "1m"
	return _unit(float(a) / 1_000.0, "k")

static func _unit(val: float, suffix: String) -> String:
	if val >= 100.0:
		return "%d%s" % [int(round(val)), suffix]
	return ("%.1f" % val).trim_suffix(".0") + suffix


## 카드/패널 틀 — 둥근 + 테두리 + 그림자.
static func card(bg: Color, border: Color = Color.TRANSPARENT, w := 1, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.set_border_width_all(w)
		s.border_color = border
	s.shadow_color = Color(0.164, 0.129, 0.106, 0.12)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s
