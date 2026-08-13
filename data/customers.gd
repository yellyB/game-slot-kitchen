class_name Customers
extends RefCounted

const IDS := ["bear", "rabbit", "fox", "cat", "dog"]

static var _tex_cache := {}

static func random_id() -> String:
	return IDS[randi() % IDS.size()]

static var _tex_cache_sm := {}

static func tex(id: String, small := false) -> Texture2D:
	var cache: Dictionary = _tex_cache_sm if small else _tex_cache
	if not cache.has(id):
		var dir := "customers_48" if small else "customers_128"
		var path := "res://assets/art/%s/customer_%s.png" % [dir, id]
		cache[id] = load(path) if ResourceLoader.exists(path) else null
	return cache[id]

static func icon_node(id: String, px: int) -> Control:
	var t := tex(id, px <= 30)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label("🙋", px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
