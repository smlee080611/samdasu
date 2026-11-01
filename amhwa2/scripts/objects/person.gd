extends AnimatableBody3D
## 병원 사람 한 명. 상태: STATUE(석상) → MAD(광인) → CURED(정신 회복, 입구로 걸어감)
##                        MAD → (어둠 속 오래) → STATUE
## 자식 노드: CollisionShape3D, Model(models/patient_parts.glb: Head, Torso, ArmXp/ArmXn, LegXp/LegXn), Breath(숨소리)
## 모델은 부위별로 나뉘어 있고 각 부위의 원점이 관절이다. _animate()가 부위를 돌려 걸음과 경련을 만든다.
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
@export var escape_search := 90       # 숨을 곳을 찾을 때 살펴볼 칸 수
@export var lunge_speed := 4.8        # 빛에 갇혔을 때 돌발적으로 달려드는 속도
@export var lunge_cooldown := 3.5
@export var walk_out_speed := 1.5
@export var skin: StandardMaterial3D   ## 사람 피부·옷 재질 (models/patient_skin.tres). 사람마다 복제해서 색을 바꾼다

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
var flee_path: Array[Vector2i] = []   # 플레이어 시야 밖 어두운 곳까지의 길
var fled := false                     # 방금 빛에서 도망쳐 숨었음
var lurk_t := 0.0                     # 숨은 뒤 잠시 가만히 엿보는 시간
var stuck_t := 0.0                    # 빛 속에서 도망칠 곳이 없던 시간
var lunge_t := 0.0                    # 돌발 돌진 중
var lunge_cd := 0.0
var held_by: Node = null              # (회복한 사람) 나를 붙잡은 광인
var held_t := 0.0                     # 붙잡혀 굳어 가는 정도(초). hold_petrify가 되면 석상
var victim: Node = null               # (광인) 내가 붙잡고 있는 사람
@export var hold_petrify := 5.0
const HELP_LINES := ["살려주세요...!", "누가 좀...!", "놔, 놔요...!", "간호사님...!"]
var loose_now := 0.0                # 지금 몸이 풀린 정도 (움직임 연출용)
const MAD_TINT := Color(0.92, 0.64, 0.6)
const STONE_TINT := Color(0.72, 0.74, 0.77)
var parts := {}                     # 부위 이름 -> 노드
var pose := {}                      # 부위 이름 -> 지금 각도(Vector3)
var statue_pose := {}               # 석상일 때 굳은 자세
var wander := false                 # 홀에서 기다리다 어둠 속으로 걸어 나감 (사건)
var wander_target := Vector2i.ZERO
var waiting := false          # 구출되어 엘리베이터 홀에서 기다리는 중
var wait_pos := Vector3.ZERO

const CURED_LINES := ["...간호사님?", "여기가... 어디예요?", "몸이... 움직여요.", "불, 불 좀 켜 주세요...", "우리 애는요? 우리 애...", "추워요... 너무 추워요."]

func _ready() -> void:
	add_to_group("person")
	sync_to_physics = false
	_collect_materials(model)
	rotation.y = randf() * TAU
	_random_statue_pose()
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
	var tint := Color(0.72, 0.74, 0.77) if s == State.STATUE else (MAD_TINT if s == State.MAD else Color.WHITE)
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
		model.transform = Transform3D.IDENTITY   # 굳은 순간의 부위 자세(pose)는 그대로 둔다
		held = model.global_transform
		return
	if state == State.MAD:
		loose = loose_now
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
	elif state == State.CURED and held_t > 0.0:
		lean = 0.5                     # 붙잡혀 주저앉음
		bob = 0.35
	elif state == State.CURED:
		lean = 0.08
		bob = absf(sin(step_phase)) * 0.025
		sway = sin(step_phase) * 0.05
	var b := Basis.from_euler(Vector3(-lean + twitch.x * 0.4, twitch.z * 0.3, sway * 0.5 + twitch.y * 0.4))
	var desired := global_transform * Transform3D(b, Vector3(0, -bob, 0))
	# 스톱모션: 뻣뻣할수록 드문드문 갱신 (6fps → 30fps)
	var fps := lerpf(6.0, 30.0, loose) if state == State.MAD else 30.0
	pose_t -= dt
	if pose_t <= 0.0:
		pose_t = 1.0 / fps
		held = desired
		_limb_pose(loose)
	model.global_transform = held

## 팔다리: 걸음에 맞춰 다리를 엇갈려 휘두르고, 광인은 팔을 앞으로 뻗는다.
## 뻣뻣할수록 관절이 덜 움직이고(보폭이 작고) 팔이 들린 채 굳어 있다.
func _limb_pose(loose: float) -> void:
	var moving := move_mode > 0 or (state == State.CURED and not waiting) or waiting
	var sw := sin(step_phase)
	var leg_amp := 0.0
	if moving:
		leg_amp = (0.55 if move_mode == 2 else 0.35) * (0.45 + 0.55 * loose)
	var reach := 0.0
	var arm_amp := 0.0
	if state == State.MAD:
		reach = 1.25 if move_mode == 2 else (0.7 if move_mode == 1 else 0.35)
		reach *= 1.0 - 0.4 * loose
		arm_amp = 0.12
	else:
		arm_amp = 0.25 * (1.0 if moving else 0.0)
	var target_pose := {
		"LegXp": Vector3(sw * leg_amp, 0, 0),
		"LegXn": Vector3(-sw * leg_amp, 0, 0),
		"ArmXp": Vector3(reach - sw * arm_amp + twitch.x * 0.8, 0, -0.08 + twitch.y * 0.5),
		"ArmXn": Vector3(reach * 0.85 + sw * arm_amp - twitch.x * 0.6, 0, 0.08 - twitch.y * 0.4),
		"Head": Vector3(0.15 + twitch.x * 1.5, twitch.z * 1.4, twitch.y * 1.6) if state == State.MAD else Vector3(0.1, 0, 0),
	}
	for k in target_pose:
		# 풀렸을수록 부드럽게 따라가고, 뻣뻣하면 뚝 끊겨서 바뀐다
		pose[k] = pose.get(k, Vector3.ZERO).lerp(target_pose[k], lerpf(1.0, 0.6, loose))
	_apply_pose()

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

## 광인의 행동
##  빛 속: 플레이어 시야 밖의 어두운 곳을 찾아 그곳까지 도망친다(벽 뒤, 모퉁이 너머, 문 안쪽).
##        도망칠 곳이 없으면(구석에 몰리면) 잠깐 버티다가 비명과 함께 플레이어에게 돌발적으로 달려든다.
##  숨은 뒤: 잠시 가만히 엿보다가 다시 다가온다.
##  어둠 속: 멀리서는 슬금슬금, 가까우면 돌진·멈춤 반복. 오래 있으면 점점 굳어 돌이 된다.
func _mad(dt: float, ex: Array[RID]) -> void:
	var lv := LightSystem.light_at(global_position, ex)
	var lit := lv > LightSystem.LIT_THRESHOLD
	if lit:
		dark_t = 0.0
		sanity += dt * sanity_speed * min(1.0, lv * 1.6)
		if not was_lit and lunge_t <= 0.0:
			flinch_t = 0.45            # 빛을 맞는 순간 움찔하며 멈춤
			twitch_t = 0.0
	else:
		dark_t += dt
		sanity = max(0.0, sanity - dt * 0.03)
		if fled:                       # 숨는 데 성공: 잠시 엿본다
			fled = false
			lurk_t = randf_range(1.5, 3.5)
	was_lit = lit
	lurk_t = maxf(0.0, lurk_t - dt)
	lunge_t = maxf(0.0, lunge_t - dt)
	lunge_cd = maxf(0.0, lunge_cd - dt)
	# 어둠 속에 있을수록 다시 굳어 간다: 느려지고, 뚝뚝 끊기고, 회색으로 변하다가 돌이 된다
	var harden := clampf(dark_t / petrify_after, 0.0, 1.0)
	var loose := pow(clampf(sanity, 0.0, 1.0), 0.8) * (1.0 - 0.75 * harden)
	loose_now = loose
	mats[0].albedo_color = MAD_TINT.lerp(STONE_TINT, harden * harden)
	var player_tile := level.to_tile(player.global_position)
	# 쫓을 대상: 플레이어, 또는 어둠 속을 홀로 걸어가는 회복한 사람 (플레이어를 조금 더 우선)
	var prey_tile := player_tile
	var dist := tile.distance_to(player_tile)
	if not lit:
		for q in get_tree().get_nodes_in_group("person"):
			if q.state == State.CURED and not q.waiting and q.held_by == null:
				var dq := tile.distance_to(q.tile)
				if dq + 2.0 < dist and dq < chase_range:
					dist = dq
					prey_tile = q.tile
	# 사람을 붙잡고 있는 동안은 그 자리에 머문다 (빛을 받으면 놓고 도망)
	if victim != null:
		if lit or not is_instance_valid(victim) or victim.state != State.CURED or victim.held_by != self:
			if is_instance_valid(victim) and victim.held_by == self:
				victim.held_by = null
			victim = null
		else:
			_face(victim.global_position)
			move_mode = 0
			if player.global_position.distance_to(global_position) < 0.95 and player.grab_cooldown <= 0.0:
				player.grabbed(person_name)
			return

	# 어둠 속에서 가까우면 돌진했다 멈췄다를 반복. 뻣뻣할수록 오래 멈춘다
	var rushing := not lit and dist <= rush_range and lurk_t <= 0.0
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
	if lunge_t > 0.0:
		speed = lunge_speed
		move_mode = 2
	elif flinch_t > 0.0:
		speed = 0.0
	elif lit:
		speed = lerpf(flee_speed_stiff, flee_speed_loose, loose)
		move_mode = 1
	elif lurk_t > 0.0 and dist > 2:
		speed = 0.0                    # 숨어서 엿보는 중
	elif rushing:
		if rush_t > 0.0:
			speed = lerpf(chase_speed_stiff, chase_speed_loose, loose)
			move_mode = 2
	else:
		speed = lerpf(chase_speed_stiff, chase_speed_loose, loose) * 0.45   # 멀리서는 슬금슬금
		move_mode = 1
	if lunge_t <= 0.0:
		speed *= 1.0 - 0.6 * harden

	# 빛에 갇혀 도망칠 곳이 없으면 돌발 돌진
	if lit and lunge_t <= 0.0:
		stuck_t = stuck_t + dt if flee_path.is_empty() else 0.0
		if stuck_t > 0.9 and lunge_cd <= 0.0 and dist <= 6:
			stuck_t = 0.0
			lunge_t = 0.85
			lunge_cd = lunge_cooldown
			flinch_t = 0.0
			Sfx.play_at("shriek", global_position + Vector3.UP * 1.5, 0.0, 0.1)
	else:
		stuck_t = 0.0

	if _arrived():
		var next: Variant = null
		if lunge_t > 0.0:
			next = level.next_step(tile, player_tile)
		elif lit:
			if _plan_escape(ex):
				next = flee_path[0]
				fled = true
			else:
				next = _darkest_neighbor(lv, ex)
		elif dist < chase_range and (lurk_t <= 0.0 or dist <= 2):
			next = level.next_step(tile, prey_tile)
		if next != null and (not _taken(next) or lunge_t > 0.0 or next == prey_tile):
			target = next
	elif speed > 0.0:
		_move(speed, dt)
		step_t -= dt
		if step_t <= 0.0:
			step_t = clampf(1.1 / speed, 0.18, 0.9)
			Sfx.play_at("mad_step_%d" % (randi() % 2), global_position, -6.0 if lit else 0.0, 0.15)
	if not lit and lunge_t <= 0.0 and victim == null:
		for q in get_tree().get_nodes_in_group("person"):
			if q.state == State.CURED and not q.waiting and q.held_by == null \
					and q.global_position.distance_to(global_position) < 0.95:
				victim = q
				q.grabbed_by(self)
				break
	if (not lit or lunge_t > 0.0) and global_position.distance_to(player.global_position) < 0.95:
		if player.grab_cooldown <= 0.0:
			player.grabbed(person_name)
			lunge_t = 0.0
			flinch_t = 1.6     # 붙잡은 뒤에는 잠깐 물러서서 플레이어에게 틈을 준다
			rush_t = 0.0
			pause_t = 1.6
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

## 플레이어 눈에 보이지 않고(벽에 가림) 어두운 가장 가까운 칸을 찾아 flee_path에 길을 넣는다.
## 플레이어 칸과 그 바로 옆은 지나가지 않는다(플레이어를 스치며 도망치지 않게).
const DIRS4 := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
func _plan_escape(ex: Array[RID]) -> bool:
	flee_path.clear()
	var ptile := level.to_tile(player.global_position)
	var eye: Vector3 = player.head.global_position
	var see_ex: Array[RID] = [get_rid(), player.get_rid()]
	var prev := {tile: tile}
	var queue: Array[Vector2i] = [tile]
	var i := 0
	while i < queue.size() and i < escape_search:
		var cur: Vector2i = queue[i]
		i += 1
		if cur != tile:
			var c := level.tile_center(cur)
			var hidden := not LightSystem.ray_clear(eye, c + Vector3(0, 1.2, 0), see_ex)
			if hidden and LightSystem.light_at(c, ex) < LightSystem.LIT_THRESHOLD:
				var path: Array[Vector2i] = []
				var k := cur
				while k != tile:
					path.push_front(k)
					k = prev[k]
				flee_path = path
				return true
		var dirs := DIRS4.duplicate()
		dirs.shuffle()
		for d in dirs:
			var n: Vector2i = cur + d
			if prev.has(n) or n == ptile or not level.is_walkable(n) or _taken(n):
				continue
			if n.distance_to(ptile) < 1.5 and tile.distance_to(ptile) >= 1.5:
				continue
			prev[n] = cur
			queue.append(n)
	return false

## 석상마다 다른 자세로 굳어 있다: 고개 숙임·꺾임, 한쪽 팔을 앞으로 뻗음 등
func _random_statue_pose() -> void:
	var r := randf()
	pose = {
		"Head": Vector3(randf_range(-0.1, 0.45), randf_range(-0.5, 0.5), randf_range(-0.35, 0.35)),
		"ArmXp": Vector3(randf_range(0.0, 1.4) if r < 0.4 else randf_range(-0.1, 0.3), 0, randf_range(-0.15, 0.05)),
		"ArmXn": Vector3(randf_range(0.0, 1.4) if r > 0.7 else randf_range(-0.1, 0.3), 0, randf_range(-0.05, 0.15)),
		"LegXp": Vector3(randf_range(-0.25, 0.25), 0, 0),
		"LegXn": Vector3(randf_range(-0.25, 0.25), 0, 0),
	}
	_apply_pose()

func _apply_pose() -> void:
	for k in pose:
		if parts.has(k):
			parts[k].rotation = pose[k]

func _face(p: Vector3) -> void:
	var to := p - global_position
	to.y = 0
	if to.length() > 0.1:
		look_at(global_position + to.normalized(), Vector3.UP)

func _cured(dt: float) -> void:
	if held_by != null or held_t > 0.0:
		_held(dt)
		return
	if not _arrived():
		_move(walk_out_speed, dt)
		return
	if wander:
		if tile == wander_target:
			wander = false
			body_t = 0.0
			_set_state(State.STATUE)   # 어둠 속에서 다시 굳는다
			Sfx.play_at("petrify", global_position + Vector3.UP, -3.0)
			return
		var nx: Variant = level.next_step(tile, wander_target)
		if nx != null:
			target = nx
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

## 광인이 어둠 속에서 홀로 걸어가던 사람을 붙잡는다. 붙잡힌 사람은 주저앉아 소리치고,
## hold_petrify초 동안 굳어 간다. 그 안에 빛이 닿으면 다시 일어나 걷고, 못 오면 석상이 된다.
func grabbed_by(mad: Node) -> void:
	held_by = mad
	Sfx.play_at("grab", global_position + Vector3.UP, 0.0, 0.1)
	GameState.speak(global_position, HELP_LINES.pick_random(), 30.0)   # 멀리서도 들림

func _held(dt: float) -> void:
	if held_by != null and (not is_instance_valid(held_by) or held_by.state != State.MAD \
			or held_by.global_position.distance_to(global_position) > 1.6):
		held_by = null
	var lit := LightSystem.is_lit(global_position, [get_rid()])
	if lit or held_by == null:
		held_t -= dt * 1.5
	else:
		held_t += dt
	mats[0].albedo_color = Color.WHITE.lerp(STONE_TINT, clampf(held_t / hold_petrify, 0.0, 1.0))
	if held_t >= hold_petrify:
		held_t = 0.0
		if held_by:
			held_by.victim = null
		held_by = null
		global_position = level.tile_center(tile)
		target = tile
		body_t = 0.0
		_set_state(State.STATUE)
		Sfx.play_at("petrify", global_position + Vector3.UP, -3.0)
	elif held_t <= 0.0:
		held_t = 0.0
		if held_by == null:
			mats[0].albedo_color = Color.WHITE   # 다시 일어나 입구로

## 사건: 홀에서 기다리던 사람이 누군가를 찾으러 어둠 속으로 걸어간다
func wander_off(to: Vector2i) -> void:
	waiting = false
	wander = true
	wander_target = to
	global_position = level.tile_center(level.entrance_tile)
	tile = level.entrance_tile
	target = tile
	set_process(true)
	GameState.rescued -= 1

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
	# 사람 한 명당 재질 하나(모든 부위가 공유). 상태 색은 이 재질만 바꾸면 된다
	if mats.is_empty():
		var m: StandardMaterial3D = skin.duplicate() if skin else StandardMaterial3D.new()
		m.metallic = 0.0
		m.roughness = 1.0
		mats.append(m)
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = mats[0]
		mi.visibility_range_end = 34.0
		parts[mi.name] = mi if mi.get_parent() == model else mi.get_parent()
	for c in n.get_children():
		_collect_materials(c)
