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
## 광인의 속도는 몸이 얼마나 풀렸는지(sanity 0~1)에 따라 변한다.
## 막 깨어난 광인은 뻣뻣하고 느리다. 빛을 받아 풀릴수록 매끄럽고 빨라진다(플레이어 3.2보다 빠름).
## 그래서 반쯤 비추다 놓치면 오히려 가장 위험한 광인이 된다. 끝까지 비추면 정신이 돌아온다.
@export var chase_speed_stiff := 1.6
@export var chase_speed_loose := 4.6
@export var flee_speed_stiff := 0.7
@export var flee_speed_loose := 2.6
@export var rush_range := 5          # 이 칸 수 안에 들어오면 달려들기(돌진·멈춤 반복)
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
var move_mode := 0            # 0 멈춤, 1 걷기, 2 돌진 (움직임 연출용)
var rush_t := 0.0
var pause_t := 0.0
var flinch_t := 0.0
var was_lit := false
# 1안 움직임: 뼈대 없이 모델 전체를 기울이고 흔들고 끊어서 보여준다
var held := Transform3D.IDENTITY   # 지금 화면에 보이는 모델 자세 (스톱모션처럼 가끔만 갱신)
var pose_t := 0.0
var step_phase := 0.0
var twitch := Vector3.ZERO          # 경련: (앞뒤, 좌우, 고개 돌림)
var twitch_t := 0.0
var waiting := false          # 구출되어 엘리베이터 홀에서 기다리는 중
var wait_pos := Vector3.ZERO

const CURED_LINES := ["...간호사님?", "여기가... 어디예요?", "몸이... 움직여요.", "불, 불 좀 켜 주세요...", "우리 애는요? 우리 애...", "추워요... 너무 추워요."]

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
	if waiting:
		_wait_in_hall(dt)
		return
	var ex: Array[RID] = [get_rid(), player.get_rid()]
	match state:
		State.STATUE:
			_statue(dt, ex)
		State.MAD:
			_mad(dt, ex)
		State.CURED:
			_cured(dt)
	_animate(dt)

## 1안 움직임. 굳었다 풀린 몸이라 관절이 뻣뻣하다:
## - 뻣뻣할수록 스톱모션처럼 초당 몇 장만 보인다 (풀릴수록 매끄러움)
## - 걸을 때 앞으로 숙이고 걸음마다 덜컥 흔들림, 돌진할 땐 더 숙임
## - 가끔 몸과 고개가 확 꺾이는 경련 (빛을 맞으면 크게)
func _animate(dt: float) -> void:
	var loose := 1.0
	if state == State.STATUE:
		model.transform = Transform3D.IDENTITY
		held = model.global_transform
		return
	if state == State.MAD:
		loose = clampf(sanity, 0.0, 1.0)
	# 경련
	twitch_t -= dt
	if twitch_t <= 0.0:
		var stiff_k := 1.0 - loose
		if state == State.MAD and (flinch_t > 0.0 or randf() < 0.35):
			var big := 1.6 if flinch_t > 0.0 else 1.0
			twitch = Vector3(randf_range(-0.25, 0.15), randf_range(-0.3, 0.3), randf_range(-0.5, 0.5)) * (0.4 + stiff_k) * big
		else:
			twitch = Vector3.ZERO
		twitch_t = randf_range(0.12, 0.25) if twitch != Vector3.ZERO else randf_range(0.6, 2.2) * (0.5 + loose)
	# 걸음
	var lean := 0.0
	var bob := 0.0
	var sway := 0.0
	if state == State.MAD:
		lean = 0.32 if move_mode == 2 else (0.12 if move_mode == 1 else 0.05)
		bob = absf(sin(step_phase)) * (0.06 if move_mode == 2 else 0.035) if move_mode > 0 else 0.0
		sway = sin(step_phase) * (0.12 + 0.1 * (1.0 - loose)) if move_mode > 0 else 0.0
	elif state == State.CURED:
		lean = 0.08
		bob = absf(sin(step_phase)) * 0.025
		sway = sin(step_phase) * 0.05
	var b := Basis.from_euler(Vector3(-lean + twitch.x, twitch.z, sway + twitch.y))
	var desired := global_transform * Transform3D(b, Vector3(0, -bob, 0))
	# 스톱모션: 뻣뻣할수록 드문드문 갱신 (6fps → 30fps)
	var fps := lerpf(6.0, 30.0, loose) if state == State.MAD else 30.0
	pose_t -= dt
	if pose_t <= 0.0:
		pose_t = 1.0 / fps
		held = desired
	model.global_transform = held

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

func _mad(dt: float, ex: Array[RID]) -> void:
	var lv := LightSystem.light_at(global_position, ex)
	var lit := lv > LightSystem.LIT_THRESHOLD
	if lit:
		dark_t = 0.0
		sanity += dt * sanity_speed * min(1.0, lv * 1.6)
		if not was_lit:
			flinch_t = 0.45            # 빛을 맞는 순간 움찔하며 멈춤
			twitch_t = 0.0
	else:
		dark_t += dt
		sanity = max(0.0, sanity - dt * 0.03)
	was_lit = lit
	var loose := pow(clampf(sanity, 0.0, 1.0), 0.8)
	var player_tile := level.to_tile(player.global_position)
	var dist := tile.distance_to(player_tile)

	# 어둠 속에서 가까우면 돌진했다 멈췄다를 반복. 뻣뻣할수록 오래 멈춘다
	var rushing := not lit and dist <= rush_range
	if rushing:
		if rush_t > 0.0:
			rush_t -= dt
			if rush_t <= 0.0:
				pause_t = lerpf(0.9, 0.25, loose) * randf_range(0.7, 1.3)
		elif pause_t > 0.0:
			pause_t -= dt
		else:
			rush_t = lerpf(0.5, 1.1, loose) * randf_range(0.8, 1.2)
	flinch_t = maxf(0.0, flinch_t - dt)

	var speed := 0.0
	move_mode = 0
	if flinch_t > 0.0:
		speed = 0.0
	elif lit:
		speed = lerpf(flee_speed_stiff, flee_speed_loose, loose)
		move_mode = 1
	elif rushing:
		if rush_t > 0.0:
			speed = lerpf(chase_speed_stiff, chase_speed_loose, loose)
			move_mode = 2
	else:
		speed = lerpf(chase_speed_stiff, chase_speed_loose, loose) * 0.45   # 멀리서는 슬금슬금
		move_mode = 1

	if _arrived():
		var next: Variant = null
		if lit:
			next = _darkest_neighbor(lv, ex)
		elif dist < chase_range:
			next = level.next_step(tile, player_tile)
		if next != null and not _taken(next):
			target = next
	elif speed > 0.0:
		_move(speed, dt)
		step_t -= dt
		if step_t <= 0.0:
			step_t = clampf(1.1 / speed, 0.18, 0.9)
			Sfx.play_at("mad_step_%d" % (randi() % 2), global_position, -6.0 if lit else 0.0, 0.15)
	if not lit and global_position.distance_to(player.global_position) < 0.95:
		player.grabbed(person_name)
	if sanity >= 1.0:
		_set_state(State.CURED)
		Sfx.play_at("cured", global_position + Vector3.UP, -4.0)
		GameState.speak(global_position, CURED_LINES.pick_random())
	elif dark_t > petrify_after and tile != player_tile and _arrived():
		global_position = level.tile_center(tile)
		_face(player.global_position)   # 다시 굳을 때는 플레이어 쪽을 보고 굳는다
		body_t = 0.0
		_set_state(State.STATUE)
		Sfx.play_at("petrify", global_position + Vector3.UP, -3.0)

func _face(p: Vector3) -> void:
	var to := p - global_position
	to.y = 0
	if to.length() > 0.1:
		look_at(global_position + to.normalized(), Vector3.UP)

func _cured(dt: float) -> void:
	if not _arrived():
		_move(walk_out_speed, dt)
		return
	if tile == level.entrance_tile:
		GameState.add_rescued(person_name)
		waiting = true
		wait_pos = level.take_wait_spot()
		tile = Vector2i(-100, -100)   # 다른 사람 길을 막지 않게 칸에서 빠짐
		target = tile
		return
	var next: Variant = level.next_step(tile, level.entrance_tile)
	if next == null:
		if not blocked_said:
			blocked_said = true
			GameState.speak(global_position, "지나갈 수가 없어요...")
		return
	blocked_said = false
	target = next

## 엘리베이터 홀의 빈자리로 걸어가서 홀 가운데를 보고 선다
func _wait_in_hall(dt: float) -> void:
	var to := wait_pos - global_position
	to.y = 0
	if to.length() > 0.05:
		var step := minf(to.length(), walk_out_speed * dt)
		global_position += to.normalized() * step
		step_phase += step * 2.6
		look_at(global_position + to.normalized(), Vector3.UP)
		_animate(dt)
	else:
		model.transform = Transform3D.IDENTITY
		var c := level.tile_center(level.entrance_tile)
		c.y = global_position.y
		if c.distance_to(global_position) > 0.1:
			look_at(c, Vector3.UP)
		set_process(false)

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
	var step := minf(to.length(), speed * dt)
	global_position += to.normalized() * step
	step_phase += step * 2.6
	if to.length() > 0.01:
		look_at(global_position + to.normalized(), Vector3.UP)

func _darkest_neighbor(current: float, ex: Array[RID]) -> Variant:
	var best := current - 0.02
	var pick: Variant = null
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	dirs.shuffle()
	var ptile := level.to_tile(player.global_position)
	for d in dirs:
		var n: Vector2i = tile + d
		if not level.is_walkable(n) or _taken(n) or n == ptile:   # 플레이어 발밑으로는 도망치지 않음
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
