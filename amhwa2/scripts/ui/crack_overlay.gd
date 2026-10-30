extends Control
## 굳음이 오르면 화면 가장자리에서 금이 자라 들어온다.
## hud.gd가 amount(0~1)만 넣어주면 된다. 금 모양은 처음에 한 번 무작위로 만들어 둔다.

var amount := 0.0:
	set(v):
		if absf(v - amount) > 0.003:
			amount = v
			queue_redraw()

var cracks: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 22:
		var t := rng.randf_range(0.05, 0.95)
		var starts := [Vector2(t, 0), Vector2(1, t), Vector2(t, 1), Vector2(0, t)]
		_grow(rng, starts[i % 4], rng.randi_range(7, 12), rng.randf_range(0.3, 0.7), rng.randf_range(1.6, 2.8), true)

## 한 줄기 금: 가장자리에서 중앙 쪽으로 꺾이며 자란다. 중간에 잔가지를 친다.
func _grow(rng: RandomNumberGenerator, p: Vector2, steps: int, start: float, width: float, branch: bool) -> void:
	var pts := PackedVector2Array([p])
	var dir := (Vector2(0.5, 0.5) - p).normalized()
	for k in steps:
		var to_center := (Vector2(0.5, 0.5) - p).normalized()
		dir = dir.rotated(rng.randf_range(-0.8, 0.8)).lerp(to_center, 0.2).normalized()
		p += dir * rng.randf_range(0.015, 0.04)
		pts.append(p)
		if branch and k > 1 and rng.randf() < 0.3:
			_grow(rng, p, rng.randi_range(2, 4), start + 0.1 + k * 0.02, width * 0.55, false)
	cracks.append({"pts": pts, "start": start, "w": width})

func _draw() -> void:
	for c in cracks:
		var k := clampf((amount - c.start) / 0.3, 0.0, 1.0)
		if k <= 0.0:
			continue
		var pts: PackedVector2Array = c.pts
		var f := k * (pts.size() - 1)
		var n := int(f)
		var line := PackedVector2Array()
		for j in n + 1:
			line.append(pts[j] * size)
		if n < pts.size() - 1:
			line.append(pts[n].lerp(pts[n + 1], f - n) * size)
		if line.size() < 2:
			continue
		var w: float = c.w
		# 밝은 테두리 + 어두운 홈 = 파인 금처럼 보이게
		var lit := PackedVector2Array()
		for q in line:
			lit.append(q + Vector2(1.2, 1.2))
		draw_polyline(lit, Color(0.62, 0.62, 0.6, 0.25), w * 0.8)
		draw_polyline(line, Color(0.02, 0.02, 0.03, 0.95), w * 1.3)
