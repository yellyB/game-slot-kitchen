class_name RadialTimer
extends Control

var frac := 1.0: set = set_frac
var fill_color := Palette.MAIN
var track_color := Palette.COCOA_100
var line_color := Palette.COCOA_800

func set_frac(v: float) -> void:
  frac = clampf(v, 0.0, 1.0)
  queue_redraw()

func _draw() -> void:
  var c := size * 0.5
  var r := minf(size.x, size.y) * 0.5 - 2.0
  if r <= 0.0:
    return
  draw_circle(c, r, track_color)
  if frac > 0.0:
    var steps := maxi(3, int(ceil(frac * 48.0)))
    var pts := PackedVector2Array()
    pts.append(c)
    var start := -PI * 0.5
    for i in steps + 1:
      var a := start + TAU * frac * (float(i) / float(steps))
      pts.append(c + Vector2(cos(a), sin(a)) * r)
    draw_colored_polygon(pts, fill_color)
  draw_arc(c, r, 0.0, TAU, 48, line_color, 2.5, true)
