extends Node
## 튜토리얼 (첫 판만). 1층 씬에 노드로 둔다 (level_1f.tscn의 Tutorial).
## 마당 → 보급 선반 → 현관 → 로비 석상 → 남쪽 복도 → 엘리베이터 홀 동선을 따라 키를 하나씩 직접 눌러 보게 한다.
##
## 보이는 방식: 주인공이 혼잣말로 떠올리는 생각처럼, 화면 아래 자막 한 줄 + 그 위의 작은 키 표시뿐이다 (hud.gd).
##   화살표, 반짝이는 테두리, 일시정지 팝업은 쓰지 않는다 (숫자 없는 UI 원칙).
## 진행:
##   - 단계는 표(steps)의 순서대로. 지금 단계의 조건(when)을 플레이어가 실제로 채워야 다음으로 넘어간다 (시간으로 넘기지 않음).
##   - 안내를 띄운 뒤 remind_seconds(15초) 동안 조건을 못 채우면 같은 안내를 한 번 더 띄운다 (remind_times).
##     그 뒤에는 자막 없이 키 표시만 흐리게 남는다 → 안내를 놓쳤어도 뭘 눌러야 하는지는 보인다.
##   - 조건은 판이 시작될 때부터 계속 지켜본다. 차례가 오기 전에 이미 해 본 행동이면 그 단계는 안내 없이 건너뛴다.
##   - 광인·석상 규칙은 그대로 돈다. 로비의 석상 하나(statue)만 튜토리얼용으로 정해 두고, 그 석상은 붙잡지 않는다
##     (씬에서 grabber = 0). 빛을 받아 광인이 된 뒤로는 다른 광인과 똑같다.
##   - 처음 한 판만 나온다 (GameState.tutorial_seen, F9로 다시 시작해도 안 나옴. 게임을 껐다 켜면 다시 나온다).
## "처음 겪을 때만" 안내(first_hints)는 튜토리얼이 끝난 뒤에도, 다른 층에서도 한 번씩 나온다.
##   물건 쪽 스크립트가 GameState.first("종류")로 알리면 여기서 받아 띄운다. 이 노드가 든 1층이 씬 트리에서
##   떨어져 있어도(플레이어가 2층·지하에 있을 때) 신호는 받으니 동작한다.
##
## 단계 표의 항목 (인스펙터에서 문장·위치를 바꿀 수 있다):
##   keys     작은 키 표시. {액션이름}은 지금 키 설정(입력 맵)의 키 이름으로 바뀐다. 예: "{interact}" → E
##   text     자막. 여기서도 {액션이름}을 쓸 수 있다 ([V]처럼 대괄호가 붙는다)
##   when     넘어가는 조건: walk(걷기) / supply(선반에서 챙김) / lamp_on(헤드램프 켬) / zoom_both(휠을 양쪽으로)
##            / statue_mad(튜토리얼용 석상이 광인이 됨) / lantern_placed / lantern_picked / chem_thrown
##            / sprint(달리기) / timer(안내가 뜬 뒤 seconds초) / swing(경광봉 휘두름) / rest(홀에서 쉼) / pocket(주머니 확인)
##   tile, radius   이 칸에서 radius칸 안에 들어와야 안내가 뜬다. tile이 없으면 앞 단계가 끝나자마자 뜬다
##   walk     앞 단계를 끝낸 뒤 이만큼(m) 더 걸어야 뜬다 ("복도 중간쯤")
##   mad_near 광인이 이 거리(m) 안에 있어도 뜬다 (tile과 둘 중 하나만 맞으면 됨)
##   then     조건이 채워지는 순간 띄우는 한 줄
##   seconds  when이 timer일 때 기다리는 시간

@export var tutorial := true            ## 끄면 튜토리얼도, 처음 겪을 때 안내도 나오지 않는다
@export var first_hints_on := true      ## 처음 겪을 때만 나오는 안내 (튜토리얼이 끝난 뒤에도)
@export var statue: NodePath            ## 튜토리얼용 석상 (로비). 이 석상은 붙잡지 않는다
@export var statue_line_range := 12.0   ## 석상이 광인이 되는 순간의 한 줄은 이 거리(m) 안에서 봤을 때만 띄운다
@export_group("시간")
@export var start_delay := 6.5          ## 시작 연출이 끝난 뒤 첫 안내까지 (목표 자막이 먼저 지나가게)
@export var tip_seconds := 6.0          ## 안내 자막이 떠 있는 시간
@export var line_gap := 3.0             ## 안내와 안내 사이 최소 간격 (앞 자막을 읽을 틈)
@export var remind_seconds := 15.0      ## 이만큼 지나도 조건을 못 채우면 같은 안내를 다시 띄운다
@export var remind_times := 1           ## 다시 띄우는 횟수
@export var message_wait := 2.5         ## 다른 자막(생각, 들리는 말)이 뜬 직후에는 이만큼 기다렸다가 안내를 띄운다
@export_group("조건 수치")
@export var walk_meters := 2.0          ## walk: 이만큼 걸으면
@export var sprint_seconds := 2.0       ## sprint: 이만큼 달리면 (합쳐서)
@export var rest_seconds := 3.0         ## rest: 홀에 이만큼 머물면 (합쳐서)
@export_group("")
@export var steps: Array[Dictionary] = [
	{"keys": "{move_forward}{move_left}{move_back}{move_right}", "text": "몸이 아직 움직인다.", "when": "walk"},
	{"keys": "{interact}", "text": "챙길 수 있는 건 챙기자.", "when": "supply", "tile": Vector2i(16, 20), "radius": 5.0},
	{"keys": "{toggle_lamp}", "text": "안은 깜깜하다. 헤드램프를 켜자.", "when": "lamp_on", "tile": Vector2i(19, 19), "radius": 2.0},
	{"keys": "마우스 휠", "text": "빛을 모으면 멀리, 퍼뜨리면 넓게 보인다.", "when": "zoom_both", "tile": Vector2i(19, 16), "radius": 1.5},
	{"keys": "", "text": "빛을 비추면 굳은 사람이 풀린다. 계속 비춰 보자.", "when": "statue_mad", "tile": Vector2i(21, 14), "radius": 3.0,
		"then": "정신은 아직이다. 빛을 피해 도망친다."},
	{"keys": "{lantern}", "text": "랜턴을 내려놓으면 그 자리는 계속 밝다.", "when": "lantern_placed"},
	{"keys": "{lantern}", "text": "다시 주울 수도 있다. 개수가 많지 않다.", "when": "lantern_picked"},
	{"keys": "{throw}", "text": "케미라이트를 던져 두면 돌아올 길이 보인다.", "when": "chem_thrown", "tile": Vector2i(19, 12), "radius": 2.0},
	{"keys": "{sprint}", "text": "달리면 빠르지만 발소리가 크다. 숨도 찬다.", "when": "sprint", "walk": 8.0},
	{"keys": "", "text": "막대가 다 떨어지면 한동안 못 뛴다. 몸이 굳으면 막대도 짧아진다.", "when": "timer", "seconds": 4.0},
	{"keys": "{swing} · {shove}", "text": "{swing} 휘둘러서 밀어낼 수 있다. {shove} 붙잡히면 밀쳐 낸다.", "when": "swing",
		"tile": Vector2i(19, 6), "radius": 3.0, "mad_near": 8.0},
	{"keys": "", "text": "여기는 비상 전원이 들어온다. 쉬면 몸이 풀리고 배터리가 찬다.", "when": "rest", "tile": Vector2i(18, 3), "radius": 1.5},
	{"keys": "{check_pocket}", "text": "주머니에 남은 걸 확인할 수 있다. 길게 누르면 붕대를 감는다.", "when": "pocket"},
]
@export var end_text := "사람들을 깨워 마당으로 데리고 나가야 한다."   ## 마지막 단계가 끝나면 띄우는 한 줄
## 처음 겪을 때만 한 번씩. on = GameState.first()로 오는 종류
##   grabbed(player.gd 붙잡힘) / hurt(다쳤고 붕대가 있음) / locked_door(door.gd) / note(note.gd) / surgical_box(surgical_light.gd)
@export var first_hints: Array[Dictionary] = [
	{"on": "grabbed", "keys": "{shove}", "text": "밀쳐 내야 한다."},
	{"on": "hurt", "keys": "{check_pocket} 길게", "text": "붕대를 감자."},
	{"on": "locked_door", "keys": "", "text": "직원 열쇠가 있어야 한다. 구한 간호사나 경비가 가지고 있을지도."},
	{"on": "note", "keys": "{interact}", "text": "쪽지를 읽는다."},
	{"on": "surgical_box", "keys": "{interact} 길게", "text": "헤드램프 배터리를 옮겨 꽂을 수 있다. 내 빛은 그만큼 약해진다."},
]

var active := false           # 단계 안내가 돌고 있나
var index := 0                # 지금 단계 (steps의 번호)
var shown := false            # 지금 단계의 안내를 띄웠나
var done := {}                # 채워진 조건 (when 이름 → true)
var said: Array[String] = []  # 지금까지 띄운 안내 문장 (자동 점검에서 확인)

var player: Node
var level: Level
var _statue: Node
var _shelf: Node
var _set := false
var _started := false
var _tile_m := 2.0            # 한 칸의 길이(m)
var _next_free_ms := 0        # 이 시각 전에는 새 안내를 띄우지 않는다 (앞 자막과 겹치지 않게)
var _first_shown_ms := 0
var _shown_ms := 0
var _reminds := 0
var _step_walk := 0.0         # 지금 단계가 된 뒤 걸은 거리
# 조건을 지켜보는 값
var _last_pos := Vector3.ZERO
var _walked := 0.0
var _sprint_t := 0.0
var _rest_t := 0.0
var _shelf_total := 0
var _zoom := 0.0
var _zoom_up := false
var _zoom_down := false
var _placed := 0
var _held := 0
var _chems := 0

func _ready() -> void:
	GameState.first_time.connect(_on_first)
	GameState.message.connect(_on_message)
	if tutorial and not GameState.tutorial_seen:
		begin()

## 튜토리얼 시작 (자동 점검에서도 직접 부른다)
func begin() -> void:
	active = true
	index = 0
	shown = false
	done = {}
	said = []
	_set = false
	_started = false
	_reminds = 0
	_step_walk = 0.0
	_walked = 0.0
	_sprint_t = 0.0
	_rest_t = 0.0
	_zoom_up = false
	_zoom_down = false
	GameState.tutorial_seen = true   # 처음 한 판만: 시작하는 순간 본 것으로 친다
	GameState.tutorial_on = true
	_setup.call_deferred()           # 플레이어는 층보다 늦게 준비되니 한 박자 뒤에

func _setup() -> void:
	player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	level = get_parent() as Level
	if player == null or level == null:
		active = false   # 이 층에서 시작하지 않은 판 (개발용 start_floor): 단계 안내는 하지 않는다
		GameState.tutorial_on = false
		return
	_tile_m = level.tile_center(Vector2i(1, 0)).x - level.tile_center(Vector2i(0, 0)).x
	_statue = get_node_or_null(statue)
	if _statue:
		_statue.grabber = 0          # 튜토리얼용 석상은 붙잡지 않는다
	else:
		done["statue_mad"] = true    # 석상을 정해 두지 않았으면 그 단계는 건너뛴다
	for s in get_tree().get_nodes_in_group("supply"):
		if level.is_ancestor_of(s):
			_shelf = s
	# 헤드램프는 꺼진 채로 시작한다. 마당은 달빛이 있어 켤 필요가 없고, 그래야 현관 앞에서 "켜자"가 말이 된다
	player.headlamp.on = false
	_shelf_total = _shelf.total() if _shelf else 0
	_zoom = player.headlamp.zoom
	_placed = player.placed_lanterns.size()
	_held = player.lanterns_held
	_chems = player.chemlights
	_last_pos = player.global_position
	_set = true

func _exit_tree() -> void:
	# 플레이어가 다른 층으로 갔다 (이 층은 떼어 둔 채 멈춘다): 흐리게 남겨 둔 키 표시를 지우고, 돌아오면 다시 띄운다
	if active and shown:
		GameState.clear_tip()
		shown = false

func _process(dt: float) -> void:
	if not active or not _set or GameState.is_frozen():
		return
	var now := Time.get_ticks_msec()
	if not _started:   # 시작 연출이 끝난 첫 순간
		_started = true
		_next_free_ms = maxi(_next_free_ms, now + int(start_delay * 1000.0))
		_last_pos = player.global_position
	_track(dt)
	while index < steps.size() and _is_done(steps[index], now):
		_advance()
	if index >= steps.size():
		_finish()
		return
	var s := steps[index]
	if now < _next_free_ms:
		return
	if not shown:
		if _triggered(s):
			_show(s, now)
	elif _reminds < remind_times and now - _shown_ms >= int(remind_seconds * 1000.0):
		_reminds += 1
		_show(s, now)

# ---------- 단계 ----------
func _is_done(s: Dictionary, now: int) -> bool:
	var when: String = s.get("when", "")
	if when == "timer":   # 설명만 하는 단계: 안내가 뜬 뒤 정해진 시간이 지나면
		return shown and now - _first_shown_ms >= int(float(s.get("seconds", 4.0)) * 1000.0)
	return done.has(when)

func _advance() -> void:
	if shown:
		GameState.clear_tip()
	index += 1
	shown = false
	_reminds = 0
	_step_walk = 0.0

func _finish() -> void:
	active = false
	if end_text != "":
		_line_later("", end_text)

## 안내를 띄울 자리에 왔나
func _triggered(s: Dictionary) -> bool:
	if _step_walk < float(s.get("walk", 0.0)):
		return false
	var tile: Vector2i = s.get("tile", Vector2i(-1, -1))
	var mad: float = s.get("mad_near", 0.0)
	if tile.x < 0 and mad <= 0.0:
		return true
	var pos: Vector3 = player.global_position
	if tile.x >= 0:
		var c := level.tile_center(tile)
		if Vector2(pos.x - c.x, pos.z - c.z).length() <= float(s.get("radius", 1.5)) * _tile_m:
			return true
	if mad > 0.0:
		for p in level.get_node("People").get_children():
			if p.state == 1 and p.global_position.distance_to(pos) < mad:
				return true
	return false

func _show(s: Dictionary, now: int) -> void:
	var text := _fmt(s.get("text", ""), true)
	GameState.show_tip(_fmt(s.get("keys", ""), false), text, tip_seconds, true)
	if not shown:
		_first_shown_ms = now
	shown = true
	_shown_ms = now
	_next_free_ms = now + int(line_gap * 1000.0)
	said.append(text)

## 조건이 채워졌다. 그 조건의 단계에 then이 있으면 그 순간 한 줄 띄운다 (차례가 아직 안 온 단계여도).
## quiet면 조용히 표시만 한다 (플레이어가 보지 못한 곳에서 일어난 일)
func _mark(cond: String, quiet := false) -> void:
	if done.has(cond):
		return
	done[cond] = true
	if quiet:
		return
	for s in steps:
		if s.get("when", "") == cond and s.get("then", "") != "":
			var text := _fmt(s["then"], true)
			GameState.show_tip("", text, tip_seconds, false)
			_next_free_ms = Time.get_ticks_msec() + int((line_gap + 1.0) * 1000.0)
			said.append(text)

## 플레이어가 한 일을 판이 시작될 때부터 계속 지켜본다 (단계 순서와 상관없이)
func _track(dt: float) -> void:
	var pos: Vector3 = player.global_position
	var d := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos
	if d < 1.0:   # 한 프레임에 1m 넘게 움직였으면 층 이동·교대로 옮겨진 것이라 걸은 걸로 치지 않는다
		_walked += d
		_step_walk += d
	if _walked >= walk_meters:
		_mark("walk")
	if _shelf and is_instance_valid(_shelf) and _shelf.total() < _shelf_total:
		_mark("supply")
	var lamp = player.headlamp
	if lamp.on:
		_mark("lamp_on")
	if lamp.zoom > _zoom + 0.001:
		_zoom_up = true
	elif lamp.zoom < _zoom - 0.001:
		_zoom_down = true
	_zoom = lamp.zoom
	if _zoom_up and _zoom_down:
		_mark("zoom_both")
	if _statue and is_instance_valid(_statue) and _statue.state != 0:
		_mark("statue_mad", _statue.global_position.distance_to(pos) > statue_line_range)   # 멀리서 다른 빛에 깨어났으면 한 줄은 생략
	# 랜턴: 놓으면 놓인 수가 늘고 든 수가 준다. 주우면 그 반대 (선반에서 챙길 때는 든 수만 는다)
	var placed: int = player.placed_lanterns.size()
	var held: int = player.lanterns_held
	if placed > _placed and held < _held:
		_mark("lantern_placed")
	elif placed < _placed and held > _held:
		_mark("lantern_picked")
	_placed = placed
	_held = held
	if player.chemlights < _chems and player.toss_t > 0.0:
		_mark("chem_thrown")
	_chems = player.chemlights
	if player.sprinting:
		_sprint_t += dt
		if _sprint_t >= sprint_seconds:
			_mark("sprint")
	if player.swing_t > 0.0 and player.swing_kind == 1:
		_mark("swing")
	if level.has_rest() and level.to_tile(pos).distance_to(level.entrance_tile) < 1.5:   # player.gd의 "홀에서 쉬는 중"과 같은 판정
		_rest_t += dt
		if _rest_t >= rest_seconds:
			_mark("rest")
	if Input.is_action_just_pressed("check_pocket"):
		_mark("pocket")

# ---------- 처음 겪을 때만 ----------
func _on_first(kind: String) -> void:
	GameState.hints_seen[kind] = true   # 안내를 꺼 둔 경우에도 표시해 둬야 다시 알리지 않는다
	if not tutorial or not first_hints_on:
		return
	for h in first_hints:
		if h.get("on", "") == kind:
			_line_later(_fmt(h.get("keys", ""), false), _fmt(h.get("text", ""), true))
			return

## 다른 자막(주인공의 생각, 들리는 말)이 막 떴으면 안내는 잠깐 기다린다. 같은 자리에 뜨기 때문
func _on_message(_text: String) -> void:
	_next_free_ms = maxi(_next_free_ms, Time.get_ticks_msec() + int(message_wait * 1000.0))

## 앞 안내와 겹치지 않게 차례를 잡아 띄운다. 이 노드가 트리에서 떨어져 있어도(다른 층) 되게 씬 트리의 타이머를 쓴다
func _line_later(keys: String, text: String) -> void:
	var now := Time.get_ticks_msec()
	var at := maxi(now, _next_free_ms)
	_next_free_ms = at + int(line_gap * 1000.0)
	said.append(text)
	if at <= now:
		GameState.show_tip(keys, text, tip_seconds, false)
	else:
		GameState.get_tree().create_timer((at - now) / 1000.0).timeout.connect(GameState.show_tip.bind(keys, text, tip_seconds, false))

# ---------- 키 이름 ----------
## 문장 안의 {액션이름}을 지금 키 설정의 키 이름으로 바꾼다. 나중에 키를 바꿔도 안내가 따라간다
func _fmt(s: String, brackets: bool) -> String:
	for a in InputMap.get_actions():
		var token := "{%s}" % a
		if s.contains(token):
			s = s.replace(token, ("[%s]" % key_name(a)) if brackets else key_name(a))
	return s

func key_name(action: StringName) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode if e.physical_keycode != 0 else e.keycode)
		if e is InputEventMouseButton:
			return {MOUSE_BUTTON_LEFT: "좌클릭", MOUSE_BUTTON_RIGHT: "우클릭", MOUSE_BUTTON_MIDDLE: "휠 클릭"}.get(e.button_index, "마우스")
	return String(action)

## 스크린샷·자동 점검용: n번째 단계(0부터)의 안내를 바로 띄운다
func preview(n: int) -> void:
	var s := steps[clampi(n, 0, steps.size() - 1)]
	GameState.show_tip(_fmt(s.get("keys", ""), false), _fmt(s.get("text", ""), true), tip_seconds, true)
