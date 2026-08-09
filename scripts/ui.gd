class_name UI
extends RefCounted

static var _bold: FontVariation

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

static func chip(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	return s

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

static func money(n: int) -> String:
	var a := absi(n)
	var body := _abbr(a) if a >= Config.MONEY_ABBR_AT else _comma(a)
	return "-" + body if n < 0 else body

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

static func _abbr(a: int) -> String:
	if a >= 1_000_000:
		return _unit(float(a) / 1_000_000.0, "m")
	if roundi(float(a) / 1_000.0) >= 1000:
		return "1m"
	return _unit(float(a) / 1_000.0, "k")

static func _unit(val: float, suffix: String) -> String:
	if val >= 100.0:
		return "%d%s" % [int(round(val)), suffix]
	return ("%.1f" % val).trim_suffix(".0") + suffix


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
