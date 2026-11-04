extends Node
## 규칙으로 설명되는 공포 사건들. 점프스케어 없이, "어둠 속에 사람이 있다"는 걸 느끼게 한다.
##  1) 열어 둔 병실 문이 닫혀 있다 — 광인이 어둠을 지키려고 닫는다 (멀리서 문 닫히는 소리)
##  2) 간호사실에 처음 들어가면 잠시 뒤 등 뒤에서 바퀴 굴러가는 소리
##  3) 사람을 구한 뒤 홀에 돌아오면 멈춘 엘리베이터 표시등이 한 번 깜빡인다 (비상발전기 떡밥)
##  4) 홀에 두 명 이상 모인 뒤 오래 떠나 있으면, 한 명이 누군가를 찾으러 어둠 속으로 가 버린다
## 각 사건은 숫자만 바꿔 쉽게 조절할 수 있다.
## 1층 씬(level_1f.tscn) 안에 있는 노드다. 다른 층에 사건을 넣으려면 그 층 씬에 이 노드를 하나 더 두고 칸 범위를 바꾼다.

@export var door_interval := Vector2(45, 80)   # 문 사건 사이 간격(초)
@export var max_door_events := 3
@export var vanish_after := 25.0                # 홀을 떠나 있는 시간이 이만큼 지나면 사건 4
@export var vanish_target := Vector2i(10, 14)   # 108호 (아이 쪽지가 있는 방)
@export var hall_rect := Rect2i(17, 1, 5, 4)      # 엘리베이터 홀 (칸)
@export var station_rect := Rect2i(17, 8, 5, 3)   # 간호사실 (칸)

var player: Node3D
var level: Level
var door_t := 60.0
var doors_done := 0
var station_t := -1.0
var station_done := false
var elevator_done := false
var vanish_t := 0.0
var vanish_done := false

func _ready() -> void:
	door_t = randf_range(door_interval.x, door_interval.y)
	_late.call_deferred()

func _late() -> void:
	if not is_inside_tree():   # 다른 층에서 시작해서 이 층이 떼어져 있다: 이 층에 처음 올 때 마저 한다
		tree_entered.connect(func(): _late.call_deferred(), CONNECT_ONE_SHOT)
		return
	player = get_tree().get_first_node_in_group("player")
	level = get_parent() as Level   # 층 씬 안에 둔다: 그 층의 사건. 플레이어가 다른 층에 가면 같이 멈춘다
	if level == null:
		level = get_tree().get_first_node_in_group("level")

func _process(dt: float) -> void:
	# 1층 사건들이다. 플레이어가 다른 층에 있으면 멈춘다 (1층이 트리에서 떨어져 있음)
	if level == null or not level.is_inside_tree() or GameState.is_frozen():
		return
	var pt := level.to_tile(player.global_position)
	_door_event(dt)
	_station_event(dt, pt)
	_elevator_event(pt)
	_vanish_event(dt, pt)

func _in_hall(t: Vector2i) -> bool:
	return hall_rect.has_point(t)

func _unseen(pos: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	var to := (pos - cam.global_position).normalized()
	return (-cam.global_transform.basis.z).dot(to) < 0.2

func _door_event(dt: float) -> void:
	if doors_done >= max_door_events:
		return
	door_t -= dt
	if door_t > 0.0:
		return
	door_t = randf_range(door_interval.x, door_interval.y)
	var doors := level.get_node("Doors").get_children()
	doors.shuffle()
	for d in doors:
		var dist: float = d.global_position.distance_to(player.global_position)
		if d.open and dist > 10.0 and dist < 26.0 and _unseen(d.global_position):
			d.interact(self)
			if not d.open:
				doors_done += 1
				return

func _station_event(dt: float, pt: Vector2i) -> void:
	if station_done:
		return
	if station_t < 0.0 and station_rect.has_point(pt):
		station_t = 2.5
	if station_t >= 0.0:
		station_t -= dt
		if station_t <= 0.0:
			station_done = true
			var behind := player.global_position + player.global_transform.basis.z * 5.0
			Sfx.play_at("wheel_roll", behind + Vector3.UP * 0.3, 2.0, 0.0)

func _elevator_event(pt: Vector2i) -> void:
	if elevator_done or GameState.rescued < 1 or not _in_hall(pt):
		return
	elevator_done = true
	for g in get_tree().get_nodes_in_group("elevator_glow"):
		var tw := create_tween()
		for e in [2.5, 0.0, 0.3, 3.0, 0.0]:
			tw.tween_property(g, "light_energy", e, 0.08)
			tw.tween_interval(0.07)
		Sfx.play_at("elevator_buzz", g.global_position, 0.0, 0.0)

func _vanish_event(dt: float, pt: Vector2i) -> void:
	if vanish_done or GameState.rescued < 2:
		return
	if pt.distance_to(level.entrance_tile) > 12:
		vanish_t += dt
	else:
		vanish_t = 0.0
	if vanish_t < vanish_after:
		return
	for p in get_tree().get_nodes_in_group("person"):
		if p.waiting:
			vanish_done = true
			p.wander_off(vanish_target)
			return
