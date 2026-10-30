extends Node3D
class_name Level
## 레벨: 벽 배치(글자 지도)와 칸 단위 길찾기를 담당한다.
## 석상·문·차광막 같은 오브젝트는 씬 안에 직접 배치한다(에디터에서 끌어다 놓기).
## 지도 문자: # 벽, 나머지는 바닥.

const TS := 2.0
const WALL_H := 3.0

@export_multiline var wall_map := ""
@export var entrance_tile := Vector2i(4, 16)
@export var wall_material: StandardMaterial3D     ## 벽 한 면(2m × 3m)에 한 장씩 붙는 텍스처
@export var floor_material: StandardMaterial3D    ## 바닥 한 칸에 한 장
@export var ceiling_material: StandardMaterial3D  ## 천장 한 칸에 한 장

var rows: PackedStringArray
var size := Vector2i.ZERO
var astar := AStarGrid2D.new()

func _ready() -> void:
	add_to_group("level")
	rows = wall_map.strip_edges().split("\n")
	size = Vector2i(rows[0].length(), rows.size())
	_build_walls()
	refresh_nav.call_deferred()

func _build_walls() -> void:
	# 충돌: 벽 칸마다 상자 하나
	var shape := BoxShape3D.new()
	shape.size = Vector3(TS, WALL_H, TS)
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	walls.collision_layer = GameState.LAYER_WALL
	walls.collision_mask = 0
	add_child(walls)
	# 그래픽: 바닥 쪽으로 드러난 벽 면만 사각형으로 만든다 (텍스처가 면마다 한 장씩 정확히 붙음)
	var wall_st := SurfaceTool.new()
	var floor_st := SurfaceTool.new()
	var ceil_st := SurfaceTool.new()
	for st in [wall_st, floor_st, ceil_st]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in size.y:
		for x in size.x:
			var x0 := x * TS
			var x1 := x0 + TS
			var z0 := y * TS
			var z1 := z0 + TS
			if rows[y][x] != "#":
				_quad(floor_st, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.UP)
				_quad(ceil_st, Vector3(x0, WALL_H, z1), Vector3(x1, WALL_H, z1), Vector3(x1, WALL_H, z0), Vector3(x0, WALL_H, z0), Vector3.DOWN)
				continue
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = tile_center(Vector2i(x, y), WALL_H * 0.5)
			walls.add_child(cs)
			var h := WALL_H
			if _open(x, y + 1):  # 남쪽 면
				_quad(wall_st, Vector3(x0, h, z1), Vector3(x1, h, z1), Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.BACK)
			if _open(x, y - 1):  # 북쪽 면
				_quad(wall_st, Vector3(x1, h, z0), Vector3(x0, h, z0), Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3.FORWARD)
			if _open(x + 1, y):  # 동쪽 면
				_quad(wall_st, Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3.RIGHT)
			if _open(x - 1, y):  # 서쪽 면
				_quad(wall_st, Vector3(x0, h, z0), Vector3(x0, h, z1), Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3.LEFT)
	for pair in [[wall_st, wall_material, "WallMesh"], [floor_st, floor_material, "FloorMesh"], [ceil_st, ceiling_material, "CeilingMesh"]]:
		var mi := MeshInstance3D.new()
		mi.name = pair[2]
		mi.mesh = pair[0].commit()
		mi.material_override = pair[1]
		add_child(mi)

func _open(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y and rows[y][x] != "#"

## a 왼쪽 위, b 오른쪽 위, c 오른쪽 아래, d 왼쪽 아래 (바라보는 쪽 기준)
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var v := [a, b, c, d]
	for i in [0, 1, 2, 0, 2, 3]:   # Godot은 시계 방향이 앞면
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(v[i])

func tile_center(t: Vector2i, y := 0.0) -> Vector3:
	return Vector3(t.x * TS + TS * 0.5, y, t.y * TS + TS * 0.5)

func to_tile(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / TS)), int(floor(p.z / TS)))

## 지나갈 수 있는 칸인가: 벽이 아니고, "blocker" 그룹(석상, 닫힌 문 등)이 서 있지 않은 칸
func is_walkable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return false
	if rows[t.y][t.x] == "#":
		return false
	for b in get_tree().get_nodes_in_group("blocker"):
		if to_tile(b.global_position) == t:
			return false
	return true

## 석상이 생기거나 문이 열리고 닫힐 때 호출
func refresh_nav() -> void:
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in size.y:
		for x in size.x:
			astar.set_point_solid(Vector2i(x, y), not is_walkable(Vector2i(x, y)))

func next_step(from: Vector2i, to: Vector2i) -> Variant:
	if astar.is_point_solid(to) or astar.is_point_solid(from):
		var p0 := astar.get_id_path(from, to, true)
		return p0[1] if p0.size() > 1 else null
	var p := astar.get_id_path(from, to)
	return p[1] if p.size() > 1 else null
