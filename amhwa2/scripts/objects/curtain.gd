extends StaticBody3D
## 창문과 차광막. E를 길게 눌러 걷으면 창밖(마당, 밤하늘)이 보이고 Moonlight(자식 OmniLight3D)가 켜진다.
## 창이 있는 벽 칸은 지도에서 W로 표시하고, 이 씬이 창 구멍이 난 벽면(안쪽·바깥쪽)과 창틀을 직접 그린다.
## 이 씬의 +Z 쪽이 병실 안, -Z 쪽이 바깥이다. (남쪽 벽에 놓을 때는 180도 돌림)
## 자식 노드: CollisionShape3D, Cloth(닫힌 커튼), DrapeL/DrapeR(걷힌 커튼), Glass, Frame, Moonlight

@export var hold_seconds := 1.5
@export var opening := Rect2(-0.8, 0.9, 1.6, 1.5)   ## 창 구멍: x, y(바닥에서), 너비, 높이 (m)

@onready var cloth: Node3D = $Cloth
@onready var moon = $Moonlight
var open := false
var progress := 0.0

func _ready() -> void:
	GameState.curtains_total += 1
	moon.set_active(false)
	$DrapeL.visible = false
	$DrapeR.visible = false
	_build_wall.call_deferred()

## 플레이어가 E를 누르고 있는 동안 매 프레임 호출. 다 걷었으면 true
func hold(seconds: float) -> bool:
	if open:
		return false
	progress = seconds / hold_seconds
	if progress < 1.0:
		return false
	open = true
	cloth.visible = false
	$DrapeL.visible = true
	$DrapeR.visible = true
	collision_layer = GameState.LAYER_INTERACT
	moon.set_active(true)
	Sfx.play_at("curtain", global_position + Vector3(0, 1.5, 1))
	GameState.curtain_opened()
	return true

func get_hint() -> String:
	return "" if open else "E 길게 · 차광막 걷기"

# ---------- 창 구멍이 난 벽 그리기 ----------
## 칸 단위 지도라 벽 두께가 2m인데, 창까지 2m 굴처럼 보이면 어색하다.
## 그래서 창이 있는 칸은 바깥쪽 1.6m를 마당으로 비워 두고(바닥만 있고 하늘이 보임) 벽 두께를 0.4m로 그린다.
## 병실에서는 창 바로 밖이 마당이고, 마당에서는 창 부분이 살짝 들어간 벽으로 보인다.
const FACE_IN := 1.0      # 병실 쪽 벽면
const FACE_OUT := 0.6     # 창이 있는 바깥 벽면 (두께 0.4m)

func _build_wall() -> void:
	var level := get_parent().get_parent() as Level
	var x0 := opening.position.x
	var x1 := x0 + opening.size.x
	var y0 := opening.position.y
	var y1 := y0 + opening.size.y
	var h := Level.WALL_H
	var inside := SurfaceTool.new()
	var outside := SurfaceTool.new()
	var ground := SurfaceTool.new()
	for st in [inside, outside, ground]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fi := FACE_IN
	var fo := FACE_OUT
	# 병실 쪽 면과 바깥 면: 창 구멍 둘레 네 조각
	for r in [Rect2(-1, 0, x0 + 1, h), Rect2(x1, 0, 1 - x1, h), Rect2(x0, 0, x1 - x0, y0), Rect2(x0, y1, x1 - x0, h - y1)]:
		var l: float = r.position.x
		var rr: float = r.end.x
		var b: float = r.position.y
		var t: float = r.end.y
		_quad(inside, Vector3(l, t, fi), Vector3(rr, t, fi), Vector3(rr, b, fi), Vector3(l, b, fi), Vector3.BACK, false)
		_quad(outside, Vector3(rr, t, fo), Vector3(l, t, fo), Vector3(l, b, fo), Vector3(rr, b, fo), Vector3.FORWARD, true)
	# 창 둘레 (벽 두께 0.4m)
	_quad(inside, Vector3(x0, y1, fi), Vector3(x0, y1, fo), Vector3(x0, y0, fo), Vector3(x0, y0, fi), Vector3.RIGHT, false)
	_quad(inside, Vector3(x1, y1, fo), Vector3(x1, y1, fi), Vector3(x1, y0, fi), Vector3(x1, y0, fo), Vector3.LEFT, false)
	_quad(inside, Vector3(x0, y0, fo), Vector3(x1, y0, fo), Vector3(x1, y0, fi), Vector3(x0, y0, fi), Vector3.UP, false)
	_quad(inside, Vector3(x0, y1, fi), Vector3(x1, y1, fi), Vector3(x1, y1, fo), Vector3(x0, y1, fo), Vector3.DOWN, false)
	# 바깥쪽으로 비운 자리: 바닥과 양옆 외벽 (옆 칸 벽의 옆면)
	_quad(ground, Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, fo), Vector3(-1, 0, fo), Vector3.UP, false)
	_quad(outside, Vector3(-1, h, fo), Vector3(-1, h, -1), Vector3(-1, 0, -1), Vector3(-1, 0, fo), Vector3.RIGHT, false)
	_quad(outside, Vector3(1, h, -1), Vector3(1, h, fo), Vector3(1, 0, fo), Vector3(1, 0, -1), Vector3.LEFT, false)
	var facade := level.facade_material if level.facade_material else level.wall_material
	for pair in [[inside, level.wall_material, "WallIn"], [outside, facade, "WallOut"], [ground, level.outdoor_material, "Ground"]]:
		if pair[1] == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = pair[2]
		mi.mesh = pair[0].commit()
		mi.material_override = pair[1]
		add_child(mi)

## 벽 텍스처(2m×3m 한 장)가 이어지게 위치로 UV를 정한다
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, flip_u: bool) -> void:
	var v := [a, b, c, d]
	for i in [0, 1, 2, 0, 2, 3]:
		var p: Vector3 = v[i]
		var u := (p.x + 1.0) * 0.5
		if flip_u:
			u = 1.0 - u
		if n == Vector3.UP or n == Vector3.DOWN:
			st.set_uv(Vector2(u, (p.z + 1.0) * 0.5))
		elif n == Vector3.RIGHT or n == Vector3.LEFT:
			st.set_uv(Vector2((p.z + 1.0) * 0.5, 1.0 - p.y / Level.WALL_H))
		else:
			st.set_uv(Vector2(u, 1.0 - p.y / Level.WALL_H))
		st.set_normal(n)
		st.add_vertex(p)
