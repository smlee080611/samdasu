extends AnimatableBody3D
## 병원 사람 한 명. 상태: STATUE(석상) → MAD(광인) → CURED(정신 회복, 입구로 걸어감)
##                        MAD → (어둠 속 오래) → STATUE
## 자식 노드: CollisionShape3D, Model(사람 3D 모델, models/patient.glb), Breath(숨소리)
## 상태는 모델 재질의 색으로 구분한다: 석상=회색, 광인=붉은빛, 회복=원래 색

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

@onready var model: Node3D = $Model
@onready var breath: AudioStreamPlayer3D = $Breath

var mats: Array[BaseMaterial3D] = []   # 이 사람만의 재질 사본(모델의 모든 면)
var level: Level
var player: Node3D
var tile := Vector2i.ZERO
var target := Vector2i.ZERO
var body_t := 0.0
var sanity := 0.0
var dark_t := 0.0
var blocked_said := false
var step_t := 0.0

func _ready() -> void:
	add_to_group("person")
	sync_to_physics = false
	_collect_materials(model)
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
	else:
		remove_from_group("blocker")
	# 정신이 돌아온 사람은 빛을 가리지 않고, 좁은 복도에서 플레이어와 엉키지 않게 통과된다
	collision_layer = 0 if s == State.CURED else GameState.LAYER_PERSON
	var tint := Color(0.72, 0.74, 0.77) if s == State.STATUE else (Color(1.0, 0.5, 0.45) if s == State.MAD else Color.WHITE)
	for m in mats:
		m.albedo_color = tint
		m.emission_enabled = s == State.STATUE
		m.emission = Color(1.0, 0.6, 0.2)
		m.emission_energy_multiplier = 0.0
	if level:
		level.refresh_nav()
	# 광인일 때만 숨소리
	if s == State.MAD:
		breath.pitch_scale = randf_range(0.85, 1.15)
		breath.play(randf() * 2.0)
	else:
		breath.stop()

func _process(dt: float) -> void:
	if level == null or GameState.is_frozen():
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
	for m in mats:
		m.emission_energy_multiplier = body_t * 0.8
	if body_t >= 1.0:
		sanity = 0.0
		dark_t = 0.0
		_set_state(State.MAD)
		Sfx.play_at("stone_crack", global_position + Vector3.UP)
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
		step_t -= dt
		if step_t <= 0.0:
			step_t = 0.7 if lit else 0.32
			Sfx.play_at("mad_step_%d" % (randi() % 2), global_position, -6.0 if lit else 0.0)
	if not lit and global_position.distance_to(player.global_position) < 0.95:
		player.grabbed(person_name)
	if sanity >= 1.0:
		_set_state(State.CURED)
		Sfx.play_at("cured", global_position + Vector3.UP, -4.0)
		GameState.say("%s의 정신이 돌아왔다. 입구로 나간다." % person_name)
	elif dark_t > petrify_after and tile != player_tile and _arrived():
		global_position = level.tile_center(tile)
		body_t = 0.0
		_set_state(State.STATUE)
		Sfx.play_at("petrify", global_position + Vector3.UP, -3.0)

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

## 모델 안의 모든 메시 면에 이 사람 전용 재질 사본을 붙인다 (석상마다 따로 빛나도록)
func _collect_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 자기 그림자로 검게 얼룩지는 것 방지
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			var m: BaseMaterial3D = src.duplicate() if src is BaseMaterial3D else StandardMaterial3D.new()
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			m.metallic = 0.0
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED   # 얇은 옷자락 뒷면도 보이게
			mi.set_surface_override_material(i, m)
			mats.append(m)
	for c in n.get_children():
		_collect_materials(c)
