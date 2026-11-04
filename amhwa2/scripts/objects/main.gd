extends Node3D
## 게임 시작·재시작과 층 관리. 실제 내용은 자식 씬(Level, Player, HUD)에 있다.
## 층: 1층은 main.tscn에 들어 있고, 나머지 층은 upper_floors 씬을 시작할 때 미리 만들어 둔다.
## 씬 트리에는 플레이어가 있는 층 하나만 붙어 있다. 다른 층은 트리에서 떼어 두기만 해서
## 석상·광인·랜턴·케미라이트·문 상태가 그대로 남고, 그동안은 멈춰 있다(아무도 보지 않으니까).
## 다른 스크립트는 지금 층을 늘 get_first_node_in_group("level")로 찾는다.

@export var upper_floors: Array[PackedScene] = []   ## 2층부터 차례로
@export var fade_time := 0.45                       ## 계단을 오르내릴 때 화면이 어두워지는 시간

const PERSON_SCENE := preload("res://scenes/person.tscn")
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
	for c in get_children():
		if c is Level:
			levels[c.floor_no] = c
			current = c.floor_no
	visited[current] = true
	for sc in upper_floors:
		var lv := sc.instantiate() as Level
		levels[lv.floor_no] = lv   # 아직 트리에 붙이지 않는다. 처음 올라갈 때 붙이면서 _ready가 돈다
	GameState.floor_no = current
	if "selftest" in OS.get_cmdline_user_args():
		var t := Node.new()
		t.set_script(load("res://scripts/tests/selftest.gd"))
		add_child(t)
	if "shot" in OS.get_cmdline_user_args():
		var t2 := Node.new()
		t2.set_script(load("res://scripts/tests/shot.gd"))
		add_child(t2)

func _exit_tree() -> void:
	# 트리에서 떼어 둔 층은 씬과 같이 지워지지 않으니 직접 지운다 (F9 다시 시작할 때 새지 않게)
	for f in levels:
		if not levels[f].is_inside_tree():
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

## 계단: side("W"/"E")가 같은 계단으로 그 층에 도착한다. 화면이 잠깐 어두워진다
func go_to(floor_no: int, side: String) -> void:
	if moving or not levels.has(floor_no) or floor_no == current:
		return
	moving = true
	var hud := get_tree().get_first_node_in_group("hud")
	var player := get_tree().get_first_node_in_group("player")
	Sfx.play("step_%d" % (randi() % 3), -4.0)
	if hud and fade_time > 0.0:
		await hud.fade(1.0, fade_time)
	switch_level(levels[floor_no])
	var stairs := find_stairs(levels[floor_no], side)
	if stairs and player:
		player.global_position = levels[floor_no].tile_center(stairs.arrive_tile)
		player.rotation = Vector3(0, deg_to_rad(stairs.arrive_yaw), 0)
		player.head.rotation.x = 0.0
		player.velocity = Vector3.ZERO
	if not visited.has(floor_no):
		visited[floor_no] = true
		if levels[floor_no].arrive_thought != "":
			GameState.say.call_deferred(levels[floor_no].arrive_thought)
	if hud and fade_time > 0.0:
		await hud.fade(0.0, fade_time)
	moving = false

## 층 바꾸기 (화면 연출·위치 없이). 교대처럼 다른 층에서 이어받을 때도 쓴다
func switch_level(lv: Level) -> void:
	var old: Level = levels[current]
	if old == lv:
		return
	var idx := old.get_index()
	remove_child(old)
	add_child(lv)
	move_child(lv, idx)
	current = lv.floor_no
	GameState.floor_no = current
	lv.refresh_nav()
	GameState.state_changed.emit()

func find_stairs(lv: Level, side: String) -> Node:
	for c in lv.get_children():
		if c.is_in_group("stairs") or c.get("arrive_tile") != null:
			if c.get("side") == side:
				return c
	return null

## 위층에서 정신이 돌아온 사람이 계단에 닿았다: 그 계단으로 아래층에 내려가 거기서 다시 출구로 걸어간다.
## 아래층이 트리 밖이면(플레이어가 위층에 있으면) 내려간 자리에 서 있다가, 플레이어가 내려오면 움직인다.
func send_down(p: Node, from_level: Level) -> void:
	var below: Level = levels.get(from_level.floor_no - 1)
	if below == null:
		return
	var side := "W" if p.tile.x < from_level.size.x / 2 else "E"
	var stairs := find_stairs(below, side)
	var n := PERSON_SCENE.instantiate()
	n.person_name = p.person_name
	n.state = n.State.CURED
	n.came_down = true
	below.get_node("People").add_child(n)
	var t: Vector2i = stairs.arrive_tile if stairs else below.rescue_tile()
	n.position = below.tile_center(t)   # 층의 원점은 (0,0,0)이라 position = 전역 위치
	p.queue_free()
	from_level.refresh_nav()

## 교대할 사람: 어느 층이든 구출되어 기다리는 사람
func find_heir() -> Node:
	for f in [current] + levels.keys():
		for p in people_of(levels[f]):
			if is_instance_valid(p) and not p.is_queued_for_deletion() and p.waiting:
				return p
	return null
