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


## 상단바 컴포넌트 — 게임·상점 공용. 흰 카드에 [점수목표(실적바)] / [보유금] / 시간바 3줄.
## meta: day_num·money_label·score_bar·score_label·hours_bar·home_btn·coin_box.
static func top_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", card(Palette.WHITE))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	pad.add_child(box)

	# 상단: 왼쪽 날짜(두 줄 높이) + 오른쪽 [점수 줄 / 보유금 줄]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	var badge := day_badge(56)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(badge)
	var rcol := VBoxContainer.new()
	rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rcol.add_theme_constant_override("separation", 4)
	top.add_child(rcol)

	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	rcol.add_child(srow)
	var sgap := Control.new()
	sgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sgap)
	var star_name := "star" if ResourceLoader.exists("res://assets/art/ui/star.png") else "mood_happy"
	srow.add_child(ui_icon(star_name, 20))
	var sbar := ProgressBar.new()
	sbar.min_value = 0
	sbar.max_value = 100
	sbar.value = 0
	sbar.show_percentage = false
	sbar.custom_minimum_size = Vector2(64, 16)
	sbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sbar.add_theme_stylebox_override("background", chip(Palette.COCOA_100, Palette.COCOA_200))
	sbar.add_theme_stylebox_override("fill", chip(Palette.MAIN))
	srow.add_child(sbar)
	var score := label("0/0", 15, Palette.COCOA_800, true)
	srow.add_child(score)
	var home := Button.new()
	home.custom_minimum_size = Vector2(34, 34)
	home.add_child(ui_btn_icon("house", 22))
	home.add_theme_stylebox_override("normal", chip(Palette.COCOA_100, Palette.COCOA_200))
	home.add_theme_stylebox_override("hover", chip(Palette.COCOA_200))
	home.add_theme_stylebox_override("pressed", chip(Palette.COCOA_200))
	srow.add_child(home)

	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 4)
	rcol.add_child(crow)
	var cgap := Control.new()
	cgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(cgap)
	var coin := HBoxContainer.new()
	coin.add_theme_constant_override("separation", 4)
	coin.add_child(ui_icon("coin", 20))
	var money := label("0", 18, Palette.COCOA_800, true)
	coin.add_child(money)
	crow.add_child(coin)

	var hours := HBoxContainer.new()
	hours.add_theme_constant_override("separation", 8)
	box.add_child(hours)
	hours.add_child(ui_icon("sun", 18))
	var hbar := ProgressBar.new()
	hbar.min_value = 0
	hbar.max_value = 100
	hbar.value = 0
	hbar.show_percentage = false
	hbar.custom_minimum_size = Vector2(0, 14)
	hbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbar.add_theme_stylebox_override("background", chip(Palette.COCOA_100, Palette.COCOA_200))
	hbar.add_theme_stylebox_override("fill", chip(Palette.ACCENT))
	hours.add_child(hbar)
	hours.add_child(ui_icon("moon", 18))

	panel.set_meta("day_num", badge.get_meta("num"))
	panel.set_meta("money_label", money)
	panel.set_meta("score_bar", sbar)
	panel.set_meta("score_label", score)
	panel.set_meta("hours_bar", hbar)
	panel.set_meta("home_btn", home)
	panel.set_meta("coin_box", coin)
	return panel

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
