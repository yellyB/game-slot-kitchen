class_name Customers
extends RefCounted

const IDS := ["bear", "rabbit", "fox", "cat", "dog"]

static var _tex_cache := {}

static func random_id() -> String:
	return IDS[randi() % IDS.size()]

static func tex(id: String) -> Texture2D:
	if not _tex_cache.has(id):
		var path := "res://assets/art/customers/customer_%s.png" % id
		_tex_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[id]

static func icon_node(id: String, px: int) -> Control:
	var t := tex(id)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(px, px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var lbl := UI.label("🙋", px)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
