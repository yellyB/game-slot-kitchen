class_name RadialTimer
extends Control
## 조리 진행 라디얼(파이) 타이머 — 남은 비율(frac 1→0)만큼 부채꼴을 채워 카운트다운.
## 12시 방향에서 시계방향으로, 남은 시간만큼 차오른 파이가 점점 줄어든다.

var frac := 1.0: set = set_frac
var fill_color := Palette.MAIN         # 남은 시간 파이(레퍼런스처럼 또렷한 핑크)
var track_color := Palette.COCOA_100  # 빈 바탕
var line_color := Palette.COCOA_800   # 진한 외곽선

func set_frac(v: float) -> void:
  frac = clampf(v, 0.0, 1.0)
  queue_redraw()

func _draw() -> void:
  var c := size * 0.5
  var r := minf(size.x, size.y) * 0.5 - 2.0
  if r <= 0.0:
    return
  draw_circle(c, r, track_color)   # 빈 바탕
  if frac > 0.0:                    # 남은 부채꼴(12시 → 시계방향)
    var steps := maxi(3, int(ceil(frac * 48.0)))
    var pts := PackedVector2Array()
    pts.append(c)
    var start := -PI * 0.5
    for i in steps + 1:
      var a := start + TAU * frac * (float(i) / float(steps))
      pts.append(c + Vector2(cos(a), sin(a)) * r)
    draw_colored_polygon(pts, fill_color)
  draw_arc(c, r, 0.0, TAU, 48, line_color, 2.5, true)   # 진한 외곽선
