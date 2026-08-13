class_name SettingsPanel
extends Control

static var settings := {"bgm": true, "sfx": true, "vibrate": true}

var _col: VBoxContainer
var _lang_buttons: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 500
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.164, 0.129, 0.106, 0.35)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			queue_free())
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.card(Palette.WHITE, Palette.COCOA_200))
	panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(panel)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(pad)

	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	pad.add_child(_col)

	_build()


func _build() -> void:
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	_lang_buttons.clear()

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.add_child(UI.label("⚙️", 22))
	header.add_child(UI.label(Loc.t("settings"), 22, Palette.COCOA_800, true))
	var hgap := Control.new()
	hgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hgap)
	header.add_child(_close_button())
	_col.add_child(header)

	_col.add_child(_section_title(Loc.t("sound")))
	_col.add_child(_toggle_row("🎵", Loc.t("bgm"), "bgm"))
	_col.add_child(_toggle_row("🔊", Loc.t("sfx"), "sfx"))
	_col.add_child(_toggle_row("📳", Loc.t("vibrate"), "vibrate"))

	_col.add_child(_divider())

	_col.add_child(_section_title(Loc.t("language")))
	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 8)
	for code in Loc.LOCALES:
		langs.add_child(_lang_chip(code))
	_col.add_child(langs)
	_refresh_langs()


func _section_title(text: String) -> Label:
	return UI.label(text, 14, Palette.COCOA_400, true)


func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Palette.COCOA_200
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _close_button() -> Button:
	var b := Button.new()
	b.text = "✕"
	b.custom_minimum_size = Vector2(34, 34)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Palette.COCOA_400)
	b.add_theme_color_override("font_hover_color", Palette.COCOA_800)
	b.add_theme_stylebox_override("normal", UI.chip(Palette.COCOA_100))
	b.add_theme_stylebox_override("hover", UI.chip(Palette.COCOA_200))
	b.add_theme_stylebox_override("pressed", UI.chip(Palette.COCOA_200))
	b.pressed.connect(queue_free)
	Audio.attach_click(b)
	return b


func _toggle_row(icon: String, text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 36)
	row.add_child(UI.label(icon, 20))
	row.add_child(UI.label(text, 18, Palette.COCOA_800))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	row.add_child(_toggle(key))
	return row


func _toggle(key: String) -> Control:
	var pill := Panel.new()
	pill.custom_minimum_size = Vector2(52, 30)

	var knob := Panel.new()
	knob.custom_minimum_size = Vector2(24, 24)
	knob.add_theme_stylebox_override("panel", UI.chip(Palette.WHITE))
	pill.add_child(knob)

	var hit := Button.new()
	hit.flat = true
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pill.add_child(hit)

	var refresh := func():
		var on: bool = settings[key]
		pill.add_theme_stylebox_override("panel", UI.chip(Palette.SUCCESS if on else Palette.COCOA_200))
		knob.position = Vector2(25.0 if on else 3.0, 3.0)
	hit.pressed.connect(func():
		settings[key] = not settings[key]
		refresh.call()
		Audio.play("switch")
		if key == "bgm":
			Audio.set_bgm(settings["bgm"])
		elif key == "vibrate" and settings["vibrate"]:
			Audio.vibrate())
	refresh.call()
	return pill


func _lang_chip(code: String) -> Button:
	var b := Button.new()
	b.text = _lang_label(code)
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	b.set_meta("code", code)
	b.pressed.connect(func():
		if Loc.locale != code:
			Loc.locale = code
			_build())
	Audio.attach_click(b)
	_lang_buttons.append(b)
	return b


func _lang_label(code: String) -> String:
	match code:
		"ko": return "한국어"
		"en": return "English"
		"ja": return "日本語"
	return code


func _refresh_langs() -> void:
	for b in _lang_buttons:
		var selected: bool = b.get_meta("code") == Loc.locale
		var bg := Palette.MAIN if selected else Palette.COCOA_100
		var fg := Palette.WHITE if selected else Palette.COCOA_800
		b.add_theme_color_override("font_color", fg)
		b.add_theme_color_override("font_hover_color", fg)
		b.add_theme_color_override("font_pressed_color", fg)
		b.add_theme_stylebox_override("normal", UI.chip(bg))
		b.add_theme_stylebox_override("hover", UI.chip(bg.lightened(0.06) if selected else Palette.COCOA_200))
		b.add_theme_stylebox_override("pressed", UI.chip(bg))
