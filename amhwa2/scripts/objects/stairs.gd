@tool
extends Area3D
## 비상계단. 계단 첫 단(올라가는 계단) 또는 계단 구멍 가장자리(내려가는 계단)에 걸어 들어가면 다른 층으로 간다.
## 층마다 같은 쪽(side)의 계단끼리 이어진다: 1층 서쪽 계단 ↔ 2층 서쪽 계단.
## 도착하면 그 층에 있는 같은 쪽 계단의 arrive_tile에 선다 (계단에서 한 칸 떨어진 곳이라 바로 다시 걸리지 않음).
## 광인과 석상은 층을 오가지 않는다. 구한 사람은 바깥 출구가 없는 층에서 계단으로 출구 층에 간다(main.gd send_to).
## 층 하나에 계단이 여럿일 수 있다(1층에서 2층으로 가는 계단, 지하로 가는 계단). 짝은 Side와 To Floor로 찾는다.

@export var side := "W"                     ## "W" 서쪽 / "E" 동쪽
@export var to_floor := 2                   ## 이 계단이 이어지는 층
@export var arrive_tile := Vector2i(2, 4)   ## 다른 층에서 이 계단으로 왔을 때 서는 칸
@export var arrive_yaw := 180.0             ## 그때 바라보는 방향 (180 = 남쪽, 복도 쪽)
@export var zone := Vector3(3.8, 1.0, 1.2)  ## 밟으면 층을 옮기는 범위 (이 노드 기준 상자)

func _ready() -> void:
	add_to_group("stairs")
	var cs := $CollisionShape3D as CollisionShape3D
	var box := BoxShape3D.new()   # 계단마다 범위가 달라서 공유 리소스를 복제
	box.size = zone
	cs.shape = box
	cs.position = Vector3(0, zone.y * 0.5, 0)
	if Engine.is_editor_hint():
		return   # 에디터에서는 밟는 범위(초록 상자)만 보여 준다
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if not b.is_in_group("player") or GameState.is_frozen():
		return
	if b.kneel_t > 0.0:
		return
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.moving:
		return
	if not main.levels.has(to_floor):
		GameState.say("위층은 막혀 있다.")
		return
	main.go_to(to_floor, side)
