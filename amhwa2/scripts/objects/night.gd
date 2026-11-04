extends Node
## 하룻밤. 게임 전체가 새벽 2시 10분부터 해가 뜰 때까지다.
##  - 남은 시간은 HUD 숫자로 보이지 않는다. 벽시계(clock.gd)와 점점 밝아지는 창밖 하늘로만 보인다.
##  - 시간은 넉넉하게 준다. 압박은 배터리와 굳음이 맡는다.
##  - 해가 뜨면 차광막을 걷어 둔 방(과 마당)의 사람은 햇빛을 받아 저절로 깨어난다. 햇빛은 구원이다.
##    그때까지 현관 밖으로 데려온 사람 수가 결과가 된다.
## 시작 연출·쪽지 읽는 동안(is_frozen)은 시간이 멈춘다.

@export var night_seconds := 1500.0    ## 하룻밤의 실제 길이(초). 25분 (1층 15~20분 + 2층). 지하가 생기면 40~50분으로
@export var clock_start := 130.0       ## 시작 시각 (자정부터 분). 130 = 02:10 (시작 연출과 맞춤)
@export var clock_dawn := 340.0        ## 해 뜨는 시각. 340 = 05:40
@export var sky_curve := 2.2           ## 하늘이 밝아지는 모양. 클수록 밤 내내 어둡다가 끝에 몰아서 밝아짐
@export var moon_warm := Color(1.0, 0.72, 0.5)   ## 해 뜰 무렵 창·마당 빛의 색
@export var sun_color := Color(1.0, 0.86, 0.66)  ## 해가 떴을 때 창으로 드는 햇빛
@export var sun_energy := 3.0

var t := 0.0
var sky_mat: ShaderMaterial
var moons: Array = []          # [빛, 처음 색, 처음 세기]
var dawned := false

func _ready() -> void:
	add_to_group("night")
	_late.call_deferred()

func _late() -> void:
	var env := get_tree().get_first_node_in_group("world_env") as WorldEnvironment
	if env and env.environment and env.environment.sky:
		sky_mat = env.environment.sky.sky_material as ShaderMaterial
	for l in get_tree().get_nodes_in_group("moon"):
		moons.append([l, l.light_color, l.light_energy])
	for c in get_tree().get_nodes_in_group("curtain"):
		moons.append([c.moon, c.moon.light_color, c.moon.light_energy])
	_apply()

func _process(dt: float) -> void:
	if dawned or GameState.is_frozen():
		return
	t += dt
	_apply()
	if GameState.night_k >= 1.0:
		sunrise()

## 시간을 직접 옮긴다 (자동 점검, 개발용)
func set_progress(k: float) -> void:
	t = clampf(k, 0.0, 1.0) * night_seconds
	_apply()

func _apply() -> void:
	var k := clampf(t / night_seconds, 0.0, 1.0)
	GameState.night_k = k
	GameState.clock_minutes = lerpf(clock_start, clock_dawn, k)
	var sky_k := pow(k, sky_curve)
	if sky_mat:
		sky_mat.set_shader_parameter("dawn", sky_k)
	# 창으로 드는 달빛, 마당의 달빛: 끝 무렵 조금씩 붉어지고 밝아진다
	for m in moons:
		if is_instance_valid(m[0]):
			m[0].light_color = (m[1] as Color).lerp(moon_warm, sky_k * 0.8)
			m[0].light_energy = m[2] * (1.0 + sky_k * 0.6)

## 해돋이: 햇빛이 닿는 칸(차광막을 걷은 방, 마당)에 있는 사람은 깨어나고, 결과 화면으로 간다
func sunrise() -> void:
	if dawned:
		return
	dawned = true
	GameState.night_k = 1.0
	GameState.clock_minutes = clock_dawn
	if sky_mat:
		sky_mat.set_shader_parameter("dawn", 1.0)
	# 모든 층을 센다. 플레이어가 없는 층은 트리 밖이라 그룹으로 못 찾으니 main.gd에서 층마다 꺼낸다
	var main := get_tree().get_first_node_in_group("main")
	var floors: Array = main.all_levels() if main else [get_tree().get_first_node_in_group("level")]
	var cured := 0
	var left := 0
	for level in floors:
		var sun := {}
		var curtains = level.get_node_or_null("Curtains")
		if curtains:
			for c in curtains.get_children():
				if c.open:
					c.moon.light_color = sun_color
					c.moon.light_energy = sun_energy
					for tl in c.sun_tiles:
						sun[tl] = true
		var live: bool = level.is_inside_tree()
		var ppl: Array = main.people_of(level) if main else get_tree().get_nodes_in_group("person")
		for p in ppl:
			if p.waiting or p.get("counted") or p.is_queued_for_deletion():   # 이미 구출로 센 사람(현관 앞에서 나가던 중 포함)
				continue
			var in_sun: bool = sun.has(p.tile) or level.is_outdoor(p.tile)
			if p.state == p.State.CURED:
				cured += 1          # 이미 정신이 돌아와 걸어 나오던 사람: 해가 떴으니 무사하다
			elif in_sun:
				if live:            # 눈앞의 층이면 실제로 깨어나는 모습을 보여 준다
					p.held_by = null
					p.held_t = 0.0
					p._set_state(p.State.CURED)
				cured += 1
			else:
				left += 1
	GameState.dawn_cured = cured
	GameState.dawn_left = left
	GameState.night_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.state_changed.emit()
