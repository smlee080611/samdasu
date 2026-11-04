extends Node3D
## 게임 시작·재시작과 층 관리. 실제 내용은 자식 씬(층들, Player, HUD)에 있다.
##
## 층: main.tscn의 Floors 노드 아래에 층 씬(scenes/floors/*.tscn)을 전부 넣어 둔다. 층 번호는 각 층의 floor_no.
##   (1 = 1층, 2 = 2층 … 지하 1층은 -1)
##   에디터에서는 겹쳐 보이지 않게 지금 손보는 층만 눈 아이콘을 켜 두면 된다. 게임에서는 상관없다.
## 게임이 시작되면 start_floor만 남기고 나머지 층은 Floors에서 떼어 둔다.
##   씬 트리에는 플레이어가 있는 층 하나만 붙어 있다. 층마다 좌표가 같아서(높이 0, 같은 칸) 둘을 같이 붙여 두면
##   벽·빛·사람이 겹치기 때문이다. 떼어 둔 층은 석상·광인·랜턴·케미라이트·문 상태가 그대로 남고, 그동안은 멈춰 있다.
##   다른 스크립트는 지금 층을 늘 get_first_node_in_group("level")로 찾는다.
## 새 층 추가: 층 씬을 만들어 Floors 아래에 끌어다 놓고, 위아래 층에 같은 Side의 계단(stairs.tscn)을 하나씩 두면 끝.

@export var start_floor := 1           ## 게임을 시작하는 층 (개발 중에 2층부터 해 보고 싶으면 2로)
@export var fade_time := 0.45          ## 계단을 오르내릴 때 화면이 어두워지는 시간

const PERSON_SCENE := preload("res://scenes/person.tscn")
@onready var floors_root: Node3D = $Floors
var levels := {}        # 층 번호 → Level
var current := 1
var moving := false     # 층을 옮기는 중 (계단에 다시 걸리지 않게)
var visited := {}

func _enter_tree() -> void:
	add_to_group("main")
	GameState.reset()
	var args := OS.get_cmdline_user_args()
	if ("selftest" in args or "shot" in args) and not "intro" in args:
		GameState.intro_seen = true   # 자동 점검·스크린샷에서는 시작 연출 건너뜀

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("restart"):
		get_tree().reload_current_scene()

func _ready() -> void:
	for c in floors_root.get_children():
		if c is Level:
			levels[c.floor_no] = c
			c.visible = true     # 에디터에서 꺼 둔 층도 게임에서는 보여야 한다
			c.position = Vector3.ZERO
	current = start_floor if levels.has(start_floor) else levels.keys().min()
	for f in levels:
		if f != current:
			floors_root.remove_child(levels[f])
	visited[current] = true
	GameState.floor_no = current
	if current != 1:
		_place_player_at_start.call_deferred()
	if "selftest" in OS.get_cmdline_user_args():
		var t := Node.new()
		t.set_script(load("res://scripts/tests/selftest.gd"))
		add_child(t)
	if "shot" in OS.get_cmdline_user_args():
		var t2 := Node.new()
		t2.set_script(load("res://scripts/tests/shot.gd"))
		add_child(t2)

## 1층이 아닌 층에서 시작할 때(개발용): 그 층의 첫 계단 도착 칸에 선다
func _place_player_at_start() -> void:
	var lv: Level = levels[current]
	var player := get_tree().get_first_node_in_group("player")
	for s in lv.stairs():
		player.global_position = lv.tile_center(s.arrive_tile)
		player.rotation = Vector3(0, deg_to_rad(s.arrive_yaw), 0)
		return

func _exit_tree() -> void:
	# 떼어 둔 층은 씬과 같이 지워지지 않으니 직접 지운다 (F9 다시 시작할 때 새지 않게)
	for f in levels:
		if is_instance_valid(levels[f]) and not levels[f].is_inside_tree():
			levels[f].free()

func level_node() -> Level:
	return levels[current]

func all_levels() -> Array:
	return levels.values()

## 그 층의 사람들 (트리에 붙어 있든 아니든)
func people_of(lv: Level) -> Array:
	var out := []
	var ppl := lv.get_node_or_null("People")
	if ppl:
		out.append_array(ppl.get_children())
	return out

## 계단: 지금 층에서 floor_no 층으로. 도착 층에서 같은 Side이면서 지금 층으로 이어지는 계단에 선다
func go_to(floor_no: int, side: String) -> void:
	if moving or not levels.has(floor_no) or floor_no == current:
		return
	moving = true
	var from := current
	var hud := get_tree().get_first_node_in_group("hud")
	var player := get_tree().get_first_node_in_group("player")
	Sfx.play("step_%d" % (randi() % 3), -4.0)
	if hud and fade_time > 0.0:
		await hud.fade(1.0, fade_time)
	var lv: Level = levels[floor_no]
	switch_level(lv)
	var stairs := find_stairs(lv, side, from)
	if stairs and player:
		player.global_position = lv.tile_center(stairs.arrive_tile)
		player.rotation = Vector3(0, deg_to_rad(stairs.arrive_yaw), 0)
		player.head.rotation.x = 0.0
		player.velocity = Vector3.ZERO
	if not visited.has(floor_no):
		visited[floor_no] = true
		if lv.arrive_thought != "":
			GameState.say.call_deferred(lv.arrive_thought)
	if hud and fade_time > 0.0:
		await hud.fade(0.0, fade_time)
	moving = false

## 층 바꾸기 (화면 연출·위치 없이). 교대처럼 다른 층에서 이어받을 때도 쓴다
func switch_level(lv: Level) -> void:
	var old: Level = levels[current]
	if old == lv:
		return
	floors_root.remove_child(old)
	floors_root.add_child(lv)
	current = lv.floor_no
	GameState.floor_no = current
	lv.refresh_nav()
	GameState.state_changed.emit()

## lv 층에서 side 쪽이면서 leads_to 층으로 이어지는 계단. 못 찾으면 side만 맞는 계단
func find_stairs(lv: Level, side: String, leads_to: int) -> Node:
	var fallback: Node = null
	for s in lv.stairs():
		if s.side == side:
			if s.to_floor == leads_to:
				return s
			fallback = s
	return fallback

## 구해진 사람이 출구 계단에 닿았다: 그 계단으로 to_floor 층에 가서, 거기서 다시 출구로 걸어간다.
## 그 층이 트리 밖이면(플레이어가 다른 층에 있으면) 도착한 자리에 서 있다가, 플레이어가 오면 움직인다.
func send_to(p: Node, from_level: Level, to_floor: int) -> void:
	var dest: Level = levels.get(to_floor)
	if dest == null:
		return
	# 이 사람이 닿은 계단 = 출발 층에서 to_floor로 가는 계단 중 가장 가까운 것
	var side := "W"
	var best := INF
	for s in from_level.stairs():
		if s.to_floor == to_floor:
			var d: float = Vector2(s.arrive_tile).distance_to(Vector2(p.tile))
			if d < best:
				best = d
				side = s.side
	var stairs := find_stairs(dest, side, from_level.floor_no)
	var n := PERSON_SCENE.instantiate()
	n.person_name = p.person_name
	n.state = n.State.CURED
	n.came_down = true
	dest.get_node("People").add_child(n)
	var t: Vector2i = stairs.arrive_tile if stairs else dest.rescue_tile()
	n.position = dest.tile_center(t)   # 층의 원점은 (0,0,0)이라 position = 전역 위치
	p.queue_free()
	from_level.refresh_nav()

## 교대할 사람: 어느 층이든 구출되어 기다리는 사람
func find_heir() -> Node:
	for f in [current] + levels.keys():
		for p in people_of(levels[f]):
			if is_instance_valid(p) and not p.is_queued_for_deletion() and p.waiting:
				return p
	return null
