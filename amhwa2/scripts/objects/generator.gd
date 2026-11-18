extends StaticBody3D
## 지하 비상발전기. 정전 때 자동으로 안 걸려서 수동 크랭크로 시동을 걸어야 한다 (2층의 "운전 수칙" 쪽지).
##
## 흐름
##  1. 크랭크에 대고 E를 길게 누른다. 혼자서는 안 돌아간다: need_people(3)명이 함께 돌려야 한다.
##     처음 잡으면 무전으로 마당의 사람들을 부른다 → 구해 둔 사람 중 최대 need_people명이 계단으로 내려와 크랭크를 잡는다.
##     플레이어도 E를 누르고 있는 동안은 한 명으로 센다 (대신 그동안 사람들을 지키지 못한다).
##  2. 돌리는 사람이 모자라면 멈춘다. 다 채워져 있는 동안만 progress가 오른다 (crank_seconds초).
##     돌리는 동안: 소리에 이 층의 광인이 몰려오고, 지하의 낡은 전구(flicker_light.gd)가 껌뻑이면서
##     어둠 속 석상들이 하나둘 몸만 풀려 광인이 된다. 광인은 크랭크를 돌리는 사람을 붙잡는다 → 플레이어가 빛·경광봉으로 지킨다.
##  3. 시동이 걸리면(running) 차단기(breaker.gd)를 층별로 하나씩 올릴 수 있다. 올린 층은 불이 들어온다.
##     한꺼번에는 못 올린다: 하나 올리면 settle_seconds 동안 부하가 안정되길 기다려야 한다. 어느 층부터 켤지는 플레이어가 고른다.
##  4. 모든 층에 불이 들어오면 엔딩 (main.gd).

@export var need_people := 3          ## 크랭크를 함께 돌려야 하는 사람 수 (플레이어 포함 가능)
@export var crank_seconds := 70.0     ## 다 채워진 채로 돌려야 하는 시간
@export var settle_seconds := 20.0    ## 차단기 하나를 올린 뒤 다음 것을 올릴 수 있을 때까지
@export var noise_every := 1.0        ## 돌리는 동안 이 간격으로 광인들이 소리를 듣는다
@export var crank_tiles: Array[Vector2i] = []   ## 내려온 사람들이 서는 칸 (크랭크 옆)
@export var recall_wait := 12.0       ## 사람이 모자랄 때 다시 부르기까지

var progress := 0.0          # 0~1
var running := false
var cranking := false        # 지금 실제로 돌아가는 중인가 (사람이 다 찼다)
var settle_t := 0.0
var _player_t := 0.0         # 플레이어가 E를 누르고 있으면 계속 채워진다
var _called := false
var _recall_t := 0.0
var _noise_t := 0.0
var _said_need := 0.0
var _crank: Node3D
var _hum: AudioStreamPlayer3D

func _ready() -> void:
	add_to_group("generator")
	_crank = get_node_or_null("Crank")
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = load("res://sounds/elevator_buzz.wav")
	_hum.volume_db = -4.0
	_hum.unit_size = 6.0
	_hum.position = Vector3(0, 1, 0)
	add_child(_hum)

func level() -> Level:
	return get_parent().get_parent() as Level

## 지금 크랭크를 잡고 돌리는 사람 수 (내려온 사람 + E를 누르고 있는 플레이어)
func crankers() -> int:
	var n := 1 if _player_t > 0.0 else 0
	for p in _helpers():
		if p.cranking and p.held_by == null and p.held_t <= 0.0:
			n += 1
	return n

func _helpers() -> Array:
	var out := []
	var lv := level()
	if lv == null:
		return out
	for p in lv.get_node("People").get_children():
		if p.get("helper") and p.state == 2 and not p.is_queued_for_deletion():
			out.append(p)
	return out

## E를 누르고 있는 동안 매 프레임 불림
func hold(_seconds: float) -> bool:
	if running:
		return false
	_player_t = 0.25
	if not _called or (_helpers().size() + 1 < need_people and _recall_t <= 0.0):
		_call_help()
	return false

func release(_seconds: float) -> void:
	pass

func _call_help() -> void:
	_recall_t = recall_wait
	var main := get_tree().get_first_node_in_group("main")
	var want: int = need_people - _helpers().size()
	if main == null or want <= 0:
		return
	var free_tiles: Array[Vector2i] = []
	var used := {}
	for p in _helpers():
		used[p.crank_tile] = true
	for t in crank_tiles:
		if not used.has(t):
			free_tiles.append(t)
	var came: int = main.call_helpers(level(), mini(want, free_tiles.size()), free_tiles, self)
	if came > 0:
		GameState.say("“발전기실이에요. 돌릴 사람이 필요해요.”\n무전을 듣고 마당에서 %d명이 내려온다." % came)
	elif not _called or _helpers().is_empty():
		GameState.say("혼자서는 꿈쩍도 하지 않는다.\n마당에 구해 둔 사람이 있어야 한다. (%d명이 함께 돌려야 한다)" % need_people)
	_called = true

func get_hint() -> String:
	if running:
		return ""
	return "E 길게 · 크랭크 돌리기  (%d / %d명)" % [crankers(), need_people]

func _process(dt: float) -> void:
	if GameState.is_frozen():
		return
	_player_t = maxf(0.0, _player_t - dt)
	_recall_t = maxf(0.0, _recall_t - dt)
	settle_t = maxf(0.0, settle_t - dt)
	if running:
		if not _hum.playing:
			_hum.play()   # 돌아가는 동안 계속 웅웅거린다
		return
	cranking = crankers() >= need_people
	if cranking:
		progress = minf(1.0, progress + dt / crank_seconds)
		if _crank:
			_crank.rotate_x(dt * (2.0 + progress * 6.0))
		if not _hum.playing:
			_hum.play()
		_hum.pitch_scale = 0.5 + progress * 0.6
		# 소리: 이 층의 광인이 발전기 쪽으로 몰려온다
		_noise_t -= dt
		if _noise_t <= 0.0:
			_noise_t = noise_every
			var lv := level()
			var here := lv.to_tile(global_position)
			for p in lv.get_node("People").get_children():
				if p.state == 1:
					p.noise_tile = here
					p.noise_t = noise_every + 1.0
		if progress >= 1.0:
			_start()
	else:
		if _hum.playing:
			_hum.stop()
		progress = maxf(0.0, progress - dt / crank_seconds * 0.25)   # 손을 놓으면 천천히 식는다
		if _player_t > 0.0:
			_said_need -= dt
			if _said_need <= 0.0 and _called:
				_said_need = 6.0
				GameState.say("아직 모자라다. (%d / %d명)" % [crankers(), need_people])

func _start() -> void:
	running = true
	cranking = false
	settle_t = 0.0
	_hum.pitch_scale = 1.15
	_hum.volume_db = -1.0
	if not _hum.playing:
		_hum.play()
	Sfx.play_at("thud", global_position + Vector3.UP, 2.0, 0.0)
	GameState.say("발전기가 돈다.\n차단기를 층별로 하나씩 올려야 한다.")
