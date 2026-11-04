@tool
extends Node3D
class_name Level
## 레벨(층 하나): 벽 배치(글자 지도)와 칸 단위 길찾기를 담당한다.
## 에디터에서도 돈다(@tool): 층 씬을 열면 지도대로 벽·바닥·천장이 보이고, Wall Map을 고치면 바로 다시 그린다.
##   에디터에서 그린 벽은 씬 파일에 저장되지 않는다(실행할 때마다 지도에서 새로 만듦). 충돌·길찾기는 게임에서만 만든다.
## 석상·문·차광막 같은 오브젝트는 씬 안에 직접 배치한다(에디터에서 끌어다 놓기).
## 지도 문자: # 벽, W 창문이 있는 벽(차광막 씬이 창 구멍을 그림), , 야외(천장 없음, 달빛),
##           v 아래층으로 내려가는 계단 구멍(바닥 없음, 못 걸어감), 나머지는 실내 바닥.
## 층이 여럿이면 main.tscn의 Floors 아래에 층 씬을 다 넣어 두고, 게임에서는 main.gd가 플레이어가 있는 층만 트리에 붙인다.
## 층 씬은 scenes/floors/에 둔다. 층의 원점은 늘 (0, 0, 0)이다 (층마다 같은 좌표를 쓴다).

const TS := 2.0
const WALL_H := 3.0

@export_multiline var wall_map := "":
	set(v):
		wall_map = v
		if Engine.is_editor_hint() and is_inside_tree():
			_editor_preview()   # 에디터에서 지도를 고치면 바로 다시 그린다
@export var floor_no := 1                      ## 몇 층인가. 1 = 1층, 2 = 2층, -1 = 지하 1층 (main.gd가 층을 찾을 때 씀)
@export var entrance_tile := Vector2i(4, 16)   ## 플레이어가 쉬는 곳(엘리베이터 홀). 몸이 풀리고 배터리가 찬다. (-1, -1)이면 이 층엔 쉴 곳이 없음
@export var exit_tile := Vector2i(-1, -1)      ## 구한 사람이 건물 밖으로 나가는 곳(1층 현관 밖). 없으면 entrance_tile
## 0이 아니면: 이 층에는 바깥 출구가 없고, 구한 사람은 그 층으로 가는 비상계단(가까운 쪽)으로 걸어가 그 층에 나타난다.
## 2층·3층·지하는 1로 둔다. 출구 칸은 계단(stairs.tscn)의 Arrive Tile에서 알아서 찾는다.
@export var exit_floor := 0
## 처음 이 층에 올라왔을 때 주인공이 하는 생각 (비우면 없음)
@export_multiline var arrive_thought := ""
## 배터리 총량(이 층에서 쓸 수 있는 헤드램프 배터리 전부) = 처음 100 + hall_reserve + 예비 배터리 개수 × battery_amount.
## 한 사람 구하는 데 약 100이 든다고 보고(풀기 50 + 오가는 길 50) 27명 중 6~8명만 구할 수 있게 맞췄다.
## 엘리베이터 홀의 충전은 정전 뒤 엘리베이터 비상 축전지에 남은 전기라 끝이 있다.
@export var hall_reserve := 300.0          ## 홀 충전에 남은 양 (배터리 %로 셈)
@export var hall_charge_rate := 12.0       ## 홀에서 쉴 때 초당 차는 양
@export var battery_amount := 60.0         ## 뒤져서 찾는 예비 배터리 하나가 채우는 양 (loot = "battery"인 소품 6곳)
@export var wall_material: StandardMaterial3D     ## 벽 한 면(2m × 3m)에 한 장씩 붙는 텍스처
@export var floor_material: StandardMaterial3D    ## 바닥 한 칸에 한 장
@export var ceiling_material: StandardMaterial3D  ## 천장 한 칸에 한 장
@export var facade_material: StandardMaterial3D   ## 바깥에서 보이는 외벽 면
@export var outdoor_material: StandardMaterial3D  ## 야외 바닥 한 칸에 한 장

var rows: PackedStringArray
var size := Vector2i.ZERO
var astar := AStarGrid2D.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_preview()
		return
	add_to_group("level")
	_parse()
	_build_walls()
	refresh_nav.call_deferred()

func _parse() -> void:
	# Windows에서 git으로 받으면 줄바꿈이 \r\n이 되므로 \r을 지우고 나눈다 (안 지우면 줄 길이가 1 늘어나 범위 밖 오류)
	rows = wall_map.replace("\r", "").strip_edges().split("\n")
	size = Vector2i(rows[0].length(), rows.size())

## 에디터 미리보기: 전에 그린 벽을 지우고 지도대로 다시 그린다 (씬에 저장되지 않는 노드들)
var _preview: Array[Node] = []
func _editor_preview() -> void:
	for n in _preview:
		if is_instance_valid(n):
			n.free()
	_preview.clear()
	if wall_map.strip_edges() == "":
		return
	_parse()
	var before := get_child_count()
	_build_walls()
	for i in range(before, get_child_count()):
		_preview.append(get_child(i))

## 이 층의 계단들 (stairs.tscn). 층 씬 바로 아래에 둔다
func stairs() -> Array:
	var out := []
	for c in get_children():
		if c.get("arrive_tile") != null and c.get("to_floor") != null:
			out.append(c)
	return out

func _build_walls() -> void:
	# 충돌: 벽 칸마다 상자 하나 (게임에서만. 에디터 미리보기는 겉모습만)
	var editor := Engine.is_editor_hint()
	var shape := BoxShape3D.new()
	shape.size = Vector3(TS, WALL_H, TS)
	var walls := StaticBody3D.new()
	if not editor:
		walls.name = "Walls"
		walls.collision_layer = GameState.LAYER_WALL
		walls.collision_mask = 0
		add_child(walls)
	# 그래픽: 바닥 쪽으로 드러난 벽 면만 사각형으로 만든다 (텍스처가 면마다 한 장씩 정확히 붙음)
	var wall_st := SurfaceTool.new()
	var floor_st := SurfaceTool.new()
	var ceil_st := SurfaceTool.new()
	var facade_st := SurfaceTool.new()
	var ground_st := SurfaceTool.new()
	for st in [wall_st, floor_st, ceil_st, facade_st, ground_st]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in size.y:
		for x in size.x:
			var x0 := x * TS
			var x1 := x0 + TS
			var z0 := y * TS
			var z1 := z0 + TS
			var c := rows[y][x]
			if c == ",":
				_quad(ground_st, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.UP)
				continue
			if c == "v":   # 계단 구멍: 바닥 없이 천장만 (구멍 안은 stair_down 소품이 그림)
				_quad(ceil_st, Vector3(x0, WALL_H, z1), Vector3(x1, WALL_H, z1), Vector3(x1, WALL_H, z0), Vector3(x0, WALL_H, z0), Vector3.DOWN)
				continue
			if c != "#" and c != "W":
				_quad(floor_st, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.UP)
				_quad(ceil_st, Vector3(x0, WALL_H, z1), Vector3(x1, WALL_H, z1), Vector3(x1, WALL_H, z0), Vector3(x0, WALL_H, z0), Vector3.DOWN)
				continue
			if not editor:
				var cs := CollisionShape3D.new()
				cs.shape = shape
				cs.position = tile_center(Vector2i(x, y), WALL_H * 0.5)
				walls.add_child(cs)
			if c == "W":
				continue   # 창문 벽: 면은 차광막 씬(curtain.gd)이 창 구멍과 함께 그린다
			var h := WALL_H
			# 이웃이 야외면 외벽 재질, 실내면 실내 벽 재질
			if _open(x, y + 1):  # 남쪽 면
				_quad(_side(x, y + 1, wall_st, facade_st), Vector3(x0, h, z1), Vector3(x1, h, z1), Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.BACK)
			if _open(x, y - 1):  # 북쪽 면
				_quad(_side(x, y - 1, wall_st, facade_st), Vector3(x1, h, z0), Vector3(x0, h, z0), Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3.FORWARD)
			if _open(x + 1, y):  # 동쪽 면
				_quad(_side(x + 1, y, wall_st, facade_st), Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3.RIGHT)
			if _open(x - 1, y):  # 서쪽 면
				_quad(_side(x - 1, y, wall_st, facade_st), Vector3(x0, h, z0), Vector3(x0, h, z1), Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3.LEFT)
	if editor:
		walls.free()   # 에디터에서는 충돌이 필요 없다
	for pair in [[wall_st, wall_material, "WallMesh"], [floor_st, floor_material, "FloorMesh"], [ceil_st, ceiling_material, "CeilingMesh"],
			[facade_st, facade_material, "FacadeMesh"], [ground_st, outdoor_material, "GroundMesh"]]:
		if pair[1] == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = pair[2]
		mi.mesh = pair[0].commit()
		mi.material_override = pair[1]
		add_child(mi)

func _open(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y and rows[y][x] != "#" and rows[y][x] != "W"

func _side(x: int, y: int, inside: SurfaceTool, outside: SurfaceTool) -> SurfaceTool:
	return outside if rows[y][x] == "," and facade_material else inside

## a 왼쪽 위, b 오른쪽 위, c 오른쪽 아래, d 왼쪽 아래 (바라보는 쪽 기준)
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var v := [a, b, c, d]
	for i in [0, 1, 2, 0, 2, 3]:   # Godot은 시계 방향이 앞면
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(v[i])

## 홀에서 쉬며 충전: 비상 축전지에서 꺼내 준 만큼 돌려준다. 다 쓰면 0
func draw_hall_charge(want: float) -> float:
	var got := minf(want, hall_reserve)
	hall_reserve -= got
	return got

## 구한 사람이 가는 곳. 바깥 출구가 없는 층(exit_floor)이면 exit_floor로 가는 계단 중 from에서 가까운 쪽
func rescue_tile(from := Vector2i(-1, -1)) -> Vector2i:
	if exit_floor != 0:
		var best := Vector2i(-1, -1)
		for s in stairs():
			if s.to_floor == exit_floor and (best.x < 0 or from.x < 0 or from.distance_to(s.arrive_tile) < from.distance_to(best)):
				best = s.arrive_tile
		if best.x >= 0:
			return best
	return exit_tile if exit_tile.x >= 0 else entrance_tile

## 이 층에 쉴 곳(몸이 풀리고 충전되는 엘리베이터 홀)이 있나
func has_rest() -> bool:
	return entrance_tile.x >= 0

## 구한 사람이 "출구 근처"로 여기는 곳: 쉴 곳이 있으면 거기, 없으면 가까운 출구
func home_tile(from := Vector2i(-1, -1)) -> Vector2i:
	return entrance_tile if has_rest() else rescue_tile(from)

## 야외 칸(지도의 ,)인가
func is_outdoor(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y and rows[t.y][t.x] == ","

func tile_center(t: Vector2i, y := 0.0) -> Vector3:
	return Vector3(t.x * TS + TS * 0.5, y, t.y * TS + TS * 0.5)

func to_tile(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / TS)), int(floor(p.z / TS)))

## 구출된 사람이 기다릴 자리: 레벨의 WaitSpots 노드 아래 Marker3D들 (먼저 온 사람이 먼저 차지)
var _used_spots := 0
func take_wait_spot() -> Vector3:
	var spots := get_node_or_null("WaitSpots")
	if spots and _used_spots < spots.get_child_count():
		_used_spots += 1
		return spots.get_child(_used_spots - 1).global_position
	# 자리가 다 찼으면 출구 바깥 마당에 줄지어 선다 (예전엔 엘리베이터 홀로 돌아가는 버그가 있었음)
	var extra := _used_spots - (spots.get_child_count() if spots else 0)
	_used_spots += 1
	var base := tile_center(rescue_tile())
	return base + Vector3(3.0 + (extra % 6) * 1.3 + randf_range(-0.2, 0.2), 0, 3.0 + (extra / 6) * 1.3 + randf_range(-0.2, 0.2))

## 지나갈 수 있는 칸인가: 벽이 아니고, "blocker" 그룹(석상, 닫힌 문 등)이 서 있지 않은 칸
func is_walkable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return false
	if rows[t.y][t.x] == "#" or rows[t.y][t.x] == "W" or rows[t.y][t.x] == "v":
		return false
	for b in get_tree().get_nodes_in_group("blocker"):
		if to_tile(b.global_position) == t:
			return false
	return true

## 석상이 생기거나 문이 열리고 닫힐 때 호출
func refresh_nav() -> void:
	if not is_inside_tree():
		return   # 플레이어가 없는 층: 돌아올 때 main.gd가 다시 부른다
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
