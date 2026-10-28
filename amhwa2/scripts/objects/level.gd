extends Node3D
class_name Level
## 레벨: 벽 배치(글자 지도)와 칸 단위 길찾기를 담당한다.
## 석상·문·차광막 같은 오브젝트는 씬 안에 직접 배치한다(에디터에서 끌어다 놓기).
## 지도 문자: # 벽, 나머지는 바닥.

const TS := 2.0
const WALL_H := 3.0

@export_multiline var wall_map := ""
@export var entrance_tile := Vector2i(4, 16)
@export var wall_material: StandardMaterial3D
@export var floor_material: StandardMaterial3D

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
	var mesh := BoxMesh.new()
	mesh.size = Vector3(TS, WALL_H, TS)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	walls.collision_layer = GameState.LAYER_WALL
	walls.collision_mask = 0
	add_child(walls)
	for y in size.y:
		for x in size.x:
			if rows[y][x] != "#":
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = wall_material
			mi.position = tile_center(Vector2i(x, y), WALL_H * 0.5)
			walls.add_child(mi)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = mi.position
			walls.add_child(cs)
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x * TS, size.y * TS)
	for i in 2:
		var p := MeshInstance3D.new()
		p.mesh = plane
		p.material_override = floor_material
		p.position = Vector3(size.x * TS * 0.5, WALL_H * i, size.y * TS * 0.5)
		if i == 1:
			p.rotation.x = PI
		add_child(p)

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
