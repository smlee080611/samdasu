extends AnimatableBody3D
## 병원 사람 한 명. 상태: STATUE(석상) → MAD(광인) → CURED(정신 회복, 입구로 걸어감)
##                        MAD → (어둠 속 오래) → STATUE
## 자식 노드: CollisionShape3D, Body(MeshInstance3D), Head(MeshInstance3D)

enum State { STATUE, MAD, CURED }

@export var person_name := "환자"
@export var state: State = State.STATUE
@export var wake_speed := 0.7        # 빛을 받을 때 몸이 풀리는 속도
@export var sanity_speed := 0.3      # 빛 속에서 정신이 돌아오는 속도
@export var petrify_after := 6.5     # 어둠 속에서 이 시간이 지나면 다시 굳음
@export var chase_range := 10        # 이 칸 수 안의 플레이어를 쫓아감
@export var flee_speed := 1.1
@export var chase_speed := 2.4
@export var walk_out_speed := 1.5

@onready var body_mesh: MeshInstance3D = $Body
@onready var head_mesh: MeshInstance3D = $Head

var mat: StandardMaterial3D
var level: Level
var player: Node3D
var tile := Vector2i.ZERO
var target := Vector2i.ZERO
var body_t := 0.0
var sanity := 0.0
var dark_t := 0.0
var blocked_said := false

func _ready() -> void:
	add_to_group("person")
	sync_to_physics = false
	mat = (body_mesh.get_active_material(0) as StandardMaterial3D).duplicate()
	body_mesh.material_override = mat
	head_mesh.material_override = mat
	rotation.y = randf() * TAU
	_set_state(state)
	_late_ready.call_deferred()

func _late_ready() -> void:
	level = get_tree().get_first_node_in_group("level")
	player = get_tree().get_first_node_in_group("player")
	tile = level.to_tile(global_position)
	target = tile
	global_position = level.tile_center(tile)

func _set_state(s: State) -> void:
	state = s
	if s == State.STATUE:
		add_to_group("blocker")
		mat.albedo_color = Color(0.55, 0.57, 0.6)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.65, 0.25)
		mat.emission_energy_multiplier = 0.0
	else:
		remove_from_group("blocker")
		mat.emission_enabled = false
		mat.albedo_color = Color(0.55, 0.22, 0.17) if s == State.MAD else Color(0.45, 0.75, 0.68)
	if level:
		level.refresh_nav()

func _process(dt: float) -> void:
	if level == null or GameState.game_over or GameState.won:
		return
	var ex: Array[RID] = [get_rid(), player.get_rid()]
	match state:
		State.STATUE:
			_statue(dt, ex)
		State.MAD:
			_mad(dt, ex)
		State.CURED:
			_cured(dt)

func _statue(dt: float, ex: Array[RID]) -> void:
	var lv := LightSystem.light_at(global_position, ex)
	if lv > LightSystem.LIT_THRESHOLD:
		body_t += dt * (0.4 + lv) * wake_speed
	else:
		body_t = max(0.0, body_t - dt * 0.15)
	mat.emission_energy_multiplier = body_t * 1.5
	if body_t >= 1.0:
		sanity = 0.0
		dark_t = 0.0
		_set_state(State.MAD)
		GameState.say("돌 깨지는 소리. %s의 몸이 풀렸다." % person_name)

func _mad(dt: float, ex: Array[RID]) -> void:
	var lv := LightSystem.light_at(global_position, ex)
	var lit := lv > LightSystem.LIT_THRESHOLD
	if lit:
		dark_t = 0.0
		sanity += dt * sanity_speed * min(1.0, lv * 1.6)
	else:
		dark_t += dt
		sanity = max(0.0, sanity - dt * 0.03)
	var player_tile := level.to_tile(player.global_position)
	if _arrived():
		var next: Variant = null
		if lit:
			next = _darkest_neighbor(lv, ex)
		elif tile.distance_to(player_tile) < chase_range:
			next = level.next_step(tile, player_tile)
		if next != null and not _taken(next):
			target = next
	else:
		_move(flee_speed if lit else chase_speed, dt)
	if not lit and global_position.distance_to(player.global_position) < 0.95:
		player.grabbed(person_name)
	if sanity >= 1.0:
		_set_state(State.CURED)
		GameState.say("%s의 정신이 돌아왔다. 입구로 나간다." % person_name)
	elif dark_t > petrify_after and tile != player_tile and _arrived():
		global_position = level.tile_center(tile)
		body_t = 0.0
		_set_state(State.STATUE)

func _cured(dt: float) -> void:
	if not _arrived():
		_move(walk_out_speed, dt)
		return
	if tile == level.entrance_tile:
		GameState.add_rescued(person_name)
		queue_free()
		return
	var next: Variant = level.next_step(tile, level.entrance_tile)
	if next == null:
		if not blocked_said:
			blocked_said = true
			GameState.say("%s이(가) 입구로 가는 길이 막혀 멈춰 섰다." % person_name)
		return
	blocked_said = false
	target = next

func _arrived() -> bool:
	var to := level.tile_center(target) - global_position
	to.y = 0
	if to.length() < 0.05:
		tile = target
		return true
	return false

func _move(speed: float, dt: float) -> void:
	var to := level.tile_center(target) - global_position
	to.y = 0
	global_position += to.normalized() * min(to.length(), speed * dt)
	look_at(global_position + to.normalized(), Vector3.UP)

func _darkest_neighbor(current: float, ex: Array[RID]) -> Variant:
	var best := current - 0.02
	var pick: Variant = null
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	dirs.shuffle()
	for d in dirs:
		var n: Vector2i = tile + d
		if not level.is_walkable(n) or _taken(n):
			continue
		var v := LightSystem.light_at(level.tile_center(n), ex)
		if v < best:
			best = v
			pick = n
	return pick

func _taken(t: Vector2i) -> bool:
	for p in get_tree().get_nodes_in_group("person"):
		if p != self and p.state != State.STATUE and (p.tile == t or p.target == t):
			return true
	return false
